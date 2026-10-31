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
function Get-FlgExitLabel {
    if ($env:FLG_FROM_MENU -eq '1') { return '回到上一頁' }
    return '離開'
}


# Silent usage counter (Abacus). Never throws; max ~2s.
# --- FLG offline USB helpers (backwards compatible; no-op unless FLG_OFFLINE=1) ---
function Test-FlgOffline {
    return ($env:FLG_OFFLINE -eq '1')
}
function Get-FlgRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:FLG_ROOT)) {
        return ([string]$env:FLG_ROOT).TrimEnd('\', '/')
    }
    return $null
}
function Resolve-FlgOfflinePath {
    param([Parameter(Mandatory = $true)][string]$Rel)
    $root = Get-FlgRoot
    if (-not $root) { return $null }
    $rel = $Rel -replace '[\\/]+', [IO.Path]::DirectorySeparatorChar
    $p = Join-Path $root $rel
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}
function Test-FlgNetworkAvailable {
    try {
        $r = [Net.HttpWebRequest]::Create('https://lanyen007.github.io/FLGPQT/drivers/cloud.json')
        $r.Method = 'HEAD'
        $r.Timeout = 2500
        $r.ReadWriteTimeout = 2500
        $r.KeepAlive = $false
        $resp = $r.GetResponse()
        $resp.Close()
        return $true
    } catch {
        return $false
    }
}
function Get-FlgOfflineCatalogText {
    param([Parameter(Mandatory = $true)][string]$FileName)
    $local = Resolve-FlgOfflinePath ("drivers\" + $FileName)
    if (-not $local) { return $null }
    $raw = [IO.File]::ReadAllText($local, [Text.Encoding]::UTF8)
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
    return $raw
}
function Copy-FlgOfflineDriverZip {
    param(
        [Parameter(Mandatory = $true)]$Driver,
        [Parameter(Mandatory = $true)][string]$DestZip
    )
    $name = [string]$Driver.zip_name
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    $local = Resolve-FlgOfflinePath ("drivers\packages\" + $name)
    if (-not $local) { return $false }
    Write-Host ("離線模式：使用本機驅動包 " + $name) -ForegroundColor Cyan
    $destDir = Split-Path -Parent $DestZip
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $local -Destination $DestZip -Force
    return $true
}
function Get-FlgOfflineEnvPreamble {
    $parts = @()
    if (Test-FlgOffline) { $parts += "`$env:FLG_OFFLINE='1'" }
    $root = Get-FlgRoot
    if ($root) {
        $esc = $root.Replace("'", "''")
        $parts += ("`$env:FLG_ROOT='" + $esc + "'")
    }
    if ($env:FLG_FROM_MENU -eq '1') { $parts += "`$env:FLG_FROM_MENU='1'" }
    if ($env:FLG_CLOUD_DRIVER_ID) {
        $id = ([string]$env:FLG_CLOUD_DRIVER_ID).Replace("'", "''")
        $parts += ("`$env:FLG_CLOUD_DRIVER_ID='" + $id + "'")
    }
    if ($env:FLG_AUTO_MODE) {
        $m = ([string]$env:FLG_AUTO_MODE).Replace("'", "''")
        $parts += ("`$env:FLG_AUTO_MODE='" + $m + "'")
    }
    if ($parts.Count -eq 0) { return '' }
    return (($parts -join '; ') + '; ')
}

function Invoke-FlgCounterHit([string]$Key) {
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (Test-FlgOffline) { return }
    try {
        $req = [Net.HttpWebRequest]::Create(('https://abacus.jasoncameron.dev/hit/lanyen-de/' + $Key))
        $req.Method = 'GET'
        $req.Timeout = 2000
        $req.ReadWriteTimeout = 2000
        $req.KeepAlive = $false
        $resp = $req.GetResponse()
        $resp.Close()
    } catch {}
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

    $localTool = Resolve-FlgOfflinePath ("tools\" + $file)
    if (-not $localTool) { $localTool = Resolve-FlgOfflinePath $file }
    $tmp = Join-Path $env:TEMP ("flg_install_" + [Guid]::NewGuid().ToString('N') + '.exe')
    try {
        if ($localTool) {
            Write-Info ("離線模式：複製本機 " + $file)
            Copy-Item -LiteralPath $localTool -Destination $tmp -Force
        } else {
            if (Test-FlgOffline -and -not (Test-FlgNetworkAvailable)) {
                throw ('離線版無法下載，請連網（未內建：' + $file + '）')
            }
            if (Test-FlgOffline) { Write-WarnMsg '本機無此工具，改從網路下載…' }
            Write-Info "正在下載 $key …"
            Write-Host "  $url"
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        }
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
    Write-Host ('  0) ' + (Get-FlgExitLabel))
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

Invoke-FlgCounterHit 'filebox'

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
    Write-WarnMsg ('已' + (Get-FlgExitLabel) + '。')
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
