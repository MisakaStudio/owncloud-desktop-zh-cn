# ownCloud 桌面客户端 简体中文语言包（非官方）

> **English:** [README.md](README.md)  ·  **本项目是社区汉化，与 ownCloud GmbH 没有任何关联，不是官方发布。**
> ownCloud 是 ownCloud GmbH 的商标。本项目只做语言本地化，不改变软件的任何功能。

官方 ownCloud 桌面客户端 **7.1.1.19543** 没有提供简体中文（上游 `translations/` 只有 15 种语言，
不含 `zh_CN`），安装后界面是英文。本项目提供：

- **632 条界面字符串**的简体中文翻译（Qt `.ts` 源文件 + 编译好的 `.qm`）；
- 一个**中文安装向导**：自动获取官方原版安装包并校验 SHA-256，静默安装，然后加中文界面；
- 可复现的**字节补丁脚本**（只改 20 个字节，用来让客户端从磁盘加载外置语言包）。

---

## 快速开始（普通用户）

1. 到本仓库的 **Releases** 页面下载 `ownCloud-7.1.1-简体中文安装程序.exe`；
2. 右键 → **以管理员身份运行**（或双击后在 UAC 对话框点“是”）；
3. 点“开始安装”，等进度完成即可；
4. 打开 ownCloud，界面就是简体中文。

安装器会依次做这些事：

| 步骤 | 说明 |
|---|---|
| ① 获取官方 MSI | 优先在本机（下载/桌面/当前目录/临时目录）找 `ownCloud-7.1.1.19543.x64.msi`；找不到就从 ownCloud 官方服务器下载；都不行则弹窗让你手动选择。**任何来源都必须通过 SHA-256 校验**（见下表），否则拒绝安装 |
| ② 安装主程序 | 若检测到已安装的 ownCloud，则跳过；否则 `msiexec /i ... /qn /norestart` 静默安装官方原版 |
| ③ 打中文补丁 | 校验安装目录里 `ownCloudGui.dll` 的哈希等于官方值后，原位替换 20 个字节（等长，文件大小不变），并在首次修改前备份为 `ownCloudGui.dll.orig` |
| ④ 安装语言包 | 把 `client_zh_CN.qm` 写入 `C:\ProgramData\ocL10n\` 并校验哈希 |

系统要求：Windows 10 / 11 64 位（与官方 7.1.1 一致）。安装需要管理员权限。

### 卸载 / 还原英文界面

1. 删除目录 `C:\ProgramData\ocL10n`；
2. 把 `<安装目录>\ownCloudGui.dll.orig` 复制回 `ownCloudGui.dll`（覆盖）；
3. 重启 ownCloud。

（安装目录默认 `C:\Program Files\ownCloud`，也可以从注册表卸载项里查到。）

---

## 手动安装（不使用安装器）

1. 从 ownCloud 官方站点下载 `ownCloud-7.1.1.19543.x64.msi`（或使用你手头的原包），
   用 SHA-256 校验其与下表一致；
2. 静默安装：`msiexec /i ownCloud-7.1.1.19543.x64.msi /qn /norestart`
3. 以管理员身份运行补丁脚本：

   ```powershell
   # 先退出 ownCloud
   taskkill /f /im owncloud.exe
   # 打补丁（脚本会校验哈希、自动备份）
   powershell -ExecutionPolicy Bypass -File .\tools\patch-dll.ps1 -InstallDir "C:\Program Files\ownCloud"
   ```

4. 新建目录 `C:\ProgramData\ocL10n`，把 `translations\client_zh_CN.qm` 复制进去；
5. 重新打开 ownCloud。

---

## 可选：资源管理器「云文件」右键菜单中文化（Windows 组件）

在 ownCloud 同步目录里右键文件，还会看到几个**英文**菜单项，例如
`Always keep on this device`、`Free up space`、`Pause syncing`。

它们**不是 ownCloud 的字符串**：ownCloud 只是把同步目录注册为 Windows 的“云文件
（Cloud Files）”位置，菜单由 Windows 资源管理器提供；字符串来自 Windows 组件
`Windows.FileExplorer.Common.dll` 的 MUI 语言资源。多数中文 Windows 只带 `en-US`
版本、缺少 `zh-CN` 版本，因此回退显示英文。

本仓库提供了一个**可选**工具在用户本机生成并安装 zh-CN MUI（17 条字符串，
语言 ID `0x0409` → `0x0804`，文件大小不变，不修改原 en-US 文件）：

```bat
rem 需要管理员权限（脚本会自动请求 UAC），安装后自动重启资源管理器
tools\windows\install-cloud-menu-zh.cmd

