# lanyen.de 重灌後常用軟體
# 用法：irm lanyen.de/pc | iex
# 透過 Windows winget 安裝勾選的軟體。
# LINE、新酷音、AweSun、RustDesk、KMPlayer 64X、Global PotPlayer 使用官方安裝檔。

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$DownloadDir = Join-Path $env:USERPROFILE 'Downloads\lanyen-pc'
$LineUrl = 'https://desktop.line-scdn.net/win/new/LineInst.exe'
$ChewingApi = 'https://api.github.com/repos/chewing/windows-chewing-tsf/releases/latest'

$Apps = @(
    @{ Num = 1;  Key = 'reader';      Group = 'pdf';     Recommend = $true;  Kind = 'winget'; Id = 'Adobe.Acrobat.Reader.64-bit'; TitleZh = 'Adobe Acrobat Reader'; TitleEn = 'Adobe Acrobat Reader' }
    @{ Num = 2;  Key = 'pdfxchange';  Group = 'pdf';     Recommend = $false; Kind = 'winget'; Id = 'TrackerSoftware.PDF-XChangeEditor'; TitleZh = 'PDF-XChange Editor'; TitleEn = 'PDF-XChange Editor' }
    @{ Num = 3;  Key = 'libreoffice'; Group = 'pdf';     Recommend = $true;  Kind = 'winget'; Id = 'TheDocumentFoundation.LibreOffice'; TitleZh = 'LibreOffice'; TitleEn = 'LibreOffice' }
    @{ Num = 4;  Key = 'openoffice';  Group = 'pdf';     Recommend = $false; Kind = 'winget'; Id = 'Apache.OpenOffice'; TitleZh = 'OpenOffice'; TitleEn = 'OpenOffice' }
    @{ Num = 5;  Key = 'chrome';      Group = 'browser'; Recommend = $true;  Kind = 'winget'; Id = 'Google.Chrome'; TitleZh = 'Google Chrome'; TitleEn = 'Google Chrome' }
    @{ Num = 6;  Key = 'edge';        Group = 'browser'; Recommend = $false; Kind = 'winget'; Id = 'Microsoft.Edge'; TitleZh = 'Microsoft Edge'; TitleEn = 'Microsoft Edge' }
    @{ Num = 7;  Key = 'brave';       Group = 'browser'; Recommend = $false; Kind = 'winget'; Id = 'Brave.Brave'; TitleZh = 'Brave'; TitleEn = 'Brave' }
    @{ Num = 8;  Key = 'firefox';     Group = 'browser'; Recommend = $false; Kind = 'winget'; Id = 'Mozilla.Firefox.zh-TW'; TitleZh = '火狐 Firefox'; TitleEn = 'Firefox' }
    @{ Num = 9;  Key = '7zip';        Group = 'archive'; Recommend = $true;  Kind = 'winget'; Id = '7zip.7zip'; TitleZh = '7-Zip'; TitleEn = '7-Zip' }
    @{ Num = 10; Key = 'winrar';      Group = 'archive'; Recommend = $false; Kind = 'winget'; Id = 'RARLab.WinRAR'; TitleZh = 'WinRAR'; TitleEn = 'WinRAR' }
    @{ Num = 11; Key = 'vlc';         Group = 'media';   Recommend = $true;  Kind = 'winget'; Id = 'VideoLAN.VLC'; TitleZh = 'VLC Media Player'; TitleEn = 'VLC Media Player' }
    @{ Num = 12; Key = 'potplayer';   Group = 'media';   Recommend = $false; Kind = 'winget'; Id = 'Daum.PotPlayer'; TitleZh = 'PotPlayer'; TitleEn = 'PotPlayer' }
    @{ Num = 13; Key = 'capcut';      Group = 'media';   Recommend = $false; Kind = 'winget'; Id = 'ByteDance.CapCut'; TitleZh = 'CapCut（剪映）'; TitleEn = 'CapCut' }
    @{ Num = 14; Key = 'line';        Group = 'system';  Recommend = $true;  Kind = 'line';   Id = ''; TitleZh = 'LINE 電腦版'; TitleEn = 'LINE for desktop' }
    @{ Num = 15; Key = 'chewing';     Group = 'system';  Recommend = $true;  Kind = 'chewing'; Id = ''; TitleZh = '新酷音輸入法'; TitleEn = 'Chewing input method' }
    @{ Num = 16; Key = 'gimytv';      Group = 'desktop'; Recommend = $true;  Kind = 'link';   Id = ''; Url = 'https://gimytw.cc/'; TitleZh = 'Gimy TV'; TitleEn = 'Gimy TV' }
    @{ Num = 17; Key = 'onedrive';    Group = 'cloud';   Recommend = $false; Kind = 'winget'; Id = 'Microsoft.OneDrive'; TitleZh = 'OneDrive'; TitleEn = 'OneDrive' }
    @{ Num = 18; Key = 'pcloud';      Group = 'cloud';   Recommend = $false; Kind = 'winget'; Id = 'pCloudAG.pCloudDrive'; TitleZh = 'pCloud'; TitleEn = 'pCloud' }
    @{ Num = 19; Key = 'dropbox';     Group = 'cloud';   Recommend = $false; Kind = 'winget'; Id = 'Dropbox.Dropbox'; TitleZh = 'Dropbox'; TitleEn = 'Dropbox' }
    @{ Num = 20; Key = 'mega';        Group = 'cloud';   Recommend = $false; Kind = 'winget'; Id = 'Mega.MEGASync'; TitleZh = 'MEGA'; TitleEn = 'MEGA' }
    @{ Num = 21; Key = 'gdrive';      Group = 'cloud';   Recommend = $false; Kind = 'winget'; Id = 'Google.GoogleDrive'; TitleZh = 'Google 雲端硬碟電腦版'; TitleEn = 'Google Drive for desktop' }
    @{ Num = 22; Key = 'everything';  Group = 'system';  Recommend = $false; Kind = 'winget'; Id = 'voidtools.Everything'; TitleZh = 'Everything'; TitleEn = 'Everything' }
    @{ Num = 23; Key = 'stickynotes'; Group = 'system';  Recommend = $false; Kind = 'winget'; Id = 'Simnet.SimpleStickyNotes'; TitleZh = 'Simple Sticky Notes'; TitleEn = 'Simple Sticky Notes' }
    @{ Num = 24; Key = 'deskin';      Group = 'remote';  Recommend = $false; Kind = 'winget'; Id = 'ZulerTechnology.DeskIn'; TitleZh = 'DeskIn'; TitleEn = 'DeskIn' }
    @{ Num = 25; Key = 'anydesk';     Group = 'remote';  Recommend = $false; Kind = 'winget'; Id = 'AnyDesk.AnyDesk'; TitleZh = 'AnyDesk'; TitleEn = 'AnyDesk' }
    @{ Num = 26; Key = 'teamviewer';  Group = 'remote';  Recommend = $false; Kind = 'winget'; Id = 'TeamViewer.TeamViewer'; TitleZh = 'TeamViewer'; TitleEn = 'TeamViewer' }
    @{ Num = 27; Key = 'awesun';      Group = 'remote';  Recommend = $false; Kind = 'awesun'; Id = ''; TitleZh = 'AweSun'; TitleEn = 'AweSun' }
    @{ Num = 28; Key = 'rustdesk';    Group = 'remote';  Recommend = $false; Kind = 'rustdesk'; Id = ''; TitleZh = 'RustDesk'; TitleEn = 'RustDesk' }
    @{ Num = 29; Key = 'itunes';      Group = 'media';   Recommend = $false; Kind = 'winget'; Id = 'Apple.iTunes'; TitleZh = 'Apple iTunes'; TitleEn = 'Apple iTunes' }
    @{ Num = 30; Key = 'kmplayer';    Group = 'media';   Recommend = $false; Kind = 'kmplayer'; Id = ''; TitleZh = 'KMPlayer 64X'; TitleEn = 'KMPlayer 64X' }
    @{ Num = 31; Key = 'potglobal';   Group = 'media';   Recommend = $false; Kind = 'potglobal'; Id = ''; TitleZh = 'Global PotPlayer'; TitleEn = 'Global PotPlayer' }
)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrMsg([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-FlgUiIsZh {
    try {
        $n = [string](Get-UICulture).Name
        if ([string]::IsNullOrWhiteSpace($n)) { $n = [string](Get-Culture).Name }
        return ($n -match '^(?i)zh')
    } catch {
        try { return ([string](Get-Culture).Name -match '^(?i)zh') } catch { return $true }
    }
}
if (-not (Get-Variable -Name FlgIsZh -Scope Script -ErrorAction SilentlyContinue)) {
    $script:FlgIsZh = Get-FlgUiIsZh
}
function Get-FlgT([string]$Zh, [string]$En) {
    if ($script:FlgIsZh) { return $Zh } else { return $En }
}
function Get-FlgExitLabel {
    return (Get-FlgT '回到上一頁' 'Back')
}
function Test-FlgConsoleInput {
    if ($script:FlgConsoleChecked) { return [bool]$script:FlgConsoleInput }
    $script:FlgConsoleChecked = $true
    try {
        $null = [Console]::KeyAvailable
        $script:FlgConsoleInput = $true
    } catch {
        $script:FlgConsoleInput = $false
    }
    return [bool]$script:FlgConsoleInput
}
function Test-FlgOffline {
    return ($env:FLG_OFFLINE -eq '1')
}
function Invoke-FlgCounterHit([string]$Key) {
    # Legacy telemetry endpoint retired; keep this as a safe no-op to avoid 404 noise.
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (Test-FlgOffline) { return }
    return
}
function Get-AppTitle($App) {
    if ($script:FlgIsZh) { return [string]$App.TitleZh }
    return [string]$App.TitleEn
}
function Get-GroupTitle([string]$Group) {
    switch ($Group) {
        'pdf' { return (Get-FlgT '文件與 PDF' 'Documents and PDF') }
        'browser' { return (Get-FlgT '網路瀏覽器' 'Browsers') }
        'archive' { return (Get-FlgT '壓縮與解壓縮' 'Archives') }
        'media' { return (Get-FlgT '影音播放與剪輯' 'Video') }
        'system' { return (Get-FlgT '系統工具與輸入法' 'System and input') }
        'desktop' { return (Get-FlgT '桌面' 'Desktop') }
        'cloud' { return (Get-FlgT '雲端硬碟' 'Cloud storage') }
        'remote' { return (Get-FlgT '遠端連線' 'Remote desktop') }
        default { return $Group }
    }
}

function Show-Menu {
    Write-Host ''
    Write-Host ('======== ' + (Get-FlgT 'lanyen.de 重灌後常用軟體' 'lanyen.de post-reinstall apps') + ' ========') -ForegroundColor White
    Write-Host (Get-FlgT '多個編號用逗號分開，例如 1,7,12' 'Separate numbers with commas, for example 1,7,12')
    $suggestNums = ((@($Apps | Where-Object { $_.Recommend } | ForEach-Object { $_.Num })) -join ',')
    Write-Host ('  [A] ' + (Get-FlgT '建議組合：' 'Suggested: ') + $suggestNums)
    Write-Host ('  [0] ' + (Get-FlgExitLabel))
    Write-Host (Get-FlgT '約 8 秒沒有輸入會回到上一頁。' 'Goes back after about 8 seconds with no input.') -ForegroundColor DarkGray
    Write-Host ''
    $lastGroup = ''
    foreach ($app in $Apps) {
        if ($app.Group -ne $lastGroup) {
            $lastGroup = $app.Group
            Write-Host ('  ' + (Get-GroupTitle $lastGroup)) -ForegroundColor White
        }
        $mark = ''
        if ($app.Recommend) { $mark = (Get-FlgT '  （建議）' '  (suggested)') }
        Write-Host ("  [{0}] {1}{2}" -f $app.Num, (Get-AppTitle $app), $mark)
    }
    Write-Host ''
}

function Resolve-AppChoice([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return @() }
    $v = $Raw.Trim() -replace '，', ','
    if ($v -eq '0' -or $v -match '^(?i)(q|quit|exit|cancel|取消|離開)$') { return $null }
    if ($v -match '^(?i)(a|suggest|suggested|建議|建議組合)$') {
        return @($Apps | Where-Object { $_.Recommend })
    }
    $parts = @($v -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) { return @() }
    $picked = @()
    foreach ($part in $parts) {
        $n = 0
        if ([int]::TryParse($part, [ref]$n)) {
            $hit = $Apps | Where-Object { $_.Num -eq $n } | Select-Object -First 1
            if ($null -eq $hit) { throw (Get-FlgT "沒有編號 $part" "No item numbered $part") }
            $picked += $hit
            continue
        }
        $hit = @($Apps | Where-Object { $_.Key -eq $part -or $_.Id -eq $part })
        if ($hit.Count -ne 1) { throw (Get-FlgT "找不到「$part」" "No match for '$part'") }
        $picked += $hit[0]
    }
    $unique = @()
    foreach ($item in $picked) {
        if (@($unique | Where-Object { $_.Key -eq $item.Key }).Count -eq 0) { $unique += $item }
    }
    return $unique
}

function Test-WingetReady {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    Write-WarnMsg (Get-FlgT '找不到 winget，嘗試啟用 App Installer…' 'winget was not found. Trying to enable App Installer…')
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    } catch {}
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Get-WingetResult([int]$Code) {
    if ($Code -eq 0) { return 'ok' }
    # 0x8A15002B: already installed and no newer package applies.
    if ($Code -eq -1978335189) { return 'have' }
    return 'fail'
}

function Install-WingetApp($App) {
    $id = [string]$App.Id
    if ($App.Key -eq 'reader' -and -not [Environment]::Is64BitOperatingSystem) {
        $id = 'Adobe.Acrobat.Reader.32-bit'
    }
    Write-Info ((Get-FlgT '正在安裝 {0}…' 'Installing {0}…') -f (Get-AppTitle $App))
    & winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    $code = $LASTEXITCODE
    $state = Get-WingetResult ([int]$code)
    if ($state -eq 'fail') {
        return @{ State = 'fail'; Detail = ('winget ' + $code) }
    }
    return @{ State = $state; Detail = '' }
}

function Save-UrlFile([string]$Url, [string]$Dest) {
    $dir = Split-Path -Parent $Dest
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $tmp = Join-Path $env:TEMP ("lanyen_pc_" + [Guid]::NewGuid().ToString('N') + '.bin')
    try {
        $wc = New-Object Net.WebClient
        try {
            $wc.Headers['User-Agent'] = 'lanyen-pc'
            $wc.DownloadFile($Url, $tmp)
        } finally {
            $wc.Dispose()
        }
        if (-not (Test-Path -LiteralPath $tmp)) { throw (Get-FlgT '下載失敗' 'Download failed') }
        if ((Get-Item -LiteralPath $tmp).Length -lt 100000) { throw (Get-FlgT '下載檔案過小' 'Downloaded file is too small') }
        Move-Item -LiteralPath $tmp -Destination $Dest -Force
    } finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-LineApp {
    Write-Info (Get-FlgT '正在下載 LINE 官方安裝檔…' 'Downloading the official LINE installer…')
    $dest = Join-Path $DownloadDir 'LineInst.exe'
    Save-UrlFile -Url $LineUrl -Dest $dest
    Write-Info (Get-FlgT '已開啟 LINE 安裝程式，請在視窗中完成安裝。' 'The LINE installer is open. Finish it in that window.')
    $proc = Start-Process -FilePath $dest -WorkingDirectory $DownloadDir -Wait -PassThru
    if ($proc.ExitCode -ne 0 -and $null -ne $proc.ExitCode) {
        return @{ State = 'fail'; Detail = ('LINE ' + $proc.ExitCode) }
    }
    return @{ State = 'ok'; Detail = '' }
}

function Install-ChewingApp {
    Write-Info (Get-FlgT '正在取得新酷音最新官方安裝檔…' 'Getting the latest official Chewing installer…')
    $wc = New-Object Net.WebClient
    try {
        $wc.Headers['User-Agent'] = 'lanyen-pc'
        $json = $wc.DownloadString($ChewingApi)
    } finally {
        $wc.Dispose()
    }
    $rel = $json | ConvertFrom-Json
    $asset = $rel.assets | Where-Object { $_.name -like '*-installer.msi' } | Select-Object -First 1
    if ($null -eq $asset -or [string]::IsNullOrWhiteSpace([string]$asset.browser_download_url)) {
        throw (Get-FlgT '找不到新酷音安裝檔' 'Chewing installer was not found')
    }
    $name = [string]$asset.name
    $dest = Join-Path $DownloadDir $name
    Save-UrlFile -Url ([string]$asset.browser_download_url) -Dest $dest
    $shaAsset = $rel.assets | Where-Object { $_.name -eq ($name + '.sha256') } | Select-Object -First 1
    if ($null -ne $shaAsset) {
        $shaWc = New-Object Net.WebClient
        try {
            $shaWc.Headers['User-Agent'] = 'lanyen-pc'
            $shaText = $shaWc.DownloadString([string]$shaAsset.browser_download_url)
        } finally {
            $shaWc.Dispose()
        }
        $expect = ([regex]::Match($shaText, '[A-Fa-f0-9]{64}')).Value.ToLowerInvariant()
        if ($expect) {
            $sha = [Security.Cryptography.SHA256]::Create()
            try {
                $fs = [IO.File]::OpenRead($dest)
                try { $got = ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLowerInvariant() }
                finally { $fs.Close() }
            } finally { $sha.Dispose() }
            if ($got -ne $expect) { throw (Get-FlgT '新酷音安裝檔校驗不符' 'Chewing installer checksum did not match') }
        }
    }
    Write-Info (Get-FlgT '正在安裝新酷音。若跳出權限詢問，請按「是」。' 'Installing Chewing. Choose Yes if Windows asks for permission.')
    $msiArgs = @('/i', $dest, '/qn', '/norestart')
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
    } else {
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru -Verb RunAs
    }
    if ($null -eq $proc) { return @{ State = 'fail'; Detail = 'msiexec' } }
    if ($proc.ExitCode -eq 0) { return @{ State = 'ok'; Detail = '' } }
    if ($proc.ExitCode -eq 3010) { return @{ State = 'ok'; Detail = '' } }
    return @{ State = 'fail'; Detail = ('msiexec ' + $proc.ExitCode) }
}

function Install-DesktopLink($App) {
    $url = [string]$App.Url
    if ([string]::IsNullOrWhiteSpace($url)) { throw (Get-FlgT '沒有網址' 'Missing URL') }
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) {
        throw (Get-FlgT '找不到桌面' 'Desktop folder was not found')
    }
    $name = (Get-AppTitle $App) -replace '[\\/:*?"<>|]', ''
    $path = Join-Path $desktop ($name + '.url')
    $body = "[InternetShortcut]`r`nURL=$url`r`n"
    [IO.File]::WriteAllText($path, $body, [Text.Encoding]::ASCII)
    Write-Info ((Get-FlgT '已放上桌面：{0}' 'Placed on the desktop: {0}') -f $path)
    return @{ State = 'ok'; Detail = '' }
}

function Install-DownloadedSetup([string]$Url, [string]$FileName, [string]$Label) {
    $dest = Join-Path $DownloadDir $FileName
    Save-UrlFile -Url $Url -Dest $dest
    Write-Info (Get-FlgT '已開啟安裝程式，請在視窗中完成安裝。若跳出權限詢問，請按「是」。' 'The installer is open. Finish it in that window. Choose Yes if Windows asks for permission.')
    $work = Split-Path -Parent $dest
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        $proc = Start-Process -FilePath $dest -WorkingDirectory $work -Wait -PassThru
    } else {
        $proc = Start-Process -FilePath $dest -WorkingDirectory $work -Wait -PassThru -Verb RunAs
    }
    if ($null -eq $proc) { return @{ State = 'fail'; Detail = $Label } }
    if ($proc.ExitCode -eq 0 -or $null -eq $proc.ExitCode -or $proc.ExitCode -eq 3010) {
        return @{ State = 'ok'; Detail = '' }
    }
    return @{ State = 'fail'; Detail = ($Label + ' ' + $proc.ExitCode) }
}

