#Requires -Version 5.1
<#
.SYNOPSIS
    为缺少网络适配器配置的 .vmx 追加 e1000e 网卡配置。

.DESCRIPTION
    对应 README 问题 2。

    现象：Windows 11 的 OOBE 强制要求联网。若 .vmx 中完全没有 ethernet0，
          联网页会显示「出现错误:0xe000022f」并锁死「下一步」按钮，
          点击「安装驱动程序」也无法解决。

    实现要点：
      1. 使用【追加写入】而非重写整个文件。已启用虚拟 TPM 的虚拟机
         .vmx 中含有 encryption.* 与 vtpm.* 键值，重写可能造成不可恢复的损坏。
      2. 写入前以独占方式打开文件，确认虚拟机已关机且文件未被占用。
      3. 写入前自动生成备份。

.PARAMETER VmxPath
    .vmx 文件的完整路径。虚拟机必须处于关机状态。

.PARAMETER ConnectionType
    网络模式：nat（默认）/ bridged / hostonly。

.EXAMPLE
    .\Add-NicToVMX.ps1 -VmxPath 'D:\Windows11\Windows 11 x64.vmx'

.EXAMPLE
    .\Add-NicToVMX.ps1 -VmxPath 'D:\Windows11\Windows 11 x64.vmx' -ConnectionType bridged
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VmxPath,
    [ValidateSet('nat', 'bridged', 'hostonly')][string]$ConnectionType = 'nat'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $VmxPath)) { throw "找不到 .vmx 文件：$VmxPath" }
$VmxPath = (Resolve-Path -LiteralPath $VmxPath).Path

if (Get-Process vmware-vmx -ErrorAction SilentlyContinue) {
    throw '检测到 vmware-vmx 进程。请先关闭虚拟机——运行期间对 .vmx 的修改会被 Workstation 回写覆盖。'
}

if (Select-String -Path $VmxPath -Pattern '^ethernet0\.present' -Quiet) {
    Write-Host '已存在 ethernet0.present，无需处理。' -ForegroundColor Yellow
    Select-String -Path $VmxPath -Pattern '^ethernet0\.' | ForEach-Object { Write-Host "  $($_.Line)" }
    return
}

# 独占方式打开，确认文件未被占用（同时验证可写）
try {
    $stream = [IO.File]::Open($VmxPath, 'Open', 'ReadWrite', 'None')
    $stream.Close()
} catch {
    throw ".vmx 仍被占用或不可写：$($_.Exception.Message)"
}

$backup = "$VmxPath.prenic-backup"
Copy-Item -LiteralPath $VmxPath -Destination $backup -Force
Write-Host "已生成备份：$backup"

$block = @(
    'ethernet0.present = "TRUE"',
    'ethernet0.virtualDev = "e1000e"',
    ('ethernet0.connectionType = "{0}"' -f $ConnectionType),
    'ethernet0.addressType = "generated"',
    'ethernet0.startConnected = "TRUE"',
    'ethernet0.displayName = "Network Adapter"'
) -join "`r`n"

$before = (Get-Content -LiteralPath $VmxPath).Count
[IO.File]::AppendAllText($VmxPath, "`r`n" + $block + "`r`n", [Text.Encoding]::ASCII)
$after = (Get-Content -LiteralPath $VmxPath).Count

Write-Host ''
Write-Host "已追加配置（行数 $before -> $after）：" -ForegroundColor Green
Select-String -Path $VmxPath -Pattern '^ethernet0\.' | ForEach-Object { Write-Host "  $($_.Line)" }

Write-Host ''
Write-Host '后续检查：' -ForegroundColor Cyan
Write-Host '  1. 开机后在 vmware.log 中确认出现 "Ethernet0 MAC Address" 与 "e1000e-- tx queue"'
Write-Host '  2. 在 %ProgramData%\VMware\vmnetdhcp.leases 中确认客户机取得租约'
Write-Host '  3. 若 OOBE 仍显示「无 Internet」，请检查 VMware NAT 服务（见 README 问题 3）'
