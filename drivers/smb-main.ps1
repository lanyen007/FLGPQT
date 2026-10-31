# FLG 快速建立 SMB 共用資料夾（影印機掃描到資料夾）
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/smb.ps1 | iex
# 需要系統管理員權限（會嘗試自動提權）

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$IsWindowsOs = $false
try {
    if ($PSVersionTable.PSEdition -eq 'Desktop') { $IsWindowsOs = $true }
    elseif ($PSVersionTable.Platform -eq 'Win32NT') { $IsWindowsOs = $true }
    elseif ($env:OS -match 'Windows') { $IsWindowsOs = $true }
} catch {}

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrMsg([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-FlgExitLabel {
    if ($env:FLG_FROM_MENU -eq '1') { return '回到上一頁' }
    return '離開'
}

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

function Test-IsAdmin {
    if (-not $IsWindowsOs) { return $true }
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-UserProfilePath {
    $p = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($p)) { $p = $env:HOME }
    if ([string]::IsNullOrWhiteSpace($p)) { $p = [IO.Path]::GetTempPath() }
    return $p
}

function New-RandomPassword([int]$Length = 10) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $rnd = New-Object Random
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Length; $i++) { [void]$sb.Append($chars[$rnd.Next(0, $chars.Length)]) }
    return $sb.ToString()
}

function Get-LocalIPv4List {
    $list = New-Object System.Collections.ArrayList
    try {
        if ($IsWindowsOs) {
            $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' }
            foreach ($a in @($addrs)) {
                $alias = ''
                try { $alias = [string]$a.InterfaceAlias } catch {}
                if ($alias -match '(?i)Loopback|vEthernet|Hyper-V|WSL|Docker|VirtualBox|VMware|VPN|TAP|Bluetooth|Pseudo') { continue }
                if ($list -notcontains $a.IPAddress) { [void]$list.Add([string]$a.IPAddress) }
            }
        }
    } catch {}
    if ($list.Count -eq 0) {
        try {
            $hostEntry = [Net.Dns]::GetHostEntry([Net.Dns]::GetHostName())
            foreach ($a in $hostEntry.AddressList) {
                if ($a.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork) {
                    $s = $a.ToString()
                    if ($s -notmatch '^(127\.|169\.254\.)' -and $list -notcontains $s) { [void]$list.Add($s) }
                }
            }
        } catch {}
    }
    if ($list.Count -eq 0) { [void]$list.Add('127.0.0.1') }
    return @($list)
}

function Request-Elevation {
    Write-WarnMsg '需要系統管理員權限，即將跳出 UAC 提示…'
    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/smb.ps1'
    $parts = @()
    foreach ($a in $args) {
        $s = [string]$a
        $parts += ("'" + $s.Replace("'", "''") + "'")
    }
    $argStr = $parts -join ' '
    $envPass = Get-FlgOfflineEnvPreamble
    if ($env:FLG_FROM_MENU -eq '1' -and $envPass -notmatch 'FLG_FROM_MENU') {
        $envPass += "`$env:FLG_FROM_MENU='1'; "
    }
    $localMain = Resolve-FlgOfflinePath 'drivers\smb-main.ps1'
    if ($localMain) {
        $esc = $localMain.Replace("'", "''")
        $inner = $envPass + "& '$esc' $argStr"
    } else {
        $inner = $envPass + "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$boot'))) $argStr"
    }
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList | Out-Null
        Write-Info '已啟動提權視窗，請在新視窗完成設定。'
    } catch {
        Write-ErrMsg ("無法提權：" + $_.Exception.Message)
        Write-Host '請以「系統管理員」開啟 PowerShell 後再執行：' -ForegroundColor Yellow
        Write-Host '  irm https://lanyen007.github.io/FLGPQT/drivers/smb.ps1 | iex' -ForegroundColor White
        return
    }
}

