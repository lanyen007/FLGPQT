# FLG 簡易 FTP 伺服器（影印機掃描到電腦）
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/ftp.ps1 | iex
#   & script 2121                 # 指定埠
# 測試／非互動：設 FLG_FTP_AUTO=1 與 FLG_FTP_PORT / FLG_FTP_ROOT / FLG_FTP_USER / FLG_FTP_PASS / FLG_FTP_ANON=1

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
function Write-LogLine([string]$Message) {
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host ("[{0}] {1}" -f $ts, $Message) -ForegroundColor Gray
}

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

function Test-FlgFixedDrive([string]$Letter) {
    try {
        $letter = $Letter.TrimEnd(':').Substring(0,1).ToUpperInvariant()
        $di = New-Object IO.DriveInfo ($letter + ':')
        return ($di.IsReady -and $di.DriveType -eq [IO.DriveType]::Fixed)
    } catch { return $false }
}

function Request-FlgFtpElevation {
    # Relaunch elevated; return $true if launched (caller should return)
    if (-not $IsWindowsOs) { return $false }
    if (Test-IsAdmin) { return $false }
    if ($env:FLG_FTP_ELEVATING -eq '1') { return $false }
    Write-WarnMsg '埠 21、防火牆與自動啟動需要系統管理員權限，即將跳出 UAC 提權…'
    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/ftp.ps1'
    $parts = @()
    foreach ($a in $args) {
        $s = [string]$a
        $parts += ("'" + $s.Replace("'", "''") + "'")
    }
    $argStr = $parts -join ' '
    $envBits = "`$env:FLG_FTP_ELEVATING='1'; "
    if ($env:FLG_FROM_MENU -eq '1') { $envBits += "`$env:FLG_FROM_MENU='1'; " }
    $envBits += (Get-FlgOfflineEnvPreamble)
    $localMain = Resolve-FlgOfflinePath 'drivers\ftp-main.ps1'
    if ($localMain) {
        $esc = $localMain.Replace("'", "''")
        $inner = $envBits + "& '$esc' $argStr"
    } else {
        $inner = $envBits + "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$boot'))) $argStr"
    }
    $argList = "-NoProfile -ExecutionPolicy Bypass -NoExit -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -ErrorAction Stop | Out-Null
        Write-Ok '已開啟「系統管理員」視窗，請在新視窗操作。此視窗將結束。'
        return $true
    } catch {
        Write-WarnMsg '您取消了 UAC，或以一般權限繼續。將改用埠 2121，並以啟動資料夾做自動啟動（若需要）。'
        return $false
    }
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
    if ($list.Count -eq 0) {
        try {
            $ipOut = & ip -4 -o addr show 2>$null
            foreach ($line in @($ipOut)) {
                if ($line -match 'inet\s+([0-9.]+)/') {
                    $ip = $Matches[1]
                    if ($ip -notmatch '^(127\.|169\.254\.)' -and $list -notcontains $ip) { [void]$list.Add($ip) }
                }
            }
        } catch {}
    }
    if ($list.Count -eq 0) { [void]$list.Add('127.0.0.1') }
    return @($list)
}

function New-RandomPassword([int]$Length = 8) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $rnd = New-Object Random
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Length; $i++) { [void]$sb.Append($chars[$rnd.Next(0, $chars.Length)]) }
    return $sb.ToString()
}

function Get-UserProfilePath {
    $p = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($p)) { $p = $env:HOME }
    if ([string]::IsNullOrWhiteSpace($p)) { $p = [IO.Path]::GetTempPath() }
    return $p
}

# ---- firewall / scheduled task / startup (Windows) ----
$script:FirewallRuleNames = @('FLG FTP Control', 'FLG FTP Passive')
$script:FtpTaskName = 'FLG-SimpleFTP'
$script:FtpStartupName = 'FLG-SimpleFTP.cmd'

function Get-FlgFtpConfigDir {
    $base = $env:APPDATA
    if ([string]::IsNullOrWhiteSpace($base)) { $base = Join-Path (Get-UserProfilePath) 'AppData\Roaming' }
    $dir = Join-Path $base 'lanyen-ftp'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}
function Get-FlgFtpConfigPath { return (Join-Path (Get-FlgFtpConfigDir) 'config.json') }
function Get-FlgFtpStartupCmdPath {
    $startup = [Environment]::GetFolderPath('Startup')
    if ([string]::IsNullOrWhiteSpace($startup)) {
        $startup = Join-Path (Get-UserProfilePath) 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    }
    return (Join-Path $startup $script:FtpStartupName)
}

