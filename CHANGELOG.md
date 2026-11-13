# Changelog

## v1.1.0 — 2026-11-13

- 新增**可选**工具 `tools/windows/`：把 Windows 资源管理器“云文件”右键菜单
  （`Always keep on this device` / `Free up space` / `Pause syncing` / `Resume syncing` /
  `Sync` 等 17 条字符串）中文化。这些字符串属于 Windows 组件
  `Windows.FileExplorer.Common.dll`，不是 ownCloud 的界面，因此单独提供、可独立安装/卸载。
  - 原理：读取本机 `System32\en-US\Windows.FileExplorer.Common.dll.mui`，
    等长替换字符串（文件大小不变）并把资源语言 ID `0x0409` 改为 `0x0804`，
    安装到 `System32\zh-CN\`；原 en-US 文件不修改。
  - 仓库不提交、不分发任何微软文件：`.mui` 在用户本机由脚本现场生成（`.gitignore` 排除）。
  - 一键安装/卸载脚本：`install-cloud-menu-zh.cmd` / `uninstall-cloud-menu-zh.cmd`。
- README（中/英）新增该可选工具的说明；CI 增加 PowerShell 脚本语法检查与生成器冒烟测试。

## v1.0.0 — 2026-11-13

首个版本。

- 新增 `translations/client_zh_CN.ts`：632 条消息、110 个上下文，覆盖菜单、设置、同步状态、
  冲突/错误提示、共享、空间、账号、通知、OAuth 登录等界面文案。
- 新增 `translations/client_zh_CN.qm`（70785 字节，SHA-256
  `acc30d22709c18475255f2c32987509e77a3a327e2bba8b67b1b99cc734a148d`）。
- 新增 `patches/translation-directory-patch.md`：说明如何在 `ownCloudGui.dll`（7.1.1.19543）中
  把翻译目录常量 `:/client/translations/` 等长替换为 `C:/ProgramData/ocL10n/`。
- 新增 `tools/patch-dll.ps1`：带 SHA-256 校验与 `.orig` 备份的补丁脚本。
- 新增 `tools/setup/`：中文安装器源码（WinForms / .NET Framework 4），
  从官方服务器下载并校验官方 MSI，安装后自动打补丁、写语言包。
- 新增 CI：校验 `.ts` 完整性、编译安装器、自检内嵌语言包哈希。

### 已知限制

- 补丁只针对 `7.1.1.19543` 版本；其他版本需要重新定位常量偏移（脚本会校验哈希并拒绝执行）。
- 客户端升级/修复安装会覆盖 `ownCloudGui.dll`，需要重新运行安装器。
- 上游目前没有接收这份翻译；如果将来上游加入了官方中文，本补丁就不再必需。
