#Requires -RunAsAdministrator
<#
.SYNOPSIS
    处理 VMnet1 与物理局域网网段冲突导致的虚拟机「无 Internet」。

.DESCRIPTION
    对应 README 问题 3 的方案 A（临时缓解）。

    原理：当 VMware 的仅主机网络 VMnet1 与物理局域网处于同一网段时，
          路由表中会出现一条指向 VMnet1 的 /32 主机路由，其优先级高于
          默认路由。此时：

            - Windows 解析器会把 DNS 查询绑定到「持有该 DNS 服务器的网卡」
              （即物理网卡），因此宿主机自身的域名解析仍然正常；
            - 但 VMware NAT 服务使用普通 socket，按路由表选路，会被该 /32
              路由导向 VMnet1，无法访问上游 DNS；
            - 结果：客户机拿到 IP、也有网关，但 DNS 不通，表现为「无 Internet」
              （Windows 11 OOBE 中的错误码为 0x80070015）。

    本脚本为临时缓解：为上游 DNS 服务器添加一条指向物理网卡的高优先级路由，
    并重启 VMware 虚拟网络服务。该路由存放在 ActiveStore，**重启后失效**。

    根治方案是在「虚拟网络编辑器」中把 VMnet1 改到不与物理局域网冲突的网段。

.PARAMETER DnsServer
    被路由劫持的上游 DNS 服务器地址，通常就是物理网关。

.PARAMETER HostAdapterName
    承载实际上网流量的物理网卡名称，默认 WLAN。

.PARAMETER SkipServiceRestart
    只添加路由，不重启 VMware 虚拟网络服务。

.EXAMPLE
    .\Repair-VMnet1Conflict.ps1 -DnsServer 192.168.31.1 -HostAdapterName WLAN

.NOTES
    脚本不会修改 VMnet1 的网段配置，也不会改动虚拟机文件。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DnsServer,
    [string]$HostAdapterName = 'WLAN',
    [switch]$SkipServiceRestart
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin  = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw '需要以管理员身份运行本脚本。' }

Write-Host '== 1/4 处理前的路由状态 ==' -ForegroundColor Cyan
$existing = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "$DnsServer/32" -ErrorAction SilentlyContinue
if ($existing) {
    $existing | ForEach-Object { Write-Host ("  {0} -> {1} (metric {2})" -f $_.DestinationPrefix, $_.InterfaceAlias, $_.RouteMetric) }
} else {
    Write-Host '  未发现该地址的 /32 路由。'
}

$hostAdapter = Get-NetAdapter -Name $HostAdapterName -ErrorAction SilentlyContinue
if (-not $hostAdapter) {
    throw "找不到物理网卡：$HostAdapterName。请用 Get-NetAdapter 确认名称后通过 -HostAdapterName 指定。"
}
Write-Host ("  物理网卡 {0} (ifIndex {1})" -f $hostAdapter.Name, $hostAdapter.ifIndex)

Write-Host '== 2/4 添加高优先级路由 ==' -ForegroundColor Cyan
# 幂等：先移除本脚本可能留下的同名路由
Remove-NetRoute -DestinationPrefix "$DnsServer/32" -InterfaceIndex $hostAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
try {
    New-NetRoute -DestinationPrefix "$DnsServer/32" -InterfaceIndex $hostAdapter.ifIndex `
                 -NextHop '0.0.0.0' -RouteMetric 1 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null
    Write-Host '  已添加 on-link 路由（metric 1）'
} catch {
    Write-Host "  on-link 方式失败，尝试指定网关：$($_.Exception.Message)" -ForegroundColor Yellow
    New-NetRoute -DestinationPrefix "$DnsServer/32" -InterfaceIndex $hostAdapter.ifIndex `
                 -NextHop $DnsServer -RouteMetric 1 -PolicyStore ActiveStore | Out-Null
    Write-Host '  已添加路由（metric 1）'
}

Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "$DnsServer/32" -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("  {0} -> {1} (metric {2})" -f $_.DestinationPrefix, $_.InterfaceAlias, $_.RouteMetric) }

if (-not $SkipServiceRestart) {
    Write-Host '== 3/4 重启 VMware 虚拟网络服务（使 NAT 重新探测上游 DNS） ==' -ForegroundColor Cyan
    foreach ($svc in @('VMnetDHCP', 'VMware NAT Service')) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if (-not $s) { Write-Warning "  未找到服务：$svc"; continue }
        try {
            Restart-Service -Name $svc -Force -ErrorAction Stop
            Write-Host "  已重启 $svc"
        } catch {
            Write-Warning "  $svc 重启失败：$($_.Exception.Message)"
        }
        Start-Sleep -Seconds 3
    }
} else {
    Write-Host '== 3/4 已跳过服务重启 ==' -ForegroundColor DarkGray
}

Write-Host '== 4/4 验证 ==' -ForegroundColor Cyan
Write-Host '  --- 直连上游 DNS 解析测试 ---'
$result = & nslookup www.msftconnecttest.com $DnsServer 2>&1 | Out-String
$result.Trim() -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host '若上方返回了解析结果，说明 DNS 路径已恢复，虚拟机的「无 Internet」状态应随之消失。' -ForegroundColor Green
Write-Host '注意：本路由位于 ActiveStore，重启宿主机后失效。' -ForegroundColor Yellow
Write-Host '根治方法：Workstation → 编辑 → 虚拟网络编辑器 → 更改设置 → 选中 VMnet1 →' -ForegroundColor Yellow
Write-Host '          将子网 IP 改为不与物理局域网冲突的网段（如 192.168.70.0/24）→ 应用。' -ForegroundColor Yellow
