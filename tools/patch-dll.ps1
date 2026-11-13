# ownCloud 桌面客户端中文界面补丁脚本（独立版）
#
# 作用：把 ownCloudGui.dll 里保存翻译目录的常量
#         :/client/translations/   ->   C:/ProgramData/ocL10n/
#       两者都是 22 个字符，属于等长替换，只改动 20 个字节，文件大小不变。
#
# 本脚本只对 ownCloud 桌面客户端 7.1.1.19543 有效：
#   官方 ownCloudGui.dll SHA-256 = d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931
#   补丁后            SHA-256 = 9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492
# 版本不符会拒绝修改（避免把别的版本改坏）。
#
# 用法（需要管理员权限，先退出 ownCloud）：
#   powershell -ExecutionPolicy Bypass -File tools\patch-dll.ps1
#   powershell -ExecutionPolicy Bypass -File tools\patch-dll.ps1 -InstallDir "D:\Apps\ownCloud"
#   powershell -ExecutionPolicy Bypass -File tools\patch-dll.ps1 -DllPath "C:\path\ownCloudGui.dll" -DryRun
#
# 本脚本是 GPLv2 项目 owncloud-desktop-zh-cn 的一部分，见仓库根目录 LICENSE。

[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'ownCloud'),
    [string]$DllPath,
    [string]$L10nDir = (Join-Path $env:ProgramData 'ocL10n'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$OfficialSha = 'd52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931'
$PatchedSha  = '9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492'
$PatchOffset = 0x24B900
$PatchOld    = ':/client/translations/'
$PatchNew    = 'C:/ProgramData/ocL10n/'

function Get-Sha256Bytes([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

function Get-Sha256File([string]$Path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'Read')
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLowerInvariant()
    } finally { $fs.Dispose(); $sha.Dispose() }
}

if (-not $DllPath) { $DllPath = Join-Path $InstallDir 'ownCloudGui.dll' }
if (-not (Test-Path $DllPath)) { throw "找不到 $DllPath，请确认 ownCloud 已安装，或用 -DllPath 指定。" }

Write-Host "目标文件 : $DllPath"
$bytes = [System.IO.File]::ReadAllBytes($DllPath)
$hash = Get-Sha256Bytes $bytes
Write-Host "当前哈希 : $hash"

if ($hash -eq $PatchedSha) {
    Write-Host "该文件已经是中文版（哈希匹配），无需重复打补丁。" -ForegroundColor Green
} elseif ($hash -ne $OfficialSha) {
    throw @"
该 ownCloudGui.dll 不是 7.1.1.19543 的官方版本，已停止。
  期望官方 SHA-256: $OfficialSha
  实际 SHA-256    : $hash
请先安装对应版本，或使用与版本匹配的补丁偏移。
"@
} else {
    $oldBytes = [System.Text.Encoding]::Unicode.GetBytes($PatchOld)
    $newBytes = [System.Text.Encoding]::Unicode.GetBytes($PatchNew)
    if ($PatchOffset + $oldBytes.Length -gt $bytes.Length) { throw '文件长度异常，已停止。' }
    for ($i = 0; $i -lt $oldBytes.Length; $i++) {
        if ($bytes[$PatchOffset + $i] -ne $oldBytes[$i]) {
            throw ("补丁位置内容不符（偏移 0x{0:X}），可能不是该版本，已停止。" -f $PatchOffset)
        }
    }
    if ($DryRun) {
        Write-Host "[DryRun] 校验通过，可以安全打补丁（未写入文件）。" -ForegroundColor Yellow
    } else {
        $backup = "$DllPath.orig"
        if (-not (Test-Path $backup)) {
            Copy-Item -LiteralPath $DllPath -Destination $backup -Force
            Write-Host "已备份原文件 : $backup"
        } else {
            Write-Host "备份已存在   : $backup（保留最早的官方原版）"
        }
        [System.Array]::Copy($newBytes, 0, $bytes, $PatchOffset, $newBytes.Length)
        [System.IO.File]::WriteAllBytes($DllPath, $bytes)
        $after = Get-Sha256File $DllPath
        if ($after -ne $PatchedSha) { throw "补丁后校验失败（$after），请用 .orig 还原。" }
        Write-Host "补丁完成，仅修改 20 个字节。" -ForegroundColor Green
        Write-Host "补丁后哈希 : $after"
    }
}

# 安装 / 刷新语言包（如果仓库里有 translations/client_zh_CN.qm）
$qmSource = Join-Path (Split-Path -Parent $PSScriptRoot) 'translations\client_zh_CN.qm'
if (Test-Path $qmSource) {
    if (-not (Test-Path $L10nDir)) { New-Item -ItemType Directory -Force -Path $L10nDir | Out-Null }
    $qmTarget = Join-Path $L10nDir 'client_zh_CN.qm'
    if ($DryRun) {
        Write-Host "[DryRun] 将复制语言包 -> $qmTarget" -ForegroundColor Yellow
    } else {
        Copy-Item -LiteralPath $qmSource -Destination $qmTarget -Force
        Write-Host "语言包已写入 : $qmTarget"
    }
}

Write-Host ''
Write-Host '完成。若客户端正在运行，请完全退出后重新打开；界面应变为简体中文。'
Write-Host '还原英文：删除 C:\ProgramData\ocL10n，并把 ownCloudGui.dll.orig 复制回 ownCloudGui.dll。'
