# 资源管理器「云文件菜单」中文化（可选工具，系统级修改）
#
# 背景：Explorer 里云文件（ownCloud / OneDrive 等 Cloud Files 提供方）的
#   "Always keep on this device" / "Free up space" / "Pause syncing" 等菜单项，
#   字符串来自 Windows 组件 Windows.FileExplorer.Common.dll 的 MUI 资源：
#       C:\Windows\System32\<语言>\Windows.FileExplorer.Common.dll.mui
#   多数中文 Windows 只有 en-US 版本、缺少 zh-CN 版本，所以这些菜单回退显示英文。
#
# 本脚本不是 ownCloud 汉化的一部分，而是可选的 Windows 系统级修补：
#   1. 读取本机 en-US 的 MUI（用户自己的系统文件，脚本不下载/不分发它）；
#   2. 把 17 条已知英文菜单字符串等长替换为中文（空格补齐，文件大小/PE 结构不变）；
#   3. 把资源目录中的语言 ID 0x0409(en-US) 改为 0x0804(zh-CN)；
#   4. 写入 System32\zh-CN\Windows.FileExplorer.Common.dll.mui（需管理员），
#      原 en-US 文件不会被修改；可随时 -Uninstall 还原。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\windows\cloud-menu-zh.ps1 -GenerateOnly -OutputPath out.mui
#   powershell -ExecutionPolicy Bypass -File tools\windows\cloud-menu-zh.ps1 -Install      # 需要管理员
#   powershell -ExecutionPolicy Bypass -File tools\windows\cloud-menu-zh.ps1 -Uninstall    # 需要管理员
#
# 本文件是 GPLv2 项目 owncloud-desktop-zh-cn 的一部分，见仓库根目录 LICENSE。
# 修改记录：2026-11-13 新增。

