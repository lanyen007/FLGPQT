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
# lanyen 工具箱 掃描到資料夾（GUI）
# 用法：irm https://lanyen007.github.io/FLGPQT/drivers/scan2folder.ps1 | iex
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

function Test-FlgOffline { return ($env:FLG_OFFLINE -eq '1') }
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
function Get-FlgOfflineEnvPreamble {
    $parts = @()
    if (Test-FlgOffline) { $parts += "`$env:FLG_OFFLINE='1'" }
    $root = Get-FlgRoot
    if ($root) {
        $esc = $root.Replace("'", "''")
        $parts += ("`$env:FLG_ROOT='" + $esc + "'")
    }
    if ($env:FLG_FROM_MENU -eq '1') { $parts += "`$env:FLG_FROM_MENU='1'" }
    if ($parts.Count -eq 0) { return '' }
    return (($parts -join '; ') + '; ')
}

function Invoke-FlgCounterHit([string]$Key) {
    # Legacy telemetry endpoint retired; keep this as a safe no-op to avoid 404 noise.
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (Test-FlgOffline) { return }
    return
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
        if ($IsWindowsOs) {
            try {
                $cim = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${letter}:' AND DriveType=3" -ErrorAction Stop
                if ($cim) { return $true }
            } catch {}
        }
        $di = New-Object IO.DriveInfo ($letter + ':')
        return ($di.IsReady -and $di.DriveType -eq [IO.DriveType]::Fixed)
    } catch { return $false }
}

function Get-DefaultScanFolder {
    if (Test-FlgFixedDrive 'D') { return 'D:\scan' }
    return 'C:\scan'
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

function Request-Elevation {
    Write-WarnMsg '需要系統管理員權限，即將跳出 UAC 提示…'
    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/scan2folder.ps1'
    $envPass = Get-FlgOfflineEnvPreamble
    if ($env:FLG_FROM_MENU -eq '1' -and $envPass -notmatch 'FLG_FROM_MENU') {
        $envPass += "`$env:FLG_FROM_MENU='1'; "
    }
    $envPass += "`$env:FLG_S2F_ELEVATING='1'; "
    $localMain = Resolve-FlgOfflinePath 'drivers\scan2folder-main.ps1'
    if ($localMain) {
        $esc = $localMain.Replace("'", "''")
        $inner = $envPass + "& '$esc'"
    } else {
        $inner = $envPass + "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$boot')))"
    }
    $argList = "-NoProfile -ExecutionPolicy Bypass -STA -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList | Out-Null
        Write-Info '已啟動提權視窗，請在新視窗完成設定。'
    } catch {
        Write-ErrMsg ("無法提權：" + $_.Exception.Message)
        Write-Host '請以「系統管理員」開啟 PowerShell 後再執行：' -ForegroundColor Yellow
        Write-Host '  irm https://lanyen007.github.io/FLGPQT/drivers/scan2folder.ps1 | iex' -ForegroundColor White
    }
}

function Enable-FlgFileSharingFirewall {
    param([scriptblock]$Log)
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    try {
        Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction Stop | Out-Null
        & $Log '已啟用防火牆「檔案及印表機共用」規則群組。'
        return $true
    } catch {
        try {
            Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction Stop | Out-Null
            & $Log '已啟用防火牆 File and Printer Sharing。'
            return $true
        } catch {
            try {
                Enable-NetFirewallRule -DisplayGroup '檔案及印表機共用' -ErrorAction Stop | Out-Null
                & $Log '已啟用防火牆「檔案及印表機共用」。'
                return $true
            } catch {
                & $Log ("啟用防火牆規則失敗：" + $_.Exception.Message)
                return $false
            }
        }
    }
}

function Set-FlgNetworkPrivateAuto {
    param([scriptblock]$Log)
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.NetworkCategory -eq 'Public' })
        if ($profiles.Count -eq 0) {
            & $Log '網路設定檔已是私人／網域，無需變更。'
            return
        }
        foreach ($p in $profiles) {
            try {
                Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                & $Log ("已將介面 {0} 設為私人。" -f $p.InterfaceAlias)
            } catch {
                & $Log ("變更網路類型失敗（{0}）：{1}" -f $p.InterfaceAlias, $_.Exception.Message)
            }
        }
    } catch {
        & $Log ("讀取網路設定檔失敗：" + $_.Exception.Message)
    }
}

function Ensure-SmbServerEnabled {
    param([scriptblock]$Log)
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    try {
        $svc = Get-Service -Name LanmanServer -ErrorAction Stop
        if ($svc.Status -ne 'Running') {
            Start-Service LanmanServer -ErrorAction Stop
            & $Log '已啟動 Server（LanmanServer）服務。'
        } else {
            & $Log 'LanmanServer 服務已在執行。'
        }
    } catch {
        & $Log ("啟動 LanmanServer 失敗：" + $_.Exception.Message)
    }
    try {
        Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force -ErrorAction Stop
        & $Log '已確認 SMB2 協定啟用。'
    } catch {
        & $Log ("設定 SMB2：（可能已啟用）" + $_.Exception.Message)
    }
    try {
        Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $true -Force -ErrorAction Stop
        & $Log '已設定 SMB 簽章為「不強制」（相容舊款影印機）。'
    } catch {
        & $Log ("設定 SMB 簽章失敗：" + $_.Exception.Message)
    }
}

