#Requires -Version 5.1
<#
.SYNOPSIS
    使用 VMware 自带的 vmcli.exe 创建并配置一台 Windows 11 虚拟机。

.DESCRIPTION
    封装 README 步骤 2–6：
      1. 创建虚拟机骨架
      2. 创建动态虚拟磁盘
      3. 配置固件（UEFI）、虚拟 TPM 2.0、CPU 与内存
      4. 挂载 NVMe 系统磁盘
      5. 挂载 SATA 光驱与安装镜像
      6. 配置网络适配器（e1000e）

    重要：vmcli VM Create 生成的 .vmx 只包含芯片组配置，
    磁盘挂载、光驱、固件类型与网络适配器都必须手工补齐。
    本脚本即该补齐过程的自动化实现，避免遗漏网络适配器导致 OOBE 无法联网。

.PARAMETER Name
    虚拟机名称，同时作为 .vmx 与 .vmdk 的文件名前缀。

.PARAMETER Dir
    虚拟机存放目录，必须对当前用户可写（参见 Repair-VMFolderACL.ps1）。

.PARAMETER VmcliPath
    vmcli.exe 的完整路径，默认 D:\vmcli.exe。

.PARAMETER IsoPath
    Windows 11 安装镜像（ISO）的完整路径。

.PARAMETER MemoryMB
    内存大小（MB），默认 8192。

.PARAMETER VcpuCount
    vCPU 数量，默认 4。

.PARAMETER DiskSizeGB
    系统磁盘容量（GB），默认 80。

.PARAMETER NetworkType
    网络模式：nat（默认）/ bridged / hostonly。

.EXAMPLE
    .\New-Win11VM.ps1 -Name 'Windows 11 x64' -Dir 'D:\Windows11' `
        -IsoPath 'D:\Windows11\Windows11_Client_x64_zh-cn_26300_9457.iso'

.NOTES
    本脚本不涉及任何授权或激活操作。
    首次开机时 Workstation 会要求设置虚拟机加密密码（虚拟 TPM 的强制要求），请妥善保管。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$IsoPath,
    [string]$VmcliPath = 'D:\vmcli.exe',
    [int]$MemoryMB = 8192,
    [int]$VcpuCount = 4,
    [int]$DiskSizeGB = 80,
    [ValidateSet('nat', 'bridged', 'hostonly')][string]$NetworkType = 'nat'
)

$ErrorActionPreference = 'Stop'

foreach ($item in @(@($VmcliPath, 'vmcli.exe'), @($Dir, '虚拟机目录'), @($IsoPath, '安装镜像'))) {
    if (-not (Test-Path -LiteralPath $item[0])) { throw "$($item[1]) 不存在：$($item[0])" }
}

$vmcli = (Resolve-Path -LiteralPath $VmcliPath).Path
$Dir   = (Resolve-Path -LiteralPath $Dir).Path
$iso   = (Resolve-Path -LiteralPath $IsoPath).Path

$vmx  = Join-Path $Dir "$Name.vmx"
$vmdk = Join-Path $Dir "$Name.vmdk"

function Set-Entry {
    param([string]$Key, [string]$Value)
    Write-Host ('  {0,-32} = {1}' -f $Key, $Value)
    & $vmcli $vmx ConfigParams SetEntry $Key $Value | Out-Null
}

Write-Host '== 1/6 创建虚拟机骨架 ==' -ForegroundColor Cyan
& $vmcli VM Create -n $Name -d $Dir -c windows11-64

Write-Host '== 2/6 创建虚拟磁盘 ==' -ForegroundColor Cyan
if (Test-Path -LiteralPath $vmdk) { Remove-Item -LiteralPath $vmdk -Force }
& $vmcli Disk Create -f $vmdk -a lsilogic -s "${DiskSizeGB}GB" -t 0

Write-Host '== 3/6 固件 / 虚拟 TPM / CPU / 内存 ==' -ForegroundColor Cyan
Set-Entry 'firmware'              'efi'
Set-Entry 'managedVM.autoAddVTPM' 'software'
Set-Entry 'memsize'               $MemoryMB
Set-Entry 'numvcpus'              $VcpuCount
Set-Entry 'cpuid.coresPerSocket'  '2'

Write-Host '== 4/6 系统磁盘（NVMe 控制器） ==' -ForegroundColor Cyan
Set-Entry 'nvme0.present'        'TRUE'
Set-Entry 'nvme0:0.present'      'TRUE'
Set-Entry 'nvme0:0.deviceType'   'disk'
Set-Entry 'nvme0:0.fileName'     "$Name.vmdk"

Write-Host '== 5/6 光驱（SATA 控制器） ==' -ForegroundColor Cyan
Set-Entry 'sata0.present'            'TRUE'
Set-Entry 'sata0:1.present'          'TRUE'
Set-Entry 'sata0:1.deviceType'       'cdrom-image'
Set-Entry 'sata0:1.fileName'         $iso
Set-Entry 'sata0:1.startConnected'   'TRUE'
Set-Entry 'bios.bootOrder'           'cdrom'

Write-Host '== 6/6 网络适配器 ==' -ForegroundColor Cyan
Set-Entry 'ethernet0.present'        'TRUE'
Set-Entry 'ethernet0.virtualDev'     'e1000e'
Set-Entry 'ethernet0.connectionType' $NetworkType
Set-Entry 'ethernet0.addressType'    'generated'
Set-Entry 'ethernet0.startConnected' 'TRUE'
Set-Entry 'ethernet0.displayName'    'Network Adapter'

Set-Entry 'displayName' $Name

Write-Host ''
Write-Host '--- 配置校验（vmcli 回读） ---' -ForegroundColor Cyan
& $vmcli $vmx ConfigParams query | Select-String -Pattern 'firmware|guestOS|memsize|numvcpus|autoAddVTPM|nvme0|sata0|ethernet0'

Write-Host ''
Write-Host "完成。虚拟机配置文件：$vmx" -ForegroundColor Green
Write-Host '提示：安装完成后建议断开光驱，避免重启时误入安装程序（见 README 问题 9）。' -ForegroundColor Yellow
