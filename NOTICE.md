# NOTICE — 版权与第三方说明

本项目（owncloud-desktop-zh-cn，下称“本项目”）是社区制作的 ownCloud 桌面客户端简体中文语言包
及其安装工具。**本项目与 ownCloud GmbH 没有任何关联，也不是官方发布。**

## 1. 上游软件

- **ownCloud Desktop Client** — Copyright © ownCloud GmbH 及贡献者。
  - 许可证：GNU General Public License v2.0（GPLv2）
  - 源码：<https://github.com/owncloud/client>
  - 本项目的翻译、补丁与安装器是对该作品的衍生/配套工作，因此按 GPLv2 发布（见 `LICENSE`）。

## 2. 本项目内容

| 内容 | 作者 | 许可证 |
|---|---|---|
| `translations/client_zh_CN.ts`、`client_zh_CN.qm` | 本项目贡献者 | GPL-2.0 |
| `patches/`、`tools/`、`tools/setup/` | 本项目贡献者 | GPL-2.0 |

本项目**不包含** ownCloud 官方安装包（MSI）、`ownCloudGui.dll`、`ownCloudResources.dll`，
也不包含 Qt、OpenSSL 或任何其他第三方二进制。安装器在用户机器上：

1. 从 ownCloud 官方服务器下载官方 MSI，并用 SHA-256 校验；
2. 用 `msiexec` 安装该官方包；
3. 在本地对已安装的 `ownCloudGui.dll` 做 20 字节修改（同时保留 `.orig` 备份）。

## 3. 第三方组件（未随本项目分发，但安装在用户机器上）

ownCloud 官方安装包中包含若干第三方组件，它们各自适用自己的许可证：

- **Qt 6**（LGPLv3 / GPLv3，动态链接）— <https://www.qt.io/licensing/>
- **OpenSSL**（Apache License 2.0）
- **Microsoft Visual C++ 运行库**（按 Microsoft 可再发行组件许可分发）
- 其他库（zlib、bzip2、HarfBuzz、libxml2 等）见官方安装包内的许可文件。

如果你要制作并分发包含这些二进制的“整合包”，请自行履行相应许可义务；本项目的安装器刻意
避免了再分发这些文件。

## 4. 商标

ownCloud 及相关名称、标识是 ownCloud GmbH 的商标。见 `TRADEMARKS.md`。
