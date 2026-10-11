#Requires -RunAsAdministrator
<#
.SYNOPSIS
    为虚拟机目录授予当前账户 Modify 权限，修复「无法打开配置文件 .vmx：拒绝访问」。

.DESCRIPTION
    对应 README 问题 1。

    现象：Workstation 以非提权进程运行时，若目标目录的 ACL 只包含
          Administrators:(F) / Everyone:(RX) / SYSTEM:(F)，
          则当前用户的有效权限仅剩 Everyone:(RX)，无法新建 .vmx。

    本脚本只授予 Modify（M）权限：包含创建/删除文件与文件夹、写入数据，
    不包含修改 ACL 与取得所有权的权利，是最小够用权限集。

.PARAMETER Path
    需要授权的目录，可指定多个。通常为虚拟机存放目录
    （若虚拟机分散在多个子目录中，可指定父目录并加上 -Recurse）。

.PARAMETER Recurse
    同时处理子目录与子文件。

.EXAMPLE
    .\Repair-VMFolderACL.ps1 -Path 'D:\Windows11'

.EXAMPLE
    .\Repair-VMFolderACL.ps1 -Path 'D:\VMs' -Recurse

.NOTES
    建议只对虚拟机目录授权，不要对盘符根目录整体授权——根目录下
    往往存在 Program Files、ProgramData 等需要保持严格权限的目录。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Path,
    [switch]$Recurse
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin  = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw '需要以管理员身份运行本脚本。' }

$sid = $identity.User.Value
Write-Host "账户：$($identity.Name)"
Write-Host "SID ：$sid"

foreach ($target in $Path) {
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Warning "跳过（路径不存在）：$target"
        continue
    }

    Write-Host ''
    Write-Host "=== $target ===" -ForegroundColor Cyan

    Write-Host '--- 处理前 ---'
    icacls $target | ForEach-Object { Write-Host "  $_" }

    $icaclsArgs = @($target, '/grant', "*${sid}:(OI)(CI)M")
    if ($Recurse) { $icaclsArgs += '/T' }
    icacls @icaclsArgs | ForEach-Object { Write-Host "  $_" }

    Write-Host '--- 处理后 ---'
    icacls $target | ForEach-Object { Write-Host "  $_" }

    # 以当前（提权）身份做一次写入探测
    $probe = Join-Path $target '__acl_write_test.tmp'
    try {
        Set-Content -LiteralPath $probe -Value 'x' -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        Write-Host '  提权写入探测：OK' -ForegroundColor Green
    } catch {
        Write-Warning "  提权写入探测失败：$($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host '完成。请以【非提权】身份复现一次写入以确认修复生效：' -ForegroundColor Green
Write-Host '  [IO.File]::WriteAllText("<目录>\__write_test.tmp","x")'
Write-Host '若仍失败，请确认 Workstation 不是以更高权限运行、且目录未被其他进程占用。'