function Save-FlgFtpConfig {
    param([string]$Root, [string]$User, [string]$Pass, [int]$Port, [bool]$Anonymous, [int]$PasvStart = 50000, [int]$PasvEnd = 50010)
    $obj = [ordered]@{
        root = $Root
        user = $User
        pass = $Pass
        port = $Port
        anonymous = [bool]$Anonymous
        pasvStart = $PasvStart
        pasvEnd = $PasvEnd
        updated = (Get-Date).ToString('o')
    }
    $path = Get-FlgFtpConfigPath
    ($obj | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Add-FlgFtpFirewallRules([int]$ControlPort, [int]$PasvStart, [int]$PasvEnd) {
    if (-not $IsWindowsOs) { return }
    if (-not (Test-IsAdmin)) {
        Write-WarnMsg '目前不是系統管理員，無法自動新增防火牆規則。'
        Write-Host '請手動開放（或用系統管理員重跑本工具）：' -ForegroundColor Yellow
        Write-Host ("  控制埠 TCP {0}、被動埠 TCP {1}-{2}" -f $ControlPort, $PasvStart, $PasvEnd) -ForegroundColor White
        Write-Host '  Windows 安全性 → 防火牆 → 進階設定 → 輸入規則 → 新增連接埠' -ForegroundColor DarkGray
        return
    }
    try {
        Remove-FlgFtpFirewallRules -Quiet
        $null = netsh advfirewall firewall add rule name="FLG FTP Control" dir=in action=allow protocol=TCP localport=$ControlPort 2>&1
        $null = netsh advfirewall firewall add rule name="FLG FTP Passive" dir=in action=allow protocol=TCP localport=$PasvStart-$PasvEnd 2>&1
        Write-Ok '已新增 Windows 防火牆規則（控制埠 + 被動埠）。'
    } catch {
        Write-WarnMsg '新增防火牆規則失敗，請手動允許 FTP 控制埠與被動埠範圍。'
        Write-Host ("  需要：TCP {0} 與 TCP {1}-{2}" -f $ControlPort, $PasvStart, $PasvEnd) -ForegroundColor White
    }
}
function Remove-FlgFtpFirewallRules([switch]$Quiet) {
    if (-not $IsWindowsOs) { return }
    foreach ($n in $script:FirewallRuleNames) {
        try { $null = netsh advfirewall firewall delete rule name="$n" 2>&1 } catch {}
    }
    if (-not $Quiet) { Write-Info '已嘗試移除 FLG FTP 防火牆規則。' }
}

function Install-FlgFtpStartupShortcut {
    param([string]$ConfigPath)
    $cmdPath = Get-FlgFtpStartupCmdPath
    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/ftp.ps1'
    # cmd launches powershell minimized; powershell reads config json and sets env
    $ps = @(
        "$ErrorActionPreference='Stop'",
        ("`$cfgPath = '{0}'" -f $ConfigPath.Replace("'", "''")),
        "if (-not (Test-Path -LiteralPath `$cfgPath)) { exit 0 }",
        "`$j = Get-Content -LiteralPath `$cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json",
        "`$env:FLG_FTP_AUTO='1'",
        "`$env:FLG_FTP_PORT = [string]`$j.port",
        "`$env:FLG_FTP_ROOT = [string]`$j.root",
        "`$env:FLG_FTP_USER = [string]`$j.user",
        "`$env:FLG_FTP_PASS = [string]`$j.pass",
        "if (`$j.anonymous) { `$env:FLG_FTP_ANON='1' } else { Remove-Item Env:FLG_FTP_ANON -ErrorAction SilentlyContinue }",
        ("& ([scriptblock]::Create((Invoke-RestMethod -Uri '{0}')))" -f $boot)
    ) -join '; '
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -Command `"$ps`""
    $lines = @(
        '@echo off',
        'rem FLG Simple FTP autostart (user Startup folder)',
        ('start "" /min powershell.exe ' + $arg)
    )
    $dir = Split-Path -Parent $cmdPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $cmdPath -Value ($lines -join "`r`n") -Encoding ASCII
    Write-Ok ("已建立「啟動」捷徑：{0}" -f $cmdPath)
    return $cmdPath
}

function Install-FlgFtpAutostart {
    param([string]$Root, [string]$User, [string]$Pass, [int]$Port, [bool]$Anonymous)
    if (-not $IsWindowsOs) { Write-WarnMsg '自動啟動目前僅支援 Windows。'; return }

    $isAdmin = Test-IsAdmin
    if ($Port -lt 1024 -and -not $isAdmin) {
        $Port = 2121
        Write-WarnMsg '一般權限無法綁定埠 21，自動啟動改用埠 2121（請在影印機填 2121）。'
    }

    $configPath = Save-FlgFtpConfig -Root $Root -User $User -Pass $Pass -Port $Port -Anonymous $Anonymous
    Write-Info ("設定已儲存：{0}" -f $configPath)

    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/ftp.ps1'
    $cfgEsc = $configPath.Replace("'", "''")
    $inner = @"
`$ErrorActionPreference='Stop'; `$j = Get-Content -LiteralPath '$cfgEsc' -Raw -Encoding UTF8 | ConvertFrom-Json; `$env:FLG_FTP_AUTO='1'; `$env:FLG_FTP_PORT=[string]`$j.port; `$env:FLG_FTP_ROOT=[string]`$j.root; `$env:FLG_FTP_USER=[string]`$j.user; `$env:FLG_FTP_PASS=[string]`$j.pass; if (`$j.anonymous) { `$env:FLG_FTP_ANON='1' }; & ([scriptblock]::Create((Invoke-RestMethod -Uri '$boot')))
"@
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -Command `"$inner`""

    $taskOk = $false
    try {
        Unregister-ScheduledTask -TaskName $script:FtpTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        # Admin-created task can use Highest so logon instance can bind port 21
        $runLevel = $(if ($isAdmin) { 'Highest' } else { 'Limited' })
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel $runLevel
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $script:FtpTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Write-Ok ("已登錄登入自動啟動工作（{0}）：{1}" -f $(if ($isAdmin) { '最高權限' } else { '一般權限' }), $script:FtpTaskName)
        $taskOk = $true
    } catch {
        Write-WarnMsg '無法登錄「工作排程器」，改用「啟動」資料夾。'
    }

    if (-not $taskOk) {
        try {
            Install-FlgFtpStartupShortcut -ConfigPath $configPath | Out-Null
        } catch {
            Write-WarnMsg '寫入「啟動」資料夾也失敗了。請每次登入後執行 irm lanyen.de/ftp | iex。'
            Write-Host ("  設定檔：{0}" -f $configPath) -ForegroundColor White
            return
        }
    } else {
        $cmdPath = Get-FlgFtpStartupCmdPath
        if (Test-Path -LiteralPath $cmdPath) {
            try { Remove-Item -LiteralPath $cmdPath -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    Write-Host ''
    Write-Ok '自動啟動已設定完成。'
    Write-Host ("  埠：{0}　帳號：{1}　密碼：{2}" -f $Port, $User, $Pass) -ForegroundColor Green
    Write-Host ("  資料夾：{0}" -f $Root) -ForegroundColor Green
    if ($Port -ne 21) {
        Write-Host '  請確認影印機 FTP 埠與此相同。' -ForegroundColor Yellow
    }
}

function Remove-FlgFtpAutostart {
    if (-not $IsWindowsOs) { return }
    $removed = $false
    try {
        $t = Get-ScheduledTask -TaskName $script:FtpTaskName -ErrorAction SilentlyContinue
        if ($t) {
            Unregister-ScheduledTask -TaskName $script:FtpTaskName -Confirm:$false -ErrorAction Stop
            Write-Ok ("已移除工作排程：{0}" -f $script:FtpTaskName)
            $removed = $true
        }
    } catch {
        Write-WarnMsg '移除工作排程失敗（可能本來就不存在，或權限不足）。'
    }
    try {
        $cmdPath = Get-FlgFtpStartupCmdPath
        if (Test-Path -LiteralPath $cmdPath) {
            Remove-Item -LiteralPath $cmdPath -Force -ErrorAction Stop
            Write-Ok ("已移除啟動捷徑：{0}" -f $cmdPath)
            $removed = $true
        }
    } catch {
        Write-WarnMsg '移除啟動捷徑失敗。'
    }
    # keep config.json so user can reinstall easily; mention path
    $cfg = Get-FlgFtpConfigPath
    if (Test-Path -LiteralPath $cfg) {
        Write-Info ("設定檔仍保留：{0}（可手動刪除）" -f $cfg)
    }
    if (-not $removed) {
        Write-Info '沒有找到可移除的自動啟動項目。'
    }
}

# ---- FTP session helpers ----
function Send-FtpReply {
    param($Writer, [string]$CodeMessage)
    $Writer.WriteLine($CodeMessage)
    $Writer.Flush()
}

function Resolve-FtpPath {
    param([string]$Root, [string]$Cwd, [string]$Target)
    if ([string]::IsNullOrWhiteSpace($Target)) { $Target = '.' }
    $Target = $Target -replace '\\', '/'
    if ($Target.StartsWith('/')) {
        $rel = $Target.TrimStart('/')
    } else {
        $base = $Cwd.Trim('/')
        if ($base) { $rel = "$base/$Target" } else { $rel = $Target }
    }
    $parts = New-Object System.Collections.ArrayList
    foreach ($p in ($rel -split '/')) {
        if ([string]::IsNullOrWhiteSpace($p) -or $p -eq '.') { continue }
        if ($p -eq '..') {
            if ($parts.Count -gt 0) { $parts.RemoveAt($parts.Count - 1) }
            continue
        }
        # block weird names
        if ($p -match '[<>:"|?*]' -or $p -eq '.') { continue }
        [void]$parts.Add($p)
    }
    $relPath = ($parts -join [IO.Path]::DirectorySeparatorChar)
    $full = if ($relPath) { Join-Path $Root $relPath } else { $Root }
    $rootFull = [IO.Path]::GetFullPath($Root)
    $fullResolved = [IO.Path]::GetFullPath($full)
    if (-not $fullResolved.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    $virtual = '/' + (($parts -join '/'))
    if ($virtual -eq '/') { } else { $virtual = $virtual.TrimEnd('/') }
    if (-not $virtual) { $virtual = '/' }
    return @{ Full = $fullResolved; Virtual = $virtual }
}

function Format-FtpListLine {
    param([IO.FileSystemInfo]$Item)
    $isDir = $Item.PSIsContainer
    $mode = $(if ($isDir) { 'drwxr-xr-x' } else { '-rw-r--r--' })
    $size = 0
    if (-not $isDir) { try { $size = [int64]$Item.Length } catch {} }
    $mtime = $Item.LastWriteTime.ToString('MMM dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    return ("{0} 1 ftp ftp {1,12} {2} {3}" -f $mode, $size, $mtime, $Item.Name)
}

function Format-FtpMlsdLine {
    param([IO.FileSystemInfo]$Item)
    $isDir = $Item.PSIsContainer
    $type = $(if ($isDir) { 'dir' } else { 'file' })
    $size = 0
    if (-not $isDir) { try { $size = [int64]$Item.Length } catch {} }
    $mod = $Item.LastWriteTimeUtc.ToString('yyyyMMddHHmmss')
    return ("Type={0};Size={1};Modify={2}; {3}" -f $type, $size, $mod, $Item.Name)
}

function Open-PassiveListener {
    param([int]$StartPort, [int]$EndPort)
    for ($p = $StartPort; $p -le $EndPort; $p++) {
        try {
            $l = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Any), $p
            $l.Start()
            return @{ Listener = $l; Port = $p }
        } catch {}
    }
    throw '被動模式埠範圍皆無法綁定。'
}

function Accept-DataClient {
    param(
        $Session
    )
    # returns connected TcpClient for data
    if ($Session.PassiveListener) {
        $ok = $Session.PassiveListener.Pending()
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $Session.PassiveListener.Pending() -and $sw.ElapsedMilliseconds -lt 30000) {
            Start-Sleep -Milliseconds 50
        }
        if (-not $Session.PassiveListener.Pending()) { throw '被動資料連線逾時。' }
        $client = $Session.PassiveListener.AcceptTcpClient()
        try { $Session.PassiveListener.Stop() } catch {}
        $Session.PassiveListener = $null
        return $client
    }
    if ($Session.ActiveEndpoint) {
        $client = New-Object Net.Sockets.TcpClient
        $client.Connect($Session.ActiveEndpoint)
        $Session.ActiveEndpoint = $null
        return $client
    }
    throw '尚未設定 PASV/PORT。'
}

function Handle-FtpClient {
    param(
        [Net.Sockets.TcpClient]$Client,
        [hashtable]$Config
    )
    $stream = $null
    $reader = $null
    $writer = $null
    $session = @{
        Auth = $false
        User = ''
        Cwd = '/'
        Type = 'I'   # binary default (good for scans)
        Utf8 = $true
        PassiveListener = $null
        ActiveEndpoint = $null
        RenameFrom = $null
    }
    try {
        $Client.ReceiveTimeout = 120000
        $Client.SendTimeout = 120000
        $stream = $Client.GetStream()
        $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $false, 1024, $true)
        $writer = New-Object IO.StreamWriter($stream, [Text.Encoding]::ASCII)
        $writer.NewLine = "`r`n"
        $writer.AutoFlush = $true
        Send-FtpReply $writer '220 FLG Simple FTP ready.'

        while ($Client.Connected) {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }
            $line = $line.TrimEnd()
            if (-not $line) { continue }
            $cmd = $line
            $arg = ''
            $sp = $line.IndexOf(' ')
            if ($sp -gt 0) {
                $cmd = $line.Substring(0, $sp).ToUpperInvariant()
                $arg = $line.Substring($sp + 1)
            } else {
                $cmd = $line.ToUpperInvariant()
            }

            switch ($cmd) {
                'USER' {
                    $session.User = $arg
                    $session.Auth = $false
                    if ($Config.Anonymous -and ($arg -eq 'anonymous' -or $arg -eq 'ftp' -or $arg -eq $Config.User)) {
                        Send-FtpReply $writer '331 User name okay, need password.'
                    } elseif ($arg -eq $Config.User) {
                        Send-FtpReply $writer '331 User name okay, need password.'
                    } else {
                        Send-FtpReply $writer '331 User name okay, need password.'
                    }
                }
                'PASS' {
                    $ok = $false
                    if ($Config.Anonymous -and ($session.User -eq 'anonymous' -or $session.User -eq 'ftp')) { $ok = $true }
                    elseif ($session.User -eq $Config.User -and $arg -eq $Config.Pass) { $ok = $true }
                    elseif ($Config.Anonymous -and $session.User -eq $Config.User) { $ok = $true }
                    if ($ok) {
                        $session.Auth = $true
                        Send-FtpReply $writer '230 Login successful.'
                        Write-LogLine ("登入成功：{0} from {1}" -f $session.User, $Client.Client.RemoteEndPoint)
                    } else {
                        $session.Auth = $false
                        Send-FtpReply $writer '530 Login incorrect.'
                    }
                }
                'QUIT' { Send-FtpReply $writer '221 Goodbye.'; break }
                'NOOP' { Send-FtpReply $writer '200 NOOP ok.' }
                'SYST' { Send-FtpReply $writer '215 UNIX Type: L8' }
                'FEAT' {
                    Send-FtpReply $writer '211-Features:'
                    $writer.WriteLine(' UTF8')
                    $writer.WriteLine(' PASV')
                    $writer.WriteLine(' EPSV')
                    $writer.WriteLine(' SIZE')
                    $writer.WriteLine(' MLSD')
                    $writer.WriteLine(' REST STREAM')
                    Send-FtpReply $writer '211 End'
                }
                'OPTS' {
                    if ($arg -match '(?i)^UTF8\s+ON') { $session.Utf8 = $true; Send-FtpReply $writer '200 UTF8 set to on.' }
                    elseif ($arg -match '(?i)^UTF8\s+OFF') { $session.Utf8 = $false; Send-FtpReply $writer '200 UTF8 set to off.' }
                    else { Send-FtpReply $writer '501 Option not understood.' }
                }
                'TYPE' {
                    if ($arg -match '^(?i)I') { $session.Type = 'I'; Send-FtpReply $writer '200 Type set to I.' }
                    elseif ($arg -match '^(?i)A') { $session.Type = 'A'; Send-FtpReply $writer '200 Type set to A.' }
                    else { Send-FtpReply $writer '504 Type not implemented.' }
                }
                'PWD' { Send-FtpReply $writer ('257 "{0}" is current directory.' -f $session.Cwd) }
                'XPWD' { Send-FtpReply $writer ('257 "{0}" is current directory.' -f $session.Cwd) }
                'CWD' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Container)) {
                        Send-FtpReply $writer '550 Failed to change directory.'
                    } else {
                        $session.Cwd = $res.Virtual
                        Send-FtpReply $writer '250 Directory successfully changed.'
                    }
                }
                'XCWD' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Container)) {
                        Send-FtpReply $writer '550 Failed to change directory.'
                    } else {
                        $session.Cwd = $res.Virtual
                        Send-FtpReply $writer '250 Directory successfully changed.'
                    }
                }
                'CDUP' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target '..'
                    if (-not $res) { Send-FtpReply $writer '550 Failed.'; break }
                    $session.Cwd = $res.Virtual
                    Send-FtpReply $writer '250 Directory successfully changed.'
                }
                'MKD' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res) { Send-FtpReply $writer '550 Permission denied.'; break }
                    try {
                        if (-not (Test-Path -LiteralPath $res.Full)) { New-Item -ItemType Directory -Path $res.Full -Force | Out-Null }
                        Send-FtpReply $writer ('257 "{0}" created.' -f $res.Virtual)
                        Write-LogLine ("建立資料夾：{0}" -f $res.Virtual)
                    } catch { Send-FtpReply $writer '550 Create directory failed.' }
                }
                'XMKD' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res) { Send-FtpReply $writer '550 Permission denied.'; break }
                    try {
                        if (-not (Test-Path -LiteralPath $res.Full)) { New-Item -ItemType Directory -Path $res.Full -Force | Out-Null }
                        Send-FtpReply $writer ('257 "{0}" created.' -f $res.Virtual)
                    } catch { Send-FtpReply $writer '550 Create directory failed.' }
                }
                'PASV' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        if ($session.PassiveListener) { try { $session.PassiveListener.Stop() } catch {}; $session.PassiveListener = $null }
                        $pasv = Open-PassiveListener -StartPort $Config.PasvStart -EndPort $Config.PasvEnd
                        $session.PassiveListener = $pasv.Listener
                        $session.ActiveEndpoint = $null
                        $ip = $Config.AdvertiseIp
                        $parts = $ip.Split('.')
                        $p1 = [int][Math]::Floor($pasv.Port / 256)
                        $p2 = $pasv.Port % 256
                        Send-FtpReply $writer ("227 Entering Passive Mode ({0},{1},{2},{3},{4},{5})." -f $parts[0], $parts[1], $parts[2], $parts[3], $p1, $p2)
                    } catch {
                        Send-FtpReply $writer '425 Cannot open passive connection.'
                    }
                }
                'EPSV' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        if ($session.PassiveListener) { try { $session.PassiveListener.Stop() } catch {}; $session.PassiveListener = $null }
                        $pasv = Open-PassiveListener -StartPort $Config.PasvStart -EndPort $Config.PasvEnd
                        $session.PassiveListener = $pasv.Listener
                        $session.ActiveEndpoint = $null
                        Send-FtpReply $writer ("229 Entering Extended Passive Mode (|||{0}|)" -f $pasv.Port)
                    } catch {
                        Send-FtpReply $writer '425 Cannot open passive connection.'
                    }
                }
                'PORT' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $nums = @($arg -split ',' | ForEach-Object { [int]$_.Trim() })
                        if ($nums.Count -ne 6) { throw 'bad PORT' }
                        $ip = "{0}.{1}.{2}.{3}" -f $nums[0], $nums[1], $nums[2], $nums[3]
                        $port = $nums[4] * 256 + $nums[5]
                        if ($session.PassiveListener) { try { $session.PassiveListener.Stop() } catch {}; $session.PassiveListener = $null }
                        $session.ActiveEndpoint = New-Object Net.IPEndPoint ([Net.IPAddress]::Parse($ip), $port)
                        Send-FtpReply $writer '200 PORT command successful.'
                    } catch {
                        Send-FtpReply $writer '501 Bad PORT command.'
                    }
                }
                'LIST' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $targetArg = $arg
                        if ($targetArg -match '^-') { $targetArg = '' } # ignore flags like -a
                        $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $(if ($targetArg) { $targetArg } else { '.' })
                        if (-not $res -or -not (Test-Path -LiteralPath $res.Full)) { Send-FtpReply $writer '550 Path not found.'; break }
                        Send-FtpReply $writer '150 Here comes the directory listing.'
                        $data = Accept-DataClient -Session $session
                        $ds = $data.GetStream()
                        $dw = New-Object IO.StreamWriter($ds, (New-Object Text.UTF8Encoding $false))
                        $dw.NewLine = "`r`n"
                        if (Test-Path -LiteralPath $res.Full -PathType Container) {
                            Get-ChildItem -LiteralPath $res.Full -Force | ForEach-Object {
                                $dw.WriteLine((Format-FtpListLine $_))
                            }
                        } else {
                            $dw.WriteLine((Format-FtpListLine (Get-Item -LiteralPath $res.Full)))
                        }
                        $dw.Flush(); $dw.Dispose(); $data.Close()
                        Send-FtpReply $writer '226 Directory send OK.'
                    } catch {
                        Send-FtpReply $writer ('425 Data connection failed: ' + $_.Exception.Message)
                    }
                }
                'NLST' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $(if ($arg) { $arg } else { '.' })
                        if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Container)) { Send-FtpReply $writer '550 Path not found.'; break }
                        Send-FtpReply $writer '150 Here comes the directory listing.'
                        $data = Accept-DataClient -Session $session
                        $ds = $data.GetStream()
                        $dw = New-Object IO.StreamWriter($ds, (New-Object Text.UTF8Encoding $false))
                        $dw.NewLine = "`r`n"
                        Get-ChildItem -LiteralPath $res.Full -Force | ForEach-Object { $dw.WriteLine($_.Name) }
                        $dw.Flush(); $dw.Dispose(); $data.Close()
                        Send-FtpReply $writer '226 Directory send OK.'
                    } catch {
                        Send-FtpReply $writer ('425 Data connection failed: ' + $_.Exception.Message)
                    }
                }
                'MLSD' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $(if ($arg) { $arg } else { '.' })
                        if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Container)) { Send-FtpReply $writer '550 Path not found.'; break }
                        Send-FtpReply $writer '150 Opening data connection for MLSD.'
                        $data = Accept-DataClient -Session $session
                        $ds = $data.GetStream()
                        $dw = New-Object IO.StreamWriter($ds, (New-Object Text.UTF8Encoding $false))
                        $dw.NewLine = "`r`n"
                        Get-ChildItem -LiteralPath $res.Full -Force | ForEach-Object { $dw.WriteLine((Format-FtpMlsdLine $_)) }
                        $dw.Flush(); $dw.Dispose(); $data.Close()
                        Send-FtpReply $writer '226 Closing data connection.'
                    } catch {
                        Send-FtpReply $writer ('425 Data connection failed: ' + $_.Exception.Message)
                    }
                }
                'SIZE' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Leaf)) { Send-FtpReply $writer '550 Could not get file size.'; break }
                    $len = (Get-Item -LiteralPath $res.Full).Length
                    Send-FtpReply $writer ("213 {0}" -f $len)
                }
                'STOR' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                        if (-not $res) { Send-FtpReply $writer '550 Permission denied.'; break }
                        $dir = Split-Path -Parent $res.Full
                        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                        Send-FtpReply $writer '150 Ok to send data.'
                        $data = Accept-DataClient -Session $session
                        $ds = $data.GetStream()
                        $fs = [IO.File]::Create($res.Full)
                        try {
                            $buf = New-Object byte[] 65536
                            while (($n = $ds.Read($buf, 0, $buf.Length)) -gt 0) { $fs.Write($buf, 0, $n) }
                        } finally { $fs.Close(); $data.Close() }
                        $sz = (Get-Item -LiteralPath $res.Full).Length
                        Send-FtpReply $writer '226 Transfer complete.'
                        Write-LogLine ("收到檔案：{0}（{1:N1} KB）" -f $res.Virtual, ($sz / 1KB))
                    } catch {
                        Send-FtpReply $writer ('426 Transfer aborted: ' + $_.Exception.Message)
                    }
                }
                'APPE' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                        if (-not $res) { Send-FtpReply $writer '550 Permission denied.'; break }
                        $dir = Split-Path -Parent $res.Full
                        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                        Send-FtpReply $writer '150 Ok to send data.'
                        $data = Accept-DataClient -Session $session
                        $ds = $data.GetStream()
                        $fs = [IO.File]::Open($res.Full, [IO.FileMode]::Append, [IO.FileAccess]::Write)
                        try {
                            $buf = New-Object byte[] 65536
                            while (($n = $ds.Read($buf, 0, $buf.Length)) -gt 0) { $fs.Write($buf, 0, $n) }
                        } finally { $fs.Close(); $data.Close() }
                        Send-FtpReply $writer '226 Transfer complete.'
                        Write-LogLine ("附加寫入：{0}" -f $res.Virtual)
                    } catch {
                        Send-FtpReply $writer ('426 Transfer aborted: ' + $_.Exception.Message)
                    }
                }
                'RETR' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    try {
                        $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                        if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Leaf)) { Send-FtpReply $writer '550 File not found.'; break }
                        Send-FtpReply $writer '150 Opening data connection.'
                        $data = Accept-DataClient -Session $session
                        $ds = $data.GetStream()
                        $fs = [IO.File]::OpenRead($res.Full)
                        try {
                            $buf = New-Object byte[] 65536
                            while (($n = $fs.Read($buf, 0, $buf.Length)) -gt 0) { $ds.Write($buf, 0, $n) }
                            $ds.Flush()
                        } finally { $fs.Close(); $data.Close() }
                        Send-FtpReply $writer '226 Transfer complete.'
                    } catch {
                        Send-FtpReply $writer ('426 Transfer aborted: ' + $_.Exception.Message)
                    }
                }
                'DELE' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Leaf)) { Send-FtpReply $writer '550 Delete failed.'; break }
                    try {
                        Remove-Item -LiteralPath $res.Full -Force
                        Send-FtpReply $writer '250 Delete operation successful.'
                        Write-LogLine ("刪除：{0}" -f $res.Virtual)
                    } catch { Send-FtpReply $writer '550 Delete failed.' }
                }
                'RMD' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res -or -not (Test-Path -LiteralPath $res.Full -PathType Container)) { Send-FtpReply $writer '550 Remove failed.'; break }
                    try {
                        Remove-Item -LiteralPath $res.Full -Recurse -Force
                        Send-FtpReply $writer '250 Remove directory operation successful.'
                    } catch { Send-FtpReply $writer '550 Remove failed.' }
                }
                'RNFR' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res -or -not (Test-Path -LiteralPath $res.Full)) { Send-FtpReply $writer '550 File not found.'; break }
                    $session.RenameFrom = $res.Full
                    Send-FtpReply $writer '350 Ready for RNTO.'
                }
                'RNTO' {
                    if (-not $session.Auth) { Send-FtpReply $writer '530 Please login.'; break }
                    if (-not $session.RenameFrom) { Send-FtpReply $writer '503 Bad sequence.'; break }
                    $res = Resolve-FtpPath -Root $Config.Root -Cwd $session.Cwd -Target $arg
                    if (-not $res) { Send-FtpReply $writer '550 Rename failed.'; break }
                    try {
                        Move-Item -LiteralPath $session.RenameFrom -Destination $res.Full -Force
                        $session.RenameFrom = $null
                        Send-FtpReply $writer '250 Rename successful.'
                    } catch { Send-FtpReply $writer '550 Rename failed.' }
                }
                'REST' { Send-FtpReply $writer '350 Restart position accepted (0 only).' }
                default { Send-FtpReply $writer ("502 Command not implemented: {0}" -f $cmd) }
            }
        }
    } catch {
        Write-LogLine ("連線結束／錯誤：{0}" -f $_.Exception.Message)
    } finally {
        if ($session.PassiveListener) { try { $session.PassiveListener.Stop() } catch {} }
        try { if ($writer) { $writer.Dispose() } } catch {}
        try { if ($reader) { $reader.Dispose() } } catch {}
        try { $Client.Close() } catch {}
    }
}

