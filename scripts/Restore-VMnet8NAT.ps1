#Requires -RunAsAdministrator
<#
.SYNOPSIS
    重建 VMware 的 NAT 网络（vmnet8）配置并恢复相关服务。

.DESCRIPTION
    对应 README 问题 8。

    现象：宿主机重启后，客户机仍能取得 IP，但无法访问互联网。检查发现：
      - VMware NAT Service 的启动类型被改为 Disabled，服务未运行
      - C:\ProgramData\VMware\vmnetnat.conf 文件丢失
      - 注册表 ...\VMnetConfig\vmnet8 下 IPSubnetAddress / NAT / DHCP 配置丢失
      - netmap.conf 中 vmnet8 的类型名被重置（应为 "NAT"；vmnet0 应为 "Bridged"）

    本脚本按上述四项逐一恢复，并重建虚拟网络、启动服务。

.PARAMETER SubnetBase
    NAT 网络网段，默认 192.168.139.0（对应子网掩码 255.255.255.0）。
    若你的 vmnet8 使用其他网段，请通过本参数指定。

.PARAMETER VnetlibPath
    vnetlib64.exe 的完整路径，默认 D:\vnetlib64.exe。

.PARAMETER SkipVnetRebuild
    只恢复配置文件与服务启动类型，不执行 vnetlib64 -- stop / -- start。

.EXAMPLE
    .\Restore-VMnet8NAT.ps1

.EXAMPLE
    .\Restore-VMnet8NAT.ps1 -SubnetBase 192.168.139.0

.NOTES
    执行 vnetlib64 -- stop 会短暂中断所有 VMware 虚拟网络。
    请先关闭正在运行的虚拟机，或在可接受网络闪断的时机执行。
#>
[CmdletBinding()]
param(
    [string]$SubnetBase   = '192.168.139.0',
    [string]$VnetlibPath  = 'D:\vnetlib64.exe',
    [switch]$SkipVnetRebuild
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin  = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw '需要以管理员身份运行本脚本。' }

$mask      = '255.255.255.0'
$gateway   = ($SubnetBase -replace '\.0$', '.2')
$hostAddr  = ($SubnetBase -replace '\.0$', '.1')
$hostMac   = '00:50:56:C0:00:08'
$natConf   = 'C:\ProgramData\VMware\vmnetnat.conf'
$netmap    = 'C:\ProgramData\VMware\netmap.conf'
$regBase   = 'HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMnetLib\VMnetConfig'

Write-Host '== 1/6 恢复 vmnet8 注册表配置 ==' -ForegroundColor Cyan
$k8 = Join-Path $regBase 'vmnet8'
if (-not (Test-Path $k8)) { New-Item -Path $k8 -Force | Out-Null }
New-ItemProperty -Path $k8 -Name 'IPSubnetAddress' -Value $SubnetBase -PropertyType String -Force | Out-Null
New-ItemProperty -Path $k8 -Name 'IPSubnetMask'    -Value $mask       -PropertyType String -Force | Out-Null
foreach ($pair in @(@('NAT', 'UseNAT'), @('DHCP', 'UseDHCP'), @('Adapter', 'UseAdapter'))) {
    $sub = Join-Path $k8 $pair[0]
    New-Item -Path $sub -Force | Out-Null
    New-ItemProperty -Path $sub -Name $pair[1] -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Host "  vmnet8\$($pair[0])\$($pair[1]) = 1"
}
Write-Host "  IPSubnetAddress = $SubnetBase / $mask"

# vmnet1 的 Adapter 子键在部分环境下同样会丢失
$k1 = Join-Path $regBase 'vmnet1'
if (Test-Path $k1) {
    New-Item -Path (Join-Path $k1 'Adapter') -Force | Out-Null
    New-ItemProperty -Path (Join-Path $k1 'Adapter') -Name 'UseAdapter' -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Host '  vmnet1\Adapter\UseAdapter = 1'
}

Write-Host '== 2/6 重建 vmnetnat.conf ==' -ForegroundColor Cyan
if (Test-Path -LiteralPath $natConf) {
    Copy-Item -LiteralPath $natConf -Destination "$natConf.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
}
$natText = @"
# Windows NAT configuration file

[host]

# NAT gateway address
ip = $gateway/24
hostMAC = $hostMac

# VMnet device if not specified on command line
device = vmnet8

activeFTP = 1
allowAnyOUI = 1
resetConnectionOnLinkDown = 1
resetConnectionOnDestLocalHost = 1
natIp6Enable = 0
natIp6Prefix = fd15:4ba5:5a2b:1008::/64