function Enable-FlgFileSharingFirewall {
    try {
        # Localized group name via resource string
        Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction Stop | Out-Null
        Write-Ok '已啟用防火牆「檔案及印表機共用」規則群組。'
    } catch {
        try {
            Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction Stop | Out-Null
            Write-Ok '已啟用防火牆 File and Printer Sharing。'
        } catch {
            try {
                Enable-NetFirewallRule -DisplayGroup '檔案及印表機共用' -ErrorAction Stop | Out-Null
                Write-Ok '已啟用防火牆「檔案及印表機共用」。'
            } catch {
                Write-WarnMsg ("啟用防火牆規則失敗：" + $_.Exception.Message)
                Write-Host '請手動確認「檔案及印表機共用」已允許。' -ForegroundColor Yellow
            }
        }
    }
}

function Set-FlgNetworkPrivateIfNeeded {
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.NetworkCategory -eq 'Public' })
        if ($profiles.Count -eq 0) {
            Write-Info '網路設定檔已是私人／網域，無需變更。'
            return
        }
        Write-WarnMsg ("偵測到 {0} 個「公用」網路設定檔。公用網路通常會擋 SMB。" -f $profiles.Count)
        $ans = (Read-Host '要改成「私人」嗎？(Y/N，建議 Y)').Trim()
        if ($ans -match '^(?i)y|yes|是$') {
            foreach ($p in $profiles) {
                try {
                    Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                    Write-Ok ("已將介面 {0} 設為私人。" -f $p.InterfaceAlias)
                } catch {
                    Write-WarnMsg ("變更失敗（{0}）：{1}" -f $p.InterfaceAlias, $_.Exception.Message)
                }
            }
        }
    } catch {
        Write-WarnMsg ("讀取網路設定檔失敗：" + $_.Exception.Message)
    }
}

function Ensure-SmbServerEnabled {
    try {
        $svc = Get-Service -Name LanmanServer -ErrorAction Stop
        if ($svc.Status -ne 'Running') {
            Start-Service LanmanServer -ErrorAction Stop
            Write-Ok '已啟動 Server（LanmanServer）服務。'
        }
    } catch {
        Write-WarnMsg ("啟動 LanmanServer 失敗：" + $_.Exception.Message)
    }
    try {
        Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force -ErrorAction Stop
        Write-Ok '已確認 SMB2 協定啟用。'
    } catch {
        Write-WarnMsg ("設定 SMB2 失敗（可能已是啟用）：" + $_.Exception.Message)
    }
}