function Start-FlgFtpServer {
    param([hashtable]$Config)

    $listener = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Any), ([int]$Config.Port)
    $listener.Start()
    Write-Ok ("FTP 伺服器已啟動，監聽 0.0.0.0:{0}" -f $Config.Port)

    $pool = [runspacefactory]::CreateRunspacePool(1, 8)
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList
    $script:FtpStop = $false

    # Accept loop in background runspace; main waits for Enter
    $acceptPS = [powershell]::Create().AddScript({
        param($Listener, $Config, $HandleScript)
        $handler = [scriptblock]::Create($HandleScript)
        while ($true) {
            try {
                if (-not $Listener.Server.IsBound) { break }
                if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
                $client = $Listener.AcceptTcpClient()
                # handle inline in this accept loop's pool via nested - simpler: handle synchronously in another runspace from caller
                # For this accept thread we just enqueue by calling handler in new runspace - but we don't have pool here.
                # Call handler directly (blocking one client at a time in this thread) - parent spawns per-client.
                & $handler -Client $client -Config $Config
            } catch {
                Start-Sleep -Milliseconds 200
                if (-not $Listener.Server.IsBound) { break }
            }
        }
    }).AddArgument($listener).AddArgument($Config).AddArgument(${function:Handle-FtpClient}.ToString())

    # Better approach: main thread accepts, dispatches to runspaces
    Write-Info '等待影印機連線中…（按 Enter 停止）'
    $acceptError = $null

    # Non-blocking Enter watcher
    if ($env:FLG_FTP_STOP_FILE) {
        $stopFile = [string]$env:FLG_FTP_STOP_FILE
    } else {
        $stopFile = Join-Path ([IO.Path]::GetTempPath()) ('flg-ftp-stop-' + [Guid]::NewGuid().ToString('N'))
    }
    $Config.StopFile = $stopFile
    if (Test-Path -LiteralPath $stopFile) { Remove-Item -LiteralPath $stopFile -Force -ErrorAction SilentlyContinue }

    $uiPS = $null
    if ($env:FLG_FTP_TEST -eq '1') {
        # test mode: wait until stop file appears (created by test harness)
        Write-Info ("測試模式：停止檔 {0}" -f $stopFile)
    } else {
        $uiPS = [powershell]::Create().AddScript({
            param($StopFile)
            try { [Console]::ReadLine() | Out-Null } catch { Start-Sleep -Seconds 86400 }
            'stop' | Set-Content -LiteralPath $StopFile -Encoding ASCII
        }).AddArgument($stopFile)
        $uiPS.RunspacePool = $pool
        $uiHandle = $uiPS.BeginInvoke()
    }

    try {
        while ($true) {
            if (Test-Path -LiteralPath $stopFile) { break }
            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $ps = [powershell]::Create().AddScript({
                    param($Client, $Config, $FnText)
                    $fn = [scriptblock]::Create($FnText)
                    & $fn -Client $Client -Config $Config
                }).AddArgument($client).AddArgument($Config).AddArgument(${function:Handle-FtpClient}.ToString())
                # Also need helper functions inside the runspace - they are embedded in Handle-FtpClient's calls!
                # PROBLEM: Handle-FtpClient calls other functions not defined in runspace.
                # Fix: run handler in same process synchronously via Start-Job is heavy; better use runspace with InitialSessionState importing functions.
                $ps.Dispose()
                # Dispatch with InitialSessionState
                $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                foreach ($fnName in @('Write-LogLine','Send-FtpReply','Resolve-FtpPath','Format-FtpListLine','Format-FtpMlsdLine','Open-PassiveListener','Accept-DataClient','Handle-FtpClient','Write-Host','Write-Info','Write-Ok','Write-WarnMsg','Write-ErrMsg')) {
                    $fi = Get-Command $fnName -ErrorAction SilentlyContinue
                    if ($fi -and $fi.ScriptBlock) {
                        $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($fnName, $fi.ScriptBlock)))
                    }
                }
                $rs = [runspacefactory]::CreateRunspace($iss)
                $rs.Open()
                $ps2 = [powershell]::Create()
                $ps2.Runspace = $rs
                [void]$ps2.AddScript('Handle-FtpClient -Client $args[0] -Config $args[1]').AddArgument($client).AddArgument($Config)
                $handle = $ps2.BeginInvoke()
                [void]$jobs.Add([pscustomobject]@{ PS = $ps2; RS = $rs; Handle = $handle })
                # cleanup finished
                $alive = New-Object System.Collections.ArrayList
                foreach ($j in $jobs) {
                    if ($j.Handle.IsCompleted) {
                        try { $j.PS.EndInvoke($j.Handle) } catch {}
                        try { $j.PS.Dispose() } catch {}
                        try { $j.RS.Close(); $j.RS.Dispose() } catch {}
                    } else { [void]$alive.Add($j) }
                }
                $jobs = $alive
            } else {
                Start-Sleep -Milliseconds 80
            }
            # auto-test timeout stop
            if ($env:FLG_FTP_TEST -eq '1' -and $env:FLG_FTP_TEST_SECONDS) {
                # handled by external stop file
            }
        }
    } finally {
        Write-Info '正在停止 FTP 伺服器…'
        try { $listener.Stop() } catch {}
        foreach ($j in $jobs) {
            try { if (-not $j.Handle.IsCompleted) { $j.PS.Stop() } } catch {}
            try { $j.PS.Dispose() } catch {}
            try { $j.RS.Dispose() } catch {}
        }
        if ($uiPS) { try { $uiPS.Stop(); $uiPS.Dispose() } catch {} }
        try { $pool.Close(); $pool.Dispose() } catch {}
        if (Test-Path -LiteralPath $stopFile) { Remove-Item -LiteralPath $stopFile -Force -ErrorAction SilentlyContinue }
        Remove-FlgFtpFirewallRules -Quiet
        Write-Ok 'FTP 伺服器已停止。'
    }
}

