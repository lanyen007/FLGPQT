# FLG 驅動程式一鍵下載（共用邏輯）
# 由 ricoh-main.ps1 / sharp-main.ps1 設定 $FlgDriverBrand、$FlgDriverJson 後載入
# 亦可直接：傳入第一個參數 brand（ricoh|sharp），其餘為搜尋關鍵字

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# Brand can be preset by wrapper, or first arg
$argList = @($args)
if (-not $FlgDriverBrand) {
    if ($argList.Count -gt 0 -and $argList[0] -match '^(?i)(ricoh|sharp)$') {
        $FlgDriverBrand = $argList[0]
        $argList = @($argList | Select-Object -Skip 1)
    } else {
        $FlgDriverBrand = 'Ricoh'
    }
}
$FlgDriverBrand = [string]$FlgDriverBrand
if (-not $FlgDriverJson) {
    if ($FlgDriverBrand -match '^(?i)sharp$') { $FlgDriverJson = 'sharp.json' }
    else { $FlgDriverJson = 'ricoh.json'; $FlgDriverBrand = 'Ricoh' }
}
if ($FlgDriverBrand -match '^(?i)sharp$') {
    $FlgDriverBrand = 'Sharp'
    $FlgDriverJson = 'sharp.json'
    $FlgSearchHint = 'MX2600、M266、452'
} else {
    $FlgDriverBrand = 'Ricoh'
    $FlgDriverJson = 'ricoh.json'
    $FlgSearchHint = 'C3503、IM C3000'
}

$Query = ''
if ($argList -and $argList.Count -gt 0) { $Query = [string]$argList[0] }

$RawBase = 'https://raw.githubusercontent.com/lanyen007/FLGPQT/main'
$JsonUrl = "$RawBase/drivers/$FlgDriverJson" + '?t=' + [DateTime]::UtcNow.Ticks
$DestRoot = Join-Path $env:USERPROFILE ("Downloads\FLG-Drivers\" + $FlgDriverBrand)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrMsg([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-JsonCatalog {
    Write-Info '正在讀取驅動程式清單…'
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
        Write-WarnMsg "此項目會開啟瀏覽器：$($Item.title)"
        Start-Process $url
        return $null
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

function Get-ModelList {
    param($Catalog)
    $models = @()
    foreach ($d in $Catalog.drivers) {
        if ($d.kind -eq 'backup') { continue }
        if ($models -notcontains $d.model) { $models += $d.model }
    }
    return $models
}

function Filter-Drivers {
    param($Catalog, [string]$Keyword)
    $all = @($Catalog.drivers)
    if ([string]::IsNullOrWhiteSpace($Keyword)) { return $all }
    $k = $Keyword.Trim()
    return @($all | Where-Object {
        $_.model -like "*$k*" -or $_.title -like "*$k*" -or $_.type -like "*$k*" -or $_.filename -like "*$k*" -or $_.id -eq $k
    })
}

function Show-ModelMenu {
    param([string[]]$Models)
    Write-Host ''
    Write-Host ("======== FLG {0} 驅動程式 ========" -f $FlgDriverBrand) -ForegroundColor White
    Write-Host '請選擇機型（輸入編號，或直接輸入關鍵字搜尋）：'
    $i = 1
    foreach ($m in $Models) {
        Write-Host ("  {0,2}) {1}" -f $i, $m)
        $i++
    }
    Write-Host '   S) 搜尋關鍵字'
    Write-Host '   0) 離開'
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
    Write-Host '   0) 返回'
    Write-Host ''
}

function Open-SourcePage {
    param($Item)
    if ($Item.page) { Start-Process ([string]$Item.page) }
}

# ---- main ----
$catalog = Get-JsonCatalog
Write-Ok ("清單載入完成，共 {0} 筆（{1}／Blogger／試算表）" -f $catalog.count, $FlgDriverBrand)

$models = Get-ModelList -Catalog $catalog

# Non-interactive query from args
if ($Query) {
    $hits = Filter-Drivers -Catalog $catalog -Keyword $Query
    if ($hits.Count -eq 0) {
        Write-ErrMsg "找不到符合「$Query」的項目。"
        exit 1
    }
    # If query matches a model exactly / solely, show submenu via auto-pick first model group
    $modelHits = @($hits | Where-Object { $_.model -like "*$Query*" } | Select-Object -ExpandProperty model -Unique)
    if ($modelHits.Count -eq 1) {
        $items = @($catalog.drivers | Where-Object { $_.model -eq $modelHits[0] })
        Show-DriverMenu -Items $items -ModelName $modelHits[0]
        $sel = Read-Host '請輸入編號'
        if ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) { exit 0 }
        $n = 0
        if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $items.Count) {
            Write-ErrMsg '無效選項'; exit 1
        }
        $chosen = $items[$n - 1]
        $path = Download-DriverItem -Item $chosen
        After-Download -Path $path
        exit 0
    }
    Write-Host "搜尋「$Query」結果："
    $i = 1
    foreach ($d in $hits) {
        Write-Host ("  {0,2}) {1}" -f $i, $d.title)
        $i++
    }
    $sel = Read-Host '請輸入編號（0 取消）'
    if ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) { exit 0 }
    $n = 0
    if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $hits.Count) {
        Write-ErrMsg '無效選項'; exit 1
    }
    $chosen = $hits[$n - 1]
    $path = Download-DriverItem -Item $chosen
    After-Download -Path $path
    exit 0
}

while ($true) {
    Show-ModelMenu -Models $models
    $choice = Read-Host '請選擇'
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0' -or $choice -match '^(?i)q|quit|exit|取消$') {
        Write-Info '已離開。'
        break
    }

    $selectedModel = $null
    if ($choice -match '^(?i)s$') {
        $kw = Read-Host ("輸入機型關鍵字（例如 {0}）" -f $FlgSearchHint)
        $hits = Filter-Drivers -Catalog $catalog -Keyword $kw
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
            $hits = Filter-Drivers -Catalog $catalog -Keyword $choice
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

    $items = @($catalog.drivers | Where-Object { $_.model -eq $selectedModel })
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