function Install-AweSunApp {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw (Get-FlgT 'AweSun 這裡用的是 64 位元官方安裝檔。' 'This AweSun installer is 64-bit.')
    }
    # 下載頁沒有固定的最新版網址。這是官方全球版，Oray 出新版時要改這一行。
    $url = 'https://dl.oray.com/sl/windows/AweSun_16.6.0.32198_global_x64.exe'
    Write-Info (Get-FlgT '正在下載 AweSun 官方安裝檔…' 'Downloading the official AweSun installer…')
    return (Install-DownloadedSetup -Url $url -FileName 'AweSun_16.6.0.32198_global_x64.exe' -Label 'AweSun')
}

function Install-RustDeskApp {
    Write-Info (Get-FlgT '正在取得 RustDesk 最新官方安裝檔…' 'Getting the latest official RustDesk installer…')
    $wc = New-Object Net.WebClient
    try {
        $wc.Headers['User-Agent'] = 'lanyen-pc'
        $json = $wc.DownloadString('https://api.github.com/repos/rustdesk/rustdesk/releases/latest')
    } finally {
        $wc.Dispose()
    }
    $rel = $json | ConvertFrom-Json
    $arch = $env:PROCESSOR_ARCHITEW6432
    if ([string]::IsNullOrWhiteSpace($arch)) { $arch = $env:PROCESSOR_ARCHITECTURE }
    $pattern = '*-x86_64.exe'
    if ($arch -eq 'ARM64') { $pattern = '*-aarch64.exe' }
    elseif ($arch -ne 'AMD64' -and $arch -ne 'x64') { $pattern = '*-x86-sciter.exe' }
    $asset = $rel.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
    if ($null -eq $asset -or [string]::IsNullOrWhiteSpace([string]$asset.browser_download_url)) {
        throw (Get-FlgT '找不到 RustDesk 安裝檔' 'RustDesk installer was not found')
    }
    Write-Info (Get-FlgT '正在下載 RustDesk 官方安裝檔…' 'Downloading the official RustDesk installer…')
    return (Install-DownloadedSetup -Url ([string]$asset.browser_download_url) -FileName ([string]$asset.name) -Label 'RustDesk')
}

