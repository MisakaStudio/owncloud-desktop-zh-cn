# 验证记录

本文件记录 v1.0.0（ownCloud 桌面客户端 7.1.1.19543）汉化的验证方法与结果。
所有验证在 Windows 10 21H2（19044，简体中文系统，AMD64）上完成。

## 1. 语言包格式验证（`.qm` 与 Qt 官方输出完全一致）

`.qm` 是 Qt 的二进制翻译格式。为确认本项目生成的 `client_zh_CN.qm` 与 Qt 官方 `lrelease`
的输出格式**逐字节兼容**，使用自写的解析/重建工具对**官方自带**的语言包做“解析 → 重建 →
逐字节比对”：

| 官方语言包 | 原始大小 | 重建大小 | 结果 |
|---|---|---|---|
| `qtbase_zh_CN.qm`（Qt 自带中文） | 136673 | 136673 | 完全一致 |
| `client_de.qm`（客户端德语，含复数规则） | 112502 | 112502 | 完全一致 |
| `client_ja_JP.qm`（客户端日语） | 62988 | 62988 | 完全一致 |

说明：重建过程使用的写入逻辑与本项目生成 `client_zh_CN.qm` 的写入逻辑相同，因此该结果
证明生成的 `.qm` 在结构、哈希表、消息编码、复数规则等所有细节上与 Qt 官方格式一致。

本项目的 `client_zh_CN.qm`：

- 大小：70785 字节
- SHA-256：`acc30d22709c18475255f2c32987509e77a3a327e2bba8b67b1b99cc734a148d`
- 语言字段：`zh_CN`
- 消息数：632（110 个上下文）

## 2. 客户端实际加载验证

用打过补丁的客户端启动，捕获其调试输出（`--logdebug`），可见：

```
[     321ms] DBG pid=10684: gui.main: Using "zh_CN" translation "zh_CN"
```

该日志由客户端翻译模块在**成功加载语言包**后输出，证明：

1. `ownCloudGui.dll` 的目录常量补丁生效（客户端改从磁盘目录读取）；
2. `client_zh_CN.qm` 被 Qt 的 `QTranslator` 正确加载并安装；
3. 客户端识别到当前系统语言为 `zh_CN`。

同时客户端日志显示 `locale: "zh_CN"`，与预期一致。

## 3. 哈希校验

| 文件 | 大小（字节） | SHA-256 |
|---|---|---|
| 官方 `ownCloud-7.1.1.19543.x64.msi` | 39407616 | `91520fe07de44348f5df258863c3b1d57686c451ee40341cd02504768e2b235a` |
| 官方 `ownCloudGui.dll` | 3304960 | `d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931` |
| 补丁后 `ownCloudGui.dll` | 3304960 | `9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492` |
| `client_zh_CN.qm` | 70785 | `acc30d22709c18475255f2c32987509e77a3a327e2bba8b67b1b99cc734a148d` |

补丁前后文件大小完全一致（3304960 字节），差异只有 20 个字节。

## 4. 安装器界面

安装向导已在简体中文 Windows 上实际渲染验证（见 `docs/setup-ui.png`）：
界面全部为中文，能正确识别已安装的客户端路径（`C:\Program Files\ownCloud`）。

## 5. 复现验证

任何人都可以复现上述验证：

```powershell
# 1) 校验内置翻译包（编译安装器后）
powershell -ExecutionPolicy Bypass -File tools\setup\build.ps1
$exe = 'dist\ownCloud-7.1.1-简体中文安装程序.exe'
$p = Start-Process $exe -ArgumentList '--selftest' -Wait -PassThru   # ExitCode 0 = 内置 qm 哈希正确
Start-Process $exe -ArgumentList @('--extract-qm','out') -Wait      # 解出 qm，与 translations 下比对

# 2) 校验补丁偏移是否正确（不会写文件）
powershell -ExecutionPolicy Bypass -File tools\patch-dll.ps1 -DryRun

# 3) 校验翻译文件
python tools\validate-translations.py
```
