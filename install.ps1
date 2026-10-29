# FLG 檔案箱一鍵安裝
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://lanyen007.github.io/FLGPQT/install.ps1))) PQT
#   & ([scriptblock]::Create((irm https://lanyen007.github.io/FLGPQT/install.ps1))) 全部

$Tool = ''
if ($args -and $args.Count -gt 0) { $Tool = [string]$args[0] }

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$RawBase = 'https://raw.githubusercontent.com/lanyen007/FLGPQT/main'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'FLG'

$Tools = @(
    @{ Key = 'PQT';                  File = 'PQT.exe';                  Title = 'PQT（影印機計數器／排程抄表）' }
    @{ Key = 'RicohMfpTool';         File = 'RicohMfpTool.exe';         Title = 'RicohMfpTool（Ricoh 複合機工具）' }
    @{ Key = 'Ricoh_UserCounter';    File = 'Ricoh_UserCounter.exe';    Title = 'Ricoh_UserCounter（使用者計數查詢）' }
    @{ Key = 'UserCounterDownload';  File = 'UserCounterDownload.exe';  Title = 'UserCounterDownload（使用者計數下載）' }
    @{ Key = 'FLGPQT_Download';      File = 'FLGPQT_Download.exe';      Title = 'FLGPQT_Download（多工具一鍵下載）' }
)

function Write-Info([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}
function Write-Ok([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}
function Write-WarnMsg([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
}

function Get-DesktopPath {
    [Environment]::GetFolderPath('Desktop')
}

function Get-StartMenuProgramsPath {
    Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\FLG'
}

function New-Shortcut {
    param(
        [Parameter(Mandatory = $true)][string]$ShortcutPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$WorkingDirectory = ''
    )
    $dir = Split-Path -Parent $ShortcutPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($ShortcutPath)
    $sc.TargetPath = $TargetPath
    if ($WorkingDirectory) {
        $sc.WorkingDirectory = $WorkingDirectory
    } else {
        $sc.WorkingDirectory = Split-Path -Parent $TargetPath
    }
    $sc.IconLocation = "$TargetPath,0"
    $sc.Save()
}

function Install-OneTool {
    param(
        [Parameter(Mandatory = $true)]$Item
    )
    $key = $Item.Key
    $file = $Item.File
    $destDir = Join-Path $InstallRoot $key
    $destPath = Join-Path $destDir $file
    $url = "$RawBase/$file"

    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Write-Info "正在下載 $key …"
    Write-Host "  $url"
    $tmp = Join-Path $env:TEMP ("flg_install_" + [Guid]::NewGuid().ToString('N') + '.exe')
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        if (-not (Test-Path -LiteralPath $tmp) -or ((Get-Item -LiteralPath $tmp).Length -lt 1024)) {
            throw "下載失敗或檔案過小：$file"
        }
        Copy-Item -LiteralPath $tmp -Destination $destPath -Force
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    $desktop = Get-DesktopPath
    $deskLnk = Join-Path $desktop ($key + '.lnk')
    New-Shortcut -ShortcutPath $deskLnk -TargetPath $destPath -WorkingDirectory $destDir

    $smDir = Get-StartMenuProgramsPath
    $smLnk = Join-Path $smDir ($key + '.lnk')
    New-Shortcut -ShortcutPath $smLnk -TargetPath $destPath -WorkingDirectory $destDir

    Write-Ok "已安裝 $key → $destPath"
    return $destPath
}

function Show-Menu {
    Write-Host ''
    Write-Host '======== FLG 檔案箱 ========' -ForegroundColor White
    Write-Host '請選擇要安裝的工具：'
    $i = 1
    foreach ($t in $Tools) {
        Write-Host ("  {0}) {1}" -f $i, $t.Title)
        $i++
    }
    Write-Host ("  {0}) 全部安裝" -f $i)
    Write-Host '  0) 取消'
    Write-Host ''
}

function Resolve-Selection {
    param([string]$InputValue)

    if ([string]::IsNullOrWhiteSpace($InputValue)) { return @() }

    $v = $InputValue.Trim()
    if ($v -eq '0' -or $v -match '^(?i)(q|quit|exit|cancel|取消)$') { return @() }

    if ($v -match '^(?i)(all|全部|全部安裝)$') {
        return @($Tools)
    }

    # numeric index 1..N
    $n = 0
    if ([int]::TryParse($v, [ref]$n)) {
        if ($n -ge 1 -and $n -le $Tools.Count) {
            return @($Tools[$n - 1])
        }
        if ($n -eq ($Tools.Count + 1)) {
            return @($Tools)
        }
        throw "無效選項：$v"
    }

    # name match
    $matched = @($Tools | Where-Object {
        $_.Key -eq $v -or $_.Key -ieq $v -or $_.File -ieq $v -or ($_.File -ieq ($v + '.exe'))
    })
    if ($matched.Count -eq 1) { return $matched }
    if ($matched.Count -gt 1) { return $matched }

    # partial
    $partial = @($Tools | Where-Object { $_.Key -like ("*" + $v + "*") -or $_.Title -like ("*" + $v + "*") })
    if ($partial.Count -eq 1) { return $partial }
    if ($partial.Count -gt 1) {
        throw ("找到多個符合「{0}」的工具：{1}" -f $v, (($partial | ForEach-Object { $_.Key }) -join ', '))
    }
    throw "找不到工具：$v"
}

# ---- main ----
$selected = @()
if (-not [string]::IsNullOrWhiteSpace($Tool)) {
    $selected = @(Resolve-Selection -InputValue $Tool)
} else {
    Show-Menu
    $choice = Read-Host '輸入編號或工具名稱'
    $selected = @(Resolve-Selection -InputValue $choice)
}

if ($selected.Count -eq 0) {
    Write-WarnMsg '已取消。'
    return
}

$installed = @()
foreach ($item in $selected) {
    $path = Install-OneTool -Item $item
    $installed += [pscustomobject]@{ Key = $item.Key; Path = $path }
}

Write-Host ''
Write-Ok ("完成，共安裝 {0} 個工具。" -f $installed.Count)
Write-Host ("安裝位置：{0}" -f $InstallRoot)
Write-Host '桌面與「開始」功能表（FLG）已建立捷徑。'

if ($installed.Count -eq 1) {
    $ans = Read-Host '要現在啟動嗎？(Y/N)'
    if ($ans -match '^(?i)(y|yes|是)$') {
        Start-Process -FilePath $installed[0].Path
    }
} elseif ($installed.Count -gt 1) {
    Write-Host ''
    Write-Host '已安裝：'
    $j = 1
    foreach ($x in $installed) {
        Write-Host ("  {0}) {1}" -f $j, $x.Key)
        $j++
    }
    Write-Host '  0) 不啟動'
    $pick = Read-Host '要啟動哪一個？（編號）'
    $pn = 0
    if ([int]::TryParse($pick, [ref]$pn) -and $pn -ge 1 -and $pn -le $installed.Count) {
        Start-Process -FilePath $installed[$pn - 1].Path
    }
}