function Install-KmPlayerApp {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw (Get-FlgT 'KMPlayer 64X 只提供 64 位元版本。' 'KMPlayer 64X is 64-bit only.')
    }
    Write-Info (Get-FlgT '正在取得 KMPlayer 64X 官方下載位址…' 'Getting the official KMPlayer 64X download…')
    $wc = New-Object Net.WebClient
    try {
        $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
        $wc.Headers['Referer'] = 'https://www.kmplayer.com/pc64x'
        $page = $wc.DownloadString('https://update.kmpmedia.net/player/download/kmp64x/en')
    } finally {
        $wc.Dispose()
    }
    $found = ([regex]::Match($page, 'https://dn\.kmplayer\.com/[^"''\s>]+\.exe')).Value
    if ([string]::IsNullOrWhiteSpace($found)) {
        throw (Get-FlgT '找不到 KMPlayer 64X 安裝檔' 'KMPlayer 64X installer was not found')
    }
    $name = [IO.Path]::GetFileName(($found -split '\?')[0])
    Write-Info (Get-FlgT '正在下載 KMPlayer 64X 官方安裝檔…' 'Downloading the official KMPlayer 64X installer…')
    return (Install-DownloadedSetup -Url $found -FileName $name -Label 'KMPlayer')
}

function Install-PotPlayerGlobalApp {
    $name = 'PotPlayerSetup64.exe'
    if (-not [Environment]::Is64BitOperatingSystem) { $name = 'PotPlayerSetup.exe' }
    $url = 'https://t1.daumcdn.net/potplayer/PotPlayer/Version/Latest/' + $name
    Write-Info (Get-FlgT '正在下載 Global PotPlayer 官方安裝檔…' 'Downloading the official Global PotPlayer installer…')
    return (Install-DownloadedSetup -Url $url -FileName $name -Label 'PotPlayer')
}

