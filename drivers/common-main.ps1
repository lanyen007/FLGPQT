# FLG 驅動程式一鍵下載（共用邏輯）
# 由 ricoh-main.ps1 / sharp-main.ps1 / fuji-main.ps1 設定 $FlgDriverBrand、$FlgDriverJson 後載入
# 亦可直接：傳入第一個參數 brand（ricoh|sharp|fuji），其餘為搜尋關鍵字

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# Brand can be preset by wrapper, or first arg
$argList = @($args)
if (-not $FlgDriverBrand) {
    if ($argList.Count -gt 0 -and $argList[0] -match '^(?i)(ricoh|sharp|fuji|fujifilm)$') {
        $FlgDriverBrand = $argList[0]
        $argList = @($argList | Select-Object -Skip 1)
    } else {
        $FlgDriverBrand = 'Ricoh'
    }
}
$FlgDriverBrand = [string]$FlgDriverBrand
if (-not $FlgDriverJson) {
    if ($FlgDriverBrand -match '^(?i)sharp$') { $FlgDriverJson = 'sharp.json' }
    elseif ($FlgDriverBrand -match '^(?i)(fuji|fujifilm)$') { $FlgDriverJson = 'fuji.json' }
    else { $FlgDriverJson = 'ricoh.json'; $FlgDriverBrand = 'Ricoh' }
}
if ($FlgDriverBrand -match '^(?i)sharp$') {
    $FlgDriverBrand = 'Sharp'
    $FlgDriverJson = 'sharp.json'
    if (-not $FlgSearchHint) { $FlgSearchHint = 'MX2600、M266、452' }
} elseif ($FlgDriverBrand -match '^(?i)(fuji|fujifilm)$') {
    $FlgDriverBrand = 'FUJIFILM'
    $FlgDriverJson = 'fuji.json'
    if (-not $FlgSearchHint) { $FlgSearchHint = 'C3070、Apeos、SC2022、MMD2' }
} else {
    $FlgDriverBrand = 'Ricoh'
    $FlgDriverJson = 'ricoh.json'
    if (-not $FlgSearchHint) { $FlgSearchHint = 'C3503、IM C3000' }
}

$Query = ''
if ($argList -and $argList.Count -gt 0) { $Query = [string]$argList[0] }

