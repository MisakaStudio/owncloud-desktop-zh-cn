# 翻译目录补丁说明（7.1.1.19543）

本文说明让 ownCloud 桌面客户端加载**外置** `.qm` 语言包所需的最小修改。

## 1. 为什么需要这个补丁

ownCloud 客户端把自身翻译编译进了 `ownCloudResources.dll` 的 Qt 资源中，运行时通过常量路径读取：

```cpp
// 概念示意，不是原始源码
QString translationsDirectoryPath() { return QStringLiteral(":/client/translations/"); }
```

`:/client/translations/` 是 Qt 资源路径（Qt Resource System），不是文件系统路径。因此把
`client_zh_CN.qm` 放在磁盘上任何位置都不会被加载。

把该常量改成磁盘目录（例如 `C:/ProgramData/ocL10n/`）后，`QTranslator` 就会从磁盘加载
`client_zh_CN.qm`，无需修改任何逻辑代码。

## 2. 补丁内容

| 项目 | 值 |
|---|---|
| 目标文件 | `ownCloudGui.dll`（7.1.1.19543，x64） |
| 文件偏移 | `0x24B900`（十进制 2406656） |
| 修改长度 | 44 字节（22 个 UTF-16LE 字符） |
| 实际变化字节 | 20 个（其余字符恰好相同） |
| 原字符串 | `:/client/translations/` |
| 新字符串 | `C:/ProgramData/ocL10n/` |
| 文件大小 | 3304960 → 3304960（不变） |

两个字符串长度都是 22 个字符，因此可以原位等长替换，PE 结构、字符串长度字段都不需要改。

### 校验值

| 状态 | SHA-256 |
|---|---|
| 官方原始 `ownCloudGui.dll` | `d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931` |
| 补丁后 `ownCloudGui.dll` | `9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492` |

官方 DLL 可从官方 MSI（SHA-256 `91520fe07de44348f5df258863c3b1d57686c451ee40341cd02504768e2b235a`）
中提取，或来自 7.1.1.19543 的安装目录。**哈希不符时必须停止**，说明版本不同，偏移不可用。

## 3. 自动化脚本

```powershell
# 先完全退出 ownCloud（托盘图标右键退出，或 taskkill /f /im owncloud.exe）
powershell -ExecutionPolicy Bypass -File tools\patch-dll.ps1 -DryRun      # 只校验，不写
powershell -ExecutionPolicy Bypass -File tools\patch-dll.ps1             # 备份并打补丁
```

脚本会：

1. 计算目标 DLL 的 SHA-256；
2. 若已是补丁版 → 跳过；若是官方版 → 继续；否则报错退出；
3. 校验偏移处的原始字节确实是 `:/client/translations/`；
4. 首次修改前备份为 `ownCloudGui.dll.orig`；
5. 原位替换为 `C:/ProgramData/ocL10n/`，写回后再校验哈希必须等于补丁后值。

## 4. 手工操作（不依赖脚本）

Python 示例（管理员权限运行，先备份）：

```python
import hashlib, pathlib

dll = pathlib.Path(r"C:\Program Files\ownCloud\ownCloudGui.dll")
OFFICIAL = "d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931"
PATCHED  = "9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492"
OFFSET   = 0x24B900
OLD      = ":/client/translations/"
NEW      = "C:/ProgramData/ocL10n/"

data = bytearray(dll.read_bytes())
assert hashlib.sha256(data).hexdigest() == OFFICIAL, "版本不符，已停止"
old, new = OLD.encode("utf-16-le"), NEW.encode("utf-16-le")
assert len(old) == len(new) == 44
assert data[OFFSET:OFFSET+44] == old, "补丁位置内容不符"
dll.with_name(dll.name + ".orig").write_bytes(data)   # 备份
data[OFFSET:OFFSET+44] = new
dll.write_bytes(data)
assert hashlib.sha256(data).hexdigest() == PATCHED
print("ok")
```

## 5. 适用范围与风险

- **只适用于 7.1.1.19543**。其他版本请重新定位常量偏移（见下节）。
- 修改后官方 Authenticode 签名失效 → 这是为什么本项目必须明确标注“非官方”。
- 补丁不改变任何功能代码，不联网，不改配置；只改一个字符串常量。
- 客户端升级/“修复安装”会用官方文件覆盖 `ownCloudGui.dll`，需要重新运行补丁。
- 如果以后上游官方加入了中文，则不再需要本补丁（也不要使用）。

## 6. 如何适配新版本

1. 在新版 `ownCloudGui.dll` 中搜索 UTF-16LE 编码的 `:/client/translations/`：

   ```powershell
   $bytes = [IO.File]::ReadAllBytes("ownCloudGui.dll")
   $needle = [Text.Encoding]::Unicode.GetBytes(":/client/translations/")
   # 逐字节查找 needle 出现的位置，记录偏移
   ```

2. 选择同样 22 个字符的目标磁盘路径（例如 `C:/ProgramData/ocL10n/`）；
3. 更新 `tools/patch-dll.ps1` 与 `tools/setup/OwnCloudZhSetup.cs` 里的
   `PatchOffset` / 官方哈希 / 补丁后哈希 三个常量；
4. 用 `-DryRun` 验证后再实跑，并记录新的哈希到 README。

> 提示：如果搜索到多处，需要确认哪一处在翻译加载路径上（通常只出现一次，且紧邻
   `client_`、`.qm` 这类字符串常量）。
