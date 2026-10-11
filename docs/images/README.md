# docs/images

本目录用于存放 README 与文档中引用的截图。

## 命名约定

- 全部使用**小写英文 + 连字符**，不使用中文或空格
- 需要体现顺序时以两位数字开头，便于按文件名排序
- 使用 PNG 格式，建议宽度不超过 1600px，单张控制在 500 KB 以内

## 现有占位标记

README 中的截图占位标记与建议文件名对应关系如下：

| 占位标记 | 建议文件名 |
|---|---|
| `<!-- Screenshot: VMware Workstation 17.6.2 关于对话框 -->` | `01-vmware-version.png` |
| `<!-- Screenshot: icacls D:\Windows11 修复前后的权限对比 -->` | `02-icacls-before-after.png` |
| `<!-- Screenshot: 「拒绝访问」错误对话框 -->` | `03-access-denied.png` |
| `<!-- Screenshot: 新建虚拟机向导 - 固件类型选择 UEFI -->` | `04-uefi-firmware.png` |
| `<!-- Screenshot: 新建虚拟机向导 - 摘要页 -->` | `05-wizard-summary.png` |
| `<!-- Screenshot: 向导中的磁盘容量与类型设置 -->` | `06-disk-capacity.png` |
| `<!-- Screenshot: EFI 从 ISO 启动，进入 Windows 安装程序 -->` | `07-setup-start.png` |
| `<!-- Screenshot: 安装类型选择界面 -->` | `08-install-type.png` |
| `<!-- Screenshot: 磁盘选择界面，显示 80 GB 未分配空间 -->` | `09-disk-selection.png` |
| `<!-- Screenshot: OOBE 错误 0xe000022f -->` | `10-oobe-0xe000022f.png` |
| `<!-- Screenshot: OOBE 显示「网络 / 无 Internet」 -->` | `11-oobe-no-internet.png` |
| `<!-- Screenshot: 虚拟网络编辑器 VMnet1 子网设置 -->` | `12-vnet-editor-vmnet1.png` |
| `<!-- Screenshot: OOBE 显示「网络 / 已连接」 -->` | `13-oobe-connected.png` |
| `<!-- Screenshot: Windows 11 桌面 -->` | `14-desktop.png` |
| `<!-- Screenshot: Workstation 主窗口被模态向导阻塞 -->` | `15-modal-blocked.png` |

## 提交注意

- 截图请先裁剪掉与说明无关的区域
- **提交前务必检查并遮盖**：虚拟机加密密码输入框、产品密钥及其片段、用户名、计算机名、内网地址等可识别信息
- 截图属于教程文档的一部分，随本仓库以 MIT 协议发布；涉及 Windows 界面截图的，请自行确认使用场景符合微软的相关条款