[CmdletBinding()]
param(
    [switch]$GenerateOnly,
    [string]$OutputPath,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$EnMui     = Join-Path $env:WINDIR 'System32\en-US\Windows.FileExplorer.Common.dll.mui'
$TargetDir = Join-Path $env:WINDIR 'System32\zh-CN'
$TargetMui = Join-Path $TargetDir 'Windows.FileExplorer.Common.dll.mui'
$RT_STRING = 6
$LANG_EN   = 0x0409
$LANG_ZH   = 0x0804

$Map = @{
    'Open' = '打开'
    'Open the selected file with the default program.' = '用默认程序打开所选文件。'
    'View problems' = '查看问题'
    'Resolve syncing errors for the selected item' = '解决所选项目的同步问题'
    'Always keep on this device' = '始终保留在此设备上'
    'Download and make selected items always available' = '下载所选项目并使其始终可用'
    'Free up space' = '释放空间'
    'Items will be available only when online' = '项目将只在联机时可用'
    'Pause syncing' = '暂停同步'
    'Pause syncing files' = '暂停文件同步'
    'Resume syncing' = '恢复同步'
    'Resume syncing files' = '恢复文件同步'
    'Sync' = '同步'
    'Check for sync updates' = '检查同步更新'
    "Can't complete operation" = '无法完成操作'
    "We're unable to complete your requested operation right now. Would you like to make it available offline the next time you connect?" = '当前无法完成请求的操作。是否要在下次连接时将其设为可脱机使用？'
    "We're unable to complete your requested operation right now. Would you like to make it available online the next time you connect?" = '当前无法完成请求的操作。是否要在下次连接时将其设为仅在联机时可用？'
}

function Test-IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PeInfo([byte[]]$Data) {
    $pe = [BitConverter]::ToInt32($Data, 0x3C)
    if ([Text.Encoding]::ASCII.GetString($Data, $pe, 4) -ne "PE`0`0") {
        throw '目标文件不是有效的 PE 文件。'
    }
    $nsec = [BitConverter]::ToUInt16($Data, $pe + 6)
    $optSize = [BitConverter]::ToUInt16($Data, $pe + 20)
    $opt = $pe + 24
    $magic = [BitConverter]::ToUInt16($Data, $opt)
    if ($magic -eq 0x20B) { $dd = $opt + 112 } else { $dd = $opt + 96 }
    $resRva = [BitConverter]::ToInt32($Data, $dd + 16)
    $sections = @()
    $secBase = $opt + $optSize
    for ($i = 0; $i -lt $nsec; $i++) {
        $o = $secBase + $i * 40
        $sections += [pscustomobject]@{
            Name    = ([Text.Encoding]::ASCII.GetString($Data, $o, 8)).TrimEnd([char]0)
            Va      = [BitConverter]::ToUInt32($Data, $o + 12)
            VSize   = [BitConverter]::ToUInt32($Data, $o + 8)
            RawPtr  = [BitConverter]::ToUInt32($Data, $o + 20)
            RawSize = [BitConverter]::ToUInt32($Data, $o + 16)
        }
    }
    return [pscustomobject]@{ Sections = $sections; ResRva = $resRva }
}

function Convert-RvaToOffset($Sections, [uint32]$Rva) {
    foreach ($s in $Sections) {
        $span = [Math]::Max($s.VSize, $s.RawSize)
        if ($Rva -ge $s.Va -and $Rva -lt ($s.Va + $span)) {
            return [int]($Rva - $s.Va + $s.RawPtr)
        }
    }
    throw ("RVA 映射失败: 0x{0:X}" -f $Rva)
}

function Walk-ResourceDir([byte[]]$Data, [int]$Rsrc, [int]$DirOff, [int]$Level, [int]$TypeId, [int]$NameId, $Out) {
    $named = [BitConverter]::ToUInt16($Data, $DirOff + 12)
    $ids = [BitConverter]::ToUInt16($Data, $DirOff + 14)
    $total = $named + $ids
    for ($i = 0; $i -lt $total; $i++) {
        $e = $DirOff + 16 + $i * 8
        $nameField = [BitConverter]::ToUInt32($Data, $e)
        $offField = [BitConverter]::ToUInt32($Data, $e + 4)
        if ($nameField -band 0x80000000) { $cid = -1 } else { $cid = [int]($nameField -band 0x7FFFFFFF) }
        # OffsetToData 是相对资源目录起点（rsrc）的偏移
        $child = $Rsrc + [int]($offField -band 0x7FFFFFFF)
        if ($Level -eq 0) {
            Walk-ResourceDir $Data $Rsrc $child 1 $cid 0 $Out
        } elseif ($Level -eq 1) {
            Walk-ResourceDir $Data $Rsrc $child 2 $TypeId $cid $Out
        } else {
            $dataEntry = $Rsrc + [int]($offField -band 0x7FFFFFFF)
            $dataRva = [BitConverter]::ToUInt32($Data, $dataEntry)
            $size = [BitConverter]::ToUInt32($Data, $dataEntry + 4)
            $Out.Add([pscustomobject]@{
                Type    = $TypeId
                Name    = $NameId
                Lang    = $cid
                EntryOff = $e
                DataOff = (Convert-RvaToOffset $script:Pe.Sections $dataRva)
                Size    = [int]$size
            }) | Out-Null
        }
    }
}

function Read-BlockStrings([byte[]]$Data, [int]$Off, [int]$Size) {
    $strings = New-Object System.Collections.Generic.List[string]
    $pos = $Off
    for ($i = 0; $i -lt 16; $i++) {
        if (($pos + 2) -gt ($Off + $Size)) { $strings.Add(''); continue }
        $len = [BitConverter]::ToUInt16($Data, $pos)
        $pos += 2
        if (($pos + $len * 2) -gt ($Off + $Size)) { $strings.Add(''); continue }
        $strings.Add([Text.Encoding]::Unicode.GetString($Data, $pos, $len * 2))
        $pos += $len * 2
    }
    return $strings
}

function Get-MuiBytes([byte[]]$Source) {
    $script:Pe = Get-PeInfo $Source
    $rsrc = Convert-RvaToOffset $script:Pe.Sections $script:Pe.ResRva
    $leaves = New-Object System.Collections.Generic.List[object]
    Walk-ResourceDir $Source $rsrc $rsrc 0 0 0 $leaves

    $data = [byte[]]($Source.Clone())
    $translated = 0
    foreach ($item in $leaves) {
        if ($item.Type -ne $RT_STRING) { continue }
        $strings = Read-BlockStrings $data $item.DataOff $item.Size
        $lengths = @()
        foreach ($s in $strings) { $lengths += $s.Length }
        $newStrings = @()
        for ($i = 0; $i -lt 16; $i++) {
            $s = $strings[$i]
            if ($Map.ContainsKey($s)) { $newStrings += $Map[$s]; $translated++ } else { $newStrings += $s }
        }
        $ms = New-Object System.IO.MemoryStream
        for ($i = 0; $i -lt 16; $i++) {
            $s = $newStrings[$i]
            $target = $lengths[$i]
            if ($s.Length -gt $target) { $s = $s.Substring(0, $target) }
            if ($s.Length -lt $target) { $s = $s.PadRight($target, ' ') }
            $chars = [Text.Encoding]::Unicode.GetBytes($s)
            $lenBytes = [BitConverter]::GetBytes([uint16]($chars.Length / 2))
            $ms.Write($lenBytes, 0, 2)
            $ms.Write($chars, 0, $chars.Length)
        }
        $block = $ms.ToArray()
        $ms.Dispose()
        if ($block.Length -ne $item.Size) { throw ("字符串块大小变化: block={0}" -f $item.Name) }
        [Array]::Copy($block, 0, $data, $item.DataOff, $block.Length)
    }

    $langChanged = 0
    foreach ($item in $leaves) {
        if ($item.Lang -eq $LANG_EN) {
            [BitConverter]::GetBytes([uint32]$LANG_ZH).CopyTo($data, $item.EntryOff)
            $langChanged++
        }
    }

    return [pscustomobject]@{ Bytes = $data; Translated = $translated; LangChanged = $langChanged; Blocks = @($leaves | Where-Object { $_.Type -eq $RT_STRING }).Count }
}

function Restart-Explorer {
    Write-Host '正在重启 Windows 资源管理器...'
    Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    Start-Process explorer.exe | Out-Null
}

if (-not (Test-Path $EnMui)) {
    throw "找不到 Windows 资源文件：$EnMui（此工具仅适用于 Windows 10/11）。"
}

# ---------------- 卸载 ----------------
if ($Uninstall) {
    if (-not (Test-IsAdmin)) { throw '需要管理员权限：请右键“以管理员身份运行”。' }
    if (Test-Path $TargetMui) {
        Remove-Item -LiteralPath $TargetMui -Force
        Write-Host "已删除：$TargetMui"
    } else {
        Write-Host "未找到补丁文件：$TargetMui"
    }
    $backup = "$TargetMui.bak-zhcn"
    if (Test-Path $backup) {
        Move-Item -LiteralPath $backup -Destination $TargetMui -Force
        Write-Host "已从备份还原：$TargetMui"
    }
    Restart-Explorer
    Write-Host '完成。云文件菜单将恢复英文。'
    exit 0
}

# ---------------- 生成 ----------------
$result = Get-MuiBytes ([System.IO.File]::ReadAllBytes($EnMui))
$out = if ($OutputPath) { [System.IO.Path]::GetFullPath($OutputPath) } else { Join-Path $env:TEMP 'Windows.FileExplorer.Common.dll.mui' }
$outDir = Split-Path -Parent $out
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
[System.IO.File]::WriteAllBytes($out, $result.Bytes)
Write-Host ("已生成本地化 MUI: {0}" -f $out)
Write-Host ("  大小: {0} 字节（原始 {1}）" -f $result.Bytes.Length, (Get-Item $EnMui).Length)
Write-Host ("  字符串块: {0}，翻译条目: {1}，语言 ID 修改: {2}" -f $result.Blocks, $result.Translated, $result.LangChanged)

if ($GenerateOnly -or -not $Install) {
    if (-not $Install) { Write-Host '提示：加 -Install 可安装到 System32\zh-CN（需管理员）。' }
    exit 0
}

# ---------------- 安装 ----------------
if (-not (Test-IsAdmin)) { throw '需要管理员权限：请右键“以管理员身份运行”。' }
if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null }
if (Test-Path $TargetMui) {
    $backup = "$TargetMui.bak-zhcn"
    if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $TargetMui -Destination $backup -Force }
    Write-Host "已备份原有 MUI：$backup"
}
Copy-Item -LiteralPath $out -Destination $TargetMui -Force
Write-Host "已安装：$TargetMui"
Restart-Explorer
Write-Host ''
Write-Host '完成。请在 ownCloud 同步目录里右键文件查看效果。'
Write-Host '还原：运行 tools\windows\uninstall-cloud-menu-zh.cmd'