function Install-SelectedApp($App) {
    if ($App.Kind -eq 'winget') { return (Install-WingetApp $App) }
    if ($App.Kind -eq 'line') { return (Install-LineApp) }
    if ($App.Kind -eq 'chewing') { return (Install-ChewingApp) }
    if ($App.Kind -eq 'link') { return (Install-DesktopLink $App) }
    if ($App.Kind -eq 'awesun') { return (Install-AweSunApp) }
    if ($App.Kind -eq 'rustdesk') { return (Install-RustDeskApp) }
    if ($App.Kind -eq 'kmplayer') { return (Install-KmPlayerApp) }
    if ($App.Kind -eq 'potglobal') { return (Install-PotPlayerGlobalApp) }
    return @{ State = 'fail'; Detail = 'unknown' }
}

function Invoke-InstallSet($Selected) {
    $keys = @($Selected | ForEach-Object { $_.Key })
    if (($keys -contains 'libreoffice') -and ($keys -contains 'openoffice')) {
        Write-WarnMsg (Get-FlgT 'LibreOffice 與 OpenOffice 功能重疊，一般裝其中一個即可。仍會照你的選擇安裝。' 'LibreOffice and OpenOffice overlap. One of them is enough. Both will still be installed.')
    }
    if (($keys -contains 'potplayer') -and ($keys -contains 'potglobal')) {
        Write-WarnMsg (Get-FlgT 'PotPlayer 與 Global PotPlayer 是同一套播放器，一般裝其中一個即可。仍會照你的選擇安裝。' 'PotPlayer and Global PotPlayer are the same player. One of them is enough. Both will still be installed.')
    }
    $needsWinget = @($Selected | Where-Object { $_.Kind -eq 'winget' }).Count -gt 0
    if ($needsWinget -and -not (Test-WingetReady)) {
        Write-ErrMsg (Get-FlgT '這台電腦還沒有 winget。請先到 Microsoft Store 更新「應用程式安裝程式」，再重跑一次。官方安裝檔的項目仍可安裝。' 'This PC does not have winget yet. Update App Installer from the Microsoft Store, then run this again. Items that use an official installer can still be installed.')
    }
    $report = @()
    foreach ($app in $Selected) {
        if ($app.Kind -eq 'winget' -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $report += @{ Title = (Get-AppTitle $app); State = 'fail'; Detail = 'winget' }
            continue
        }
        try {
            $result = Install-SelectedApp $app
            $report += @{ Title = (Get-AppTitle $app); State = [string]$result.State; Detail = [string]$result.Detail }
            if ($result.State -eq 'ok') { Write-Ok ((Get-FlgT '完成：{0}' 'Done: {0}') -f (Get-AppTitle $app)) }
            elseif ($result.State -eq 'have') { Write-Ok ((Get-FlgT '已是最新：{0}' 'Already current: {0}') -f (Get-AppTitle $app)) }
            else { Write-ErrMsg ((Get-FlgT '失敗：{0}（{1}）' 'Failed: {0} ({1})') -f (Get-AppTitle $app), $result.Detail) }
        } catch {
            $report += @{ Title = (Get-AppTitle $app); State = 'fail'; Detail = $_.Exception.Message }
            Write-ErrMsg ((Get-FlgT '失敗：{0}（{1}）' 'Failed: {0} ({1})') -f (Get-AppTitle $app), $_.Exception.Message)
        }
    }
    Write-Host ''
    Write-Host (Get-FlgT '安裝結果' 'Results') -ForegroundColor White
    foreach ($row in $report) {
        $label = switch ($row.State) {
            'ok' { Get-FlgT '完成' 'Done' }
            'have' { Get-FlgT '已有' 'Present' }
            default { Get-FlgT '失敗' 'Failed' }
        }
        $color = 'Red'
        if ($row.State -eq 'ok' -or $row.State -eq 'have') { $color = 'Green' }
        Write-Host ("  {0}  {1}" -f $label, $row.Title) -ForegroundColor $color
    }
    Write-Host ''
}