function New-FlgScanShare {
    param(
        [string]$Folder,
        [string]$ShareName = 'scan',
        [string]$UserName = 'scanner',
        [string]$Password = 'scanner1234',
        [scriptblock]$Log
    )
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    if (-not (Test-Path -LiteralPath $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        & $Log ("已建立資料夾：{0}" -f $Folder)
    } else {
        & $Log ("資料夾已存在：{0}" -f $Folder)
    }

    $pc = $env:COMPUTERNAME
    $localUser = $UserName
    $secure = ConvertTo-SecureString $Password -AsPlainText -Force
    $existing = Get-LocalUser -Name $localUser -ErrorAction SilentlyContinue
    if ($existing) {
        & $Log ("本機使用者「{0}」已存在，將更新密碼。" -f $localUser)
        Set-LocalUser -Name $localUser -Password $secure -PasswordNeverExpires $true -ErrorAction Stop
    } else {
        New-LocalUser -Name $localUser -Password $secure -FullName 'lanyen 工具箱 Scan' -Description 'lanyen 工具箱 scan-to-folder' -PasswordNeverExpires -UserMayNotChangePassword:$false -ErrorAction Stop | Out-Null
        try { Remove-LocalGroupMember -Group 'Administrators' -Member $localUser -ErrorAction SilentlyContinue } catch {}
        & $Log ("已建立本機使用者：{0}" -f $localUser)
    }
    try { Set-LocalUser -Name $localUser -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
    try { Enable-LocalUser -Name $localUser -ErrorAction SilentlyContinue } catch {}
    try {
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
        if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
        New-ItemProperty -Path $k -Name $localUser -Value 0 -PropertyType DWord -Force | Out-Null
        & $Log ("已從登入畫面隱藏帳號：{0}" -f $localUser)
    } catch {
        & $Log ("隱藏登入帳號失敗（可略過）：" + $_.Exception.Message)
    }
    $accessAccount = "$pc\$localUser"

    try {
        $acl = Get-Acl -LiteralPath $Folder
        $inherit = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
        $prop = [Security.AccessControl.PropagationFlags]::None
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($accessAccount, 'Modify', $inherit, $prop, 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $Folder -AclObject $acl
        & $Log ("已設定 NTFS 權限（Modify）：{0}" -f $accessAccount)
    } catch {
        & $Log ("設定 NTFS 權限失敗：" + $_.Exception.Message)
    }

    $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if ($existingShare) {
        & $Log ("共用名稱「{0}」已存在，將移除後重建。" -f $ShareName)
        Remove-SmbShare -Name $ShareName -Force -ErrorAction Stop
    }
    New-SmbShare -Name $ShareName -Path $Folder -FullAccess $accessAccount -Description 'lanyen 工具箱 scan-to-folder' -ErrorAction Stop | Out-Null
    & $Log ("已建立 SMB 共用：\\{0}\{1} → {2}" -f $pc, $ShareName, $Folder)

    return [pscustomobject]@{
        Folder = $Folder
        ShareName = $ShareName
        AccessAccount = $accessAccount
        Password = $Password
        UserName = $UserName
        ComputerName = $pc
    }
}

function Remove-FlgScanShare {
    param([string]$ShareName = 'scan', [string]$UserName = 'scanner', [switch]$RemoveUser, [scriptblock]$Log)
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    $share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    $folder = $null
    if ($share) {
        $folder = [string]$share.Path
        Remove-SmbShare -Name $ShareName -Force -ErrorAction Stop
        & $Log ("已移除共用：{0}" -f $ShareName)
    } else {
        & $Log ("找不到共用：{0}" -f $ShareName)
    }
    if ($RemoveUser -and $UserName) {
        $u = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
        if ($u) {
            Remove-LocalUser -Name $UserName -ErrorAction Stop
            & $Log ("已刪除本機使用者：{0}" -f $UserName)
            try {
                $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
                if (Test-Path $k) { Remove-ItemProperty -Path $k -Name $UserName -Force -ErrorAction SilentlyContinue }
            } catch {}
        } else {
            & $Log ("找不到使用者：{0}" -f $UserName)
        }
    }
    if ($folder) { & $Log ("資料夾仍保留（未刪檔）：{0}" -f $folder) }
}

function Start-FlgFtpBackground {
    param(
        [string]$Folder,
        [string]$UserName = 'scanner',
        [string]$Password = 'scanner1234',
        [int]$Port = 21,
        [scriptblock]$Log
    )
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/ftp.ps1'
    $localBoot = Resolve-FlgOfflinePath 'drivers\ftp.ps1'
    $folderEsc = $Folder.Replace("'", "''")
    $userEsc = $UserName.Replace("'", "''")
    $passEsc = $Password.Replace("'", "''")
    $envBits = "`$env:FLG_FTP_AUTO='1'; `$env:FLG_FTP_ROOT='$folderEsc'; `$env:FLG_FTP_USER='$userEsc'; `$env:FLG_FTP_PASS='$passEsc'; `$env:FLG_FTP_PORT='$Port'; "
    $envBits += (Get-FlgOfflineEnvPreamble)
    if ($localBoot) {
        $esc = $localBoot.Replace("'", "''")
        $inner = $envBits + "& ([scriptblock]::Create([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes('$esc')).TrimStart([char]0xFEFF)))"
    } else {
        $inner = $envBits + "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$boot')))"
    }
    $argList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList | Out-Null
        & $Log ("已在背景啟動 FTP 伺服器（埠 {0}，資料夾 {1}）。" -f $Port, $Folder)
        return $true
    } catch {
        & $Log ("啟動 FTP 失敗：" + $_.Exception.Message)
        return $false
    }
}

function Install-FlgFtpAutostartFromGui {
    param(
        [string]$Folder,
        [string]$UserName = 'scanner',
        [string]$Password = 'scanner1234',
        [int]$Port = 21,
        [scriptblock]$Log
    )
    if (-not $Log) { $Log = { param($m) Write-Host $m } }
    $base = $env:APPDATA
    if ([string]::IsNullOrWhiteSpace($base)) { $base = Join-Path $env:USERPROFILE 'AppData\Roaming' }
    $dir = Join-Path $base 'lanyen-ftp'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $cfgPath = Join-Path $dir 'config.json'
    $obj = [ordered]@{
        root = $Folder
        user = $UserName
        pass = $Password
        port = $Port
        anonymous = $false
        pasvStart = 50000
        pasvEnd = 50010
        updated = (Get-Date).ToString('o')
    }
    ($obj | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $cfgPath -Encoding UTF8
    & $Log ("FTP 設定已儲存：{0}" -f $cfgPath)

    $boot = 'https://lanyen007.github.io/FLGPQT/drivers/ftp.ps1'
    $cfgEsc = $cfgPath.Replace("'", "''")
    $inner = "`$ErrorActionPreference='Stop'; `$j = Get-Content -LiteralPath '$cfgEsc' -Raw -Encoding UTF8 | ConvertFrom-Json; `$env:FLG_FTP_AUTO='1'; `$env:FLG_FTP_PORT=[string]`$j.port; `$env:FLG_FTP_ROOT=[string]`$j.root; `$env:FLG_FTP_USER=[string]`$j.user; `$env:FLG_FTP_PASS=[string]`$j.pass; & ([scriptblock]::Create((Invoke-RestMethod -Uri '$boot')))"
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -Command `"$inner`""
    try {
        Unregister-ScheduledTask -TaskName 'FLG-SimpleFTP' -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName 'FLG-SimpleFTP' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        & $Log '已登錄 FTP 登入自動啟動工作（FLG-SimpleFTP）。'
    } catch {
        & $Log ("登錄 FTP 自動啟動失敗：" + $_.Exception.Message)
    }
}

function Test-LocalPortListening([int]$Port) {
    try {
        $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
        return (@($conns).Count -gt 0)
    } catch {
        try {
            $lines = netstat -an 2>$null | Select-String (":$Port\s+")
            foreach ($l in @($lines)) {
                if ($l.Line -match 'LISTENING|LISTEN') { return $true }
            }
        } catch {}
        return $false
    }
}

function Get-BrandHintText {
    param(
        [ValidateSet('Ricoh','Sharp','FUJIFILM')]
        [string]$Brand,
        [string]$Ip,
        [string]$ShareName = 'scan',
        [string]$UserName = 'scanner',
        [string]$Password = 'scanner1234',
        [string]$ComputerName,
        [int]$FtpPort = 21
    )
    if (-not $ComputerName) { $ComputerName = $env:COMPUTERNAME }
    if (-not $ComputerName) { $ComputerName = 'PCNAME' }
    if (-not $Ip) {
        $ips = Get-LocalIPv4List
        $Ip = $ips[0]
    }
    $smbPath = "\\$Ip\$ShareName"
    $userSimple = $UserName
    $userQualified = "$ComputerName\$UserName"
    $sb = New-Object Text.StringBuilder
    switch ($Brand) {
        'Ricoh' {
            [void]$sb.AppendLine('【Ricoh】操作路徑：操作面板 → 通訊錄 → 登錄 → 資料夾')
            [void]$sb.AppendLine('協定選擇：SMB')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('—— SMB 欄位 ——')
            [void]$sb.AppendLine("路徑：          $smbPath")
            [void]$sb.AppendLine('（有的機型拆成「伺服器」與「路徑」：伺服器填 IP，路徑填 /scan 或 \scan）')
            [void]$sb.AppendLine("使用者名稱：    $userSimple")
            [void]$sb.AppendLine("（連不上可改填） $userQualified")
            [void]$sb.AppendLine("密碼：          $Password")
            [void]$sb.AppendLine('網域／登入：    可留空，或填電腦名稱')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('—— 若改用 FTP ——')
            [void]$sb.AppendLine("通訊協定：FTP　　伺服器：$Ip　　埠：$FtpPort")
            [void]$sb.AppendLine("使用者：$userSimple　　密碼：$Password　　路徑：/ 或空白")
            [void]$sb.AppendLine('傳輸模式：被動（PASV）；檔案格式建議 PDF')
        }
        'Sharp' {
            [void]$sb.AppendLine('【Sharp】操作路徑：網頁設定（瀏覽器開影印機 IP）→ 通訊錄 → 網路資料夾')
            [void]$sb.AppendLine('（面板名稱可能是 Address Book / Network Folder）')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('—— SMB／網路資料夾 ——')
            [void]$sb.AppendLine("主機名稱（Host）：$Ip")
            [void]$sb.AppendLine("資料夾（Directory）：$ShareName   或  \$ShareName")
            [void]$sb.AppendLine("完整路徑參考：    $smbPath")
            [void]$sb.AppendLine("使用者名稱：      $userSimple")
            [void]$sb.AppendLine("（連不上可改填） $userQualified")
            [void]$sb.AppendLine("密碼：            $Password")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('—— FTP ——')
            [void]$sb.AppendLine("通訊協定：FTP　　主機：$Ip　　埠：$FtpPort")
            [void]$sb.AppendLine("使用者：$userSimple　　密碼：$Password　　目錄：/ 或空白")
            [void]$sb.AppendLine('模式：被動模式（Passive）')
        }
        'FUJIFILM' {
            [void]$sb.AppendLine('【FUJIFILM／全錄】操作路徑：網頁 CentreWare Internet Services')
            [void]$sb.AppendLine('→ 通訊錄／位址簿 → 新增 → 伺服器（SMB 或 FTP）')
            [void]$sb.AppendLine('（不同機型選單名稱可能略有差異，請找「SMB」「FTP」「伺服器」）')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('—— SMB ——')
            [void]$sb.AppendLine("伺服器名稱／IP：$Ip")
            [void]$sb.AppendLine("共用名稱：      $ShareName")
            [void]$sb.AppendLine("完整路徑參考：  $smbPath")
            [void]$sb.AppendLine("登入名稱：      $userQualified   （建議用 電腦名\帳號）")
            [void]$sb.AppendLine("（也可試）      $userSimple")
            [void]$sb.AppendLine("密碼：          $Password")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('—— FTP ——')
            [void]$sb.AppendLine("伺服器：$Ip　　埠：$FtpPort　　登入：$userSimple　　密碼：$Password")
            [void]$sb.AppendLine('文件路徑：/ 或空白；傳輸：被動模式')
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('※ 請確認影印機與這台電腦同一網段；若連線失敗，到「狀態檢查」看埠與防火牆。')
    return $sb.ToString()
}

function Get-StatusReportText {
    $ips = Get-LocalIPv4List
    $pc = $env:COMPUTERNAME
    if (-not $pc) { $pc = [Net.Dns]::GetHostName() }
    $share = $null
    try { $share = Get-SmbShare -Name 'scan' -ErrorAction SilentlyContinue } catch {}
    $folder = Get-DefaultScanFolder
    if ($share -and $share.Path) { $folder = [string]$share.Path }
    $smbListen = Test-LocalPortListening 445
    $ftpListen = Test-LocalPortListening 21
    $fwOk = $false
    try {
        $rules = Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction SilentlyContinue |
            Where-Object { $_.Enabled -eq 'True' -or $_.Enabled -eq $true }
        if (@($rules).Count -gt 0) { $fwOk = $true }
    } catch {
        try {
            $rules = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue |
                Where-Object { $_.Enabled -eq 'True' -or $_.Enabled -eq $true }
            if (@($rules).Count -gt 0) { $fwOk = $true }
        } catch {}
    }
    $userExists = $false
    try { $userExists = [bool](Get-LocalUser -Name 'scanner' -ErrorAction SilentlyContinue) } catch {}
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine("電腦名稱：$pc")
    [void]$sb.AppendLine("本機 IPv4：")
    foreach ($ip in $ips) { [void]$sb.AppendLine("  · $ip") }
    [void]$sb.AppendLine('')
    $folderExists = Test-Path -LiteralPath $folder
    [void]$sb.AppendLine("掃描資料夾：$folder  $(if ($folderExists) { '（存在）' } else { '（尚不存在）' })")
    [void]$sb.AppendLine("SMB 共用 scan：$(if ($share) { '已建立 → ' + $share.Path } else { '尚未建立' })")
    [void]$sb.AppendLine("本機帳號 scanner：$(if ($userExists) { '存在' } else { '不存在' })")
    [void]$sb.AppendLine("TCP 445（SMB）監聽中：$(if ($smbListen) { '是' } else { '否' })")
    [void]$sb.AppendLine("TCP 21（FTP）監聽中：$(if ($ftpListen) { '是' } else { '否' })")
    [void]$sb.AppendLine("防火牆檔案共用規則：$(if ($fwOk) { '已啟用（至少部分）' } else { '未偵測到／未知' })")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('影印機 SMB 路徑範例：')
    foreach ($ip in $ips) { [void]$sb.AppendLine("  \\$ip\scan") }
    return [pscustomobject]@{
        Text = $sb.ToString()
        Folder = $folder
        Ips = $ips
    }
}

function Show-Scan2FolderGui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:S2fUser = 'scanner'
    $script:S2fPass = 'scanner1234'
    $script:S2fShare = 'scan'
    $script:S2fFolder = Get-DefaultScanFolder
    $script:S2fWatcher = $null
    $script:S2fLastBalloon = Get-Date '2000-01-01'

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'lanyen 工具箱 — 掃描到資料夾'
    $form.Size = New-Object System.Drawing.Size(720, 560)
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 10)
    $form.MinimumSize = New-Object System.Drawing.Size(640, 480)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabSetup = New-Object System.Windows.Forms.TabPage
    $tabSetup.Text = '一鍵設定'
    $tabBrand = New-Object System.Windows.Forms.TabPage
    $tabBrand.Text = '廠牌設定值'
    $tabStatus = New-Object System.Windows.Forms.TabPage
    $tabStatus.Text = '狀態檢查'
    $tabNotify = New-Object System.Windows.Forms.TabPage
    $tabNotify.Text = '新檔案通知'
    [void]$tabs.TabPages.Add($tabSetup)
    [void]$tabs.TabPages.Add($tabBrand)
    [void]$tabs.TabPages.Add($tabStatus)
    [void]$tabs.TabPages.Add($tabNotify)
    $form.Controls.Add($tabs)

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Text = 'lanyen 掃描到資料夾'
    $notify.Visible = $true
    try { $notify.Icon = [System.Drawing.SystemIcons]::Information } catch {}

    $lblFolder = New-Object System.Windows.Forms.Label
    $lblFolder.Text = '掃描資料夾：'
    $lblFolder.Location = New-Object System.Drawing.Point(16, 18)
    $lblFolder.AutoSize = $true
    $txtFolder = New-Object System.Windows.Forms.TextBox
    $txtFolder.Text = $script:S2fFolder
    $txtFolder.Location = New-Object System.Drawing.Point(110, 14)
    $txtFolder.Width = 420
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = '瀏覽…'
    $btnBrowse.Location = New-Object System.Drawing.Point(540, 12)
    $btnBrowse.Width = 90
    $btnBrowse.Add_Click({
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = '選擇掃描檔存放資料夾'
        if (Test-Path -LiteralPath $txtFolder.Text) { $d.SelectedPath = $txtFolder.Text }
        if ($d.ShowDialog() -eq 'OK') { $txtFolder.Text = $d.SelectedPath }
    })

    $chkFtp = New-Object System.Windows.Forms.CheckBox
    $chkFtp.Text = '同時啟用簡易 FTP 伺服器（埠 21，帳號同上）並設登入自動啟動'
    $chkFtp.Location = New-Object System.Drawing.Point(16, 50)
    $chkFtp.AutoSize = $true

    $lblCred = New-Object System.Windows.Forms.Label
    $lblCred.Text = ("帳號：{0}　　密碼：{1}　　共用名稱：{2}" -f $script:S2fUser, $script:S2fPass, $script:S2fShare)
    $lblCred.Location = New-Object System.Drawing.Point(16, 80)
    $lblCred.AutoSize = $true
    $lblCred.ForeColor = [System.Drawing.Color]::DarkSlateGray

    $btnSetup = New-Object System.Windows.Forms.Button
    $btnSetup.Text = '一鍵建立 SMB 共用'
    $btnSetup.Location = New-Object System.Drawing.Point(16, 110)
    $btnSetup.Width = 180
    $btnSetup.Height = 32

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = '移除共用…'
    $btnRemove.Location = New-Object System.Drawing.Point(210, 110)
    $btnRemove.Width = 120
    $btnRemove.Height = 32

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = 'Vertical'
    $logBox.ReadOnly = $true
    $logBox.Location = New-Object System.Drawing.Point(16, 155)
    $logBox.Size = New-Object System.Drawing.Size(660, 300)
    $logBox.Anchor = 'Top,Bottom,Left,Right'
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 9)

    $tabSetup.Controls.AddRange(@($lblFolder, $txtFolder, $btnBrowse, $chkFtp, $lblCred, $btnSetup, $btnRemove, $logBox))

    function Append-Log([string]$m) {
        $line = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m)
        if ($logBox.Text.Length -eq 0) { $logBox.Text = $line }
        else { $logBox.AppendText("`r`n" + $line) }
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $btnSetup.Add_Click({
        try {
            $script:S2fFolder = $txtFolder.Text.Trim()
            if (-not $script:S2fFolder) { [System.Windows.Forms.MessageBox]::Show('請指定資料夾。', 'lanyen'); return }
            $log = { param($m) Append-Log $m }
            Append-Log '開始一鍵設定…'
            Ensure-SmbServerEnabled -Log $log
            Enable-FlgFileSharingFirewall -Log $log | Out-Null
            Set-FlgNetworkPrivateAuto -Log $log
            $result = New-FlgScanShare -Folder $script:S2fFolder -ShareName $script:S2fShare -UserName $script:S2fUser -Password $script:S2fPass -Log $log
            $script:S2fFolder = $result.Folder
            $txtFolder.Text = $result.Folder
            $txtWatch.Text = $result.Folder
            if ($chkFtp.Checked) {
                Append-Log '正在設定 FTP…'
                Install-FlgFtpAutostartFromGui -Folder $result.Folder -UserName $script:S2fUser -Password $script:S2fPass -Port 21 -Log $log
                Start-FlgFtpBackground -Folder $result.Folder -UserName $script:S2fUser -Password $script:S2fPass -Port 21 -Log $log | Out-Null
            }
            $ips = Get-LocalIPv4List
            Append-Log '======== 請把下列資料填到影印機 ========'
            foreach ($ip in $ips) { Append-Log ("路徑：\\{0}\{1}" -f $ip, $result.ShareName) }
            Append-Log ("使用者：{0}  或  {1}" -f $script:S2fUser, $result.AccessAccount)
            Append-Log ("密碼：{0}" -f $script:S2fPass)
            Append-Log '完成。可到「廠牌設定值」複製各品牌欄位。'
            try { Start-S2fWatcher $result.Folder } catch {}
            [System.Windows.Forms.MessageBox]::Show(("設定完成。`n路徑範例：\\{0}\scan" -f $ips[0]), 'lanyen 工具箱')
        } catch {
            Append-Log ('失敗：' + $_.Exception.Message)
            [System.Windows.Forms.MessageBox]::Show(('設定失敗：' + $_.Exception.Message), 'lanyen 工具箱')
        }
    })

    $btnRemove.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            "要移除 SMB 共用「scan」嗎？`n資料夾內的檔案會保留。`n`n按「是」= 移除共用並刪除使用者 scanner`n按「否」= 只移除共用、保留使用者`n按「取消」= 不做任何事",
            '移除掃描共用',
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($r -eq 'Cancel') { return }
        $removeUser = ($r -eq 'Yes')
        try {
            $log = { param($m) Append-Log $m }
            Remove-FlgScanShare -ShareName 'scan' -UserName 'scanner' -RemoveUser:$removeUser -Log $log
            [System.Windows.Forms.MessageBox]::Show('已處理移除。', 'lanyen 工具箱')
        } catch {
            Append-Log ('移除失敗：' + $_.Exception.Message)
        }
    })

    $lblBrand = New-Object System.Windows.Forms.Label
    $lblBrand.Text = '廠牌：'
    $lblBrand.Location = New-Object System.Drawing.Point(16, 16)
    $lblBrand.AutoSize = $true
    $cmbBrand = New-Object System.Windows.Forms.ComboBox
    $cmbBrand.DropDownStyle = 'DropDownList'
    $cmbBrand.Location = New-Object System.Drawing.Point(70, 12)
    $cmbBrand.Width = 180
    [void]$cmbBrand.Items.Add('Ricoh')
    [void]$cmbBrand.Items.Add('Sharp')
    [void]$cmbBrand.Items.Add('FUJIFILM')
    $cmbBrand.SelectedIndex = 0

    $lblIp = New-Object System.Windows.Forms.Label
    $lblIp.Text = '本機 IP：'
    $lblIp.Location = New-Object System.Drawing.Point(270, 16)
    $lblIp.AutoSize = $true
    $cmbIp = New-Object System.Windows.Forms.ComboBox
    $cmbIp.DropDownStyle = 'DropDownList'
    $cmbIp.Location = New-Object System.Drawing.Point(340, 12)
    $cmbIp.Width = 200
    foreach ($ip in (Get-LocalIPv4List)) { [void]$cmbIp.Items.Add($ip) }
    if ($cmbIp.Items.Count -gt 0) { $cmbIp.SelectedIndex = 0 }

    $txtBrand = New-Object System.Windows.Forms.TextBox
    $txtBrand.Multiline = $true
    $txtBrand.ScrollBars = 'Vertical'
    $txtBrand.ReadOnly = $true
    $txtBrand.Location = New-Object System.Drawing.Point(16, 50)
    $txtBrand.Size = New-Object System.Drawing.Size(660, 360)
    $txtBrand.Anchor = 'Top,Bottom,Left,Right'
    $txtBrand.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 10)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = '複製全部'
    $btnCopy.Location = New-Object System.Drawing.Point(560, 10)
    $btnCopy.Width = 100

    function Refresh-BrandText {
        $brand = [string]$cmbBrand.SelectedItem
        $ip = [string]$cmbIp.SelectedItem
        if (-not $ip) { $ip = (Get-LocalIPv4List)[0] }
        $txtBrand.Text = Get-BrandHintText -Brand $brand -Ip $ip -ShareName $script:S2fShare -UserName $script:S2fUser -Password $script:S2fPass -ComputerName $env:COMPUTERNAME
    }
    $cmbBrand.Add_SelectedIndexChanged({ Refresh-BrandText })
    $cmbIp.Add_SelectedIndexChanged({ Refresh-BrandText })
    $btnCopy.Add_Click({
        try {
            [System.Windows.Forms.Clipboard]::SetText($txtBrand.Text)
            [System.Windows.Forms.MessageBox]::Show('已複製到剪貼簿。', 'lanyen 工具箱')
        } catch {
            [System.Windows.Forms.MessageBox]::Show('複製失敗。', 'lanyen 工具箱')
        }
    })
    Refresh-BrandText
    $tabBrand.Controls.AddRange(@($lblBrand, $cmbBrand, $lblIp, $cmbIp, $txtBrand, $btnCopy))

    $txtStatus = New-Object System.Windows.Forms.TextBox
    $txtStatus.Multiline = $true
    $txtStatus.ScrollBars = 'Vertical'
    $txtStatus.ReadOnly = $true
    $txtStatus.Location = New-Object System.Drawing.Point(16, 50)
    $txtStatus.Size = New-Object System.Drawing.Size(660, 360)
    $txtStatus.Anchor = 'Top,Bottom,Left,Right'
    $txtStatus.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 10)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = '重新檢查'
    $btnRefresh.Location = New-Object System.Drawing.Point(16, 12)
    $btnRefresh.Width = 120

    $btnOpenFolder = New-Object System.Windows.Forms.Button
    $btnOpenFolder.Text = '開啟掃描資料夾'
    $btnOpenFolder.Location = New-Object System.Drawing.Point(150, 12)
    $btnOpenFolder.Width = 140

    $script:LastStatusFolder = $script:S2fFolder
    function Refresh-Status {
        $r = Get-StatusReportText
        $txtStatus.Text = $r.Text
        $script:LastStatusFolder = $r.Folder
    }
    $btnRefresh.Add_Click({ Refresh-Status })
    $btnOpenFolder.Add_Click({
        $f = $script:LastStatusFolder
        if (-not (Test-Path -LiteralPath $f)) {
            try { New-Item -ItemType Directory -Path $f -Force | Out-Null } catch {}
        }
        if (Test-Path -LiteralPath $f) { Start-Process explorer.exe $f }
        else { [System.Windows.Forms.MessageBox]::Show("找不到資料夾：$f", 'lanyen') }
    })
    Refresh-Status
    $tabStatus.Controls.AddRange(@($btnRefresh, $btnOpenFolder, $txtStatus))

    $lblN = New-Object System.Windows.Forms.Label
    $lblN.Text = "監看資料夾（有新掃描檔會在右下角跳出通知）：`r`n預設與一鍵設定的資料夾相同。"
    $lblN.Location = New-Object System.Drawing.Point(16, 16)
    $lblN.AutoSize = $true

    $txtWatch = New-Object System.Windows.Forms.TextBox
    $txtWatch.Text = $script:S2fFolder
    $txtWatch.Location = New-Object System.Drawing.Point(16, 70)
    $txtWatch.Width = 500

    $chkWatch = New-Object System.Windows.Forms.CheckBox
    $chkWatch.Text = '啟用新檔案通知'
    $chkWatch.Location = New-Object System.Drawing.Point(16, 110)
    $chkWatch.AutoSize = $true
    $chkWatch.Checked = $true

    $lblWatchState = New-Object System.Windows.Forms.Label
    $lblWatchState.Text = '狀態：尚未開始'
    $lblWatchState.Location = New-Object System.Drawing.Point(16, 150)
    $lblWatchState.AutoSize = $true

    function Stop-S2fWatcher {
        if ($script:S2fWatcher) {
            try { $script:S2fWatcher.EnableRaisingEvents = $false } catch {}
            try { $script:S2fWatcher.Dispose() } catch {}
            $script:S2fWatcher = $null
        }
    }
    function Start-S2fWatcher([string]$path) {
        Stop-S2fWatcher
        if (-not $chkWatch.Checked) {
            $lblWatchState.Text = '狀態：已關閉'
            return
        }
        if (-not (Test-Path -LiteralPath $path)) {
            try { New-Item -ItemType Directory -Path $path -Force | Out-Null } catch {}
        }
        if (-not (Test-Path -LiteralPath $path)) {
            $lblWatchState.Text = "狀態：資料夾不存在（$path）"
            return
        }
        $w = New-Object System.IO.FileSystemWatcher
        $w.Path = $path
        $w.IncludeSubdirectories = $true
        $w.NotifyFilter = [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::CreationTime
        $w.Filter = '*.*'
        $handler = {
            try {
                $now = Get-Date
                if (($now - $script:S2fLastBalloon).TotalSeconds -lt 2) { return }
                $script:S2fLastBalloon = $now
                $name = $Event.SourceEventArgs.Name
                $notify.BalloonTipTitle = '收到掃描檔'
                $notify.BalloonTipText = $name
                $notify.ShowBalloonTip(4000)
            } catch {}
        }
        Register-ObjectEvent -InputObject $w -EventName Created -Action $handler | Out-Null
        Register-ObjectEvent -InputObject $w -EventName Renamed -Action $handler | Out-Null
        $w.EnableRaisingEvents = $true
        $script:S2fWatcher = $w
        $txtWatch.Text = $path
        $lblWatchState.Text = "狀態：監看中 → $path"
    }

    $btnWatchApply = New-Object System.Windows.Forms.Button
    $btnWatchApply.Text = '套用監看'
    $btnWatchApply.Location = New-Object System.Drawing.Point(530, 68)
    $btnWatchApply.Width = 100
    $btnWatchApply.Add_Click({
        $script:S2fFolder = $txtWatch.Text.Trim()
        if ($chkWatch.Checked) { Start-S2fWatcher $script:S2fFolder }
        else { Stop-S2fWatcher; $lblWatchState.Text = '狀態：已關閉' }
    })
    $chkWatch.Add_CheckedChanged({
        if ($chkWatch.Checked) { Start-S2fWatcher $txtWatch.Text.Trim() }
        else { Stop-S2fWatcher; $lblWatchState.Text = '狀態：已關閉' }
    })

    $tabNotify.Controls.AddRange(@($lblN, $txtWatch, $chkWatch, $lblWatchState, $btnWatchApply))

    $form.Add_Shown({
        try { Start-S2fWatcher $script:S2fFolder } catch {}
    })
    $form.Add_FormClosed({
        Stop-S2fWatcher
        try { $notify.Visible = $false; $notify.Dispose() } catch {}
        Get-EventSubscriber -ErrorAction SilentlyContinue | Where-Object { $_.SourceObject -is [IO.FileSystemWatcher] } | ForEach-Object {
            Unregister-Event -SourceIdentifier $_.SourceIdentifier -Force -ErrorAction SilentlyContinue
        }
    })

    [void]$form.ShowDialog()
}

