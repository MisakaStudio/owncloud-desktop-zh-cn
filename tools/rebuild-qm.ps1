# 从 translations/client_zh_CN.ts 重新生成 client_zh_CN.qm
#
# 需要 Qt 的 lrelease（Qt Linguist 的一部分）。常见来源：
#   - Qt 在线安装器安装 qt6-tools / qttools
#   - Ubuntu/Debian: apt install qt6-l10n-tools（命令名 lrelease-qt6）
#   - Windows: Qt\6.x.x\msvc*/bin\lrelease.exe，或在 PATH 中
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\rebuild-qm.ps1
#   powershell -ExecutionPolicy Bypass -File tools\rebuild-qm.ps1 -LRelease "C:\Qt\6.8.0\msvc2022_64\bin\lrelease.exe"

[CmdletBinding()]
param(
    [string]$LRelease
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path (Join-Path $here '..')
$ts   = Join-Path $repo 'translations\client_zh_CN.ts'
$qm   = Join-Path $repo 'translations\client_zh_CN.qm'

if (-not $LRelease) {
    $names = @('lrelease.exe', 'lrelease-qt6.exe', 'lrelease6.exe', 'lrelease', 'lrelease-qt6', 'lrelease6')
    foreach ($n in $names) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { $LRelease = $cmd.Source; break }
    }
}
if (-not $LRelease) {
    throw '找不到 lrelease。请用 -LRelease 指定路径，或安装 Qt Linguist 工具。'
}

Write-Host "使用 lrelease: $LRelease"
& $LRelease $ts -qm $qm
if ($LASTEXITCODE -ne 0) { throw "lrelease 执行失败（退出码 $LASTEXITCODE）" }

$hash = (Get-FileHash $qm -Algorithm SHA256).Hash.ToLower()
Write-Host ("已生成: {0}" -f $qm)
Write-Host ("大小  : {0} 字节" -f (Get-Item $qm).Length)
Write-Host ("SHA256: {0}" -f $hash)
Write-Host ''
Write-Host '如果 SHA256 与 README 中记录的不一致，请检查是否改了翻译，或 lrelease 版本不同（可能产生不同但兼容的 qm）。'
