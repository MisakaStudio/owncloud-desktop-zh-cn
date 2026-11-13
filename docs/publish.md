# 发布到 GitHub 步骤

本仓库可以直接作为一个新的 GitHub 仓库推送。下面是推荐流程。

## 1. 创建仓库

在 GitHub 网页端新建空仓库（不要勾选初始化 README/License，避免冲突），例如：

- 名称：`owncloud-desktop-zh-cn`
- 可见性：Public
- 描述：`Unofficial Simplified Chinese localization for the ownCloud desktop client (GPLv2)`
- 话题（Topics）：`owncloud`、`localization`、`i18n`、`zh-cn`、`windows`

## 2. 本地初始化并推送

在仓库目录（本文件所在仓库根目录）执行：

```bash
git init -b main
git add .
git commit -m "feat: ownCloud 7.1.1 desktop client Simplified Chinese localization v1.0.0"
git remote add origin https://github.com/<你的用户名>/owncloud-desktop-zh-cn.git
git push -u origin main
```

提交前可以顺手检查：

```powershell
# 不应该出现在仓库里的大文件/官方二进制
Get-ChildItem -Recurse -Include *.msi,*.dll,*.exe | Where-Object { $_.FullName -notmatch '\\dist\\' }
```

`dist/` 已在 `.gitignore` 中忽略；**不要**把官方 MSI / `ownCloudGui.dll` 提交到仓库。

## 3. 创建 Release

1. 先编译安装器：`powershell -ExecutionPolicy Bypass -File tools\setup\build.ps1`
2. 在 GitHub 仓库 → Releases → Draft a new release：
   - Tag：`v1.0.0`，标题：`v1.0.0 — ownCloud 7.1.1 简体中文`
   - 附件：
     - `dist\ownCloud-7.1.1-简体中文安装程序.exe`
     - `translations\client_zh_CN.qm`
   - 说明里写清楚：非官方、适用版本 `7.1.1.19543`、SHA-256 校验值、还原方法
3. 生成校验并粘贴：

   ```powershell
   Get-FileHash 'dist\ownCloud-7.1.1-简体中文安装程序.exe' -Algorithm SHA256
   Get-FileHash 'translations\client_zh_CN.qm' -Algorithm SHA256
   ```

## 4. 仓库设置建议

- **About**：填写描述，勾选 Releases / Issues。
- **Security / Code scanning**：可按需开启。
- **Releases 附件** 建议同时上传 `SHA256SUMS`。
- 不推荐开启 GitHub Pages 之外的额外服务；本仓库不需要任何构建密钥。

## 5. CI

`.github/workflows/ci.yml` 会在 push / PR 时自动：

1. 校验 `.ts` 翻译完整性（消息数、占位符、未完成条目）；
2. 编译中文安装器；
3. 运行安装器 `--selftest` 与 `--extract-qm`，确认内嵌语言包与仓库里的 `.qm` 一致；
4. 对 `patch-dll.ps1` 做语法检查；
5. 上传安装器构建产物。

首次 push 后到 Actions 页面确认工作流通过。

## 6. 发布前的合规自查

- [ ] `LICENSE`（GPL-2.0）在仓库根目录；
- [ ] `NOTICE.md`、`TRADEMARKS.md` 已填写；
- [ ] README 有醒目的“非官方”声明；
- [ ] 仓库内没有官方 MSI / DLL 等二进制；
- [ ] Release 说明里写明“非官方、使用官方原包 + SHA-256 校验”；
- [ ] 没有使用 ownCloud 的官方 logo 作为项目图标。
