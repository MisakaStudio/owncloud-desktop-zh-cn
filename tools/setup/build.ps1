# 编译中文安装程序
# 仅需 Windows 自带的 .NET Framework 4（csc.exe），不需要安装 Visual Studio / SDK。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\setup\build.ps1
# 产物：
#   dist\ownCloud-7.1.1-简体中文安装程序.exe

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $here '..\..')
$repo = $root.Path
$dist = Join-Path $repo 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path $csc)) { throw '找不到 .NET Framework 4 的 csc.exe' }

$src = Join-Path $here 'OwnCloudZhSetup.cs'
$man = Join-Path $here 'app.manifest'
$qm  = Join-Path $repo 'translations\client_zh_CN.qm'
$out = Join-Path $dist 'ownCloud-7.1.1-简体中文安装程序.exe'

& $csc /nologo /target:winexe /optimize+ /out:$out /win32manifest:$man `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll `
    "/resource:$qm,client_zh_CN.qm" `
    $src
if ($LASTEXITCODE -ne 0) { throw "编译失败（csc 退出码 $LASTEXITCODE）" }

$hash = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
Write-Host ("已生成: {0}" -f $out)
Write-Host ("大小  : {0} 字节" -f (Get-Item $out).Length)
Write-Host ("SHA256: {0}" -f $hash)
