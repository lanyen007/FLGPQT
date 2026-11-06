# lanyen 工具箱 常用工具下載
# 用法：irm lanyen.de/tools | iex
# 從 GitHub Release 下載 MediaFire 備份的安裝檔，校驗後可選擇執行。

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$ReleaseTag = 'tools-mediafire-20261101'
$ReleaseBase = "https://github.com/lanyen007/FLGPQT/releases/download/$ReleaseTag"
$DownloadDir = Join-Path $env:USERPROFILE 'Downloads\lanyen-tools'

$Tools = @(
    @{
        Key = 'qserver'
        File = 'QServerTOctoIP_V4.exe'
        Title = 'QServer（掃描到 FTP 懶人包）'
        Size = 638847L
        Sha256 = '0a852b25be3f812ecc3a9e806d94841e0bcafb79c5caa582d6cd6fa12a784b04'
        Note = '內建 Quick n Easy FTP；帳號 scanner／密碼 scanner1234'
    }
    @{
        Key = 'w10sharp'
        File = 'w10sharp.exe'
        Title = 'Sharp Network Scanner Tool（Win10／較新）'
        Size = 26189544L
        Sha256 = '68893270ece06b0f14e2ad2b94b0b5c3301ab96a97f781f7e05d727fae082539'
        Note = 'Sharp 網路掃描工具（含繁中說明）'
    }
    @{
        Key = 'win7nst'
        File = 'win7NST-Lite_v2.0.10.27.exe'
        Title = 'Sharp NST Lite（Win7）'
        Size = 25945912L
        Sha256 = '6178b65797120b73adf0c705c7dae53a9d7607f865122a62a0d34b8e42708cf4'
        Note = 'Sharp Network Scanner Tool Lite v2.0.10.27'
    }
    @{
        Key = 'sharpdesk33'
        File = 'sharpdesk3.3.exe'
        Title = 'Sharpdesk 3.3'
        Size = 615683982L
        Sha256 = '5a460b19ff3a37439bb5312b90dd92b9f35e539e4d2dcf1255b35fde712f2a32'
        Note = '約 587 MB，下載需較長時間'
    }
    @{
        Key = 'sharpdesk32'
        File = 'Sharpdesk3.2.exe'
        Title = 'Sharpdesk 3.2'
        Size = 367449989L
        Sha256 = '4f28afd30636f46f47efd3587d6e0ff5c426755ce6c4896b0dd81f228710b9c1'
        Note = '約 350 MB'
    }
    @{
        Key = 'sharpdesk30'
        File = 'sharpdesk_3.0.exe'
        Title = 'Sharpdesk 3.0'
        Size = 251805133L
        Sha256 = 'f19410f98ed9ed1ce6b9829cc9626be8f894fe333fc38a9add02a50c4e766288'
        Note = '約 240 MB'
    }
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
    if ($env:FLG_FROM_MENU -eq '1') { return (Get-FlgT '回到上一頁' 'Back') }
    return (Get-FlgT '離開' 'Exit')
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

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N0} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ("$Bytes B")
}

function Get-FileSha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $fs = [IO.File]::OpenRead($Path)
        try {
            $hash = $sha.ComputeHash($fs)
            return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
        } finally {
            $fs.Close()
        }
    } finally {
        $sha.Dispose()
    }
}

function Show-CopyrightWarning {
    Write-Host ''
    Write-WarnMsg '注意：以下軟體版權屬原作者／原廠（Quick ''n Easy FTP Server 授權禁止商業散佈；Sharpdesk 等為 Sharp 軟體），僅供個人維修使用參考。若原廠要求移除，連結可能失效。下載與使用風險請自行評估。'
    Write-Host ''
}

function Show-Menu {
    Write-Host ''
    Write-Host ('======== ' + (Get-FlgT 'lanyen 工具箱 常用工具下載' 'lanyen Toolkit Common tools') + ' ========') -ForegroundColor White
    Show-CopyrightWarning
    Write-Host (Get-FlgT '請選擇要下載的項目：' 'Choose an item to download:')
    $i = 1
    foreach ($t in $Tools) {
        Write-Host ("  [{0}] {1}（{2}）" -f $i, $t.Title, (Format-Size ([long]$t.Size)))
        $i++
    }
    Write-Host ('  [0] ' + (Get-FlgExitLabel))
    Write-Host ''
}

