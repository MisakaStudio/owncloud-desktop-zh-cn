# 可选工具：资源管理器「云文件菜单」中文化

> 这是**可选的 Windows 系统级修补**，不属于 ownCloud 汉化本身。
> 不安装它不影响 ownCloud 的任何中文界面。

## 1. 它解决什么问题

在 ownCloud 同步目录里右键文件，菜单中的这些项是英文：

```
Always keep on this device      -> 始终保留在此设备上
Free up space                   -> 释放空间
Pause syncing / Resume syncing  -> 暂停同步 / 恢复同步
Sync / Check for sync updates   -> 同步 / 检查同步更新
```

它们**不是 ownCloud 的字符串**。ownCloud 只是把同步目录注册成 Windows 的
“云文件（Cloud Files）”位置，右键菜单由 Windows 资源管理器提供。这些字符串来自
Windows 组件 `Windows.FileExplorer.Common.dll` 的 MUI 语言资源：

```
C:\Windows\System32\<语言>\Windows.FileExplorer.Common.dll.mui
```

多数中文 Windows 只有 `en-US` 版本、缺少 `zh-CN` 版本，所以回退显示英文。
（可用 `tools/windows/cloud-menu-zh.ps1 -GenerateOnly` 自行核实：本工具读取的正是
本机这份 en-US 文件。）

## 2. 原理

脚本读取本机 `System32\en-US\Windows.FileExplorer.Common.dll.mui`，在内存中：

1. 把 17 条已知英文菜单/提示字符串按**等长**替换为中文（中文更短，用空格补齐，
   文件大小与 PE 结构不变）；
2. 把资源目录里的语言 ID `0x0409`(en-US) 改为 `0x0804`(zh-CN)；
3. 生成 `Windows.FileExplorer.Common.dll.mui`，安装到
   `C:\Windows\System32\zh-CN\`（管理员权限），原 `en-US` 文件**不会被修改**。

## 3. 用法（需要管理员权限）

```bat
rem 安装（双击也行，会自动请求 UAC）
tools\windows\install-cloud-menu-zh.cmd

rem 还原
tools\windows\uninstall-cloud-menu-zh.cmd
```

也可以直接调用 PowerShell：

```powershell
# 只生成，不安装（输出到指定路径，用于检查/调试）
powershell -ExecutionPolicy Bypass -File tools\windows\cloud-menu-zh.ps1 `
    -GenerateOnly -OutputPath "$env:TEMP\zh.mui"

# 安装 / 卸载
powershell -ExecutionPolicy Bypass -File tools\windows\cloud-menu-zh.ps1 -Install
powershell -ExecutionPolicy Bypass -File tools\windows\cloud-menu-zh.ps1 -Uninstall
```

安装/卸载后脚本会重启资源管理器使改动生效。

## 4. 风险与还原

- 会在 `C:\Windows\System32\zh-CN\` **新增一个文件**（需管理员），不修改现有系统文件；
- Windows 更新/系统修复可能覆盖或清除它，届时重新运行安装脚本即可；
- 若安装后菜单仍为英文（个别系统版本不加载自定义 MUI），运行卸载脚本即可完全还原；
- 卸载脚本会删除该 MUI；如果安装时已存在同名文件，会先备份为 `.bak-zhcn`，卸载时还原；
- 与 ownCloud 汉化互不影响：卸载本工具不影响 ownCloud 中文界面。

## 5. 为什么仓库里没有 `.mui` 文件

该 MUI 是从 **用户自己的 Windows 系统文件**派生出来的（含微软的资源元数据）。
为了让仓库本身保持干净、不包含、不再分发微软的文件，本工具**不提交生成的 `.mui`**，
而是在用户本机运行时现场生成。`.gitignore` 已排除 `*.mui`。

## 6. English summary

Optional tool: localizes the Windows Explorer *cloud files* context menu
(`Always keep on this device`, `Free up space`, `Pause/Resume syncing`, …), whose
strings come from the Windows component `Windows.FileExplorer.Common.dll.mui`.
Most Chinese Windows installations ship only the `en-US` MUI, so those items fall back
to English. The script reads the local `en-US` MUI, produces an equal-size zh-CN MUI
(17 strings translated, resource language retagged `0x0409` → `0x0804`) and installs it
to `System32\zh-CN` (admin required). No Microsoft files are distributed in this repo;
the MUI is generated locally at runtime. Run `uninstall-cloud-menu-zh.cmd` to restore.