[tcp]
timeWaitTimeout = 30

[udp]
timeout = 30

[dns]
policy = order
timeout = 2
retries = 3
autodetect = 1

[netbios]
nbnsTimeout = 2
nbnsRetries = 3
nbdsTimeout = 3

[incomingtcp]

[incomingudp]

[PrivilegedTCP]
autodetect = 1

[PrivilegedUDP]
autodetect = 1
"@
[IO.File]::WriteAllText($natConf, $natText, [Text.Encoding]::ASCII)
Write-Host "  已写入 $natConf（网关 $gateway）"

Write-Host '== 3/6 恢复 NAT 服务启动类型 ==' -ForegroundColor Cyan
$svc = Get-Service -Name 'VMware NAT Service' -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "  当前：$($svc.Status) / $($svc.StartType)"
    Set-Service -Name 'VMware NAT Service' -StartupType Automatic
    Write-Host "  已改为：Automatic"
} else {
    Write-Warning '  未找到服务 VMware NAT Service'
}

Write-Host '== 4/6 重建虚拟网络 ==' -ForegroundColor Cyan
$vnetlib = (Resolve-Path -LiteralPath $VnetlibPath -ErrorAction SilentlyContinue)
if ($SkipVnetRebuild) {
    Write-Host '  已跳过（-SkipVnetRebuild）' -ForegroundColor DarkGray
} elseif (-not $vnetlib) {
    Write-Warning "  未找到 $VnetlibPath，跳过虚拟网络重建"
} else {
    foreach ($a in @(@('--', 'stop'), @('--', 'start'))) {
        Write-Host ("  > vnetlib64 " + ($a -join ' '))
        $out = & $vnetlib.Path @a 2>&1 | Out-String
        if ($out.Trim()) { $out.Trim() -split "`r?`n" | ForEach-Object { Write-Host "      $_" } }
        Start-Sleep -Seconds 5
    }
}

Write-Host '== 5/6 修正 netmap.conf 网络类型名 ==' -ForegroundColor Cyan
if (Test-Path -LiteralPath $netmap) {
    Copy-Item -LiteralPath $netmap -Destination "$netmap.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
    $nm = Get-Content -LiteralPath $netmap -Raw
    $nm = $nm -replace 'network0\.name = "VMNet0"', 'network0.name = "Bridged"'
    $nm = $nm -replace 'network8\.name = "VMNet8"', 'network8.name = "NAT"'
    [IO.File]::WriteAllText($netmap, $nm, [Text.Encoding]::ASCII)
    Select-String -Path $netmap -Pattern 'network0\.name|network1\.name|network8\.name' |
        ForEach-Object { Write-Host "  $($_.Line)" }
} else {
    Write-Warning "  未找到 $netmap"
}

Write-Host '== 6/6 启动服务并验证 ==' -ForegroundColor Cyan
foreach ($name in @('VMnetDHCP', 'VMware NAT Service')) {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $s) { Write-Warning "  未找到服务：$name"; continue }
    try   { Start-Service -Name $name -ErrorAction Stop; Write-Host "  已启动 $name" }
    catch { Write-Warning "  $name 启动失败：$($_.Exception.Message)" }
    Start-Sleep -Seconds 2
}
Start-Sleep -Seconds 6

Write-Host ''
Get-Service 'VMnetDHCP', 'VMware NAT Service' -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("  服务 {0,-20} = {1} (StartType {2})" -f $_.Name, $_.Status, $_.StartType) }

$vmnat = Get-Process vmnat -ErrorAction SilentlyContinue
if ($vmnat) {
    $conns = (Get-NetTCPConnection -OwningProcess $vmnat.Id -ErrorAction SilentlyContinue |
              Where-Object State -eq 'Established').Count
    Write-Host ("  vmnat 进程 = 运行中 (pid {0})，已转发连接数 = {1}" -f $vmnat.Id, $conns)
} else {
    Write-Host '  vmnat 进程 = 未运行' -ForegroundColor Red
}

Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -like '*VMnet*' } |
    ForEach-Object { Write-Host ("  {0} = {1}/{2}" -f $_.InterfaceAlias, $_.IPAddress, $_.PrefixLength) }

Write-Host ''
Write-Host '完成。若在客户机内仍无法访问互联网，请在客户机中执行 ipconfig /renew 与 ipconfig /flushdns。' -ForegroundColor Green