$RawBase = 'https://lanyen007.github.io/FLGPQT'
$JsonUrl = "$RawBase/drivers/$FlgDriverJson" + '?t=' + [DateTime]::UtcNow.Ticks
$DestRoot = Join-Path $env:USERPROFILE ("Downloads\FLG-Drivers\" + $FlgDriverBrand)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrMsg([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-FlgExitLabel {
    if ($env:FLG_FROM_MENU -eq '1') { return '回到上一頁' }
    return '離開'
}
function Stop-FlgScript {
    param([int]$Code = 0, [string]$Message = '')
    if ($Message) {
        if ($Code -ne 0) { Write-ErrMsg $Message } else { Write-Info $Message }
    }
    # return from caller via special exception caught at top-level only when nested;
    # prefer script-scope return by setting flag
    $script:FlgShouldStop = $true
    $script:FlgStopCode = $Code
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


function Get-JsonCatalog {
    Write-Info '正在讀取驅動程式清單…'
    $text = Get-FlgOfflineCatalogText $FlgDriverJson
    if ($text) {
        Write-Ok ("離線模式：讀取本機 " + $FlgDriverJson)
        return ($text | ConvertFrom-Json)
    }
    if (Test-FlgOffline) {
        if (-not (Test-FlgNetworkAvailable)) {
            throw ('離線版找不到 drivers\' + $FlgDriverJson + '，且目前無法連網。')
        }
        Write-WarnMsg '離線模式找不到本機清單，改從網路讀取…'
    }
    $bytes = (New-Object Net.WebClient).DownloadData($JsonUrl)
    $text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
    return ($text | ConvertFrom-Json)
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-GDriveId([string]$Url) {
    if ($Url -match '[?&]id=([^&]+)') { return $Matches[1] }
    if ($Url -match '/file/d/([^/]+)') { return $Matches[1] }
    if ($Url -match '/open\?id=([^&]+)') { return $Matches[1] }
    return $null
}

function Get-DropboxDirect([string]$Url) {
    if ($Url -match '[?&]dl=0') { return ($Url -replace 'dl=0', 'dl=1') }
    if ($Url -notmatch '[?&]dl=') {
        if ($Url.Contains('?')) { return ($Url + '&dl=1') }
        return ($Url + '?dl=1')
    }
    return $Url
}

function Save-HttpFile {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [hashtable]$Headers = $null
    )
    $tmp = "$OutFile.partial"
    try {
        $wc = New-Object Net.WebClient
        $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FLG-Driver-Downloader'
        if ($Headers) {
            foreach ($k in $Headers.Keys) { $wc.Headers[$k] = [string]$Headers[$k] }
        }
        $wc.DownloadFile($Url, $tmp)
        if (-not (Test-Path -LiteralPath $tmp) -or ((Get-Item -LiteralPath $tmp).Length -lt 64)) {
            throw "下載失敗或檔案過小：$Url"
        }
        Move-Item -LiteralPath $tmp -Destination $OutFile -Force
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

function Download-GoogleDrive {
    param(
        [Parameter(Mandatory = $true)][string]$FileId,
        [Parameter(Mandatory = $true)][string]$OutDir,
        [string]$PreferredName = ''
    )
    Ensure-Dir $OutDir
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $probeUrl = "https://drive.google.com/uc?export=download&id=$FileId"
    Write-Info "Google Drive：$FileId"
    $resp = Invoke-WebRequest -Uri $probeUrl -WebSession $session -UseBasicParsing -MaximumRedirection 5
    $outName = $PreferredName
    $cd = $resp.Headers['Content-Disposition']
    if (-not $outName -and $cd -and ($cd -match 'filename\*?=(?:UTF-8'''')?"?([^";]+)"?')) {
        $outName = [Uri]::UnescapeDataString(($Matches[1]).Trim())
    }
    if (-not $outName -and $cd -and ($cd -match 'filename="?([^";]+)"?')) {
        $outName = $Matches[1].Trim()
    }

    $bytes = $resp.Content
    $isHtml = $false
    if ($bytes -is [string]) {
        $isHtml = $bytes -match '<!DOCTYPE html|<html|confirm|Download anyway|download-form'
        if (-not $isHtml) {
            # string body but maybe binary misread; fall through to file write via raw
        }
    }

    # Large file confirm page
    if ($resp.Content -is [string] -and $resp.Content -match 'confirm') {
        $html = [string]$resp.Content
        $confirm = 't'
        $uuid = ''
        if ($html -match 'name="confirm"\s+value="([^"]+)"') { $confirm = $Matches[1] }
        if ($html -match 'name="uuid"\s+value="([^"]+)"') { $uuid = $Matches[1] }
        if ($html -match 'confirm=([0-9A-Za-z_-]+)') { $confirm = $Matches[1] }
        $dl = "https://drive.usercontent.google.com/download?id=$FileId&export=download&confirm=$confirm"
        if ($uuid) { $dl += "&uuid=$uuid" }
        if (-not $outName) { $outName = "$FileId.bin" }
        $outPath = Join-Path $OutDir $outName
        Write-Info "確認下載大型／可執行檔…"
        Invoke-WebRequest -Uri $dl -WebSession $session -OutFile $outPath -UseBasicParsing -MaximumRedirection 5
        if (-not (Test-Path -LiteralPath $outPath) -or ((Get-Item -LiteralPath $outPath).Length -lt 1024)) {
            throw "Google Drive 下載失敗：$FileId"
        }
        return $outPath
    }

    if (-not $outName) { $outName = "$FileId.bin" }
    $outPath = Join-Path $OutDir $outName
    # Re-download as file to avoid string corruption
    Invoke-WebRequest -Uri $probeUrl -WebSession $session -OutFile $outPath -UseBasicParsing -MaximumRedirection 5
    # If we got HTML warn page saved as file, retry with confirm=t
    $head = Get-Content -LiteralPath $outPath -TotalCount 2 -ErrorAction SilentlyContinue | Out-String
    if ($head -match '<!DOCTYPE|<html') {
        $dl = "https://drive.usercontent.google.com/download?id=$FileId&export=download&confirm=t"
        Invoke-WebRequest -Uri $dl -WebSession $session -OutFile $outPath -UseBasicParsing -MaximumRedirection 5
    }
    if (-not (Test-Path -LiteralPath $outPath) -or ((Get-Item -LiteralPath $outPath).Length -lt 1024)) {
        throw "Google Drive 下載失敗：$FileId"
    }
    return $outPath
}

function Download-MediaFire {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutDir,
        [string]$PreferredName = ''
    )
    Ensure-Dir $OutDir
    Write-Info "MediaFire：$Url"
    # Direct CDN links can be used as-is
    if ($Url -match 'download\d+\.mediafire\.com/') {
        $name = $PreferredName
        if (-not $name) { $name = [Uri]::UnescapeDataString(([Uri]$Url).Segments[-1]) }
        $outPath = Join-Path $OutDir $name
        Invoke-WebRequest -Uri $Url -OutFile $outPath -UseBasicParsing -MaximumRedirection 8 -UserAgent 'Mozilla/5.0'
        return $outPath
    }

    $html = (Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 5 -UserAgent 'Mozilla/5.0').Content
    $direct = $null
    if ($html -match 'href="(https://download[^"]+mediafire\.com/[^"]+)"') {
        $direct = $Matches[1]
    } elseif ($html -match '(https://download\d+\.mediafire\.com/\S+)') {
        $direct = $Matches[1]
    }
    if (-not $direct) {
        # Sometimes the page already redirected; try downloading the page URL with IWR OutFile
        Write-WarnMsg '找不到 MediaFire 直連，改用瀏覽器開啟頁面。'
        Start-Process $Url
        return $null
    }
    $name = $PreferredName
    if (-not $name) {
        $name = [Uri]::UnescapeDataString(([Uri]$direct).Segments[-1])
    }
    $outPath = Join-Path $OutDir $name
    Write-Info "直連下載：$name"
    Invoke-WebRequest -Uri $direct -OutFile $outPath -UseBasicParsing -MaximumRedirection 5 -UserAgent 'Mozilla/5.0'
    if (-not (Test-Path -LiteralPath $outPath) -or ((Get-Item -LiteralPath $outPath).Length -lt 1024)) {
        throw "MediaFire 下載失敗：$Url"
    }
    return $outPath
}

function Download-DriverItem {
    param($Item)

    Ensure-Dir $DestRoot
    $modelDir = Join-Path $DestRoot (($Item.model -replace '[\\/:*?"<>|]', '_').Trim())
    Ensure-Dir $modelDir

    $hostName = [string]$Item.host
    $url = [string]$Item.url
    $pref = [string]$Item.filename

    if ($Item.kind -eq 'guide' -or $hostName -eq 'blogger' -or $hostName -eq 'mega') {
        if (Test-FlgOffline -and -not (Test-FlgNetworkAvailable)) {
            Write-WarnMsg '離線版無法下載，請連網'
            return $null
        }
        Write-WarnMsg "此項目會開啟瀏覽器：$($Item.title)"
        Start-Process $url
        return $null
    }

    if (Test-FlgOffline) {
        $bundledName = $null
        if ($pref) { $bundledName = $pref }
        elseif ($url) {
            try { $bundledName = [IO.Path]::GetFileName(([Uri]$url).LocalPath) } catch {}
        }
        $bundled = $null
        if ($bundledName) {
            $bundled = Resolve-FlgOfflinePath ("drivers\packages\" + $bundledName)
            if (-not $bundled) { $bundled = Resolve-FlgOfflinePath ("drivers\extras\" + $bundledName) }
        }
        if ($bundled) {
            $path = Join-Path $modelDir ([IO.Path]::GetFileName($bundled))
            Copy-Item -LiteralPath $bundled -Destination $path -Force
            Write-Ok ("離線模式：已複製本機檔案 " + $path)
            return $path
        }
        if (-not (Test-FlgNetworkAvailable)) {
            Write-WarnMsg '離線版無法下載，請連網'
            return $null
        }
        Write-WarnMsg '離線模式：機種專用驅動改從網路下載…'
    }

    Write-Info "下載：$($Item.title)"
    $path = $null
    switch ($hostName) {
        'gdrive' {
            $id = Get-GDriveId $url
            if (-not $id) { throw "無法解析 Google Drive 檔案 ID：$url" }
            $path = Download-GoogleDrive -FileId $id -OutDir $modelDir -PreferredName $pref
        }
        'mediafire' {
            $path = Download-MediaFire -Url $url -OutDir $modelDir -PreferredName $pref
        }
        'dropbox' {
            $durl = Get-DropboxDirect $url
            if (-not $pref) { $pref = 'dropbox-download.bin' }
            $path = Join-Path $modelDir $pref
            Invoke-WebRequest -Uri $durl -OutFile $path -UseBasicParsing -MaximumRedirection 8
        }
        'ricoh' {
            if (-not $pref) { $pref = ([Uri]$url).Segments[-1] }
            $path = Join-Path $modelDir $pref
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -MaximumRedirection 5 -UserAgent 'Mozilla/5.0'
        }
        'http' {
            if (-not $pref) { $pref = ([Uri]$url).Segments[-1] }
            $path = Join-Path $modelDir $pref
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -MaximumRedirection 8 -UserAgent 'Mozilla/5.0'
        }
        'sharp' {
            if (-not $pref) { $pref = ([Uri]$url).Segments[-1] }
            $path = Join-Path $modelDir $pref
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -MaximumRedirection 5 -UserAgent 'Mozilla/5.0'
        }
        'fujifilm' {
            if (-not $pref) { $pref = ([Uri]$url).Segments[-1] }
            $path = Join-Path $modelDir $pref
            $headers = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'; 'Referer' = 'https://support-fb.fujifilm.com/' }
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -MaximumRedirection 8 -Headers $headers
        }
        default {
            if (-not $pref) { $pref = 'download.bin' }
            $path = Join-Path $modelDir $pref
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -MaximumRedirection 8 -UserAgent 'Mozilla/5.0'
        }
    }

    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        Write-WarnMsg '沒有下載到檔案。'
        return $null
    }
    $len = (Get-Item -LiteralPath $path).Length
    Write-Ok ("完成：{0}（{1:N1} MB）" -f $path, ($len / 1MB))
    return $path
}

function Expand-IfArchive {
    param([string]$Path)
    if (-not $Path) { return $null }
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -ne '.zip') { return $null }
    $dest = Join-Path (Split-Path -Parent $Path) ([IO.Path]::GetFileNameWithoutExtension($Path))
    Ensure-Dir $dest
    Write-Info "解壓縮到 $dest"
    Expand-Archive -LiteralPath $Path -DestinationPath $dest -Force
    return $dest
}

function Find-InfFiles {
    param([string]$Root)
    if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { return @() }
    return @(Get-ChildItem -LiteralPath $Root -Filter *.inf -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Install-InfDrivers {
    param([string[]]$InfPaths)
    if (-not $InfPaths -or $InfPaths.Count -eq 0) { return }
    Write-Info ("找到 {0} 個 .inf，準備用 pnputil 安裝（需要系統管理員）" -f $InfPaths.Count)
    if (-not (Test-IsAdmin)) {
        Write-WarnMsg '目前不是系統管理員權限。'
        Write-Host '可手動以系統管理員開啟 PowerShell 後執行：'
        $root = Split-Path -Parent $InfPaths[0]
        Write-Host ("  pnputil /add-driver `"$root\*.inf`" /subdirs /install") -ForegroundColor White
        $ans = Read-Host '要現在用系統管理員重新啟動安裝嗎？(Y/N)'
        if ($ans -match '^(?i)y|yes|是$') {
            $cmd = "pnputil /add-driver `"$root\*.inf`" /subdirs /install; pause"
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-Command', $cmd)
        }
        return
    }
    $root = Split-Path -Parent $InfPaths[0]
    & pnputil.exe /add-driver "$root\*.inf" /subdirs /install
}

function After-Download {
    param([string]$Path)
    if (-not $Path) { return }
    $dir = Split-Path -Parent $Path
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()

    $extractDir = Expand-IfArchive -Path $Path
    $searchRoot = $(if ($extractDir) { $extractDir } else { $dir })
    $infs = Find-InfFiles -Root $searchRoot

    if ($ext -eq '.exe') {
        Write-Host ''
        Write-Host '下載的是安裝程式（.exe）。' -ForegroundColor White
        $ans = Read-Host '要現在執行安裝嗎？(Y/N，預設 Y)'
        if ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^(?i)y|yes|是$') {
            Start-Process -FilePath $Path -WorkingDirectory $dir
        } else {
            Write-Info "檔案位置：$Path"
            Start-Process explorer.exe -ArgumentList $dir
        }
        return
    }

    if ($infs.Count -gt 0) {
        Install-InfDrivers -InfPaths $infs
        Start-Process explorer.exe -ArgumentList $searchRoot
        return
    }

    Write-Info "已開啟資料夾：$dir"
    Start-Process explorer.exe -ArgumentList $dir
}

function Get-SeriesList {
    param($Catalog)
    if ($Catalog.series_list) {
        return @($Catalog.series_list)
    }
    $series = @()
    foreach ($d in $Catalog.drivers) {
        $s = [string]$d.series
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        if ($series -notcontains $s) { $series += $s }
    }
    return $series
}

function Get-ModelList {
    param(
        $Catalog,
        [string]$Series = ''
    )
    $models = @()
    foreach ($d in $Catalog.drivers) {
        if ($d.kind -eq 'backup') { continue }
        if ($Series -and [string]$d.series -ne $Series -and $Series -ne '全部') { continue }
        if ($models -notcontains $d.model) { $models += $d.model }
    }
    return $models
}

function Filter-Drivers {
    param(
        $Catalog,
        [string]$Keyword,
        [string]$Series = ''
    )
    $all = @($Catalog.drivers)
    if ($Series -and $Series -ne '全部') {
        $all = @($all | Where-Object { [string]$_.series -eq $Series })
    }
    if ([string]::IsNullOrWhiteSpace($Keyword)) { return $all }
    $k = $Keyword.Trim()
    return @($all | Where-Object {
        $_.model -like "*$k*" -or $_.title -like "*$k*" -or $_.type -like "*$k*" -or $_.filename -like "*$k*" -or $_.id -eq $k -or ([string]$_.series -like "*$k*")
    })
}

function Show-SeriesMenu {
    param([string[]]$SeriesList)
    Write-Host ''
    Write-Host ("======== FLG {0} 驅動程式 · 選系列 ========" -f $FlgDriverBrand) -ForegroundColor White
    Write-Host '請選擇系列：'
    $i = 1
    foreach ($s in $SeriesList) {
        Write-Host ("  {0,2}) {1}" -f $i, $s)
        $i++
    }
    Write-Host ("  {0,2}) 全部系列" -f $i)
    Write-Host '   S) 搜尋關鍵字'
    Write-Host ('   0) ' + (Get-FlgExitLabel))
    Write-Host ''
}

function Show-ModelMenu {
    param(
        [string[]]$Models,
        [string]$SeriesLabel = ''
    )
    Write-Host ''
    if ($SeriesLabel) {
        Write-Host ("======== FLG {0} · {1} ========" -f $FlgDriverBrand, $SeriesLabel) -ForegroundColor White
    } else {
        Write-Host ("======== FLG {0} 驅動程式 ========" -f $FlgDriverBrand) -ForegroundColor White
    }
    Write-Host '請選擇機型（輸入編號，或直接輸入關鍵字搜尋）：'
    $i = 1
    foreach ($m in $Models) {
        Write-Host ("  {0,2}) {1}" -f $i, $m)
        $i++
    }
    Write-Host '   S) 搜尋關鍵字'
    if ($SeriesLabel) { Write-Host '   B) 回到上一頁（系列）' }
    Write-Host ('   0) ' + $(if ($SeriesLabel) { '回到上一頁' } else { Get-FlgExitLabel }))
    Write-Host ''
}

function Show-DriverMenu {
    param($Items, [string]$ModelName)
    Write-Host ''
    Write-Host ("======== {0} ========" -f $ModelName) -ForegroundColor White
    Write-Host '請選擇要下載的項目：'
    $i = 1
    foreach ($d in $Items) {
        $extra = ''
        if ($d.filename) { $extra = "  [$($d.filename)]" }
        Write-Host ("  {0,2}) {1} / {2}{3}" -f $i, $d.type, $d.os, $extra)
        $i++
    }
    Write-Host '   0) 回到上一頁'
    Write-Host ''
}

function Open-SourcePage {
    param($Item)
    if ($Item.page) { Start-Process ([string]$Item.page) }
}

if ($FlgDriverBrand -eq 'Sharp') { Invoke-FlgCounterHit 'dl-sharp' }
elseif ($FlgDriverBrand -eq 'FUJIFILM') { Invoke-FlgCounterHit 'dl-fuji' }
else { Invoke-FlgCounterHit 'dl-ricoh' }

# ---- main ----
$catalog = Get-JsonCatalog
Write-Ok ("清單載入完成，共 {0} 筆（{1}）" -f $catalog.count, $FlgDriverBrand)

$useSeries = (($FlgDriverBrand -eq 'Ricoh') -or ($FlgDriverBrand -eq 'FUJIFILM')) -and ((Get-SeriesList -Catalog $catalog).Count -gt 0)
$activeSeries = ''
$models = Get-ModelList -Catalog $catalog

function Invoke-DriverPick {
    param($Items, [string]$Label)
    if (-not $Items -or $Items.Count -eq 0) { Write-WarnMsg '沒有項目。'; return }
    Show-DriverMenu -Items $Items -ModelName $Label
    Write-Host '  P) 開啟原網頁說明'
    $sel = Read-Host '請選擇'
    if ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) { return }
    if ($sel -match '^(?i)p$') { Open-SourcePage -Item $Items[0]; return }
    $n = 0
    if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $Items.Count) {
        Write-WarnMsg '無效選項。'; return
    }
    $chosen = $Items[$n - 1]
    try {
        $path = Download-DriverItem -Item $chosen
        After-Download -Path $path
    } catch {
        Write-ErrMsg ("下載失敗：{0}" -f $_.Exception.Message)
        Write-WarnMsg '可改開原網頁手動下載（輸入 P）。'
    }
}

# Non-interactive query from args
if ($Query) {
    $hits = Filter-Drivers -Catalog $catalog -Keyword $Query
    if ($hits.Count -eq 0) {
        Write-ErrMsg "找不到符合「$Query」的項目。"
        return
    }
    $modelHits = @($hits | Where-Object { $_.model -like "*$Query*" } | Select-Object -ExpandProperty model -Unique)
    if ($modelHits.Count -eq 1) {
        $items = @($catalog.drivers | Where-Object { $_.model -eq $modelHits[0] })
        Invoke-DriverPick -Items $items -Label $modelHits[0]
        return
    }
    Write-Host "搜尋「$Query」結果："
    $i = 1
    foreach ($d in $hits) {
        Write-Host ("  {0,2}) {1}" -f $i, $d.title)
        $i++
    }
    $sel = Read-Host '請輸入編號（0 取消）'
    if ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) { return }
    $n = 0
    if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $hits.Count) {
        Write-ErrMsg '無效選項'; return
    }
    $chosen = $hits[$n - 1]
    $path = Download-DriverItem -Item $chosen
    After-Download -Path $path
    return
}

while ($true) {
    if ($useSeries -and -not $activeSeries) {
        $seriesList = Get-SeriesList -Catalog $catalog
        Show-SeriesMenu -SeriesList $seriesList
        $choice = Read-Host '請選擇'
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0' -or $choice -match '^(?i)q|quit|exit|取消$') {
            Write-Info ('已' + (Get-FlgExitLabel) + '。')
            break
        }
        if ($choice -match '^(?i)s$') {
            $kw = Read-Host ("輸入機型關鍵字（例如 {0}）" -f $FlgSearchHint)
            $hits = Filter-Drivers -Catalog $catalog -Keyword $kw
            if ($hits.Count -eq 0) { Write-WarnMsg '沒有符合的項目。'; continue }
            $mlist = @($hits | Select-Object -ExpandProperty model -Unique)
            if ($mlist.Count -eq 1) {
                $items = @($catalog.drivers | Where-Object { $_.model -eq $mlist[0] })
                Invoke-DriverPick -Items $items -Label $mlist[0]
            } else {
                Write-Host '符合的機型：'
                $i = 1
                foreach ($m in $mlist) { Write-Host ("  {0}) {1}" -f $i, $m); $i++ }
                $ms = Read-Host '選機型編號'
                $n = 0
                if ([int]::TryParse($ms, [ref]$n) -and $n -ge 1 -and $n -le $mlist.Count) {
                    $items = @($catalog.drivers | Where-Object { $_.model -eq $mlist[$n - 1] })
                    Invoke-DriverPick -Items $items -Label $mlist[$n - 1]
                } else { Write-WarnMsg '無效選項。' }
            }
            continue
        }
        $n = 0
        if ([int]::TryParse($choice, [ref]$n)) {
            if ($n -ge 1 -and $n -le $seriesList.Count) {
                $activeSeries = $seriesList[$n - 1]
            } elseif ($n -eq ($seriesList.Count + 1)) {
                $activeSeries = '全部'
            } else {
                Write-WarnMsg '無效選項。'; continue
            }
        } else {
            Write-WarnMsg '無效選項。'; continue
        }
        $models = Get-ModelList -Catalog $catalog -Series $activeSeries
        continue
    }

    Show-ModelMenu -Models $models -SeriesLabel $(if ($activeSeries) { $activeSeries } else { '' })
    $choice = Read-Host '請選擇'
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0' -or $choice -match '^(?i)q|quit|exit|取消$') {
        if ($useSeries -and $activeSeries) {
            $activeSeries = ''
            continue
        }
        Write-Info ('已' + (Get-FlgExitLabel) + '。')
        break
    }

    if ($choice -match '^(?i)b$' -and $useSeries) {
        $activeSeries = ''
        continue
    }

    $selectedModel = $null
    if ($choice -match '^(?i)s$') {
        $kw = Read-Host ("輸入機型關鍵字（例如 {0}）" -f $FlgSearchHint)
        $hits = Filter-Drivers -Catalog $catalog -Keyword $kw -Series $activeSeries
        if ($hits.Count -eq 0) { Write-WarnMsg '沒有符合的項目。'; continue }
        $mlist = @($hits | Select-Object -ExpandProperty model -Unique)
        if ($mlist.Count -eq 1) { $selectedModel = $mlist[0] }
        else {
            Write-Host '符合的機型：'
            $i = 1
            foreach ($m in $mlist) { Write-Host ("  {0}) {1}" -f $i, $m); $i++ }
            $ms = Read-Host '選機型編號'
            $n = 0
            if ([int]::TryParse($ms, [ref]$n) -and $n -ge 1 -and $n -le $mlist.Count) {
                $selectedModel = $mlist[$n - 1]
            } else { Write-WarnMsg '無效選項'; continue }
        }
    } else {
        $n = 0
        if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $models.Count) {
            $selectedModel = $models[$n - 1]
        } else {
            # treat as keyword
            $hits = Filter-Drivers -Catalog $catalog -Keyword $choice -Series $activeSeries
            $mlist = @($hits | Select-Object -ExpandProperty model -Unique)
            if ($mlist.Count -eq 1) { $selectedModel = $mlist[0] }
            elseif ($mlist.Count -gt 1) {
                Write-Host '符合的機型：'
                $i = 1
                foreach ($m in $mlist) { Write-Host ("  {0}) {1}" -f $i, $m); $i++ }
                $ms = Read-Host '選機型編號'
                $nn = 0
                if ([int]::TryParse($ms, [ref]$nn) -and $nn -ge 1 -and $nn -le $mlist.Count) {
                    $selectedModel = $mlist[$nn - 1]
                } else { Write-WarnMsg '無效選項'; continue }
            } else {
                Write-WarnMsg '無效選項。'
                continue
            }
        }
    }

    if (-not $selectedModel) { continue }

    if ($activeSeries -and $activeSeries -ne '全部') {
        $items = @($catalog.drivers | Where-Object { $_.model -eq $selectedModel -and [string]$_.series -eq $activeSeries })
        if ($items.Count -eq 0) {
            $items = @($catalog.drivers | Where-Object { $_.model -eq $selectedModel })
        }
    } else {
        $items = @($catalog.drivers | Where-Object { $_.model -eq $selectedModel })
    }
    while ($true) {
        Show-DriverMenu -Items $items -ModelName $selectedModel
        Write-Host '  P) 開啟原網頁說明'
        $sel = Read-Host '請選擇'
        if ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) { break }
        if ($sel -match '^(?i)p$') {
            Open-SourcePage -Item $items[0]
            continue
        }
        $n = 0
        if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $items.Count) {
            Write-WarnMsg '無效選項。'
            continue
        }
        $chosen = $items[$n - 1]
        try {
            $path = Download-DriverItem -Item $chosen
            After-Download -Path $path
        } catch {
            Write-ErrMsg ("下載失敗：{0}" -f $_.Exception.Message)
            Write-WarnMsg '可改開原網頁手動下載（輸入 P）。'
        }
        $again = Read-Host '還要下載同機型其他項目嗎？(Y/N)'
        if ($again -notmatch '^(?i)y|yes|是$') { break }
    }
}

Write-Host ''
Write-Ok "下載目錄：$DestRoot"
