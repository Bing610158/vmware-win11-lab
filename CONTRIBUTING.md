# 贡献指南 Contributing

感谢你愿意为本项目做出贡献。本文档说明**可以提交什么、不可以提交什么**，以及提交的流程与格式要求。

- [一、内容范围与红线](#一内容范围与红线)
- [二、法规与版权前提](#二法规与版权前提)
- [三、提交 Issue](#三提交-issue)
- [四、提交 Pull Request](#四提交-pull-request)
- [五、文档格式约定](#五文档格式约定)
- [六、脚本贡献要求](#六脚本贡献要求)
- [七、行为准则](#七行为准则)
- [八、许可证](#八许可证)

---

## 一、内容范围与红线

### 1.1 本项目收录的内容

- 在 **VMware Workstation** 中部署 Windows 11 的完整步骤、参数与配置说明
- 满足 Windows 11 硬件要求的两类做法：
  1. **VMware 自带的虚拟 TPM 2.0**：通过 `managedVM.autoAddVTPM = "software"` 由 Workstation 自动添加 vTPM，并配合 UEFI 固件（`firmware = "efi"`）
  2. **注册表绕过方案**：在 Windows 安装程序界面按 `Shift + F10` 调出命令提示符，通过注册表项跳过 TPM 与安全启动检查（`LabConfig` 下的 `BypassTPMCheck`、`BypassSecureBootCheck`、`BypassRAMCheck`）
- 虚拟磁盘、CPU、内存、固件类型、网络模式等虚拟机配置说明
- 真实环境中的报错、根因分析与排查方法
- 宿主机侧与客户机侧可复现的命令、脚本与配置片段

### 1.2 本项目不收录的内容（硬性红线）

以下内容一律不接受，提交后会被直接关闭，不予讨论：

| 禁止项 | 说明 |
|---|---|
| 任何破解工具、激活工具 | 包括但不限于激活脚本、破解补丁、授权规避工具 |
| 任何与授权服务器相关的内容 | 包括模拟授权服务、第三方授权服务器地址、授权服务配置 |
| 产品密钥 | 无论来源，包括零售密钥、批量密钥、公开的通用密钥 |
| Windows 系统镜像文件 | 仓库**不存放、不镜像、不转存**任何 ISO / ESD / WIM 文件 |
| 非官方镜像下载链接 | 文档中的镜像来源只能指向**微软官方网站** |
| 隐私与凭据 | 虚拟机加密密码、账户凭据、可识别的个人信息 |

> 若你需要在 Issue 中描述授权相关的界面现象，请只描述**观察到的提示文本**，不要附加任何工具名称、下载地址或密钥片段。

---

## 二、法规与版权前提

- Windows 操作系统的版权归 **Microsoft Corporation** 所有，使用者必须遵守微软最终用户许可协议（EULA）。
- 本项目**仅提供部署教程与技术文档**，不提供任何系统镜像、授权或激活手段。
- 镜像请一律从微软官方渠道获取，并自行校验哈希：

| 渠道 | 地址 |
|---|---|
| Windows 11 官方下载 | https://www.microsoft.com/software-download/windows11 |
| Windows 11 企业版评估版 | https://www.microsoft.com/evalcenter/download-windows-11-enterprise |
| Microsoft Evaluation Center | https://www.microsoft.com/evalcenter |

- 提交内容即视为你确认该内容不侵犯任何第三方权利。

---

## 三、提交 Issue

### 3.1 提交前

1. 先搜索现有 Issue 与文档，确认问题尚未被记录
2. 确认问题与 **VMware 部署 Windows 11** 相关，属于本项目范围

### 3.2 故障报告应包含

1. **环境信息**
   - VMware Workstation 版本（帮助 → 关于）
   - 宿主机系统版本（`winver`）、内存容量与 CPU 型号
   - 虚拟机硬件版本（`.vmx` 中的 `virtualHW.version`）
   - 宿主机 CPU 虚拟化是否已开启

2. **复现步骤**：操作顺序、涉及的命令、预期结果与实际结果

3. **完整错误文本**：直接粘贴文本，不要只放截图

4. **相关日志片段**：虚拟机目录下的 `vmware.log`

5. **网络相关问题时**，附以下命令输出：

```powershell
Get-Service 'VMware NAT Service', 'VMnetDHCP' | Select-Object Name, Status, StartType
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like '*VMnet*' }
Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -like '*.*.*.*/32' }
```

### 3.3 提交前务必删除

- 虚拟机加密密码
- 产品密钥及其任何片段
- 用户名、计算机名、内网地址等可识别个人信息（可用占位符替代）

---

## 四、提交 Pull Request

### 4.1 流程

1. Fork 本仓库
2. 从 `main` 创建分支，命名遵循下表
3. 完成改动并自测
4. 提交 PR，说明改动原因、验证环境与验证方式

### 4.2 分支命名

| 前缀 | 用途 | 示例 |
|---|---|---|
| `docs/` | 文档修改 | `docs/vmnet-subnet-conflict` |
| `fix/` | 修正错误内容 | `fix/efi-boot-order` |
| `feat/` | 新增章节或脚本 | `feat/vmcli-cheatsheet` |
| `chore/` | 仓库维护 | `chore/gitignore-iso` |

### 4.3 提交信息规范

使用祈使句，可参考 Conventional Commits：

```text
docs: 补充虚拟 TPM 启用步骤
fix: 修正 UEFI 固件配置项说明
feat: 新增虚拟机目录 ACL 修复脚本
```

---

## 五、文档格式约定

| 约定 | 要求 |
|---|---|
| 操作来源标注 | 宿主机侧使用 `【VMware 操作步骤】`，客户机内使用 `【Windows 安装步骤】` |
| 未验证内容 | 必须显式标注「本项目未采用」，不得与已验证步骤混排 |
| 截图占位 | 使用 `<!-- Screenshot: 描述 -->` |
| 代码块 | 统一使用 ` ```powershell ` / ` ```cmd ` / ` ```text `，不以截图代替命令 |
| 故障条目结构 | 固定为 **现象 → 根因 → 定位 → 处理 → 验证** |
| 术语 | 首次出现的专有名词给出中英文对照 |
| 语言 | 中文为主，命令、路径、配置项保持原文 |

### 5.1 新增故障排查条目模板

````markdown
### 问题 N：<一句话描述现象>

**现象**

<完整错误文本或界面表现>

**根因**

<技术原因，需可验证>

**定位**

<用于确认根因的命令与预期输出>

**处理**

<修复步骤或命令>

**验证**

<如何确认问题已解决>
````

---

## 六、脚本贡献要求

- 仅接受 PowerShell（`.ps1`），须在文件头注释中说明用途、前提条件与用法
- 涉及系统级修改的脚本，需说明**所需权限**（管理员 / 非管理员）
- 涉及不可逆操作的脚本，需在执行前自动备份原文件
- **禁止**在脚本中硬编码密码、密钥、用户名或内部地址
- 脚本中不得包含任何授权或激活相关逻辑

---

## 七、行为准则

- 讨论聚焦技术问题，保持客观与礼貌
- 不接受任何形式的破解、盗版或授权规避请求
- 维护者有权关闭超出项目范围或违反红线的 Issue / PR

---

## 八、许可证

- 向本仓库提交内容，即表示你同意该内容以 **MIT 协议**发布。
- MIT 协议的保护范围**仅限本仓库中的教程文档与脚本**，**不包含 Windows 操作系统**；Windows 的版权归 Microsoft Corporation 所有。
- 详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。