# ---- main ----
Invoke-FlgCounterHit 'scan2folder'

Write-Host ''
Write-Host ('======== ' + (Get-FlgT 'lanyen 工具箱 掃描到資料夾' 'lanyen Toolkit Scan to folder') + ' ========') -ForegroundColor White
Write-Host 'Ricoh／Sharp／FUJIFILM 掃描到 SMB／FTP 一鍵設定（視窗介面）' -ForegroundColor Gray
Write-Host ''

if (-not $IsWindowsOs) {
    Write-ErrMsg '此工具需要 Windows 與 System.Windows.Forms（目前環境無法開啟視窗）。'
    Write-Host '功能預覽：一鍵建立 scanner/scanner1234、D:\scan 或 C:\scan、SMB 共用、可選 FTP、廠牌填寫提示、埠檢查、新檔通知。' -ForegroundColor DarkGray
    try {
        $t = Get-BrandHintText -Brand 'Ricoh' -Ip '192.168.1.10'
        if ($t -match 'SMB' -and $t -match 'scanner') { Write-Ok '品牌提示文字產生正常（Ricoh）。' }
        $null = Get-BrandHintText -Brand 'Sharp' -Ip '192.168.1.10'
        $null = Get-BrandHintText -Brand 'FUJIFILM' -Ip '192.168.1.10'
        Write-Ok '品牌提示文字產生正常（Sharp／FUJIFILM）。'
        Write-Ok ("預設資料夾邏輯：{0}" -f (Get-DefaultScanFolder))
        Write-Ok ("IPv4 列表：{0}" -f ((Get-LocalIPv4List) -join ', '))
        $st = Get-StatusReportText
        if ($st.Text -match 'IPv4') { Write-Ok '狀態報告文字產生正常。' }
    } catch {
        Write-ErrMsg ('自我檢查失敗：' + $_.Exception.Message)
    }
    return
}

if (-not (Test-IsAdmin)) {
    if ($env:FLG_S2F_ELEVATING -eq '1') {
        Write-ErrMsg '提權後仍不是系統管理員，請以系統管理員開啟後再試。'
        return
    }
    Request-Elevation
    return
}

try {
    Show-Scan2FolderGui
} catch {
    Write-ErrMsg ('無法開啟視窗介面：' + $_.Exception.Message)
    if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
}
