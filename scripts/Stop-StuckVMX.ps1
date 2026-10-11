#Requires -RunAsAdministrator
<#
.SYNOPSIS
    结束卡死的 vmware-vmx.exe 进程，并清理虚拟机目录中的锁定文件。

.DESCRIPTION
    对应 README 问题 4 与问题 6。

    现象：vmware-vmx.exe 由 VMware 授权服务以高完整性（提权）身份启动，
          非提权进程执行 Stop-Process / taskkill 会返回 Access denied。
          常见诱因是 Workstation 主窗口被模态对话框阻塞（例如新建虚拟机向导
          停留在某个错误提示上），导致 VMX 进程拿不到窗口而空等。

    本脚本会：
      1. 结束所有 vmware-vmx.exe 进程
      2. 可选清理指定目录下的 *.lck 锁定目录

.PARAMETER VmDir
    可选。指定后会清理该目录及其一级子目录下的 *.lck 目录。

.EXAMPLE
    .\Stop-StuckVMX.ps1

.EXAMPLE
    .\Stop-StuckVMX.ps1 -VmDir 'D:\Windows11'

.NOTES
    结束 vmware-vmx 等同于对虚拟机执行硬关机。
    若客户机内有未保存的工作，请优先通过图形界面正常关机。
#>
[CmdletBinding()]
param([string]$VmDir)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin  = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw '需要以管理员身份运行本脚本。' }

Write-Host '== 结束 vmware-vmx.exe ==' -ForegroundColor Cyan
$procs = Get-Process vmware-vmx -ErrorAction SilentlyContinue
if (-not $procs) {
    Write-Host '  未发现 vmware-vmx 进程。'
} else {
    foreach ($p in $procs) {
        Write-Host "  正在结束 pid $($p.Id)"
        try   { Stop-Process -Id $p.Id -Force -ErrorAction Stop }
        catch { Write-Warning "  pid $($p.Id) 结束失败：$($_.Exception.Message)" }
    }
    Start-Sleep -Seconds 4
    $left = Get-Process vmware-vmx -ErrorAction SilentlyContinue
    if ($left) { Write-Warning "  仍有残留进程：$($left.Id -join ', ')" }
    else       { Write-Host '  vmware-vmx 已全部结束。' -ForegroundColor Green }
}

if ($VmDir) {
    Write-Host ''
    Write-Host '== 清理锁定目录 ==' -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $VmDir)) {
        Write-Warning "  目录不存在：$VmDir"
    } else {
        $locks = Get-ChildItem -LiteralPath $VmDir -Force -Directory -Filter '*.lck' -Recurse -Depth 1 -ErrorAction SilentlyContinue
        if (-not $locks) {
            Write-Host '  未发现 *.lck 目录。'
        } else {
            foreach ($l in $locks) {
                Write-Host "  删除 $($l.FullName)"
                Remove-Item -LiteralPath $l.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host ''
Write-Host '完成。若问题反复出现，请先关闭 Workstation 中的模态对话框再开机。' -ForegroundColor Green