# ---- args / config ----
$script:ArgPort = 0
if ($args -and $args.Count -ge 1) {
    $n = 0
    if ([int]::TryParse([string]$args[0], [ref]$n) -and $n -gt 0 -and $n -lt 65536) { $script:ArgPort = $n }
}

Invoke-FlgCounterHit 'ftp'

Write-Host ''
Write-Host '======== FLG 簡易 FTP 伺服器 ========' -ForegroundColor White
Write-Host '給影印機「掃描到 FTP／資料夾」用：把檔案存到這台電腦' -ForegroundColor Gray
Write-Host '預設：帳號 scanner　密碼 scanner1234　埠 21' -ForegroundColor DarkGray
Write-Host ''

$auto = ($env:FLG_FTP_AUTO -eq '1')

# Self-elevate for interactive use (port 21 / firewall / task)
if ($IsWindowsOs -and -not $auto -and -not (Test-IsAdmin)) {
    if (Request-FlgFtpElevation @args) { return }
    $script:FlgFtpNonAdminFallback = $true
} else {
    $script:FlgFtpNonAdminFallback = $false
}

function Show-FtpTopMenu {
    Write-Host '請選擇：'
    Write-Host '  [1] 啟動 FTP 伺服器'
    Write-Host '  [2] 安裝登入後自動啟動'
    Write-Host '  [3] 移除自動啟動'
    Write-Host ('  [0] ' + (Get-FlgExitLabel))
    Write-Host ''
}

