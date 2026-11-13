# ownCloud Desktop Client — Simplified Chinese Localization (unofficial)

> **中文说明：** [README_CN.md](README_CN.md)
> This is an **unofficial community localization**. It is not affiliated with, sponsored by, or
> endorsed by ownCloud GmbH. ownCloud is a trademark of ownCloud GmbH. This project only provides
> localization; it does not change the software's functionality.

The official ownCloud desktop client **7.1.1.19543** ships 15 languages (de, fr, it, ja, …) and
**no Simplified Chinese (`zh_CN`)**, so the UI is English-only. This project provides:

- a **632-string Simplified Chinese translation** (Qt `.ts` source + compiled `.qm`);
- a **Chinese installer** that obtains the official, unmodified MSI, verifies its SHA-256,
  installs it silently and then enables the Chinese UI;
- a documented, reproducible **20-byte binary patch** that makes the client load an external
  translation catalog from disk.

---

## Quick start (end users)

1. Download `ownCloud-7.1.1-简体中文安装程序.exe` from the **Releases** page;
2. Right-click → **Run as administrator** (or confirm the UAC prompt);
3. Click “开始安装” (Start) and wait for it to finish;
4. Open ownCloud — the UI is now in Simplified Chinese.

What the installer does:

| Step | Detail |
|---|---|
| ① Obtain the official MSI | Looks for `ownCloud-7.1.1.19543.x64.msi` locally (Downloads / Desktop / cwd / temp), otherwise downloads it from the official ownCloud server, otherwise asks you to pick the file. **Every source must match the official SHA-256** (see below) or the installer refuses to continue |
| ② Install the client | Skipped if ownCloud is already installed; otherwise `msiexec /i ... /qn /norestart` |
| ③ Apply the UI patch | Verifies `ownCloudGui.dll` matches the official 7.1.1.19543 hash, replaces 20 bytes in place (same length, file size unchanged) and backs up the original as `ownCloudGui.dll.orig` |
| ④ Install the catalog | Writes `client_zh_CN.qm` to `C:\ProgramData\ocL10n\` and verifies its hash |

Requirements: Windows 10 / 11 x64. Administrator rights are required for installation.

### Restore the English UI

1. Delete `C:\ProgramData\ocL10n`;
2. Copy `<install dir>\ownCloudGui.dll.orig` back to `ownCloudGui.dll`;
3. Restart ownCloud.

---

## Manual installation

1. Download `ownCloud-7.1.1.19543.x64.msi` from the official ownCloud server and verify the SHA-256
   against the table below;
2. Install silently: `msiexec /i ownCloud-7.1.1.19543.x64.msi /qn /norestart`
3. Run the patch script as administrator (it verifies the hash and creates a backup):

   ```powershell
   taskkill /f /im owncloud.exe
   powershell -ExecutionPolicy Bypass -File .\tools\patch-dll.ps1 -InstallDir "C:\Program Files\ownCloud"
   ```

4. Create `C:\ProgramData\ocL10n` and copy `translations\client_zh_CN.qm` into it;
5. Restart ownCloud.

---

## Optional: localize the Explorer “cloud files” context menu (Windows component)

Inside the ownCloud sync root, a few context-menu entries remain English, e.g.
`Always keep on this device`, `Free up space`, `Pause syncing`.

These are **not** ownCloud strings. ownCloud only registers the sync folder as a Windows
“Cloud Files” location; the menu is provided by Windows Explorer and its strings live in the
MUI resource of the Windows component `Windows.FileExplorer.Common.dll`. Most Chinese
Windows installations ship only the `en-US` MUI and lack the `zh-CN` one, so the items fall
back to English.

This repository includes an **optional** tool that generates and installs a zh-CN MUI on the
user's machine (17 strings, resource language `0x0409` → `0x0804`, file size unchanged, the
original `en-US` file is not modified):

```bat
rem Requires administrator rights (the script self-elevates) and restarts Explorer.
tools\windows\install-cloud-menu-zh.cmd