function Read-MenuLine {
    $prompt = Get-FlgT '請輸入編號，多個用逗號分開' 'Enter numbers, separated by commas'
    if (-not (Test-FlgConsoleInput)) {
        return (Read-Host $prompt)
    }
    Write-Host ($prompt + ': ') -NoNewline
    $buf = New-Object System.Text.StringBuilder
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (-not [Console]::KeyAvailable) {
            Start-Sleep -Milliseconds 100
            continue
        }
        $key = [Console]::ReadKey($true)
        $deadline = [DateTime]::UtcNow.AddSeconds(8)
        if ($key.Key -eq 'Enter') {
            Write-Host ''
            return $buf.ToString()
        }
        if ($key.Key -eq 'Backspace') {
            if ($buf.Length -gt 0) {
                $null = $buf.Remove($buf.Length - 1, 1)
                Write-Host "`b `b" -NoNewline
            }
            continue
        }
        if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
            $null = $buf.Append($key.KeyChar)
            Write-Host $key.KeyChar -NoNewline
        }
    }
    Write-Host ''
    return $null
}

function Wait-BackToMenu {
    param([int]$Seconds = 8)
    if (-not (Test-FlgConsoleInput)) {
        Write-Host ((Get-FlgT '約 {0} 秒後回到目錄。' 'Back to the menu in about {0} seconds.') -f $Seconds) -ForegroundColor DarkGray
        Start-Sleep -Seconds $Seconds
        return 'menu'
    }
    for ($left = $Seconds; $left -gt 0; $left--) {
        Write-Host ("`r" + ((Get-FlgT '約 {0} 秒後回到目錄。按 Enter 立刻返回，按 0 回到上一頁。' 'Back to the menu in about {0} s. Enter returns now, 0 goes back.') -f $left)) -NoNewline
        $until = [DateTime]::UtcNow.AddSeconds(1)
        while ([DateTime]::UtcNow -lt $until) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                Write-Host ''
                if ($key.KeyChar -eq '0') { return 'back' }
                return 'menu'
            }
            Start-Sleep -Milliseconds 100
        }
    }
    Write-Host ''
    return 'menu'
}

