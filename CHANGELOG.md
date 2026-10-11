# Changelog

本项目所有值得记录的变更都写在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.0.0] - 2026-10-11

### Added

- 初始版本：VMware Workstation 部署 Windows 11 完整实战教程
- **前置依赖 & 环境要求**：宿主机硬件实测值、CPU 虚拟化检查、软件版本要求
- **系统镜像准备**：微软官方获取渠道、SHA256 校验方法、满足 Windows 11 硬件要求的两种做法
  - 方案一：VMware 自带的虚拟 TPM 2.0 + UEFI 固件（本项目采用）
  - 方案二：安装程序内的注册表绕过（`LabConfig`，本项目未采用）
- **分步安装教程**（步骤 1–9）：
  - 步骤 1：虚拟机目录与权限准备
  - 步骤 2：创建虚拟机（`vmcli` 命令行 / 图形界面向导）
  - 步骤 3：创建 80 GiB 动态虚拟磁盘
  - 步骤 4：补齐 `.vmx` 配置（固件、vTPM、CPU、内存、NVMe 磁盘、SATA 光驱）
  - 步骤 5：CPU 与内存分配
  - 步骤 6：配置网络适配器（`e1000e` + NAT）
  - 步骤 7：开机并进入安装程序
  - 步骤 8：执行 Windows 11 安装
  - 步骤 9：完成 OOBE 初始设置
- **关键配置说明**：UEFI 模式设置、vTPM 与加密、虚拟磁盘分区方案、虚拟机网络模式
- **故障排查 Troubleshooting**（9 条，全部来自真实排障记录）：
  1. 创建虚拟机报「无法打开配置文件 `.vmx`：拒绝访问」
  2. OOBE 卡在联网页，错误 `0xe000022f`（缺网络适配器）
  3. OOBE 显示「网络 / 无 Internet」，错误 `0x80070015`（VMnet1 与物理局域网网段冲突）
  4. `vmcli Power Start` 报 `cannot connect to the virtual machine`（模态对话框阻塞）
  5. `vmcli Power Stop` 报 `getting password from stdin`（虚拟机已加密）
  6. 提权的 `vmware-vmx.exe` 无法结束（Access denied）
  7. 虚拟磁盘无法识别
  8. 重启后客户机仍无 Internet（NAT 服务被禁用、`vmnet8` 配置被清空）
  9. 开机时又从光驱进入安装程序
- `scripts/` 目录，6 个可复用 PowerShell 脚本：
  - `New-Win11VM.ps1`
  - `Repair-VMFolderACL.ps1`
  - `Add-NicToVMX.ps1`
  - `Stop-StuckVMX.ps1`
  - `Repair-VMnet1Conflict.ps1`
  - `Restore-VMnet8NAT.ps1`
- `CONTRIBUTING.md`：内容范围与硬性红线、Issue / PR 流程、文档格式约定、脚本贡献要求
- `LICENSE`：MIT 协议
- `NOTICE`：许可证适用范围声明（MIT 仅覆盖文档与脚本，不包含 Windows 操作系统）
- `.github/`：Issue 表单、PR 模板

### Notes

- 本仓库不包含、不分发、不镜像任何 Windows 系统镜像；文档中的镜像获取渠道仅指向微软官方网站。
- 本仓库不提供、不讨论任何授权绕过手段。