function Get-ToolByChoice([string]$Choice) {
    if ([string]::IsNullOrWhiteSpace($Choice)) { return $null }
    $v = $Choice.Trim()
    if ($v -eq '0' -or $v -match '^(?i)(q|quit|exit|cancel|取消)$') { return $null }
    $n = 0
    if ([int]::TryParse($v, [ref]$n)) {
        if ($n -ge 1 -and $n -le $Tools.Count) { return $Tools[$n - 1] }
        throw "無效選項：$v"
    }
    $matched = @($Tools | Where-Object {
        $_.Key -eq $v -or $_.Key -ieq $v -or $_.File -ieq $v -or ($_.File -ieq ($v + '.exe')) -or $_.Title -like ("*" + $v + "*")
    })
    if ($matched.Count -eq 1) { return $matched[0] }
    if ($matched.Count -gt 1) {
        throw ("找到多個符合「{0}」的項目" -f $v)
    }
    throw "找不到項目：$v"
}

function Save-ToolFile {
    param([Parameter(Mandatory = $true)]$Item)

    if (-not (Test-Path -LiteralPath $DownloadDir)) {
        New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
    }
    $dest = Join-Path $DownloadDir $Item.File
    $url = "$ReleaseBase/$($Item.File)"
    $expected = [long]$Item.Size
    $expectHash = ([string]$Item.Sha256).ToLowerInvariant()

    if ((Test-Path -LiteralPath $dest) -and ((Get-Item -LiteralPath $dest).Length -eq $expected)) {
        $have = Get-FileSha256 $dest
        if ($have -eq $expectHash) {
            Write-Ok ("本機已有正確檔案：{0}" -f $dest)
            return $dest
        }
        Write-WarnMsg '本機檔案校驗不符，重新下載…'
    }

    if (Test-FlgOffline) {
        throw '離線模式無法從 GitHub Release 下載；請連網後再試。'
    }

    Write-Info ("正在下載 {0}（{1}）…" -f $Item.Title, (Format-Size $expected))
    Write-Host ("  {0}" -f $url)
    $tmp = Join-Path $env:TEMP ("lanyen_tools_" + [Guid]::NewGuid().ToString('N') + '.bin')
    try {
        $wc = New-Object Net.WebClient
        try {
            $wc.DownloadFile($url, $tmp)
        } finally {
            $wc.Dispose()
        }
        if (-not (Test-Path -LiteralPath $tmp)) { throw '下載失敗：沒有產生檔案' }
        $got = (Get-Item -LiteralPath $tmp).Length
        if ($got -ne $expected) {
            throw ("檔案大小不符：期望 {0}，實際 {1}" -f $expected, $got)
        }
        $hash = Get-FileSha256 $tmp
        if ($hash -ne $expectHash) {
            throw ("SHA256 不符：期望 {0}，實際 {1}" -f $expectHash, $hash)
        }
        Copy-Item -LiteralPath $tmp -Destination $dest -Force
        Write-Ok ("已下載並校驗：{0}" -f $dest)
        return $dest
    } finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Start-ToolFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    Write-Info ("即將執行：{0}" -f $Path)
    $ans = (Read-Host '現在執行這個安裝程式？(Y/N)').Trim()
    if ($ans -notmatch '^(?i)(y|yes|是)$') {
        Write-Host '已跳過執行。可稍後到下載資料夾手動開啟。'
        return
    }
    Start-Process -FilePath $Path -WorkingDirectory (Split-Path -Parent $Path)
    Write-Ok '已啟動安裝程式。'
}

Invoke-FlgCounterHit 'dl-tools'

$argChoice = ''
if ($args -and $args.Count -gt 0) { $argChoice = [string]$args[0] }

while ($true) {
    if ($argChoice) {
        $choice = $argChoice
        $argChoice = ''
    } else {
        Show-Menu
        $choice = Read-Host (Get-FlgT '請輸入編號' 'Enter number')
    }
    try {
        $item = Get-ToolByChoice $choice
    } catch {
        Write-ErrMsg $_.Exception.Message
        if ($env:FLG_FROM_MENU -eq '1' -and $choice -eq '0') { return }
        continue
    }
    if ($null -eq $item) {
        if ($env:FLG_FROM_MENU -eq '1') { return }
        Write-Host (Get-FlgT '已離開。' 'Exited.')
        return
    }
    try {
        if ($item.Note) { Write-Host ('說明：' + $item.Note) -ForegroundColor DarkGray }
        $path = Save-ToolFile -Item $item
        Start-ToolFile -Path $path
    } catch {
        Write-ErrMsg ('失敗：' + $_.Exception.Message)
    }
    if ($env:FLG_FROM_MENU -ne '1') {
        # standalone: loop until 0
        continue
    }
    # from menu: after one download, show menu again until 0
}