Invoke-FlgCounterHit 'dl-pc'

if (Test-FlgOffline) {
    Write-ErrMsg (Get-FlgT '離線模式無法下載這些軟體。請連上網路後再執行 irm lanyen.de/pc | iex' 'Offline mode cannot download these apps. Connect to the internet, then run irm lanyen.de/pc | iex')
    return
}

$argChoice = ''
if ($args -and $args.Count -gt 0) { $argChoice = ($args -join ',') }

while ($true) {
    if ($argChoice) {
        $choice = $argChoice
        $argChoice = ''
    } else {
        Show-Menu
        $choice = Read-MenuLine
        if ($null -eq $choice) {
            Write-Host (Get-FlgT '時間到，回到上一頁。' 'Time is up. Going back.')
            return
        }
    }
    try {
        $selected = Resolve-AppChoice $choice
    } catch {
        Write-ErrMsg $_.Exception.Message
        if ($env:FLG_FROM_MENU -eq '1' -and $choice -eq '0') { return }
        continue
    }
    if ($null -eq $selected) {
        Write-Host (Get-FlgT '回到上一頁。' 'Going back.')
        return
    }
    if (@($selected).Count -eq 0) {
        Write-WarnMsg (Get-FlgT '沒有選擇任何軟體。' 'No apps selected.')
        continue
    }
    $names = (@($selected | ForEach-Object { Get-AppTitle $_ }) -join ', ')
    Write-Info ((Get-FlgT '將安裝：{0}' 'Will install: {0}') -f $names)
    try {
        Invoke-InstallSet $selected
    } catch {
        Write-ErrMsg ((Get-FlgT '失敗：' 'Failed: ') + $_.Exception.Message)
    }
    if ((Wait-BackToMenu -Seconds 8) -eq 'back') {
        Write-Host (Get-FlgT '回到上一頁。' 'Going back.')
        return
    }
}