rem Restore
tools\windows\uninstall-cloud-menu-zh.cmd
```

Details, rationale, risks and restore steps: [`tools/windows/README.md`](tools/windows/README.md).

Notes:

- This is a **system-level** change (it adds one MUI file under
  `C:\Windows\System32\zh-CN\`). It is independent of the ownCloud localization and not
  required for it;
- No Microsoft files are committed or redistributed: the MUI is generated locally from the
  user's own system file at runtime (`.gitignore` excludes `*.mui`);
- Windows updates may overwrite it — re-run the install script if that happens; uninstall to
  restore completely.

---

## Why is a DLL patch required?

The client compiles its own `client_*.qm` catalogs into a Qt resource inside `ownCloudResources.dll`
and reads them only from the Qt resource path `:/client/translations/`. A `.qm` file placed on disk is
therefore never loaded.

`ownCloudGui.dll` stores that directory constant as a UTF-16LE string of **22 characters**:

```
old: :/client/translations/
new: C:/ProgramData/ocL10n/
```

Both strings have the same length, so the replacement can be done in place — no code structure or file
size changes:

- offset `0x24B900` (2406656), 44 bytes (22 UTF-16 code units);
- 20 bytes actually differ;
- valid **only** for the exact build `7.1.1.19543`; the scripts verify SHA-256 first and abort on any
  other version.

With the patch, `QTranslator` loads `C:\ProgramData\ocL10n\client_zh_CN.qm`. `ProgramData` is used
instead of the install directory because the install directory is user-selectable.

> Note: this modifies a file signed by ownCloud GmbH, so its Authenticode signature no longer matches.
> That is one reason this project must be clearly marked as unofficial. The patch does not touch
> functionality, network access or configuration.

---

## Version and checksums

All hashes are **SHA-256** (lowercase hex):

| File | Size (bytes) | SHA-256 |
|---|---|---|
| Official `ownCloud-7.1.1.19543.x64.msi` | 39407616 | `91520fe07de44348f5df258863c3b1d57686c451ee40341cd02504768e2b235a` |
| Official `ownCloudGui.dll` (unmodified) | 3304960 | `d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931` |
| Patched `ownCloudGui.dll` | 3304960 | `9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492` |
| `client_zh_CN.qm` in this repo | 70785 | `acc30d22709c18475255f2c32987509e77a3a327e2bba8b67b1b99cc734a148d` |

Official MSI (downloaded at runtime from the official ownCloud archive; **not redistributed here**):

```
https://attic.owncloud.com/desktop/ownCloud/stable/7.1.1.19543/win/ownCloud-7.1.1.19543.x64.msi
```

---

## Repository layout

```
owncloud-desktop-zh-cn/
├─ README.md / README_CN.md   # English / Chinese documentation
├─ translations/
│  ├─ client_zh_CN.ts        # translation source (canonical): 632 messages, 110 contexts
│  └─ client_zh_CN.qm        # compiled catalog loaded by the client
├─ patches/
│  └─ translation-directory-patch.md   # full patch documentation (offset/hashes/rationale)
├─ tools/
│  ├─ patch-dll.ps1          # standalone patch script (hash checks + backup)
│  ├─ validate-translations.py  # .ts completeness / placeholder validation
│  ├─ rebuild-qm.ps1         # rebuild .qm from .ts with Qt lrelease
│  ├─ setup/                 # installer source (C# / WinForms / .NET Framework 4)
│  └─ windows/               # optional: Explorer cloud-files menu localization
│     ├─ cloud-menu-zh.ps1   # generate zh-CN MUI locally / install / uninstall
│     ├─ install-cloud-menu-zh.cmd
│     └─ uninstall-cloud-menu-zh.cmd
├─ docs/
│  ├─ verification.md        # verification record (format parity, runtime log, hashes)
│  ├─ publish.md             # publishing to GitHub
│  └─ setup-ui.png           # installer screenshot
└─ .github/workflows/ci.yml  # CI: validate translations + build installer + self-test
```

---

## Build and release

**Edit translations**

1. Edit `translations/client_zh_CN.ts`;
2. `python tools/validate-translations.py`;
3. `powershell -ExecutionPolicy Bypass -File tools/rebuild-qm.ps1` (requires Qt `lrelease`);
4. Commit both the `.ts` and the `.qm`.

**Build the installer** (only needs the .NET Framework 4 compiler shipped with Windows):

```powershell
powershell -ExecutionPolicy Bypass -File tools/setup/build.ps1
# output: dist/ownCloud-7.1.1-简体中文安装程序.exe
```

**Before committing**: run `python tools/check-privacy.py` to make sure no local user paths, machine
names, intranet domains, e-mail addresses or phone numbers leak into the repository (CI runs it too).

See [`docs/publish.md`](docs/publish.md) for the full GitHub publishing checklist.

---

## License and disclaimer

- The translation, patch scripts and installer source in this repository are licensed under
  **GNU GPL v2.0** (see `LICENSE`), because they are derivative works of the GPLv2 ownCloud desktop
  client.
- This repository does **not** contain or redistribute the official ownCloud installer or any
  third-party binaries (Qt, OpenSSL, Microsoft VC++ runtime, …). The installer downloads the original
  MSI from the official server at runtime and verifies its SHA-256. If you build a bundle that
  redistributes those binaries, you are responsible for the corresponding license obligations
  (Qt LGPLv3, OpenSSL, Microsoft redistributables).
- Not affiliated with ownCloud GmbH. No official logos are used; the name is used only to describe
  the software this localization targets (see `TRADEMARKS.md`).
- Provided “as is”, without warranty of any kind.