function New-FlgScanShare {
    param(
        [string]$Folder,
        [string]$ShareName,
        [string]$UserName,
        [string]$Password,
        [bool]$UseCurrentUser
    )

    if (-not (Test-Path -LiteralPath $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        Write-Ok ("已建立資料夾：{0}" -f $Folder)
    } else {
        Write-Info ("資料夾已存在：{0}" -f $Folder)
    }

    $accessAccount = $null
    $pc = $env:COMPUTERNAME

    if ($UseCurrentUser) {
        $accessAccount = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
        Write-Info ("使用目前使用者授權：$accessAccount")
    } else {
        $localUser = $UserName
        $existing = Get-LocalUser -Name $localUser -ErrorAction SilentlyContinue
        $secure = ConvertTo-SecureString $Password -AsPlainText -Force
        if ($existing) {
            Write-WarnMsg ("本機使用者「{0}」已存在，將更新密碼。" -f $localUser)
            Set-LocalUser -Name $localUser -Password $secure -PasswordNeverExpires $true -ErrorAction Stop
        } else {
            New-LocalUser -Name $localUser -Password $secure -FullName 'FLG Scan Share' -Description 'FLG copier scan-to-folder' -PasswordNeverExpires -UserMayNotChangePassword:$false -ErrorAction Stop | Out-Null
            # ensure not in Administrators
            try { Remove-LocalGroupMember -Group 'Administrators' -Member $localUser -ErrorAction SilentlyContinue } catch {}
            Write-Ok ("已建立本機使用者：{0}" -f $localUser)
        }
        try { Set-LocalUser -Name $localUser -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
        $accessAccount = "$pc\$localUser"
    }

    # NTFS ACL: Modify for access account
    try {
        $acl = Get-Acl -LiteralPath $Folder
        $inherit = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
        $prop = [Security.AccessControl.PropagationFlags]::None
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($accessAccount, 'Modify', $inherit, $prop, 'Allow')
        $acl.SetAccessRule($rule)
        # also ensure Users can traverse if needed - Modify on share user is enough
        Set-Acl -LiteralPath $Folder -AclObject $acl
        Write-Ok ("已設定 NTFS 權限（Modify）：{0}" -f $accessAccount)
    } catch {
        Write-WarnMsg ("設定 NTFS 權限失敗：" + $_.Exception.Message)
    }

    # Remove existing share with same name
    $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if ($existingShare) {
        Write-WarnMsg ("共用名稱「{0}」已存在，將移除後重建。" -f $ShareName)
        Remove-SmbShare -Name $ShareName -Force -ErrorAction Stop
    }

    New-SmbShare -Name $ShareName -Path $Folder -FullAccess $accessAccount -Description 'FLG scan-to-folder' -ErrorAction Stop | Out-Null
    Write-Ok ("已建立 SMB 共用：\\{0}\{1} → {2}" -f $pc, $ShareName, $Folder)

    return [pscustomobject]@{
        Folder = $Folder
        ShareName = $ShareName
        AccessAccount = $accessAccount
        Password = $(if ($UseCurrentUser) { '(目前登入密碼)' } else { $Password })
        CreatedUser = (-not $UseCurrentUser)
        UserName = $UserName
    }
}

function Remove-FlgScanShare {
    param([string]$ShareName, [string]$UserName, [switch]$RemoveUser)
    $share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    $folder = $null
    if ($share) {
        $folder = [string]$share.Path
        Remove-SmbShare -Name $ShareName -Force -ErrorAction Stop
        Write-Ok ("已移除共用：{0}" -f $ShareName)
    } else {
        Write-WarnMsg ("找不到共用：{0}" -f $ShareName)
    }
    if ($RemoveUser -and $UserName) {
        $u = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
        if ($u) {
            Remove-LocalUser -Name $UserName -ErrorAction Stop
            Write-Ok ("已刪除本機使用者：{0}" -f $UserName)
        } else {
            Write-WarnMsg ("找不到使用者：{0}" -f $UserName)
        }
    }
    if ($folder) {
        Write-Info ("資料夾仍保留（未刪檔）：{0}" -f $folder)
    }
}

# ---- main ----
Invoke-FlgCounterHit 'smb'

Write-Host ''
Write-Host '======== FLG 快速建立 SMB 共用 ========' -ForegroundColor White
Write-Host '影印機「掃描到資料夾／SMB／網路資料夾」用' -ForegroundColor Gray
Write-Host ''

if (-not $IsWindowsOs) {
    Write-ErrMsg '此工具只能在 Windows 上建立 SMB 共用（目前環境無法實作）。'
    Write-Host '功能預覽：建立資料夾、本機使用者 scan、New-SmbShare、NTFS Modify、防火牆、私人網路。' -ForegroundColor DarkGray
    return
}

if (-not (Test-IsAdmin)) {
    Request-Elevation @args
    return
}

Write-Host '請選擇：'
Write-Host '  [1] 建立／更新掃描共用'
Write-Host '  [2] 移除掃描共用（可選刪除使用者，保留檔案）'
Write-Host ('  [0] ' + (Get-FlgExitLabel))
Write-Host ''
$choice = (Read-Host '請輸入編號').Trim()
if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) {
    Write-Info ('已' + (Get-FlgExitLabel) + '。')
    return
}

if ($choice -eq '2') {
    $sn = (Read-Host '共用名稱（預設 scan）').Trim()
    if (-not $sn) { $sn = 'scan' }
    if ($sn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
    $un = (Read-Host '若要刪除本機使用者，輸入帳號（預設 scan；不想刪請直接 Enter）').Trim()
    $removeUser = $false
    $userToRemove = 'scan'
    if ($un) {
        if ($un -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
        $userToRemove = $un
        $removeUser = $true
    } else {
        $ask = (Read-Host '要一併刪除本機使用者 scan 嗎？(Y/N，預設 N)').Trim()
        if ($ask -match '^(?i)y|yes|是$') { $removeUser = $true; $userToRemove = 'scan' }
    }
    try {
        Remove-FlgScanShare -ShareName $sn -UserName $userToRemove -RemoveUser:$removeUser
    } catch {
        Write-ErrMsg ('移除失敗：' + $_.Exception.Message)
    }
    return
}

if ($choice -ne '1') {
    Write-WarnMsg '無效的編號。'
    return
}

# --- create flow ---
$defaultFolder = 'C:\掃描'
$altDesktop = Join-Path (Get-UserProfilePath) ([IO.Path]::Combine('Desktop', '掃描'))
Write-Host ("預設資料夾：{0}" -f $defaultFolder) -ForegroundColor White
Write-Host ("也可以用桌面：{0}" -f $altDesktop) -ForegroundColor DarkGray
$folderIn = (Read-Host '直接 Enter 用 C:\掃描；輸入 D 用桌面；或貼上其他路徑').Trim()
if ($folderIn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
$folder = $defaultFolder
if ($folderIn -match '^(?i)d$') { $folder = $altDesktop }
elseif ($folderIn) { $folder = $folderIn }
$folder = [IO.Path]::GetFullPath($folder)

$shareName = 'scan'
$snIn = (Read-Host '共用名稱（預設 scan）').Trim()
if ($snIn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
if ($snIn) { $shareName = $snIn }

$useCurrent = $false
$who = (Read-Host '授權帳號：1=新建本機使用者 scan（建議）  2=使用目前登入的 Windows 帳號').Trim()
if ($who -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
if ($who -eq '2') { $useCurrent = $true }

$userName = 'scan'
$password = New-RandomPassword 10
if (-not $useCurrent) {
    $uIn = (Read-Host '本機使用者名稱（預設 scan）').Trim()
    if ($uIn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
    if ($uIn) { $userName = $uIn }
    $pIn = Read-Host ("密碼（Enter=使用隨機「{0}」）" -f $password)
    if ($pIn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
    if (-not [string]::IsNullOrWhiteSpace($pIn)) { $password = $pIn }
}

try {
    Ensure-SmbServerEnabled
    Enable-FlgFileSharingFirewall
    Set-FlgNetworkPrivateIfNeeded
    $result = New-FlgScanShare -Folder $folder -ShareName $shareName -UserName $userName -Password $password -UseCurrentUser:$useCurrent
} catch {
    Write-ErrMsg ('建立失敗：' + $_.Exception.Message)
    if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    return
}

$ips = Get-LocalIPv4List
$pc = $env:COMPUTERNAME

Write-Host ''
Write-Host '======== 請把下列資料填到影印機 ========' -ForegroundColor Yellow
foreach ($ip in $ips) {
    Write-Host ("  路徑（IP）：  \\{0}\{1}" -f $ip, $result.ShareName) -ForegroundColor Green
}
Write-Host ("  路徑（名稱）：\\{0}\{1}" -f $pc, $result.ShareName) -ForegroundColor Green
Write-Host ("  使用者：      {0}" -f $result.AccessAccount) -ForegroundColor Green
Write-Host ("  密碼：        {0}" -f $result.Password) -ForegroundColor Green
Write-Host ("  本機資料夾：  {0}" -f $result.Folder) -ForegroundColor DarkGray
Write-Host ''
Write-Host '各品牌提示：' -ForegroundColor Cyan
Write-Host '  Ricoh：掃描到資料夾 → SMB／FTP 選 SMB；路徑 \\IP\scan 或 /scan；填網域可留空或填電腦名。'
Write-Host '  Sharp：Network Folder / SMB；Host=電腦 IP，Directory=scan 或 \scan。'
Write-Host '  FUJIFILM／全錄：SMB 傳輸；共用名稱 scan；使用者 PC名\scan。'
Write-Host '  Canon：檔案傳送 → Windows (SMB)；主機名稱填 IP；資料夾路徑 \scan。'
Write-Host '  美樂達／KM：SMB；Host=IP；File Path=\scan；User=PC名\scan。'
Write-Host '  若連不上：確認影印機與電腦同一網段、網路設為私人、防火牆已放行。'
Write-Host ''
Write-Ok '完成。可用檔案總管測試：\\localhost\scan'