rem 一键还原
tools\windows\uninstall-cloud-menu-zh.cmd
```

说明、原理、风险与还原细节见 [`tools/windows/README.md`](tools/windows/README.md)。

注意：

- 这是**系统级修改**（在 `C:\Windows\System32\zh-CN\` 新增一个 MUI 文件），与 ownCloud
  汉化互相独立，不安装也不影响 ownCloud 的中文界面；
- 仓库**不提交、不分发**任何微软文件：该 MUI 由脚本在用户本机从自己的系统文件现场生成；
- Windows 更新可能覆盖它，届时重新运行安装脚本即可；不想用它时运行卸载脚本完全还原。

---

## 原理：为什么需要改 DLL？

官方客户端把 `client_*.qm` 语言包**编译进了 `ownCloudResources.dll` 的 Qt 资源里**，运行时只从
Qt 资源路径 `:/client/translations/` 读取，所以把 `.qm` 放到磁盘目录里**不会**被加载。

`ownCloudGui.dll` 中保存了该目录常量的字符串（UTF-16LE，22 个字符）：

```
原值: :/client/translations/
新值: C:/ProgramData/ocL10n/
```

两者**长度相同**，因此可以在原位置等长替换，不需要改任何代码结构、文件大小不变：

- 修改位置：文件偏移 `0x24B900`（2406656），长度 44 字节（22 个 UTF-16 字符）；
- 实际发生变化的是 20 个字节（其余字符碰巧相同）；
- 只对 `7.1.1.19543` 这个具体版本有效，脚本会先用 SHA-256 确认版本，版本不符会拒绝修改。

替换后 `QTranslator` 会从 `C:\ProgramData\ocL10n\client_zh_CN.qm` 加载中文；选择 `ProgramData`
而不是安装目录，是因为安装目录可以被用户改，而 ProgramData 路径固定。

> 注意：这是一个**二进制补丁**，改的是官方签名的文件，因此官方 Authenticode 签名会失效。
> 这也是本项目必须明确声明“非官方”的原因之一。补丁不改功能、不联网、不改配置。

---

## 版本与校验值

所有哈希均为 **SHA-256**（小写十六进制）：

| 文件 | 大小（字节） | SHA-256 |
|---|---|---|
| 官方 `ownCloud-7.1.1.19543.x64.msi` | 39407616 | `91520fe07de44348f5df258863c3b1d57686c451ee40341cd02504768e2b235a` |
| 官方 `ownCloudGui.dll`（未修改） | 3304960 | `d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931` |
| 补丁后 `ownCloudGui.dll` | 3304960 | `9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492` |
| 本仓库 `client_zh_CN.qm` | 70785 | `acc30d22709c18475255f2c32987509e77a3a327e2bba8b67b1b99cc734a148d` |

官方 MSI 下载地址（ownCloud 官方归档服务器，按官方允许的方式下载，不随本仓库分发）：

```
https://attic.owncloud.com/desktop/ownCloud/stable/7.1.1.19543/win/ownCloud-7.1.1.19543.x64.msi
```

---

## 仓库结构

```
owncloud-desktop-zh-cn/
├─ README.md / README_CN.md   # 英文 / 中文说明
├─ translations/
│  ├─ client_zh_CN.ts        # 翻译源文件（canonical，632 条消息 / 110 个上下文）
│  └─ client_zh_CN.qm        # 编译产物，供客户端加载
├─ patches/
│  └─ translation-directory-patch.md   # 20 字节补丁的完整说明（偏移/哈希/原理）
├─ tools/
│  ├─ patch-dll.ps1          # 独立补丁脚本（校验哈希 + 自动备份）
│  ├─ validate-translations.py  # 校验 .ts：完整性、占位符一致性
│  ├─ rebuild-qm.ps1         # 用 Qt lrelease 从 .ts 重新生成 .qm
│  ├─ setup/                 # 中文安装器源码（C# / WinForms / .NET Framework 4）
│  │  ├─ OwnCloudZhSetup.cs
│  │  ├─ app.manifest        # requireAdministrator
│  │  └─ build.ps1
│  └─ windows/               # 可选：资源管理器“云文件菜单”中文化（系统级，见其 README）
│     ├─ cloud-menu-zh.ps1   # 在本机从 en-US MUI 生成 zh-CN MUI / 安装 / 卸载
│     ├─ install-cloud-menu-zh.cmd
│     └─ uninstall-cloud-menu-zh.cmd
├─ docs/
│  ├─ verification.md        # 验证记录（格式一致性、运行日志、哈希）
│  ├─ publish.md             # 发布到 GitHub 的步骤
│  └─ setup-ui.png           # 安装向导截图
└─ .github/workflows/ci.yml  # CI：校验翻译 + 编译安装器 + 自检
```

---

## 开发与发布

**修改翻译**

1. 编辑 `translations/client_zh_CN.ts`（Qt Linguist 或任意文本编辑器）；
2. 校验：`python tools/validate-translations.py`；
3. 重新编译 `.qm`：`powershell -ExecutionPolicy Bypass -File tools/rebuild-qm.ps1`
   （需要 Qt 的 `lrelease`；也可以直接用 Qt Linguist 打开 .ts 后“发布”）；
4. 提交 `.ts` 和 `.qm` 两个文件。

**编译安装器**（Windows 自带 .NET Framework 4 即可，无需安装 SDK）

```powershell
powershell -ExecutionPolicy Bypass -File tools/setup/build.ps1
# 产物：dist/ownCloud-7.1.1-简体中文安装程序.exe
```

**提交前自查**：运行 `python tools/check-privacy.py`，确认没有误带本机用户目录、机器名、
内网域名、邮箱、手机号等敏感信息（CI 也会自动执行）。

推送到 GitHub 的完整步骤（建仓库、初始化、Release 附件、CI、合规自查）见
[`docs/publish.md`](docs/publish.md)。

---

## 免责声明与许可

- 本仓库的翻译、补丁脚本、安装器源码以 **GNU GPL v2.0** 发布（见 `LICENSE`）。
  原因是翻译与补丁是 ownCloud 桌面客户端（GPLv2 作品）的衍生作品，必须使用相同许可。
- 本仓库**不包含、也不分发** ownCloud 官方安装包或任何第三方二进制（Qt、OpenSSL、微软 VC++ 运行时等）；
  安装器仅在运行时从官方服务器下载原始 MSI 并校验 SHA-256。如果你要二次分发包含这些二进制的打包版本，
  请自行确认 Qt LGPLv3、OpenSSL、Microsoft 可再发行组件等许可义务。
- 本项目与 ownCloud GmbH 无关联，不使用其官方 logo，名称仅用于说明兼容的软件对象（见 `TRADEMARKS.md`）。
- 软件按“原样”提供，不附带任何担保；使用本补丁造成的任何问题由使用者自行承担。