$choice = '1'
if (-not $auto) {
    Show-FtpTopMenu
    $choice = (Read-Host '請輸入編號').Trim()
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '0' }
}
if ($choice -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
if ($choice -eq '3') { Remove-FlgFtpAutostart; return }
if ($choice -eq '2') {
    $script:InstallAutostartOnly = $true
} else {
    $script:InstallAutostartOnly = $false
}

# defaults
$hasD = Test-FlgFixedDrive 'D'
$defaultRoot = $(if ($hasD) { 'D:\scan' } else { 'C:\scan' })
if ($env:FLG_FTP_ROOT) { $defaultRoot = $env:FLG_FTP_ROOT }
$root = $defaultRoot
$user = 'scanner'
if ($env:FLG_FTP_USER) { $user = $env:FLG_FTP_USER }
$pass = 'scanner1234'
if ($null -ne $env:FLG_FTP_PASS -and $env:FLG_FTP_PASS -ne '') { $pass = [string]$env:FLG_FTP_PASS }
elseif ($env:FLG_FTP_PASS -eq '') { $pass = '' }
$anonymous = ($env:FLG_FTP_ANON -eq '1')
$port = 21
if ($script:ArgPort -gt 0) { $port = $script:ArgPort }
elseif ($env:FLG_FTP_PORT) { $port = [int]$env:FLG_FTP_PORT }
$pasvStart = 50000
$pasvEnd = 50010

if (-not $auto) {
    Write-Host ''
    Write-Host '存放資料夾：' -ForegroundColor White
    Write-Host '  [1] C:\scan'
    if ($hasD) {
        Write-Host '  [2] D:\scan（建議，已偵測到 D:）'
    } else {
        Write-Host '  [2] D:\scan（目前沒有固定 D: 碟）' -ForegroundColor DarkGray
    }
    Write-Host ("  直接 Enter = 使用 {0}" -f $defaultRoot)
    Write-Host '  或輸入其他完整路徑'
    $r = (Read-Host '請選擇').Trim()
    if ($r -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
    if ($r -eq '1') { $root = 'C:\scan' }
    elseif ($r -eq '2') { $root = 'D:\scan' }
    elseif ($r) { $root = $r }

    $u = (Read-Host '帳號（預設 scanner）').Trim()
    if ($u -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
    if ($u) {
        if ($u -eq 'anonymous' -or $u -eq 'ftp') { $anonymous = $true; $user = 'scanner' }
        else { $user = $u }
    }
    $anonAsk = (Read-Host '允許匿名登入 anonymous？(Y/N，預設 N)').Trim()
    if ($anonAsk -match '^(?i)y|yes|是$') { $anonymous = $true }

    $pIn = Read-Host '密碼（Enter=使用 scanner1234；輸入空白請打 - ）'
    if ($pIn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
    if ($pIn -eq '-') { $pass = '' }
    elseif (-not [string]::IsNullOrWhiteSpace($pIn)) { $pass = $pIn }

    if ($script:ArgPort -le 0) {
        if ($script:FlgFtpNonAdminFallback -and $port -eq 21) { $port = 2121 }
        $pPort = (Read-Host ("FTP 埠（預設 {0}；空白=用預設）" -f $port)).Trim()
        if ($pPort -eq 'q' -or $pPort -eq 'Q') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
        if ($pPort) {
            $pn = 0
            if (-not [int]::TryParse($pPort, [ref]$pn) -or $pn -lt 1 -or $pn -gt 65535) {
                Write-WarnMsg ("埠號無效，維持 {0}。" -f $port)
            } else { $port = $pn }
        }
    }
}

# Non-admin fallback: force 2121 for bindable port when still on privileged port
if ($IsWindowsOs -and -not (Test-IsAdmin) -and $port -lt 1024) {
    $port = 2121
    Write-WarnMsg '目前不是系統管理員，改用埠 2121（請在影印機填 2121）。'
}

if (-not (Test-Path -LiteralPath $root)) {
    try {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Write-Ok ("已建立資料夾：{0}" -f $root)
    } catch {
        Write-WarnMsg ("無法建立資料夾 {0}，請確認磁碟存在與權限。" -f $root)
        return
    }
}
$root = [IO.Path]::GetFullPath($root)

$ips = Get-LocalIPv4List
$advertiseIp = $ips[0]

$config = @{
    Root = $root
    User = $user
    Pass = $pass
    Anonymous = [bool]$anonymous
    Port = [int]$port
    PasvStart = [int]$pasvStart
    PasvEnd = [int]$pasvEnd
    AdvertiseIp = $advertiseIp
}

if ($script:InstallAutostartOnly) {
    Install-FlgFtpAutostart -Root $root -User $user -Pass $pass -Port $port -Anonymous $anonymous
    return
}

try {
    Add-FlgFtpFirewallRules -ControlPort $port -PasvStart $pasvStart -PasvEnd $pasvEnd
} catch {
    Write-WarnMsg '防火牆設定略過（權限不足或系統限制）。'
}

Write-Host ''
Write-Host '======== 請把下列資料填到影印機 ========' -ForegroundColor Yellow
Write-Host ("  伺服器／主機：{0}" -f ($ips -join '  或  ')) -ForegroundColor Green
Write-Host ("  埠（Port）：  {0}" -f $port) -ForegroundColor Green
Write-Host ("  帳號：        {0}" -f $(if ($anonymous) { "$user  或 anonymous" } else { $user })) -ForegroundColor Green
Write-Host ("  密碼：        {0}" -f $(if ($pass -eq '') { '（空白）' } else { $pass })) -ForegroundColor Green
Write-Host ("  路徑／資料夾：/  （實際存到 {0}）" -f $root) -ForegroundColor Green
Write-Host ("  被動埠範圍：  {0}-{1}（PASV）" -f $pasvStart, $pasvEnd) -ForegroundColor DarkGray
Write-Host ''
Write-Host '各品牌提示：' -ForegroundColor Cyan
Write-Host '  Ricoh／Sharp／Fuji／Canon／美樂達：通訊協定選 FTP，傳輸模式盡量用被動（PASV）。'
Write-Host '  路徑填 / 或空白；若要分子資料夾可在本工具啟動後用 MKD，或在影印機填 /資料夾名。'
Write-Host '  檔案名稱建議用 PDF／TIFF；二進位（Binary／Image）模式。'
Write-Host ''
Write-Host ('按 Enter 停止伺服器並' + (Get-FlgExitLabel) + '。') -ForegroundColor White
Write-Host ''

# For advertise IP used in PASV - prefer first non-loopback
$config.AdvertiseIp = $advertiseIp

try {
    Start-FlgFtpServer -Config $config
} catch {
    Write-WarnMsg 'FTP 伺服器無法啟動。'
    $msg = [string]$_.Exception.Message
    if ($msg -match '(?i)denied|permission|access|拒絕|權限') {
        Write-Host '  原因可能是權限不足（埠 21 請用系統管理員，或改埠 2121）。' -ForegroundColor Yellow
    } elseif ($msg -match '(?i)address already|in use|占用|綁定') {
        Write-Host '  原因可能是埠已被占用，請換一個埠（例如 2121）。' -ForegroundColor Yellow
    } else {
        Write-Host ('  ' + $msg) -ForegroundColor DarkGray
    }
    try { Remove-FlgFtpFirewallRules -Quiet } catch {}
    return
}
