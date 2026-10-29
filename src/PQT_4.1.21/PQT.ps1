<#
.SYNOPSIS
    PQT007 — 查詢上傳、內建排程、列印小工具（單一主程式）
#>
[CmdletBinding()]
param(
    [ValidateSet('', 'ReleaseSpooler', 'RestartSpooler', 'CancelAllJobs', 'Install')]
    [string]$Action = '',
    [switch]$Tray
)

$ErrorActionPreference = 'Stop'
$script:AppVersion = "4.1.21"
$script:InstallDir = "C:\FLGPQT"
$script:DefaultUpdateUrl = "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/version.json"
$script:DefaultDownloadUrl = "https://github.com/lanyen007/FLGPQT/raw/main/PQT.exe"
$script:GitHubCommitsApi = "https://api.github.com/repos/lanyen007/FLGPQT/commits/main"

$procFile = $null
try { $procFile = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch {}
$isCompiled = $procFile -and ($procFile -like '*.exe') -and ($procFile -notmatch '(?i)(powershell|pwsh)\.exe$')
if ($isCompiled) {
    $scriptFile = $procFile
} else {
    $scriptFile = $MyInvocation.MyCommand.Path
    if (-not $scriptFile) { $scriptFile = $PSCommandPath }
    if (-not $scriptFile) { $scriptFile = $procFile }
}

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA' -and [string]::IsNullOrWhiteSpace($Action)) {
    if ($isCompiled -and $procFile) {
        if ($env:PQT_SKIP_STA_RELAUNCH -ne '1') {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $procFile
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = Split-Path -Parent $procFile
            if ($Tray) { $psi.Arguments = "-Tray" }
            $psi.EnvironmentVariables['PQT_SKIP_STA_RELAUNCH'] = '1'
            [void][Diagnostics.Process]::Start($psi)
            return
        }
    } else {
        $self = $scriptFile
        if ($self) {
            $staArgs = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self)
            if ($Tray) { $staArgs += '-Tray' }
            Start-Process -FilePath "powershell.exe" -ArgumentList $staArgs
        }
        return
    }
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {}

try { [Windows.Forms.Application]::EnableVisualStyles() } catch {}
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$scriptDir = Split-Path -Parent $scriptFile
$script:StartInTray = [bool]$Tray

function Get-PqtWritableDir {
    param([string]$Preferred)
    $candidates = @($Preferred, (Join-Path $env:LOCALAPPDATA "PQT4"))
    foreach ($dir in $candidates) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        try {
            if (-not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            $probe = Join-Path $dir ("pqt_write_" + [guid]::NewGuid().ToString("N") + ".tmp")
            [IO.File]::WriteAllText($probe, "ok")
            Remove-Item -LiteralPath $probe -Force
            return $dir
        } catch {}
    }
    return $Preferred
}

$dataDir = Get-PqtWritableDir $scriptDir
$script:DataDir = $dataDir
$script:LogPath = Join-Path $dataDir "PQT.log"
$script:SettingsPath = Join-Path $dataDir "pqt_settings.json"
$script:PrintJsonPath = Join-Path $dataDir "print.JSON"
$script:RicohSettingsPath = Join-Path $dataDir "ricoh_settings.json"
$script:StatePath = Join-Path $dataDir "pqt_schedule_state.json"
$spoolFolder = Join-Path $env:SystemRoot "System32\spool\PRINTERS"

$script:MutexName = "PQT_Version4_SingleInstance"
$script:ShowEventName = "PQT_Version4_Show"
$script:ShowSettingsEventName = "PQT_Version4_ShowSettings"

$script:GoogleUrls = [ordered]@{
    "中壢區" = "https://script.google.com/macros/s/AKfycbyEtKfvlP3P-73tNOaFiQaBsl9Cqwa1U7PURcUYPOxp4VcsYE3gztkpQSpbxESfVIX-YA/exec"
    "桃園區" = "https://script.google.com/macros/s/AKfycby1VwDQAHqqgcNGAwFFM-AP3z80jbNe0wKPFpXeFVvmivYHbvJckB_imCxJgsOuyFzsLw/exec"
    "楊梅區" = "https://script.google.com/macros/s/AKfycbxDlNRjoJ_k3iEFD8l4asJfHeScDwweAzlxMcZKulIWGm_pKcUhB2oePVj5hUp4Q8gKww/exec"
}

$script:Columns = @(
    "設備 IP", "Model Name", "Serial Number", "設備位置",
    "黑白合計", "彩色合計",
    "黑色碳粉", "青色碳粉", "洋紅碳粉", "黃色碳粉",
    "Error Status"
)
$script:DisplayColumns = @("設備 IP", "設備位置", "黑白合計", "彩色合計", "查詢時間")

$script:UiLogBox = $null
$script:StatusLabel = $null
$script:PrinterList = $null
$script:NetIpBox = $null
$script:NetCommunityBox = $null
$script:NetResultBox = $null
$script:LocalIpLabel = $null
$script:MainForm = $null
$script:TabControl = $null
$script:NotifyIcon = $null
$script:PqtAppIcon = $null
$script:ResultView = $null
$script:QueryStatusLabel = $null
$script:BtnQueryNow = $null
$script:BtnQueryUpload = $null
$script:Mutex = $null
$script:ShowEvent = $null
$script:ShowSettingsEvent = $null
$script:ReallyExit = $false
$script:HasShownBalloon = $false
$script:QueryBusy = $false
$script:QueryPs = $null
$script:QueryHandle = $null
$script:QueryInteractive = $false
$script:LastFiredPeriod = $null
$script:PendingPeriodKey = $null
$script:NextRunTime = $null
$script:CurrentSettings = $null
$script:SyncingUrl = $false
$script:SyncingStartup = $false
$script:ChkStartup = $null
$script:LineQrImage = $null
$script:UpdateUrlBox = $null
$script:UpdateResultLabel = $null
$script:BtnOpenDownload = $null
$script:LatestDownloadUrl = $null
$script:MonthChecks = @{}
$script:ThemeCombo = $null
$script:ThemeRoles = @{}
$script:RbAutoUpdate = $null
$script:RbNoAutoUpdate = $null
$script:SyncingAutoUpdate = $false

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal $id
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PqtAtInstallDir {
    if ([string]::IsNullOrWhiteSpace($scriptDir) -or [string]::IsNullOrWhiteSpace($script:InstallDir)) { return $false }
    try {
        $here = [IO.Path]::GetFullPath($scriptDir).TrimEnd('\')
        $inst = [IO.Path]::GetFullPath($script:InstallDir).TrimEnd('\')
        return ($here -ieq $inst)
    } catch {
        return $false
    }
}

function Set-PqtInstallDirAcl {
    param([string]$Dir)
    try {
        $acl = Get-Acl -LiteralPath $Dir
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            "Users", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl -LiteralPath $Dir -AclObject $acl
    } catch {}
}

function Copy-PqtIntoInstallDir {
    $destDir = $script:InstallDir
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    if (Test-IsAdmin) { Set-PqtInstallDirAcl $destDir }
    $destExe = Join-Path $destDir "PQT.exe"
    Copy-Item -LiteralPath $scriptFile -Destination $destExe -Force
    $names = @(
        "LINE-QR.png", "line_qr.png", "icon.ico", "icon.png",
        "pqt_settings.json", "print.JSON", "ricoh_settings.json", "pqt_schedule_state.json"
    )
    foreach ($n in $names) {
        $src = Join-Path $scriptDir $n
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $destDir $n) -Force
        }
    }
    return $destExe
}

function Start-PqtFromInstallDir {
    param([string]$DestExe, [string]$OldExe)
    $del = ""
    if ($OldExe -and ($OldExe -ne $DestExe) -and (Test-Path -LiteralPath $OldExe)) {
        $del = " & del /q `"$OldExe`""
    }
    $cmd = "/c timeout /t 2 /nobreak >nul & start `"`" `"$DestExe`"$del"
    Start-Process -FilePath (Join-Path $env:SystemRoot "System32\cmd.exe") -ArgumentList $cmd -WindowStyle Hidden
}

function Invoke-PqtFirstRunInstall {
    if (-not $isCompiled) { return $false }
    if (Test-PqtAtInstallDir) { return $false }
    $oldExe = $scriptFile
    try {
        $destExe = Copy-PqtIntoInstallDir
        Start-PqtFromInstallDir -DestExe $destExe -OldExe $oldExe
        return $true
    } catch {
        if (Test-IsAdmin) { throw }
        try {
            $p = Start-Process -FilePath $scriptFile -ArgumentList @("-Action", "Install") -Verb RunAs -Wait -PassThru
        } catch {
            throw "需要系統管理員權限才能安裝到 C:\FLGPQT"
        }
        if (-not $p -or $p.ExitCode -ne 0) {
            throw "安裝到 C:\FLGPQT 失敗或已取消"
        }
        $destExe = Join-Path $script:InstallDir "PQT.exe"
        if (-not (Test-Path -LiteralPath $destExe)) {
            throw "安裝後找不到 C:\FLGPQT\PQT.exe"
        }
        Start-PqtFromInstallDir -DestExe $destExe -OldExe $oldExe
        return $true
    }
}

function Get-PqtAppIcon {
    param([int]$Size = 32)
    if ($isCompiled -and $scriptFile -and (Test-Path -LiteralPath $scriptFile)) {
        try { return [Drawing.Icon]::ExtractAssociatedIcon($scriptFile) } catch {}
    }
    $ico = Join-Path $scriptDir "icon.ico"
    $png = Join-Path $scriptDir "icon.png"
    if (Test-Path -LiteralPath $ico) {
        try { return New-Object Drawing.Icon($ico, $Size, $Size) } catch {}
    }
    if (Test-Path -LiteralPath $png) {
        try {
            $src = [Drawing.Bitmap]::FromFile($png)
            try {
                $bmp = New-Object Drawing.Bitmap $Size, $Size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $g = [Drawing.Graphics]::FromImage($bmp)
                try {
                    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $g.Clear([Drawing.Color]::Transparent)
                    $g.DrawImage($src, 0, 0, $Size, $Size)
                } finally { $g.Dispose() }
                $h = $bmp.GetHicon()
                $tmp = [Drawing.Icon]::FromHandle($h)
                $clone = [Drawing.Icon]$tmp.Clone()
                $tmp.Dispose()
                $bmp.Dispose()
                return $clone
            } finally { $src.Dispose() }
        } catch {}
    }
    return [Drawing.SystemIcons]::Application
}

function Append-PqtLogLine {
    param([string]$Path, [string]$Line)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $enc = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::AppendAllText($Path, $Line + [Environment]::NewLine, $enc)
    } catch {}
}

function Protect-SecretText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
    $t = [string]$Text
    if ($script:GoogleUrls) {
        foreach ($u in @($script:GoogleUrls.Values)) {
            if ($u) { $t = $t.Replace([string]$u, "[已隱藏]") }
        }
    }
    $t = [regex]::Replace($t, 'https://script\.google\.com/macros/s/[A-Za-z0-9_-]+/(?:exec|dev)', '[已隱藏]')
    return $t
}

function Write-PqtLog {
    param([string]$Message, [string]$Level = "INFO")
    $Message = Protect-SecretText $Message
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Append-PqtLogLine -Path $script:LogPath -Line $line
    if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) {
        $append = {
            param($t)
            if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) {
                $script:UiLogBox.AppendText($t + [Environment]::NewLine)
                $script:UiLogBox.SelectionStart = $script:UiLogBox.Text.Length
                $script:UiLogBox.ScrollToCaret()
            }
        }
        if ($script:MainForm -and $script:MainForm.IsHandleCreated -and $script:MainForm.InvokeRequired) {
            [void]$script:MainForm.BeginInvoke([Action[string]]$append, $line)
        } else {
            & $append $line
        }
    }
}

function Get-DefaultPqtSettings {
    [PSCustomObject]@{
        IPs                  = "192.168.1.200"
        Community            = "public"
        GoogleSheetsEnabled  = $true
        GoogleWebAppUrl      = ""
        GoogleSheetName      = "查詢結果"
        GoogleRegion         = "中壢區"
        UnattendedEnabled    = $true
        ScheduleMode         = "monthly"
        Months               = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
        Day                  = 1
        ScheduleTime         = "08:30"
        StartWithWindows     = $false
        UpdateCheckUrl       = $script:DefaultUpdateUrl
        Theme                = "預設淺色"
        AutoUpdateEnabled    = $false
    }
}

function Get-RegionFromUrl {
    param([string]$Url)
    foreach ($k in $script:GoogleUrls.Keys) {
        if ($Url -eq $script:GoogleUrls[$k]) { return $k }
    }
    return "中壢區"
}

function Get-GoogleUrlForRegion {
    param([string]$Region)
    if ($Region -and $script:GoogleUrls.Contains($Region)) {
        return [string]$script:GoogleUrls[$Region]
    }
    return [string]$script:GoogleUrls["中壢區"]
}

function ConvertTo-PqtSettingsObject {
    param($Raw)
    $d = Get-DefaultPqtSettings
    if (-not $Raw) { return $d }
    if ($Raw.IPs) { $d.IPs = [string]$Raw.IPs }
    if ($Raw.Community) { $d.Community = [string]$Raw.Community }
    if ($null -ne $Raw.GoogleSheetsEnabled) { $d.GoogleSheetsEnabled = [bool]$Raw.GoogleSheetsEnabled }
    if ($Raw.GoogleSheetName) { $d.GoogleSheetName = [string]$Raw.GoogleSheetName }
    if ($Raw.GoogleRegion -and $script:GoogleUrls.Contains([string]$Raw.GoogleRegion)) {
        $d.GoogleRegion = [string]$Raw.GoogleRegion
    } elseif ($Raw.GoogleWebAppUrl) {
        $d.GoogleRegion = Get-RegionFromUrl ([string]$Raw.GoogleWebAppUrl)
    }
    $d.GoogleWebAppUrl = ""
    if ($null -ne $Raw.UnattendedEnabled) { $d.UnattendedEnabled = [bool]$Raw.UnattendedEnabled }
    if ($Raw.ScheduleMode) { $d.ScheduleMode = [string]$Raw.ScheduleMode }
    if ($Raw.Months) {
        $d.Months = @($Raw.Months | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 1 -and $_ -le 12 } | Select-Object -Unique)
        if ($d.Months.Count -eq 0) { $d.Months = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12) }
    }
    if ($Raw.Day) { $d.Day = [Math]::Max(1, [Math]::Min(31, [int]$Raw.Day)) }
    if ($Raw.ScheduleTime) {
        $t = [string]$Raw.ScheduleTime
        if ($t -match '^(\d{1,2}):(\d{2})') {
            $d.ScheduleTime = "{0:D2}:{1:D2}" -f [int]$Matches[1], [int]$Matches[2]
        }
    }
    if ($null -ne $Raw.StartWithWindows) { $d.StartWithWindows = [bool]$Raw.StartWithWindows }
    if ($Raw.UpdateCheckUrl) { $d.UpdateCheckUrl = [string]$Raw.UpdateCheckUrl }
    if ([string]::IsNullOrWhiteSpace($d.UpdateCheckUrl)) { $d.UpdateCheckUrl = $script:DefaultUpdateUrl }
    if ($Raw.Theme) { $d.Theme = [string]$Raw.Theme }
    if ($null -ne $Raw.AutoUpdateEnabled) { $d.AutoUpdateEnabled = [bool]$Raw.AutoUpdateEnabled }
    return $d
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        Write-PqtLog "讀取 $Path 失敗：$($_.Exception.Message)" "WARN"
        return $null
    }
}

function Load-PqtSettings {
    $firstRun = -not (Test-Path -LiteralPath $script:SettingsPath)
    $pqt = Read-JsonFile $script:SettingsPath
    if ($pqt) {
        return ConvertTo-PqtSettingsObject $pqt
    }

    $d = Get-DefaultPqtSettings
    $print = Read-JsonFile $script:PrintJsonPath
    $ricoh = Read-JsonFile $script:RicohSettingsPath
    if ($print) {
        if ($print.IPs) { $d.IPs = [string]$print.IPs }
        if ($null -ne $print.GoogleSheetsEnabled) { $d.GoogleSheetsEnabled = [bool]$print.GoogleSheetsEnabled }
        if ($print.GoogleSheetName) { $d.GoogleSheetName = [string]$print.GoogleSheetName }
        if ($print.GoogleWebAppUrl) { $d.GoogleRegion = Get-RegionFromUrl ([string]$print.GoogleWebAppUrl) }
        $firstRun = $true
    }
    if ($ricoh) {
        if ($ricoh.Community) { $d.Community = [string]$ricoh.Community }
        if ($null -ne $ricoh.UnattendedEnabled) { $d.UnattendedEnabled = [bool]$ricoh.UnattendedEnabled }
        if ($ricoh.ScheduleTime) {
            $t = [string]$ricoh.ScheduleTime
            if ($t -match '^(\d{1,2}):(\d{2})') {
                $d.ScheduleTime = "{0:D2}:{1:D2}" -f [int]$Matches[1], [int]$Matches[2]
            }
        }
        if ($ricoh.ExecutionDays) {
            $dayText = [string]$ricoh.ExecutionDays
            if ($dayText -match '\d+') { $d.Day = [Math]::Max(1, [Math]::Min(31, [int]$Matches[0])) }
        }
        $firstRun = $true
    }
    if ($firstRun) {
        try {
            Save-PqtSettings $d
            Write-PqtLog "第一次執行，已自動產生 pqt_settings.json、print.JSON、ricoh_settings.json"
        } catch {
            Write-PqtLog "無法寫入設定檔：$($_.Exception.Message)" "WARN"
        }
    }
    return $d
}

function Save-JsonUtf8 {
    param($Object, [string]$Path)
    $json = $Object | ConvertTo-Json -Depth 8
    $utf8 = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Path, $json, $utf8)
}

function Save-PqtSettings {
    param($Settings)
    $pqt = [ordered]@{
        IPs                 = [string]$Settings.IPs
        Community           = [string]$Settings.Community
        GoogleSheetsEnabled = [bool]$Settings.GoogleSheetsEnabled
        GoogleSheetName     = [string]$Settings.GoogleSheetName
        GoogleRegion        = [string]$Settings.GoogleRegion
        UnattendedEnabled   = [bool]$Settings.UnattendedEnabled
        ScheduleMode        = [string]$Settings.ScheduleMode
        Months              = @($Settings.Months | ForEach-Object { [int]$_ })
        Day                 = [int]$Settings.Day
        ScheduleTime        = [string]$Settings.ScheduleTime
        StartWithWindows    = [bool]$Settings.StartWithWindows
        Theme               = [string]$Settings.Theme
        AutoUpdateEnabled   = [bool]$Settings.AutoUpdateEnabled
    }
    Save-JsonUtf8 $pqt $script:SettingsPath

    $print = [ordered]@{
        IPs                 = [string]$Settings.IPs
        SavedAt             = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        GoogleSheetsEnabled = [bool]$Settings.GoogleSheetsEnabled
        GoogleSheetName     = [string]$Settings.GoogleSheetName
    }
    Save-JsonUtf8 $print $script:PrintJsonPath

    $ricoh = [ordered]@{
        Community         = [string]$Settings.Community
        UnattendedEnabled = [bool]$Settings.UnattendedEnabled
        ScheduleTime      = [string]$Settings.ScheduleTime
        ExecutionDays     = [string][int]$Settings.Day
    }
    Save-JsonUtf8 $ricoh $script:RicohSettingsPath
}

$script:RunKeyName = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$script:RunValueName = "PQT4"

function Get-PqtStartupCommand {
    if ($isCompiled -and $scriptFile) {
        return ('"{0}" -Tray' -f $scriptFile)
    }
    $ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    return ('"{0}" -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}" -Tray' -f $ps, $scriptFile)
}

function Test-PqtRunAtStartup {
    try {
        $v = Get-ItemPropertyValue -LiteralPath $script:RunKeyName -Name $script:RunValueName -ErrorAction Stop
        return -not [string]::IsNullOrWhiteSpace([string]$v)
    } catch {
        return $false
    }
}

function Set-PqtRunAtStartup {
    param([bool]$Enable)
    if ($Enable) {
        if (-not (Test-Path -LiteralPath $script:RunKeyName)) {
            New-Item -Path $script:RunKeyName -Force | Out-Null
        }
        Set-ItemProperty -LiteralPath $script:RunKeyName -Name $script:RunValueName -Value (Get-PqtStartupCommand) -Type String
        Write-PqtLog "已設定開機自動執行"
    } else {
        try {
            Remove-ItemProperty -LiteralPath $script:RunKeyName -Name $script:RunValueName -ErrorAction SilentlyContinue
        } catch {}
        Write-PqtLog "已取消開機自動執行"
    }
}

function Sync-PqtStartupCheckbox {
    if (-not $script:ChkStartup -or $script:ChkStartup.IsDisposed) { return }
    $script:SyncingStartup = $true
    try {
        $script:ChkStartup.Checked = Test-PqtRunAtStartup
    } finally {
        $script:SyncingStartup = $false
    }
}

function Get-IpListFromText {
    param([string]$Text)
    @(
        [string]$Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    )
}

function Get-AppIpList {
    if ($script:IpTextBox -and -not $script:IpTextBox.IsDisposed -and -not [string]::IsNullOrWhiteSpace($script:IpTextBox.Text)) {
        return Get-IpListFromText $script:IpTextBox.Text
    }
    if ($script:CurrentSettings) {
        return Get-IpListFromText $script:CurrentSettings.IPs
    }
    return @()
}

function Get-ScheduleMonths {
    param($Settings)
    if ([string]$Settings.ScheduleMode -eq "selected") {
        $m = @($Settings.Months | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 1 -and $_ -le 12 } | Select-Object -Unique)
        if ($m.Count -gt 0) { return $m }
    }
    return @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
}

function Get-ScheduleTimeParts {
    param([string]$Time)
    $hour = 8
    $minute = 30
    if ($Time -match '^(\d{1,2}):(\d{2})') {
        $hour = [int]$Matches[1]
        $minute = [int]$Matches[2]
    }
    return @{ Hour = $hour; Minute = $minute }
}

function Get-PeriodKey {
    param([int]$Year, [int]$Month)
    "{0:D4}-{1:D2}" -f $Year, $Month
}

function Get-PeriodWindowDates {
    param([int]$Year, [int]$Month, [int]$Day)
    $dim = [DateTime]::DaysInMonth($Year, $Month)
    $eff = [Math]::Min([Math]::Max(1, $Day), $dim)
    $base = Get-Date -Year $Year -Month $Month -Day $eff -Hour 0 -Minute 0 -Second 0
    return @(
        $base.AddDays(-1).Date,
        $base.Date,
        $base.AddDays(1).Date
    ) | Sort-Object -Unique
}

function Get-PeriodInfo {
    param([int]$Year, [int]$Month, [int]$Day, [string]$Time)
    $dates = @(Get-PeriodWindowDates -Year $Year -Month $Month -Day $Day)
    $tp = Get-ScheduleTimeParts $Time
    $firstAt = $dates[0].Date.AddHours($tp.Hour).AddMinutes($tp.Minute)
    $missedAfter = $dates[-1].Date.AddDays(1)
    [PSCustomObject]@{
        Key          = Get-PeriodKey $Year $Month
        Year         = $Year
        Month        = $Month
        WindowDates  = $dates
        FirstAt      = $firstAt
        MissedAfter  = $missedAfter
    }
}

function Get-SelectedPeriods {
    param(
        $Settings,
        [datetime]$From = (Get-Date),
        [int]$BackMonths = 2,
        [int]$ForwardMonths = 14
    )
    $months = Get-ScheduleMonths $Settings
    $day = [int]$Settings.Day
    $time = [string]$Settings.ScheduleTime
    $cursor = Get-Date -Year $From.Year -Month $From.Month -Day 1 -Hour 0 -Minute 0 -Second 0
    $cursor = $cursor.AddMonths(-1 * $BackMonths)
    $list = @()
    for ($i = 0; $i -lt ($BackMonths + $ForwardMonths); $i++) {
        if ($months -contains $cursor.Month) {
            $list += Get-PeriodInfo -Year $cursor.Year -Month $cursor.Month -Day $day -Time $time
        }
        $cursor = $cursor.AddMonths(1)
    }
    return $list
}

function Test-IsWeekend {
    param([datetime]$Date)
    $d = $Date.DayOfWeek
    return ($d -eq [DayOfWeek]::Saturday -or $d -eq [DayOfWeek]::Sunday)
}

function Test-WindowTouchesWeekend {
    param($Dates)
    foreach ($d in @($Dates)) {
        if (Test-IsWeekend $d) { return $true }
    }
    return $false
}

function Test-IsWeekendOrHoliday {
    param([datetime]$Date)
    $d = $Date.Date
    if (Test-IsWeekend $d) {
        return $true
    }
    $md = $d.ToString("MM-dd")
    if (@("01-01", "02-28", "04-04", "04-05", "05-01", "10-10") -contains $md) {
        return $true
    }
    $extra = @(
        "2026-02-14", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19", "2026-02-20", "2026-02-21",
        "2026-06-19", "2026-09-25", "2026-09-26", "2026-09-27",
        "2027-02-06", "2027-02-07", "2027-02-08", "2027-02-09", "2027-02-10", "2027-02-11"
    )
    return ($extra -contains $d.ToString("yyyy-MM-dd"))
}

function Test-WindowTouchesHoliday {
    param($Dates)
    foreach ($d in @($Dates)) {
        if (Test-IsWeekendOrHoliday $d) { return $true }
    }
    return $false
}

function Load-ScheduleState {
    $j = Read-JsonFile $script:StatePath
    if ($j -and $j.LastFiredPeriod) {
        $script:LastFiredPeriod = [string]$j.LastFiredPeriod
    }
}

function Save-LastFiredPeriod {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    $script:LastFiredPeriod = $Key
    Save-JsonUtf8 ([ordered]@{
        LastFiredPeriod = $Key
        LastFiredAt     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }) $script:StatePath
}

function Get-DueScheduleAction {
    param(
        [datetime]$Now = (Get-Date),
        $Settings = $script:CurrentSettings
    )
    if (-not $Settings -or -not [bool]$Settings.UnattendedEnabled) { return $null }
    $tp = Get-ScheduleTimeParts $Settings.ScheduleTime
    $today = $Now.Date
    $todayAtT = $today.AddHours($tp.Hour).AddMinutes($tp.Minute)
    $fired = [string]$script:LastFiredPeriod
    $periods = @(Get-SelectedPeriods -Settings $Settings -From $Now)
    $weekendToday = Test-IsWeekend $Now

    if ($weekendToday) {
        return $null
    }

    foreach ($p in $periods) {
        $dayKey = "{0}|{1}" -f $p.Key, $today.ToString("yyyy-MM-dd")
        if ($fired -eq $dayKey) { continue }
        $inWindow = $false
        foreach ($d in @($p.WindowDates)) {
            if ($d.Date -eq $today) { $inWindow = $true; break }
        }
        if ($inWindow -and $Now -ge $todayAtT) {
            return @{
                Period  = $p
                FireKey = $dayKey
                CatchUp = $false
                Reason  = ("窗口日 {0}（{1}月抄表 {2} 日）" -f $today.ToString("MM-dd"), $p.Month, $Settings.Day)
            }
        }
    }

    $cutoff = $Now.Date.AddDays(-14)
    $weekendDue = $null
    foreach ($p in $periods) {
        if ($fired -eq $p.Key -or $fired.StartsWith($p.Key + "|")) { continue }
        if (-not (Test-WindowTouchesWeekend $p.WindowDates)) { continue }
        if ($Now -lt $p.FirstAt) { continue }
        if ($p.MissedAfter.AddDays(7) -lt $Now) { continue }
        if ($p.FirstAt.Date -lt $cutoff) { continue }
        $weekendDue = $p
    }
    if ($weekendDue) {
        return @{
            Period  = $weekendDue
            FireKey = ("{0}|{1}" -f $weekendDue.Key, $Now.Date.ToString("yyyy-MM-dd"))
            CatchUp = $true
            Reason  = ("{0} 月抄表日遇周六日，開機後自動查詢" -f $weekendDue.Month)
        }
    }
    return $null
}

function Get-NextScheduledTime {
    param(
        [datetime]$From = (Get-Date),
        $Settings = $script:CurrentSettings
    )
    if (-not $Settings) { return $null }
    $due = Get-DueScheduleAction -Now $From -Settings $Settings
    if ($due) { return $From }
    $tp = Get-ScheduleTimeParts $Settings.ScheduleTime
    $fired = [string]$script:LastFiredPeriod
    foreach ($p in @(Get-SelectedPeriods -Settings $Settings -From $From)) {
        foreach ($d in @($p.WindowDates)) {
            if (Test-IsWeekend $d) { continue }
            if ($fired -eq ("{0}|{1}" -f $p.Key, $d.ToString("yyyy-MM-dd"))) { continue }
            $at = $d.Date.AddHours($tp.Hour).AddMinutes($tp.Minute)
            if ($at -ge $From) { return $at }
        }
        if (Test-WindowTouchesWeekend $p.WindowDates -and $From -ge $p.FirstAt) {
            $d = $From.Date
            while (Test-IsWeekend $d) { $d = $d.AddDays(1) }
            if ($d -gt $From.Date) {
                return $d.AddHours($tp.Hour).AddMinutes($tp.Minute)
            }
        }
    }
    return $null
}

function Update-NextRunLabel {
    if (-not $script:CurrentSettings) { return }
    if (-not [bool]$script:CurrentSettings.UnattendedEnabled) {
        $script:NextRunTime = $null
        $text = "下次執行：排程未啟用"
    } else {
        $due = Get-DueScheduleAction
        if ($due) {
            $script:NextRunTime = Get-Date
            $text = "下次執行：現在可執行（" + $due.Reason + "）"
        } else {
            $script:NextRunTime = Get-NextScheduledTime
            if ($script:NextRunTime) {
                $text = "下次執行：" + $script:NextRunTime.ToString("yyyy-MM-dd HH:mm") + "（抄表窗口三日）"
            } else {
                $text = "下次執行：無法計算（請檢查月份／日期）"
            }
        }
    }
    if ($script:NextRunLabel -and -not $script:NextRunLabel.IsDisposed) {
        $script:NextRunLabel.Text = $text
    }
}

function Get-PrinterOidMap {
    param([string]$ModelName)
    $isSHARP = $ModelName -like "*SHARP*" -or $ModelName -like "*MX-*" -or $ModelName -like "*BP-*"
    $isXEROX = $ModelName -like "*Xerox*" -or $ModelName -like "*FUJI*" -or $ModelName -like "*Apeos*" -or $ModelName -like "*DocuCentre*" -or $ModelName -like "*DocuPrint*" -or $ModelName -like "*ApeosPrint*"
    # 彩色：MP C3004、IM C4500、MPC3504。黑白：MP 3554、IM 3500、IM 430F（數字前沒有 C）
    $isRicohColor = $ModelName -match '(?i)(?:^|[^A-Za-z0-9])(?:MP|IM|SP|Pro)\s*C\s*\d' -or $ModelName -match '(?i)(?:^|[^A-Za-z0-9])(?:MPC|IMC|SPC)\d'
    $isRicohMono = -not $isRicohColor -and (
        $ModelName -match '(?i)(?:^|[^A-Za-z0-9])(?:MP|IM|SP)\s*\d{3,4}' -or
        $ModelName -match '(?i)(?:^|[^A-Za-z0-9])Pro\s+\d{3,4}' -or
        $ModelName -match '3554|3555|6054|6055|7502|7503|6502|6503'
    )

    # Konica Minolta bizhub（C360i／C300i／C250i 等）：黑白=影印+列印、彩色=影印+列印，碳粉依 Printer-MIB 描述對應
    $isKM = $ModelName -match '(?i)KONICA|MINOLTA|bizhub'
    if ($isKM) {
        $isKMColor = $ModelName -match '(?i)bizhub\s*C\s*\d' -or $ModelName -match '(?i)(?:^|[^A-Za-z0-9])C\d{3,4}i?(?:[^A-Za-z0-9]|$)'
        if ($isKMColor) {
            return [ordered]@{
                "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
                "設備位置"     = ".1.3.6.1.2.1.1.6.0"
                "黑白合計"     = "KM_SUM:.1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.1.1+.1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.1.2"
                "彩色合計"     = "KM_SUM:.1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.2.1+.1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.2.2"
                "黑色碳粉"     = "KM_TONER:Black"
                "青色碳粉"     = "KM_TONER:Cyan"
                "洋紅碳粉"     = "KM_TONER:Magenta"
                "黃色碳粉"     = "KM_TONER:Yellow"
                "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
            }
        }
        return [ordered]@{
            "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
            "設備位置"     = ".1.3.6.1.2.1.1.6.0"
            "黑白合計"     = "KM_SUM:.1.3.6.1.4.1.18334.1.1.1.5.7.2.1.1.0"
            "彩色合計"     = "INTERNAL_SKIP"
            "黑色碳粉"     = "KM_TONER:Black"
            "青色碳粉"     = "INTERNAL_SKIP"
            "洋紅碳粉"     = "INTERNAL_SKIP"
            "黃色碳粉"     = "INTERNAL_SKIP"
            "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
        }
    }

    if ($isXEROX) {
        # 彩色機：型號含 C＋數字（ApeosPort C3060、Apeos C3060、ApeosPrint C3060 S 等）
        $isXeroxColor = $ModelName -match '(?i)(?:ApeosPort|DocuCentre|ApeosPrint|Apeos|DocuPrint)\s*C\s*\d'
        # 黑白機：ApeosPrint 3960 S／3360 S／4560 S；Apeos／ApeosPort／DocuCentre 3060／3560／2560（不含 C）
        $isXeroxBM = -not $isXeroxColor -and (
            $ModelName -match '(?i)ApeosPrint\s*(?:3360|3960|4560)\s*S?' -or
            $ModelName -match '(?i)(?:ApeosPort|DocuCentre|Apeos)\s*(?:3060|3560|2560)' -or
            $ModelName -like "*ApeosPort*3060*" -or $ModelName -like "*ApeosPort*3560*" -or $ModelName -like "*DocuCentre*3060*"
        )
        if ($isXeroxBM) {
            # 黑白合計：Xerox MIB Printed Pages Mono（FUJIFILM BI／全錄通用）
            return [ordered]@{
                "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
                "設備位置"     = ".1.3.6.1.2.1.1.6.0"
                "黑白合計"     = ".1.3.6.1.4.1.253.8.53.13.2.1.6.1.20.34"
                "彩色合計"     = "INTERNAL_SKIP"
                "黑色碳粉"     = "KM_TONER:Black@1"
                "青色碳粉"     = "INTERNAL_SKIP"
                "洋紅碳粉"     = "INTERNAL_SKIP"
                "黃色碳粉"     = "INTERNAL_SKIP"
                "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
            }
        }
        # 彩色（含 ApeosPrint C3060 S／C3560 S、ApeosPort C3060 等）：Mono=.20.34、Color=.20.33
        return [ordered]@{
            "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
            "設備位置"     = ".1.3.6.1.2.1.1.6.0"
            "黑白合計"     = ".1.3.6.1.4.1.253.8.53.13.2.1.6.1.20.34"
            "彩色合計"     = ".1.3.6.1.4.1.253.8.53.13.2.1.6.1.20.33"
            "黑色碳粉"     = "KM_TONER:Black@1"
            "青色碳粉"     = "KM_TONER:Cyan@2"
            "洋紅碳粉"     = "KM_TONER:Magenta@3"
            "黃色碳粉"     = "KM_TONER:Yellow@4"
            "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
        }
    }
    if ($isSHARP) {
        $isSharpBM = $ModelName -like "*MX-M*" -or $ModelName -like "*BP-M*"
        if ($isSharpBM) {
            return [ordered]@{
                "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
                "設備位置"     = ".1.3.6.1.2.1.1.6.0"
                "黑白合計"     = ".1.3.6.1.2.1.43.10.2.1.4.1.1"
                "彩色合計"     = "INTERNAL_SKIP"
                "黑色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.1"
                "青色碳粉"     = "INTERNAL_SKIP"
                "洋紅碳粉"     = "INTERNAL_SKIP"
                "黃色碳粉"     = "INTERNAL_SKIP"
                "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
            }
        }
        # MX-2600／MX-3600／MX-4100 系列（含 N／FN 等字尾）：Sharp 私有 MIB 黑白／彩色合計
        # OID 標籤為 Black & White Total Count／Full Color Total Count（影印+列印）
        # 來源：PrinterMS OID 參考、Copytechnet Sharp SNMP、Checkmk snmpwalk 標籤對照
        $isSharpMxColorCounter = $ModelName -match '(?i)MX-?2600' -or $ModelName -match '(?i)MX-?3600' -or $ModelName -match '(?i)MX-?4100'
        if ($isSharpMxColorCounter) {
            return [ordered]@{
                "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
                "設備位置"     = ".1.3.6.1.2.1.1.6.0"
                "黑白合計"     = ".1.3.6.1.4.1.2385.1.1.19.2.1.3.5.4.61"
                "彩色合計"     = ".1.3.6.1.4.1.2385.1.1.19.2.1.3.5.4.63"
                "黑色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.4"
                "青色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.1"
                "洋紅碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.2"
                "黃色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.3"
                "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
            }
        }
        return [ordered]@{
            "Serial Number" = ".1.3.6.1.2.1.43.5.1.1.17.1"
            "設備位置"     = ".1.3.6.1.2.1.1.6.0"
            "黑白合計"     = ".1.3.6.1.2.1.43.10.2.1.4.1.1"
            "彩色合計"     = ".1.3.6.1.2.1.43.10.2.1.4.1.2"
            "黑色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.1"
            "青色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.2"
            "洋紅碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.3"
            "黃色碳粉"     = ".1.3.6.1.2.1.43.11.1.1.9.1.4"
            "Error Status"  = ".1.3.6.1.2.1.43.18.1.1.7.1"
        }
    }
    if ($isRicohMono) {
        return [ordered]@{
            "Serial Number" = ".1.3.6.1.4.1.367.3.2.1.2.1.4.0"
            "設備位置"     = ".1.3.6.1.2.1.1.6.0"
            "黑白合計"     = ".1.3.6.1.4.1.367.3.2.1.2.19.1.0"
            "彩色合計"     = "INTERNAL_SKIP"
            "黑色碳粉"     = "RICOH_TONER:Black@1"
            "青色碳粉"     = "INTERNAL_SKIP"
            "洋紅碳粉"     = "INTERNAL_SKIP"
            "黃色碳粉"     = "INTERNAL_SKIP"
            "Error Status"  = ".1.3.6.1.4.1.367.3.2.1.2.2.13.0"
        }
    }
    return [ordered]@{
        "Serial Number" = ".1.3.6.1.4.1.367.3.2.1.2.1.4.0"
        "設備位置"     = ".1.3.6.1.2.1.1.6.0"
        "黑白合計"     = ".1.3.6.1.4.1.367.3.2.1.2.19.5.1.9.22"
        "彩色合計"     = ".1.3.6.1.4.1.367.3.2.1.2.19.5.1.9.21"
        "黑色碳粉"     = "RICOH_TONER:Black@1"
        "青色碳粉"     = "RICOH_TONER:Cyan@2"
        "洋紅碳粉"     = "RICOH_TONER:Magenta@3"
        "黃色碳粉"     = "RICOH_TONER:Yellow@4"
        "Error Status"  = ".1.3.6.1.4.1.367.3.2.1.2.2.13.0"
    }
}

function Get-SnmpRawOctets {
    param(
        [string]$Ip,
        [string]$Community = "public",
        [string]$Oid,
        [int]$Port = 161,
        [int]$TimeoutMs = 4000
    )

    function New-BerLength([int]$Len) {
        if ($Len -lt 128) { return [byte[]]@([byte]$Len) }
        if ($Len -lt 256) { return [byte[]]@([byte]0x81, [byte]$Len) }
        return [byte[]]@([byte]0x82, [byte](($Len -shr 8) -band 255), [byte]($Len -band 255))
    }
    function New-BerTlv([byte]$Tag, [byte[]]$Body) {
        if ($null -eq $Body) { $Body = [byte[]]@() }
        $out = New-Object System.Collections.Generic.List[byte]
        [void]$out.Add($Tag)
        foreach ($b in (New-BerLength $Body.Length)) { [void]$out.Add($b) }
        foreach ($b in $Body) { [void]$out.Add($b) }
        return ,$out.ToArray()
    }
    function New-BerInt([int]$Number) {
        $raw = [BitConverter]::GetBytes($Number)
        if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($raw) }
        $k = 0
        while ($k -lt ($raw.Length - 1)) {
            if ($raw[$k] -eq 0 -and ($raw[$k + 1] -band 0x80) -eq 0) { $k++; continue }
            if ($raw[$k] -eq 255 -and ($raw[$k + 1] -band 0x80) -ne 0) { $k++; continue }
            break
        }
        $body = New-Object byte[] ($raw.Length - $k)
        [Array]::Copy($raw, $k, $body, 0, $body.Length)
        return ,(New-BerTlv 0x02 $body)
    }
    function New-BerOid([string]$Text) {
        $parts = @($Text.Trim('.').Split('.') | ForEach-Object { [int]$_ })
        $body = New-Object System.Collections.Generic.List[byte]
        [void]$body.Add([byte]((40 * $parts[0]) + $parts[1]))
        for ($n = 2; $n -lt $parts.Count; $n++) {
            $v = [int]$parts[$n]
            if ($v -lt 128) {
                [void]$body.Add([byte]$v)
                continue
            }
            $stack = New-Object System.Collections.Generic.Stack[byte]
            [void]$stack.Push([byte]($v -band 0x7F))
            $v = $v -shr 7
            while ($v -gt 0) {
                [void]$stack.Push([byte](($v -band 0x7F) -bor 0x80))
                $v = $v -shr 7
            }
            while ($stack.Count -gt 0) { [void]$body.Add($stack.Pop()) }
        }
        return ,(New-BerTlv 0x06 $body.ToArray())
    }
    function Read-BerTlv([byte[]]$Bytes, [int]$Offset) {
        if ($Offset -ge $Bytes.Length) { return $null }
        $tag = $Bytes[$Offset]
        $idx = $Offset + 1
        if ($idx -ge $Bytes.Length) { return $null }
        $lenByte = [int]$Bytes[$idx]
        $idx++
        $len = 0
        if ($lenByte -lt 128) {
            $len = $lenByte
        } elseif ($lenByte -eq 0x81) {
            if ($idx -ge $Bytes.Length) { return $null }
            $len = [int]$Bytes[$idx]
            $idx++
        } elseif ($lenByte -eq 0x82) {
            if (($idx + 1) -ge $Bytes.Length) { return $null }
            $len = ([int]$Bytes[$idx] -shl 8) -bor [int]$Bytes[$idx + 1]
            $idx += 2
        } else {
            return $null
        }
        if (($idx + $len) -gt $Bytes.Length) { return $null }
        $value = New-Object byte[] $len
        if ($len -gt 0) { [Array]::Copy($Bytes, $idx, $value, 0, $len) }
        return @{ Tag = $tag; Value = $value; Next = ($idx + $len) }
    }
    function Find-SnmpOctetString([byte[]]$Bytes) {
        $i = 0
        $last = $null
        while ($i -lt $Bytes.Length) {
            $tlv = Read-BerTlv $Bytes $i
            if ($null -eq $tlv) { break }
            if ($tlv.Tag -eq 0x04 -and $tlv.Value.Length -gt 0) { $last = [byte[]]$tlv.Value }
            $i = $tlv.Next
            if ($tlv.Tag -eq 0x30 -or $tlv.Tag -eq 0xA0 -or $tlv.Tag -eq 0xA2) {
                $inner = Find-SnmpOctetString ([byte[]]$tlv.Value)
                if ($null -ne $inner) { $last = $inner }
            }
        }
        if ($null -ne $last) { return ,$last }
        return $null
    }

    $oidTlv = [byte[]](New-BerOid $Oid)
    $communityBytes = [Text.Encoding]::ASCII.GetBytes($(if ([string]::IsNullOrEmpty($Community)) { "public" } else { $Community }))
    $nullTlv = [byte[]](New-BerTlv 0x05 ([byte[]]@()))
    $varBind = [byte[]](New-BerTlv 0x30 (@($oidTlv + $nullTlv)))
    $varList = [byte[]](New-BerTlv 0x30 $varBind)

    foreach ($ver in @(0, 1)) {
        try {
            $pduBody = [byte[]](@((New-BerInt (Get-Random -Minimum 1 -Maximum 65535)) + (New-BerInt 0) + (New-BerInt 0) + $varList))
            $pdu = [byte[]](New-BerTlv 0xA0 $pduBody)
            $message = [byte[]](New-BerTlv 0x30 (@((New-BerInt $ver) + (New-BerTlv 0x04 $communityBytes) + $pdu)))
            $client = New-Object System.Net.Sockets.UdpClient
            $resp = $null
            try {
                $client.Client.ReceiveTimeout = $TimeoutMs
                $client.Connect($Ip, $Port)
                [void]$client.Send($message, $message.Length)
                $wait = $client.BeginReceive($null, $null)
                if (-not $wait.AsyncWaitHandle.WaitOne($TimeoutMs)) { continue }
                $remote = New-Object System.Net.IPEndPoint ([Net.IPAddress]::Any, 0)
                $resp = [byte[]]$client.EndReceive($wait, [ref]$remote)
            } finally {
                try { $client.Close() } catch {}
            }
            if ($null -eq $resp -or @($resp).Count -lt 8) { continue }

            $at = -1
            for ($pos = 0; $pos -le ($resp.Length - $oidTlv.Length); $pos++) {
                $same = $true
                for ($q = 0; $q -lt $oidTlv.Length; $q++) {
                    if ($resp[$pos + $q] -ne $oidTlv[$q]) { $same = $false; break }
                }
                if ($same) { $at = $pos; break }
            }
            if ($at -ge 0) {
                $valueTlv = Read-BerTlv $resp ($at + $oidTlv.Length)
                if ($null -ne $valueTlv -and $valueTlv.Tag -eq 0x04) { return ,([byte[]]$valueTlv.Value) }
                if ($null -ne $valueTlv -and $valueTlv.Tag -eq 0x05) { return ,([byte[]]@()) }
            }
            $fallbackOctets = Find-SnmpOctetString $resp
            if ($null -ne $fallbackOctets) { return ,$fallbackOctets }
        } catch {}
    }
    return $null
}

function Get-PqtVendorHint {
    param(
        [string]$ModelName = "",
        [string]$SysObjectId = ""
    )
    $blob = (("{0} {1}" -f $ModelName, $SysObjectId)).ToLower()
    if ($blob -match 'xerox|fujifilm|fuji|docucentre|docuprint|apeos|1\.3\.6\.1\.4\.1\.297') {
        return "xerox"
    }
    if ($blob -match 'ricoh|1\.3\.6\.1\.4\.1\.367') {
        return "ricoh"
    }
    return "unknown"
}

function ConvertTo-SnmpByteArray {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [byte[]]) { return [byte[]]$Value }
    if ($Value -is [System.Array]) {
        $tmp = New-Object byte[] $Value.Length
        try {
            for ($i = 0; $i -lt $Value.Length; $i++) { $tmp[$i] = [byte]$Value[$i] }
            return ,$tmp
        } catch {
            return $null
        }
    }
    return $null
}

function Test-SnmpDecodedText {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    foreach ($ch in $Text.ToCharArray()) {
        $n = [int]$ch
        if ($n -eq 0xFFFD) { return $false }
        if ($n -ge 0xE000 -and $n -le 0xF8FF) { return $false }
    }
    return $true
}

function Get-SnmpDecodedScore {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return -100 }
    $score = 0
    foreach ($ch in $Text.ToCharArray()) {
        $n = [int]$ch
        if ($n -eq 0xFFFD) { $score -= 50 }
        elseif ($n -ge 0xE000 -and $n -le 0xF8FF) { $score -= 40 }
        elseif ($ch -eq '?') { $score -= 8 }
        elseif ($n -ge 0x4E00 -and $n -le 0x9FFF) { $score += 6 }
        elseif (($n -ge 48 -and $n -le 57) -or ($n -ge 65 -and $n -le 90) -or ($n -ge 97 -and $n -le 122)) { $score += 1 }
    }
    if ($Text -match '樓|層|室|廠|區|櫃|倉|辦|公|店|門市|影印|倉庫|大廳|櫃台|辦公室') { $score += 20 }
    return $score
}

function Repair-SnmpText {
    param(
        $Value,
        [string]$Vendor = "unknown"
    )
    try {
        if ($null -eq $Value) { return "" }
        $utf8Strict = New-Object System.Text.UTF8Encoding $false, $true
        $vendor = "unknown"
        if (-not [string]::IsNullOrEmpty($Vendor)) { $vendor = $Vendor.ToLower() }

        if ($vendor -eq "xerox") {
            $codePages = @(932, 950, 1252)
        } else {
            $codePages = @(950, 932, 1252)
        }

        $rawBytes = ConvertTo-SnmpByteArray $Value
        if ($null -eq $rawBytes) {
            $s = ([string]$Value).TrimEnd([char]0).Trim()
            if ([string]::IsNullOrEmpty($s) -or $s -notmatch '[^ -]') { return $s }
            $allByte = $true
            $buf = New-Object System.Collections.Generic.List[byte]
            foreach ($ch in $s.ToCharArray()) {
                $n = [int]$ch
                if ($n -gt 255) { $allByte = $false; break }
                [void]$buf.Add([byte]$n)
            }
            if ($allByte) {
                $rawBytes = $buf.ToArray()
            } else {
                $best = $null
                $bestScore = -999
                $fromPages = @(950, 932, 1252)
                if ($vendor -eq "xerox") { $fromPages = @(950, 1252, 932) }
                foreach ($fromPage in $fromPages) {
                    try {
                        $asBytes = [Text.Encoding]::GetEncoding($fromPage).GetBytes($s)
                        if ($null -eq $asBytes -or @($asBytes).Count -eq 0) { continue }
                        foreach ($toPage in @(65001, 932, 950)) {
                            try {
                                $encTo = if ($toPage -eq 65001) { $utf8Strict } else { [Text.Encoding]::GetEncoding($toPage) }
                                $decoded = $encTo.GetString($asBytes).TrimEnd([char]0).Trim()
                                if (-not (Test-SnmpDecodedText $decoded)) { continue }
                                $bonus = 0
                                if ($toPage -eq 65001) { $bonus += 10 }
                                if ($vendor -eq "xerox" -and $toPage -eq 932) { $bonus += 8 }
                                $sc = (Get-SnmpDecodedScore $decoded) + $bonus
                                if ($sc -gt $bestScore) { $bestScore = $sc; $best = $decoded }
                            } catch {}
                        }
                    } catch {}
                }
                if ($null -ne $best -and $bestScore -ge 6) { return $best }
                return $s
            }
        }

        if ($null -eq $rawBytes -or @($rawBytes).Count -eq 0) { return "" }
        if ($rawBytes.Length -ge 3 -and [int]$rawBytes[0] -eq 0xEF -and [int]$rawBytes[1] -eq 0xBB -and [int]$rawBytes[2] -eq 0xBF) {
            if ($rawBytes.Length -eq 3) { return "" }
            $rawBytes = [byte[]]($rawBytes[3..($rawBytes.Length - 1)])
        }

        $best = $null
        $bestScore = -999

        try {
            $u = $utf8Strict.GetString($rawBytes).TrimEnd([char]0).Trim()
            if (Test-SnmpDecodedText $u) {
                $sc = (Get-SnmpDecodedScore $u) + 8
                if ($sc -gt $bestScore) { $bestScore = $sc; $best = $u }
            }
        } catch {}

        foreach ($codePage in $codePages) {
            try {
                $decoded = [Text.Encoding]::GetEncoding($codePage).GetString($rawBytes).TrimEnd([char]0).Trim()
                if (-not (Test-SnmpDecodedText $decoded)) { continue }
                $bonus = 0
                if ($vendor -eq "xerox" -and $codePage -eq 932) { $bonus += 12 }
                if ($vendor -ne "xerox" -and $codePage -eq 950) { $bonus += 8 }
                $sc = (Get-SnmpDecodedScore $decoded) + $bonus
                if ($sc -gt $bestScore) { $bestScore = $sc; $best = $decoded }
            } catch {}
        }

        try {
            $hasZero = $false
            foreach ($b in $rawBytes) { if ([int]$b -eq 0) { $hasZero = $true; break } }
            if ($hasZero -and ((@($rawBytes).Count % 2) -eq 0)) {
                $decoded = [Text.Encoding]::Unicode.GetString($rawBytes).TrimEnd([char]0).Trim()
                if (Test-SnmpDecodedText $decoded) {
                    $sc = Get-SnmpDecodedScore $decoded
                    if ($sc -gt $bestScore) { $bestScore = $sc; $best = $decoded }
                }
            }
        } catch {}

        if ($null -ne $best -and $bestScore -ge 1) { return $best }
        try { return [Text.Encoding]::ASCII.GetString($rawBytes).TrimEnd([char]0).Trim() } catch {}
        return ([string]$Value).TrimEnd([char]0).Trim()
    } catch {
        try { return ([string]$Value).TrimEnd([char]0).Trim() } catch { return "" }
    }
}

function Get-PqtKmSnmpValue {
    param($Snmp, [string]$Spec)
    # KM_SUM:oidA+oidB → 加總；KM_TONER:顏色 → 依 prtMarkerSuppliesDescription 找槽位，回傳 "NN %"
    if ($Spec -like "KM_SUM:*") {
        $sum = [int64]0; $ok = $false
        foreach ($o in ($Spec.Substring(7) -split '\+')) {
            try { $v = "$($Snmp.Get($o))".Trim(); if ($v -match '^\d+$') { $sum += [int64]$v; $ok = $true } } catch {}
        }
        if ($ok) { return "$sum" }

        return "N/A"
    }
    if ($Spec -like "RICOH_TONER:*") {
        # Ricoh 私有 MIB：名稱 .24.1.1.2.N／描述 .24.1.1.3.N，餘量 .24.1.1.5.N（0～100 %、-100 即將用完、-3 尚有餘量、-2 未知）
        $rest = $Spec.Substring(12)
        $color = $rest; $def = 1
        if ($rest -match '^(\w+)@(\d+)$') { $color = $Matches[1]; $def = [int]$Matches[2] }
        $pat = switch ($color) {
            "Black"   { '(?i)black|黑|\bK\b|\bBK\b' }
            "Cyan"    { '(?i)cyan|青|\bC\b' }
            "Magenta" { '(?i)magenta|洋紅|\bM\b' }
            "Yellow"  { '(?i)yellow|黃|黄|\bY\b' }
        }
        $skipPat = '(?i)waste|drum|fuser|廢|回收|感光|定影'
        $idx = 0
        for ($i = 1; $i -le 10; $i++) {
            $d = ""
            foreach ($sub in 2, 3) { try { $d += " " + "$($Snmp.Get(".1.3.6.1.4.1.367.3.2.1.2.24.1.1.$sub.$i"))" } catch {} }
            if ([string]::IsNullOrWhiteSpace($d)) { if ($i -gt 4) { break } else { continue } }
            if ($d -match $pat -and $d -notmatch $skipPat) { $idx = $i; break }
        }
        $tryIdx = @($idx, $def) | Where-Object { $_ -gt 0 } | Select-Object -Unique
        foreach ($ti in $tryIdx) {
            $v = $null
            try { $v = "$($Snmp.Get(".1.3.6.1.4.1.367.3.2.1.2.24.1.1.5.$ti"))".Trim() } catch { continue }
            if ($v -notmatch '^-?\d+$') { continue }
            $n = [int]$v
            if ($n -eq -100) { return "即將用完" }
            if ($n -eq -3) { return "尚有餘量" }
            if ($n -eq -2) { return "未知" }
            if ($n -ge 0 -and $n -le 100) { return "$n %" }
        }
        # 私有 MIB 讀不到時改用標準 Printer-MIB（依槽位名稱）
        return (Get-PqtKmSnmpValue -Snmp $Snmp -Spec ("KM_TONER:{0}@{1}" -f $color, $def))
    }
    if ($Spec -like "KM_TONER:*") {
        $color = $Spec.Substring(9)
        $defIdx = @{ Black = 4; Cyan = 1; Magenta = 2; Yellow = 3 }
        if ($color -match '^(\w+)@(\d+)$') { $color = $Matches[1]; $defIdx = @{ $color = [int]$Matches[2] } }
        $pat = switch ($color) {
            "Black"   { '(?i)black|黑|ブラック|\bK\b' }
            "Cyan"    { '(?i)cyan|青|シアン|\bC\b' }
            "Magenta" { '(?i)magenta|洋紅|マゼンタ|\bM\b' }
            "Yellow"  { '(?i)yellow|黃|黄|イエロー|\bY\b' }
        }
        $skipPat = '(?i)waste|drum|fuser|belt|transfer|developer|廢|回收|感光|鼓|定影|轉印|転写|ドラム|定着|回収'
        $descs = [ordered]@{}
        for ($i = 1; $i -le 16; $i++) {
            try { $descs[[string]$i] = "$($Snmp.Get(".1.3.6.1.2.1.43.11.1.1.6.1.$i"))" } catch { if ($i -gt 4) { break } }
        }
        $found = 0
        foreach ($k in @($descs.Keys)) {
            $d = $descs[$k]
            if ($d -match '(?i)toner|碳粉|トナー|cartridge' -and $d -match $pat -and $d -notmatch $skipPat) { $found = [int]$k; break }
        }
        if ($found -eq 0) {
            foreach ($k in @($descs.Keys)) {
                $d = $descs[$k]
                if ($d -match $pat -and $d -notmatch $skipPat) { $found = [int]$k; break }
            }
        }
        if ($found -eq 0) { $found = $defIdx[$color] }
        $lvl = $null; $max = $null
        try { $lvl = [int]"$($Snmp.Get(".1.3.6.1.2.1.43.11.1.1.9.1.$found"))" } catch { return "N/A" }
        try { $max = [int]"$($Snmp.Get(".1.3.6.1.2.1.43.11.1.1.8.1.$found"))" } catch {}
        if ($lvl -eq -3) { return "尚有餘量" }
        if ($lvl -lt 0) { return "未知" }
        if ($max -gt 0 -and $lvl -le $max) { return ("{0} %" -f [math]::Max(0, [math]::Min(100, [math]::Round(100.0 * $lvl / $max)))) }
        if ($lvl -gt 100) { return ("剩約 {0} 頁" -f $lvl) }
        return "$lvl %"
    }
    return "N/A"
}

function Invoke-SnmpPrinterQueryCore {
    param([string[]]$IpList, [string]$Community = "public")

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($ip in $IpList) {
        $record = [ordered]@{
            "設備 IP"       = $ip
            "Model Name"    = "N/A"
            "Serial Number" = "N/A"
            "設備位置"     = "N/A"
            "黑白合計"     = "N/A"
            "彩色合計"     = "N/A"
            "黑色碳粉"     = "N/A"
            "青色碳粉"     = "N/A"
            "洋紅碳粉"     = "N/A"
            "黃色碳粉"     = "N/A"
            "Error Status"  = "N/A"
        }

        $snmp = $null
        try {
            $snmp = New-Object -ComObject OlePrn.OleSNMP
            $snmp.Open($ip, $Community, 2, 2000)

            try {
                $record["Model Name"] = $snmp.Get(".1.3.6.1.4.1.367.3.2.1.1.1.1.0")
            } catch {
                try { $record["Model Name"] = $snmp.Get(".1.3.6.1.2.1.25.3.2.1.3.1") } catch {}
            }

            $OIDs = Get-PrinterOidMap -ModelName ([string]$record["Model Name"])

            foreach ($item in $OIDs.GetEnumerator()) {
                if ($item.Value -eq "INTERNAL_SKIP") {
                    $record[$item.Key] = "-"
                    continue
                }
                if ("$($item.Value)" -like "KM_*" -or "$($item.Value)" -like "RICOH_TONER:*") {
                    try { $record[$item.Key] = Get-PqtKmSnmpValue -Snmp $snmp -Spec ([string]$item.Value) } catch { $record[$item.Key] = "N/A" }
                    continue
                }
                try {
                    $raw = $snmp.Get($item.Value)
                    if ($item.Key -like "*碳粉*") {
                        if ($raw -eq "-3" -or $raw -eq -3) {
                            $record[$item.Key] = "非碳粉/無此槽"
                        } elseif ("$raw" -match '^\d+$') {
                            $record[$item.Key] = "$raw %"
                        } else {
                            $record[$item.Key] = $raw
                        }
                    } else {
                        if ($item.Key -eq "設備位置") {
                            $fallback = "$raw"
                            try {
                                $sysOid = ""
                                try { $sysOid = "$($snmp.Get('.1.3.6.1.2.1.1.2.0'))" } catch {}
                                $vendorHint = Get-PqtVendorHint -ModelName ([string]$record["Model Name"]) -SysObjectId $sysOid
                                if ($vendorHint -eq "unknown" -and ([string]$record["Model Name"] -match 'FUJI|XEROX|DocuPrint|DocuCentre|Apeos')) {
                                    $vendorHint = "xerox"
                                }
                                $octets = $null
                                try { $octets = Get-SnmpRawOctets -Ip $ip -Community $Community -Oid ([string]$item.Value) } catch {}
                                if ($null -ne $octets -and @($octets).Count -gt 0) {
                                    $hex = ([BitConverter]::ToString([byte[]]@($octets))).Replace("-", " ")
                                    Write-PqtLog ("設備位置 raw hex {0}: {1}" -f $ip, $hex)
                                    $decoded = Repair-SnmpText -Value $octets -Vendor $vendorHint
                                } else {
                                    Write-PqtLog ("設備位置 raw 失敗，改用 COM 字串 {0}" -f $ip) "WARN"
                                    $decoded = Repair-SnmpText -Value $raw -Vendor $vendorHint
                                }
                                if (-not [string]::IsNullOrWhiteSpace([string]$decoded)) {
                                    $raw = $decoded
                                } else {
                                    $raw = $fallback
                                }
                            } catch {
                                $raw = $fallback
                            }
                        }
                        $record[$item.Key] = $raw
                    }
                } catch {
                    $record[$item.Key] = "N/A"
                }
            }
            if ($record["黑白合計"] -eq "N/A" -and $record["彩色合計"] -eq "N/A") {
                $colorType = ""
                try { $colorType = "$($snmp.Get('.1.3.6.1.4.1.367.3.2.1.2.16.1.0'))".Trim() } catch {}
                if ($colorType -ne "2") {
                    try {
                        $totalText = "$($snmp.Get('.1.3.6.1.4.1.367.3.2.1.2.19.1.0'))".Trim()
                        if ($totalText -match '^\d+$') {
                            $record["黑白合計"] = $totalText
                            $record["彩色合計"] = "-"
                        }
                    } catch {}
                }
            }
            Write-PqtLog ("已查詢 {0} ({1})" -f $ip, $record["Model Name"])
        } catch {
            $keys = @($record.Keys)
            foreach ($key in $keys) {
                if ($key -ne "設備 IP") { $record[$key] = "連線失敗" }
            }
            Write-PqtLog ("IP {0} 查詢失敗：{1}" -f $ip, $_.Exception.Message) "WARN"
        } finally {
            if ($snmp) { try { $snmp.Close() } catch {} }
        }

        [void]$results.Add([PSCustomObject]$record)
    }
    return $results
}

function Get-GoogleWebAppDeployHint {
    return @"
401 沒有權限。請檢查 Google Apps Script 部署：
1. 試算表 → 擴充功能 → Apps Script
2. 部署 doGet 網頁應用程式
3. 部署 → 管理部署 → 誰可以存取=任何人、執行身分=我
4. 使用 /exec 部署網址
"@
}

function Invoke-GoogleWebAppPost {
    param([string]$WebAppUrl, [string]$JsonBody)
    $url = $WebAppUrl.Trim()
    if ($url -match '/dev$') {
        return @{ Ok = $false; Message = "請使用 /exec 網址，不要用 /dev" }
    }
    if ($url -notmatch '/exec$') {
        return @{ Ok = $false; Message = "URL 必須以 /exec 結尾" }
    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-WebRequest -Uri $url -Method Post -Body $JsonBody `
            -ContentType "application/json; charset=utf-8" -UseBasicParsing -TimeoutSec 120
        $content = [string]$resp.Content
        if ($content -match 'accounts\.google\.com|signin|ServiceLogin') {
            return @{ Ok = $false; Message = (Get-GoogleWebAppDeployHint) }
        }
        try {
            $parsed = $content | ConvertFrom-Json
            if ($null -ne $parsed.ok -and -not [bool]$parsed.ok) {
                return @{ Ok = $false; Message = $parsed.error }
            }
        } catch {}
        return @{ Ok = $true; Message = "上傳成功"; Response = $content }
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 401) {
            return @{ Ok = $false; Message = (Get-GoogleWebAppDeployHint) }
        }
        return @{ Ok = $false; Message = (Protect-SecretText $_.Exception.Message) }
    }
}

function Convert-ResultsToGooglePayload {
    param([array]$Results, [string]$SheetName = "查詢結果")
    $queryTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cols = $script:Columns
    $headers = $cols + "查詢時間"

    $rows = @()
    foreach ($r in $Results) {
        $line = @()
        foreach ($col in $cols) {
            $line += [string]$r.$col
        }
        $line += $queryTime
        $rows += , $line
    }

    [ordered]@{
        sheetName = $SheetName
        headers   = $headers
        rows      = $rows
        queryTime = $queryTime
    }
}

function Send-ToGoogleSheets {
    param([array]$Results, [string]$WebAppUrl, [string]$SheetName = "查詢結果")
    if (-not $Results -or @($Results).Count -eq 0) {
        return @{ Ok = $false; Message = "無資料可上傳" }
    }
    if ([string]::IsNullOrWhiteSpace($WebAppUrl)) {
        return @{ Ok = $false; Message = "未選擇地區" }
    }

    $payload = Convert-ResultsToGooglePayload -Results $Results -SheetName $SheetName
    $json = $payload | ConvertTo-Json -Depth 10 -Compress

    Write-PqtLog ("正在上傳 {0} 筆資料到 Google 試算表..." -f @($Results).Count)
    Invoke-GoogleWebAppPost -WebAppUrl $WebAppUrl -JsonBody $json
}

function Get-QueryFunctionText {
    $names = @(
        "Protect-SecretText",
        "Get-SnmpRawOctets",
        "Get-PqtVendorHint",
        "ConvertTo-SnmpByteArray",
        "Test-SnmpDecodedText",
        "Get-SnmpDecodedScore",
        "Repair-SnmpText",
        "Get-PrinterOidMap",
        "Get-PqtKmSnmpValue",
        "Invoke-SnmpPrinterQueryCore",
        "Get-GoogleWebAppDeployHint",
        "Invoke-GoogleWebAppPost",
        "Convert-ResultsToGooglePayload",
        "Send-ToGoogleSheets"
    )
    $parts = foreach ($n in $names) {
        $d = (Get-Command $n -CommandType Function).Definition
        "function $n {`r`n$d`r`n}"
    }
    return ($parts -join "`r`n`r`n")
}

function Update-QueryButtonState {
    $enabled = -not $script:QueryBusy
    foreach ($b in @($script:BtnQuery, $script:BtnQueryNow, $script:BtnQueryUpload)) {
        if ($b -and -not $b.IsDisposed) { $b.Enabled = $enabled }
    }
    if ($script:BtnSave -and -not $script:BtnSave.IsDisposed) {
        $script:BtnSave.Enabled = $true
    }
}

function Get-ResultProp {
    param($Row, [string]$Name)
    if ($null -eq $Row) { return "" }
    try {
        $p = $Row.PSObject.Properties[$Name]
        if ($p) { return [string]$p.Value }
    } catch {}
    return ""
}

function Show-QueryResults {
    param($Results)
    if (-not $script:ResultView -or $script:ResultView.IsDisposed) { return }
    $cols = $script:DisplayColumns
    $when = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $script:ResultView.BeginUpdate()
    try {
        foreach ($r in @($Results)) {
            if (-not $r.PSObject.Properties["查詢時間"]) {
                $r | Add-Member -NotePropertyName "查詢時間" -NotePropertyValue $when -Force
            } elseif ([string]::IsNullOrWhiteSpace([string]$r."查詢時間")) {
                $r."查詢時間" = $when
            }
            $first = Get-ResultProp $r $cols[0]
            $item = New-Object Windows.Forms.ListViewItem($first)
            for ($i = 1; $i -lt $cols.Count; $i++) {
                [void]$item.SubItems.Add((Get-ResultProp $r $cols[$i]))
            }
            [void]$script:ResultView.Items.Add($item)
        }
    } finally {
        $script:ResultView.EndUpdate()
    }
    if ($script:QueryStatusLabel -and -not $script:QueryStatusLabel.IsDisposed) {
        $n = @($Results).Count
        $total = $script:ResultView.Items.Count
        $script:QueryStatusLabel.Text = "最近查詢：{0}　　本次 {1} 台，累計 {2} 筆" -f $when, $n, $total
    }
}

function Clear-PqtUiLog {
    if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) {
        $script:UiLogBox.Clear()
    }
    Write-PqtLog "已清除畫面紀錄"
}

function Start-PqtQueryAsync {
    param(
        [switch]$Interactive,
        [switch]$ForceUpload,
        [switch]$SkipUpload
    )

    if ($script:QueryBusy) {
        Write-PqtLog "已有查詢正在進行，請稍候" "WARN"
        if ($Interactive) {
            [Windows.Forms.MessageBox]::Show("已有查詢正在進行，請稍候。", "PQT007") | Out-Null
        }
        return
    }

    $community = "public"
    $url = ""
    $sheet = "查詢結果"
    $doUpload = $true
    $ips = @()

    if ($Interactive) {
        $ips = @(Get-AppIpList)
        if ($script:CommunityBox -and -not [string]::IsNullOrWhiteSpace($script:CommunityBox.Text)) {
            $community = $script:CommunityBox.Text.Trim()
        } elseif ($script:CurrentSettings -and $script:CurrentSettings.Community) {
            $community = [string]$script:CurrentSettings.Community
        }
        $regionSel = "中壢區"
        if ($script:RegionCombo -and $script:RegionCombo.SelectedItem) {
            $regionSel = [string]$script:RegionCombo.SelectedItem
        } elseif ($script:CurrentSettings -and $script:CurrentSettings.GoogleRegion) {
            $regionSel = [string]$script:CurrentSettings.GoogleRegion
        }
        $url = Get-GoogleUrlForRegion $regionSel
        if ($script:SheetBox -and $script:SheetBox.Text.Trim()) { $sheet = $script:SheetBox.Text.Trim() }
        if ($script:ChkGoogle) { $doUpload = [bool]$script:ChkGoogle.Checked }
        elseif ($script:CurrentSettings) { $doUpload = [bool]$script:CurrentSettings.GoogleSheetsEnabled }
        if ($ForceUpload) { $doUpload = $true }
        if ($SkipUpload) { $doUpload = $false }
    } else {
        if (-not $script:CurrentSettings) {
            Write-PqtLog "沒有已儲存的設定，略過排程查詢" "WARN"
            return
        }
        $s = $script:CurrentSettings
        $ips = @(Get-IpListFromText $s.IPs)
        if ($s.Community) { $community = [string]$s.Community }
        $url = Get-GoogleUrlForRegion ([string]$s.GoogleRegion)
        if ($s.GoogleSheetName) { $sheet = [string]$s.GoogleSheetName }
        $doUpload = [bool]$s.GoogleSheetsEnabled
    }

    if ($ips.Count -eq 0) {
        Write-PqtLog "沒有可查詢的 IP" "WARN"
        if ($Interactive) {
            [Windows.Forms.MessageBox]::Show("請先在「設備設定」填寫設備 IP（每行一個）。", "PQT007") | Out-Null
        }
        return
    }

    $work = @{
        Ips       = $ips
        Community = $community
        Url       = $url
        SheetName = $sheet
        DoUpload  = $doUpload
        LogPath   = $script:LogPath
        Columns   = $script:Columns
        FuncText  = Get-QueryFunctionText
    }

    $script:QueryBusy = $true
    $script:QueryInteractive = [bool]$Interactive
    Update-QueryButtonState
    Write-PqtLog ("開始 SNMP 查詢，共 {0} 台" -f $ips.Count)

    $rs = $null
    $ps = $null
    try {
        $rs = [RunspaceFactory]::CreateRunspace()
        $rs.ApartmentState = "STA"
        $rs.ThreadOptions = "ReuseThread"
        $rs.Open()
        $ps = [PowerShell]::Create()
        $ps.Runspace = $rs
        $script:QueryPs = $ps
        $worker = {
            param($Work)
            $ErrorActionPreference = "Continue"
            $script:WorkerLogs = New-Object System.Collections.Generic.List[string]
            $script:WorkerLogPath = $Work.LogPath
            $script:Columns = $Work.Columns
            function Write-PqtLog {
                param([string]$Message, [string]$Level = "INFO")
                $Message = [regex]::Replace([string]$Message, 'https://script\.google\.com/macros/s/[A-Za-z0-9_-]+/(?:exec|dev)', '[已隱藏]')
                $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
                try {
                    $enc = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::AppendAllText($script:WorkerLogPath, $line + [Environment]::NewLine, $enc)
                } catch {}
                [void]$script:WorkerLogs.Add($line)
            }
            Invoke-Expression $Work.FuncText
            $results = Invoke-SnmpPrinterQueryCore -IpList $Work.Ips -Community $Work.Community
            $upload = $null
            if ($Work.DoUpload) {
                $upload = Send-ToGoogleSheets -Results @($results) -WebAppUrl $Work.Url -SheetName $Work.SheetName
            } else {
                Write-PqtLog "Google 上傳未啟用，略過上傳。" "WARN"
            }
            return @{
                Results = @($results)
                Upload  = $upload
                Logs    = @($script:WorkerLogs)
            }
        }
        [void]$ps.AddScript($worker).AddArgument($work)
        $script:QueryHandle = $ps.BeginInvoke()
    } catch {
        $script:QueryBusy = $false
        $script:QueryHandle = $null
        $script:QueryPs = $null
        try { if ($ps) { $ps.Dispose() } } catch {}
        try { if ($rs) { $rs.Dispose() } } catch {}
        Update-QueryButtonState
        Write-PqtLog ("無法啟動背景查詢：{0}" -f $_.Exception.Message) "ERROR"
        if ($Interactive) { Show-ErrorBox $_.Exception.Message }
    }
}

function Complete-PqtQueryIfDone {
    if (-not $script:QueryHandle) { return }
    if (-not $script:QueryHandle.IsCompleted) { return }

    $interactive = $script:QueryInteractive
    $ps = $script:QueryPs
    $handle = $script:QueryHandle
    $script:QueryHandle = $null
    $script:QueryPs = $null

    $okMsg = ""
    try {
        $output = $ps.EndInvoke($handle)
        if ($ps.Streams.Error) {
            foreach ($err in $ps.Streams.Error) {
                Write-PqtLog ([string]$err) "ERROR"
            }
        }
        $data = $output | Select-Object -Last 1
        if ($data -and $data.Logs) {
            foreach ($line in @($data.Logs)) {
                if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) {
                    $script:UiLogBox.AppendText($line + [Environment]::NewLine)
                }
            }
            if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) {
                $script:UiLogBox.SelectionStart = $script:UiLogBox.Text.Length
                $script:UiLogBox.ScrollToCaret()
            }
        }
        $count = 0
        if ($data -and $data.Results) {
            $count = @($data.Results).Count
            Show-QueryResults -Results $data.Results
            if ($interactive -and $script:TabControl -and -not $script:TabControl.IsDisposed) {
                $script:TabControl.SelectedIndex = 0
            }
        }
        $uploadText = "略過"
        if ($data -and $data.Upload) {
            if ($data.Upload.Ok) {
                $uploadText = "成功"
                Write-PqtLog ("Google 試算表上傳成功：{0}" -f $data.Upload.Message) "SUCCESS"
            } else {
                $uploadText = "失敗"
                Write-PqtLog ("Google 試算表上傳失敗：{0}" -f $data.Upload.Message) "ERROR"
            }
        }
        $okMsg = "查詢完成，共 $count 台。Google 上傳：$uploadText"
        Write-PqtLog $okMsg
        if ($script:PendingPeriodKey) {
            Save-LastFiredPeriod $script:PendingPeriodKey
        } elseif ($script:CurrentSettings) {
            $due = Get-DueScheduleAction
            if ($due) { Save-LastFiredPeriod $due.FireKey }
        }
        $script:PendingPeriodKey = $null
        Update-NextRunLabel
    } catch {
        Write-PqtLog ("查詢結束時發生錯誤：{0}" -f $_.Exception.Message) "ERROR"
        $okMsg = $_.Exception.Message
        $script:PendingPeriodKey = $null
    } finally {
        try { if ($ps.Runspace) { $ps.Runspace.Dispose() } } catch {}
        try { $ps.Dispose() } catch {}
        $script:QueryBusy = $false
        Update-QueryButtonState
    }

    if ($interactive -and $okMsg) {
        [Windows.Forms.MessageBox]::Show($okMsg, "PQT007") | Out-Null
    }
}

function Invoke-ScheduleCheck {
    if (-not $script:CurrentSettings) { return }
    if (-not [bool]$script:CurrentSettings.UnattendedEnabled) { return }
    if ($script:QueryBusy) {
        Write-PqtLog "排程時間已到但查詢仍在進行，稍後再試" "WARN"
        return
    }
    $due = Get-DueScheduleAction
    if (-not $due) {
        Update-NextRunLabel
        return
    }
    $script:PendingPeriodKey = [string]$due.FireKey
    $kind = if ($due.CatchUp) { "補查" } else { "排程" }
    Write-PqtLog ("{0}觸發（{1}，{2}），開始查詢並上傳" -f $kind, $due.FireKey, $due.Reason)
    Start-PqtQueryAsync
    if (-not $script:QueryBusy -and -not $script:QueryHandle) {
        $script:PendingPeriodKey = $null
    }
    Update-NextRunLabel
}

function Get-SpoolerSnapshot {
    $svc = Get-Service -Name spooler -ErrorAction SilentlyContinue
    $status = if ($svc) { [string]$svc.Status } else { "找不到服務" }
    $fileCount = 0
    if (Test-Path $spoolFolder) {
        $fileCount = @(Get-ChildItem $spoolFolder -Force -ErrorAction SilentlyContinue).Count
    }
    $printers = @()
    $jobCount = 0
    try {
        $printers = @(Get-Printer -ErrorAction Stop)
        foreach ($p in $printers) {
            if ($null -ne $p.JobCount) { $jobCount += [int]$p.JobCount }
        }
    } catch {
        try { $printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop) } catch { $printers = @() }
    }
    [PSCustomObject]@{
        SpoolerStatus = $status
        QueueFiles    = $fileCount
        PrinterCount  = @($printers).Count
        JobCount      = $jobCount
        IsAdmin       = Test-IsAdmin
    }
}

function Invoke-ReleasePrintServer {
    Write-PqtLog "開始釋放列印伺服器（停止服務 → 清除佇列 → 重啟）"
    $svc = Get-Service -Name spooler -ErrorAction Stop
    if ($svc.Status -ne "Stopped") {
        Stop-Service -Name spooler -Force -ErrorAction Stop
        Write-PqtLog "已停止 Print Spooler"
    } else {
        Write-PqtLog "Print Spooler 已是停止狀態"
    }
    Start-Sleep -Milliseconds 400
    $cleared = 0
    if (Test-Path $spoolFolder) {
        $files = @(Get-ChildItem $spoolFolder -Force -ErrorAction SilentlyContinue)
        foreach ($f in $files) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $cleared++
            } catch {
                Write-PqtLog "無法刪除 $($f.Name)：$($_.Exception.Message)" "WARN"
            }
        }
    }
    $left = @(Get-ChildItem $spoolFolder -Force -ErrorAction SilentlyContinue).Count
    Write-PqtLog "已清除佇列檔 $cleared 個，剩餘 $left 個"
    Start-Service -Name spooler -ErrorAction Stop
    Start-Sleep -Milliseconds 500
    $after = Get-Service -Name spooler
    Write-PqtLog "Print Spooler 現在狀態：$($after.Status)"
    if ($after.Status -ne "Running") {
        throw "Print Spooler 未能成功啟動，目前狀態：$($after.Status)"
    }
    return $true
}

function Invoke-RestartSpoolerOnly {
    Write-PqtLog "只重啟 Print Spooler（不刪佇列檔）"
    Restart-Service -Name spooler -Force -ErrorAction Stop
    Start-Sleep -Milliseconds 400
    $after = Get-Service -Name spooler
    Write-PqtLog "Print Spooler 現在狀態：$($after.Status)"
    if ($after.Status -ne "Running") {
        throw "Print Spooler 未能成功啟動，目前狀態：$($after.Status)"
    }
}

function Invoke-CancelAllPrintJobs {
    Write-PqtLog "取消所有印表機的列印工作"
    $cancelled = 0
    $printers = @(Get-Printer -ErrorAction Stop)
    foreach ($p in $printers) {
        try {
            $jobs = @(Get-PrintJob -PrinterName $p.Name -ErrorAction SilentlyContinue)
            foreach ($job in $jobs) {
                Remove-PrintJob -InputObject $job -ErrorAction SilentlyContinue
                $cancelled++
            }
        } catch {
            try {
                $w = Get-CimInstance Win32_Printer | Where-Object { $_.Name -eq $p.Name }
                if ($w) { [void](Invoke-CimMethod -InputObject $w -MethodName CancelAllJobs) }
            } catch {}
        }
    }
    Write-PqtLog "已送出取消：$cancelled 筆工作"
}

function Get-HostExe {
    $proc = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($proc -and ($proc -like "*.exe")) { return $proc }
    return "powershell.exe"
}

function Invoke-MaybeElevated {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("ReleaseSpooler", "RestartSpooler", "CancelAllJobs")]
        [string]$Name
    )
    if (Test-IsAdmin) {
        switch ($Name) {
            "ReleaseSpooler" { Invoke-ReleasePrintServer }
            "RestartSpooler" { Invoke-RestartSpoolerOnly }
            "CancelAllJobs" { Invoke-CancelAllPrintJobs }
        }
        return
    }
    Write-PqtLog "需要系統管理員權限，即將跳出 UAC..."
    $exe = Get-HostExe
    try {
        if ($exe -like "*powershell.exe" -or $exe -like "*pwsh.exe") {
            $p = Start-Process -FilePath $exe -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-STA",
                "-File", $scriptFile, "-Action", $Name
            ) -Verb RunAs -Wait -PassThru
        } else {
            $p = Start-Process -FilePath $exe -ArgumentList @("-Action", $Name) -Verb RunAs -Wait -PassThru
        }
    } catch {
        throw "已取消系統管理員權限，無法釋放列印伺服器"
    }
    if (-not $p) {
        throw "已取消系統管理員權限，無法釋放列印伺服器"
    }
    if ($p.ExitCode -ne 0) {
        throw "提升權限後的動作失敗（結束代碼 $($p.ExitCode)）。詳見 PQT.log"
    }
    Write-PqtLog "已完成提升權限動作：$Name"
}

function Invoke-ReleaseFromUi {
    if (-not (Confirm-Danger "釋放列印伺服器" "將會：`r`n`r`n1. 停止 Print Spooler`r`n2. 清除所有卡住的列印佇列檔`r`n3. 重新啟動服務`r`n`r`n進行中的列印會中斷。確定執行？")) {
        return
    }
    Invoke-MaybeElevated -Name ReleaseSpooler
    Update-StatusPanel
    Update-PrinterList
    [Windows.Forms.MessageBox]::Show("列印伺服器已釋放，Print Spooler 已重新啟動。", "完成") | Out-Null
}

function Get-PrinterRows {
    $rows = @()
    try {
        foreach ($p in @(Get-Printer -ErrorAction Stop)) {
            $rows += [PSCustomObject]@{
                Name    = $p.Name
                Status  = [string]$p.PrinterStatus
                Jobs    = $p.JobCount
                Port    = $p.PortName
                Driver  = $p.DriverName
                Default = $p.Default
                Shared  = $p.Shared
            }
        }
    } catch {
        foreach ($p in @(Get-CimInstance Win32_Printer)) {
            $rows += [PSCustomObject]@{
                Name    = $p.Name
                Status  = [string]$p.PrinterStatus
                Jobs    = $p.JobCountSinceLastReset
                Port    = $p.PortName
                Driver  = $p.DriverName
                Default = [bool]$p.Default
                Shared  = [bool]$p.Shared
            }
        }
    }
    return $rows
}

function Get-SelectedPrinterName {
    if (-not $script:PrinterList -or $script:PrinterList.SelectedItems.Count -eq 0) {
        throw "請先在清單中選一台印表機"
    }
    return $script:PrinterList.SelectedItems[0].Text
}

function Get-CimPrinter {
    param([string]$Name)
    $p = Get-CimInstance Win32_Printer | Where-Object { $_.Name -eq $Name }
    if (-not $p) { throw "找不到印表機：$Name" }
    return $p
}

function Test-TcpPortFast {
    param([string]$Ip, [int]$Port, [int]$TimeoutMs = 1500)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($Ip, $Port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return $false
        }
        $client.EndConnect($ar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-CurrentIpText {
    $ip = ""
    if ($script:NetIpBox) { $ip = $script:NetIpBox.Text.Trim() }
    if ([string]::IsNullOrWhiteSpace($ip)) { throw "請輸入印表機 IP" }
    return $ip
}

function Update-StatusPanel {
    $s = Get-SpoolerSnapshot
    $adminText = if ($s.IsAdmin) { "系統管理員" } else { "一般使用者（釋放／重啟服務需要 UAC）" }
    $theme = $null
    try { $theme = Get-ActivePqtTheme } catch {}
    $color = if ($s.SpoolerStatus -eq "Running") {
        if ($theme) { $theme.Ok } else { [Drawing.Color]::DarkGreen }
    } else {
        if ($theme) { $theme.Error } else { [Drawing.Color]::Firebrick }
    }
    $text = @"
Print Spooler：$($s.SpoolerStatus)
佇列檔案：$($s.QueueFiles)　列印工作：$($s.JobCount)　本機印表機：$($s.PrinterCount)
權限：$adminText
"@
    if ($script:StatusLabel -and -not $script:StatusLabel.IsDisposed) {
        $script:StatusLabel.Text = $text
        $script:StatusLabel.ForeColor = $color
    }
}

function Update-PrinterList {
    if (-not $script:PrinterList) { return }
    $script:PrinterList.Items.Clear()
    foreach ($r in (Get-PrinterRows)) {
        $item = New-Object Windows.Forms.ListViewItem($r.Name)
        [void]$item.SubItems.Add([string]$r.Status)
        [void]$item.SubItems.Add([string]$r.Jobs)
        [void]$item.SubItems.Add([string]$r.Port)
        [void]$item.SubItems.Add($(if ($r.Default) { "是" } else { "" }))
        [void]$item.SubItems.Add($(if ($r.Shared) { "是" } else { "" }))
        [void]$item.SubItems.Add([string]$r.Driver)
        [void]$script:PrinterList.Items.Add($item)
    }
}

function Update-LocalIpLabel {
    if (-not $script:LocalIpLabel) { return }
    try {
        $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
            Select-Object -ExpandProperty IPAddress
        $script:LocalIpLabel.Text = "本機 IPv4：" + (($addrs | Select-Object -Unique) -join "  /  ")
    } catch {
        $script:LocalIpLabel.Text = "本機 IPv4：（無法讀取）"
    }
}

function Refresh-NetIpCombo {
    if (-not $script:NetIpBox) { return }
    $current = $script:NetIpBox.Text
    $script:NetIpBox.Items.Clear()
    foreach ($ip in (Get-AppIpList)) { [void]$script:NetIpBox.Items.Add($ip) }
    if ($current -and $script:NetIpBox.Items.Contains($current)) {
        $script:NetIpBox.Text = $current
    } elseif ($script:NetIpBox.Items.Count -gt 0 -and [string]::IsNullOrWhiteSpace($script:NetIpBox.Text)) {
        $script:NetIpBox.SelectedIndex = 0
    }
}

function Confirm-Danger {
    param([string]$Title, [string]$Text)
    $r = [Windows.Forms.MessageBox]::Show(
        $Text, $Title,
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    return $r -eq [Windows.Forms.DialogResult]::Yes
}

function Show-ErrorBox {
    param([string]$Text)
    $Text = Protect-SecretText $Text
    [Windows.Forms.MessageBox]::Show(
        $Text, "PQT007",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Get-PqtChangelogText {
    $text = @"
PQT007　　目前版本 $($script:AppVersion)

【4.1.21】
• 排程抄表改為連續三天都執行：抄表日前一天、當天、後一天各查一次（例：15 號→14、15、16；1 號→上月最後一天 30／31、1、2）

【4.1.20】
• 新增 Sharp MX-2600／MX-3600／MX-4100（含 N／FN）黑白、彩色合計抄表
• 改讀 Sharp 私有 MIB：黑白 Total .3.5.4.61、彩色 Total .3.5.4.63（影印+列印）
• 全錄／FUJIFILM：補 DocuPrint 偵測；ApeosPrint 3960 S（黑白）與 ApeosPrint C3060 S（彩色）張數
• 修正 ApeosPort C3060 被誤判成黑白；彩色讀 .20.33／黑白讀 .20.34（Xerox MIB）

【4.1.19】
• 修正理光 MP C5504ex 讀不到碳粉、MP 6054／5054／3555／6055 讀不到黑色碳粉
• 理光碳粉先依私有 MIB 碳粉名稱找槽位，讀不到再改用標準 Printer-MIB
• 理光 -100 顯示「即將用完」，-3「尚有餘量」，-2「未知」

【4.1.18】
• 修正 FUJI XEROX／FUJIFILM（全錄）碳粉餘量：改依槽位名稱對應顏色（英／中／日文、[K][C][M][Y]），不再寫死槽位
• 修正全錄碳粉顯示成 6120 %、13440 % 等錯誤數字：改用 餘量÷最大容量 換算百分比（限 0～100）；機器沒回報容量時顯示「剩約 N 頁」
• 全錄碳粉，跳過廢粉盒／感光鼓／定影器，-3 顯示「尚有餘量」、-2 顯示「未知」

【4.1.17】
• 新增 Konica Minolta（美樂達）bizhub C360i／C300i／C250i 等抄表：黑白、彩色合計（影印＋列印）
• 美樂達碳粉餘量（黑／青／洋紅／黃）依標準 Printer-MIB 槽位描述對應，換算百分比

【4.1.16】
• 版本更新頁的說明改為逐行顯示

【4.1.14】
• FUJI XEROX／FUJIFILM 設備位置改優先用 Shift-JIS（932）解碼
• 解碼結果含造字區或替代字視為失敗，避免 Big5 誤吃 Xerox 中文
• 依型號／sysObjectID 判斷廠牌後再選編碼
• 亂碼字串用系統 Big5 回推原始位元組，再改以 UTF-8／932 解
• SNMP 原始讀取改試 v1／v2c，並解析回應中的 OctetString
• 修正 SNMP 回應 byte 陣列判斷例外（位置讀不到原始位元組）
• 背景查詢補上 Xerox 解碼函式（先前 worker 沒載入，位置一直用亂碼）

【4.1.13】
• RICOH 黑白影印機（MP／IM／SP，數字前沒有 C）改讀總張數
• 設備位置改讀 SNMP 原始位元組，修正部分機型中文亂碼

【4.1.12】
• 版本更新頁可開／關自動更新；開啟後每次啟動會檢查並安裝新版

【4.1.11】
• 抄表日遇周六日不查，下次平日開機後自動啟動查詢

【4.1.10】
• 修正抄表窗口：15→14～16；30日小月→29、30、次月1；31日大月→30、31、次月1

【4.1.9】
• 主題樣式改放在「版本更新」頁

【4.1.8】
• 可選主題：預設淺色、晴空藍、石墨深色、薄荷綠、暮光橘、夜櫻紫

【4.1.7】
• 程式標籤改為 PQT007

【4.1.6】
• 開機自動執行時，程式直接縮到右下角系統匣，不跳出視窗

【4.1.5】
• 立即查詢加上查詢時間，結果可累積；可清除畫面紀錄
• 標明立即查詢張數只查詢不上傳

【4.1.4】
• 第一次執行會安裝到 C:\FLGPQT，之後從該資料夾啟動

【4.1.3】
• 分頁順序：時間設定、設備設定、釋放列印、印表機、網路檢測、常用捷徑、關於本公司、版本更新

【4.1.2】
• 「版本更新」一鍵下載並直接取代程式，完成後自動重開
• 畫面不顯示更新網址

【4.1.1】
• 檢查更新改為線上比對版本

【4.1.0】
• 報修專區改為「關於本公司」
• 新增「版本更新」：版本說明與檢查更新

【4.0.0】
• 單一 PQT.exe，第一次執行自動產生設定檔
• 縮小到系統匣；右鍵可顯示介面、釋放列印伺服器、結束
• 查詢張數顯示：設備 IP、設備位置、黑白合計、彩色合計
• 排程：每月或指定月份、每月幾日、幾點
• 抄表窗口：15日→14、15、16；30日小月→29、30、次月1；31日大月→30、31、次月1
• 遇周六日不查，平日開機後自動補查
• 遇周末假日或關機錯過，開機後自動補查
• 可勾選「開機自動執行」
• 釋放列印伺服器、印表機、網路檢測、常用捷徑
• 關於本公司：富利久有限公司聯絡方式與官方 LINE
"@
    # WinForms TextBox 只把 CRLF 當成換行；指令檔是 LF，不轉會整段黏成一行
    return ($text -replace "(?<!\r)\n", "`r`n")
}

function ConvertTo-PqtVersion {
    param([string]$Text)
    $t = ([string]$Text).Trim()
    if ($t -match '(\d+\.\d+(?:\.\d+)?)') {
        try { return [version]$Matches[1] } catch {}
    }
    return $null
}

function Get-PqtRemoteVersionInfo {
    param([string]$JsonUrl)
    $headers = @{ "User-Agent" = "PQT-FLGPQT" }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not [string]::IsNullOrWhiteSpace($JsonUrl)) {
        try {
            $resp = Invoke-WebRequest -Uri $JsonUrl -Headers $headers -UseBasicParsing -TimeoutSec 20
            $info = $resp.Content | ConvertFrom-Json
            $ver = ConvertTo-PqtVersion ([string]$info.version)
            if ($ver) {
                $dl = [string]$info.url
                if ([string]::IsNullOrWhiteSpace($dl)) { $dl = $script:DefaultDownloadUrl }
                return @{ Version = $ver; Url = $dl; Notes = [string]$info.notes }
            }
        } catch {}
    }
    $resp = Invoke-WebRequest -Uri $script:GitHubCommitsApi -Headers $headers -UseBasicParsing -TimeoutSec 20
    $c = $resp.Content | ConvertFrom-Json
    $msg = [string]$c.commit.message
    $ver = ConvertTo-PqtVersion $msg
    if (-not $ver) { throw "GitHub 上找不到 version.json，也無法從提交說明讀取版本號" }
    return @{ Version = $ver; Url = $script:DefaultDownloadUrl; Notes = $msg }
}

function Test-PqtExeFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -lt 20000) { return $false }
    $fs = [IO.File]::OpenRead($Path)
    try {
        $mz = New-Object byte[] 2
        [void]$fs.Read($mz, 0, 2)
        return ($mz[0] -eq 0x4D -and $mz[1] -eq 0x5A)
    } finally { $fs.Close() }
}

function Install-PqtDownloadedExe {
    param([string]$DownloadedPath)
    $dir = $script:InstallDir
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        if (Test-IsAdmin) { Set-PqtInstallDirAcl $dir }
    }
    $target = Join-Path $dir "PQT.exe"
    $old = Join-Path $dir "PQT.exe.old"
    if (Test-Path -LiteralPath $old) {
        try { Remove-Item -LiteralPath $old -Force } catch {}
    }
    if (Test-Path -LiteralPath $target) {
        Rename-Item -LiteralPath $target -NewName "PQT.exe.old"
    }
    Copy-Item -LiteralPath $DownloadedPath -Destination $target -Force
    try { Remove-Item -LiteralPath $DownloadedPath -Force } catch {}
    $cmd = "/c timeout /t 2 /nobreak >nul & start `"`" `"$target`""
    Start-Process -FilePath (Join-Path $env:SystemRoot "System32\cmd.exe") -ArgumentList $cmd -WindowStyle Hidden
    Close-PqtApp
}

function Invoke-PqtUpdateCheck {
    param([switch]$Auto)
    if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = "正在檢查更新..." }
    try {
        $info = Get-PqtRemoteVersionInfo -JsonUrl $script:DefaultUpdateUrl
        $remote = $info.Version
        $local = ConvertTo-PqtVersion $script:AppVersion
        $notes = [string]$info.Notes
        $dl = [string]$info.Url
        if (-not $dl) { $dl = $script:DefaultDownloadUrl }
        if ($remote -le $local) {
            $text = "已是最新版本 {0}" -f $local
            if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = $text }
            Write-PqtLog $text
            if (-not $Auto) {
                [Windows.Forms.MessageBox]::Show($text, "版本更新") | Out-Null
            }
            return
        }
        $text = "有新版本 {0}（目前 {1}）" -f $remote, $local
        if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = $text }
        Write-PqtLog $text
        if (-not $Auto) {
            $body = $text + "`r`n`r`n將下載並取代目前程式，完成後自動重新啟動。"
            if ($notes) { $body += "`r`n`r`n" + $notes }
            $r = [Windows.Forms.MessageBox]::Show(($body + "`r`n`r`n確定更新？"), "版本更新", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
            if ($r -ne [Windows.Forms.DialogResult]::Yes) {
                if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = "已取消更新" }
                return
            }
        } else {
            Write-PqtLog ("自動更新：下載 {0}" -f $remote)
            if ($script:NotifyIcon) {
                try { $script:NotifyIcon.ShowBalloonTip(4000, "PQT007", "發現新版本，正在自動更新", [Windows.Forms.ToolTipIcon]::Info) } catch {}
            }
        }
        if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = "正在下載新版本..." }
        $tmp = Join-Path $env:TEMP ("PQT_update_" + [guid]::NewGuid().ToString("N") + ".exe")
        $ProgressPreference = "SilentlyContinue"
        $headers = @{ "User-Agent" = "PQT-FLGPQT" }
        Invoke-WebRequest -Uri $dl -Headers $headers -OutFile $tmp -UseBasicParsing -TimeoutSec 120
        if (-not (Test-PqtExeFile $tmp)) {
            try { Remove-Item -LiteralPath $tmp -Force } catch {}
            throw "下載的檔案不是有效的程式，請稍後再試"
        }
        if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = "正在取代程式並重新啟動..." }
        Write-PqtLog ("已下載新版本 {0}，即將重新啟動" -f $remote)
        Install-PqtDownloadedExe -DownloadedPath $tmp
    } catch {
        $err = $_.Exception.Message
        if ($script:UpdateResultLabel) { $script:UpdateResultLabel.Text = "更新失敗：$err" }
        Write-PqtLog "版本更新失敗：$err" "ERROR"
        if (-not $Auto) {
            Show-ErrorBox "版本更新失敗：`r`n$err"
        }
    }
}

function Get-LineQrImage {
    if ($script:LineQrImage) { return $script:LineQrImage }
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($n in @("LINE-QR.png", "line_qr.png")) {
        $files.Add((Join-Path $scriptDir $n))
    }
    try {
        Get-ChildItem -LiteralPath $scriptDir -Filter "*.png" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match "報修|LINE-QR|line.qr|line_qr") { $files.Add($_.FullName) }
        }
    } catch {}
    function Convert-PqtPngBytes {
        param([byte[]]$Bytes)
        $ms = New-Object IO.MemoryStream (, $Bytes)
        $tmp = [Drawing.Image]::FromStream($ms)
        $bmp = New-Object Drawing.Bitmap $tmp.Width, $tmp.Height, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        $g.Clear([Drawing.Color]::White)
        $g.DrawImage($tmp, 0, 0, $tmp.Width, $tmp.Height)
        $g.Dispose()
        $tmp.Dispose()
        $ms.Dispose()
        return $bmp
    }
    foreach ($p in $files) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        try {
            $bytes = [IO.File]::ReadAllBytes($p)
            $script:LineQrImage = Convert-PqtPngBytes $bytes
            return $script:LineQrImage
        } catch {}
    }
    $b64 = "iVBORw0KGgoAAAANSUhEUgAAAWgAAAFoCAYAAAB65WHVAAAIqElEQVR4nO3cQW7kOBQFwdag739lzQUGowVB/CQrYm+XSrITWjzwed/3/QNAzj/TFwDAfxNogCiBBogSaIAogQaIEmiAKIEGiBJogCiBBogSaIAogQaIEmiAKIEGiBJogCiBBogSaIAogQaIEmiAKIEGiBJogCiBBogSaIAogQaIEmiAKIEGiBJogCiBBogSaIAogQaIEmiAKIEGiPo7fQHP8/y52fu+R9+/3dc//f2/vt/X71/9+d1u/367Tf/9e4MGiBJogCiBBogSaIAogQaIEmiAKIEGiBrfQdd3iF9Wd6CrO9TpnerpO9rV66/vlKfVr++J77i9QQNECTRAlEADRAk0QJRAA0QJNECUQANE5XfQX5yHfPd5w9M77Omd7PT92e3X/3+/eIMGiBJogCiBBogSaIAogQaIEmiAKIEGiDp+B017R7t7J736/U7fcd++A/513qABogQaIEqgAaIEGiBKoAGiBBogSqABouyg41bPy50+z3h6h3z69/+y+/7YUc/yBg0QJdAAUQINECXQAFECDRAl0ABRAg0QdfwO2k5z9v7Vd8a375RXP3+a/9//5w0aIEqgAaIEGiBKoAGiBBogSqABogQaICq/g67vOG8/L3l1p1q//t074+nrnz4v+9f/f1d5gwaIEmiAKIEGiBJogCiBBogSaIAogQaIGt9B//p5sNM71dOf3/RO+PadeP35384bNECUQANECTRAlEADRAk0QJRAA0QJNEDU+A561e6d5/QOeffOdHrHuvv51M+Drpu+v7vVn483aIAogQaIEmiAKIEGiBJogCiBBogSaICo5x0eAk7vmKfP0z19p3r7znz6/pxu9/N9L39+3qABogQaIEqgAaIEGiBKoAGiBBogSqABovI76FW373Tr9/fXd+j153v659/OGzRAlEADRAk0QJRAA0QJNECUQANECTRA1PgOun5e9PR5tKvij3fc9POv78Cn/36/TJ8Xv5s3aIAogQaIEmiAKIEGiBJogCiBBogSaICov9MXML2zPH1HXd/R1u/fr+/8v35//e/ziT/fVd6gAaIEGiBKoAGiBBogSqABogQaIEqgAaLGd9Cn72x374ind6C7d7q7v9/0Tnz395veAZ9+f9/4eeneoAGiBBogSqABogQaIEqgAaIEGiBKoAGirt9Br6rvTKd30vXzjnfbfd5y3ek7/Dpv0ABRAg0QJdAAUQINECXQAFECDRAl0ABRzxsfEp5+HvDunWj88Y27/e/n9Oub9sSv3xs0QJRAA0QJNECUQANECTRAlEADRAk0QNT4Drq+E969o939+V+md55fpne8u+2+/9M7XzvuNd6gAaIEGiBKoAGiBBogSqABogQaIEqgAaKO30FP72BXz+Ndtfvzp3//l1/f+dZ33NN//6fzBg0QJdAAUQINECXQAFECDRAl0ABRAg0Q9Xf6AqZ3sKs7zl/fwd6+o979+aff//rOvr6j/+INGiBKoAGiBBogSqABogQaIEqgAaIEGiBqfAe9avdOcXoHOX2e7vTnT+9Yd+/Yd5ve2U+fx/1l+vl88QYNECXQAFECDRAl0ABRAg0QJdAAUQINEPW89SHgovp5tfXfP319q3bvlKd34tP3f/o88jd+f1Z5gwaIEmiAKIEGiBJogCiBBogSaIAogQaIGj8P+vQd7ur1nb5z3v39p6/v9vPGV00/n9vvrzdogCiBBogSaIAogQaIEmiAKIEGiBJogKjxHfT0TvX083x3m96p7n7+09/vy/Tfx/T3fzffv/pO2hs0QJRAA0QJNECUQANECTRAlEADRAk0QNTzDg8B6zvF06/vy+7rv/084F/f0U/v2FfVr88bNECUQANECTRAlEADRAk0QJRAA0QJNEDU+HnQ9Z3i6Tvd+o62vmP2fNbu3+r9XzW9Y17lDRogSqABogQaIEqgAaIEGiBKoAGiBBoganwHvbpT3H3e8NfP777+afXzfqfvX30nffqO/xn+/57mDRogSqABogQaIEqgAaIEGiBKoAGiBBoganwHPb1jPf36d+9cd//89M63/vPTTj9P/HTeoAGiBBogSqABogQaIEqgAaIEGiBKoAGinrc+xLzc6TvZ6fOIv0yf110/73y3+v1/4v9/3qABogQaIEqgAaIEGiBKoAGiBBogSqABosZ30NM72Onzfus71fr1rao/v+nvP+2NP//dvEEDRAk0QJRAA0QJNECUQANECTRAlEADRP2dvoDpneHq509f/26nn2e8+/lMn3e8e8c7vUN+Dv9+q7xBA0QJNECUQANECTRAlEADRAk0QJRAA0SN76Dr59Guun2H+/X59e9/+t/n9HnV9fOUT+cNGiBKoAGiBBogSqABogQaIEqgAaIEGiBqfAf9pb6j3L0znT4veXpHu/vn6zvz1d8//fez6l28/t0/v5s3aIAogQaIEmiAKIEGiBJogCiBBogSaICo/A769B3s6u+f3rmu2r0z3X1/Tr9/9Z15/fOneYMGiBJogCiBBogSaIAogQaIEmiAKIEGiDp+B81v76xvv3/T5xHXz8N+F69v+v5+8QYNECXQAFECDRAl0ABRAg0QJdAAUQINEGUHPWz3eb1fO8/pHejq97/9PORpu5/P7s9/hq9/lTdogCiBBogSaIAogQaIEmiAKIEGiBJogKjjd9DTO8Xbr3/3ecW371ynd+5fps+r/vWd+Rdv0ABRAg0QJdAAUQINECXQAFECDRAl0ABR+R20nWR7J3v687v9/u0+L7t+/e/w91/lDRogSqABogQaIEqgAaIEGiBKoAGiBBog6nnrBxID/Chv0ABRAg0QJdAAUQINECXQAFECDRAl0ABRAg0QJdAAUQINECXQAFECDRAl0ABRAg0QJdAAUQINECXQAFECDRAl0ABRAg0QJdAAUQINECXQAFECDRAl0ABRAg0QJdAAUQINECXQAFECDRAl0AB/mv4FwCzpy34wa2QAAAAASUVORK5CYII="
    $bytes = [Convert]::FromBase64String($b64)
    $script:LineQrImage = Convert-PqtPngBytes $bytes
    return $script:LineQrImage
}

function New-Btn {
    param($Text, $Width = 150, $Height = 36, $BackColor = $null, [scriptblock]$Click, [string]$Role = "")
    $b = New-Object Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object Drawing.Size($Width, $Height)
    $b.Margin = New-Object Windows.Forms.Padding(4)
    $b.UseVisualStyleBackColor = $false
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 1
    if ($BackColor) { $b.BackColor = $BackColor }
    $b.Tag = $Click
    if (-not $Role) {
        if ($BackColor -and $BackColor.G -gt $BackColor.R -and $BackColor.G -gt 180) { $Role = "primary" }
        elseif ($BackColor -and $BackColor.R -gt 240 -and $BackColor.G -gt 200 -and $BackColor.B -lt 200) { $Role = "warn" }
        elseif ($BackColor -and $BackColor.R -gt 230 -and $BackColor.G -gt 230 -and $BackColor.B -gt 230) { $Role = "muted" }
        else { $Role = "accent" }
    }
    $script:ThemeRoles[$b] = $Role
    $b.Add_Click({
        try {
            $handler = $this.Tag
            if ($handler) { & $handler }
        } catch {
            Write-PqtLog $_.Exception.Message "ERROR"
            Show-ErrorBox $_.Exception.Message
        }
    })
    return $b
}

function RGB {
    param([int]$R, [int]$G, [int]$B)
    [Drawing.Color]::FromArgb($R, $G, $B)
}

function Get-PqtThemeCatalog {
    [ordered]@{
        "預設淺色" = @{
            FormBg = (RGB 240 240 240); PanelBg = (RGB 240 240 240); Text = (RGB 30 30 30)
            Muted = (RGB 105 105 105); Accent = (RGB 210 230 255); AccentText = (RGB 20 70 140)
            Primary = (RGB 180 230 180); Warn = (RGB 255 220 180); BtnMuted = (RGB 236 236 236)
            ButtonText = (RGB 25 25 25); InputBg = (RGB 255 255 255); TabBg = (RGB 225 228 232)
            TabOn = (RGB 255 255 255); Border = (RGB 160 160 160); Ok = (RGB 20 120 50)
            Error = (RGB 178 34 34); LogBg = (RGB 255 255 255)
        }
        "晴空藍" = @{
            FormBg = (RGB 230 242 255); PanelBg = (RGB 230 242 255); Text = (RGB 18 48 88)
            Muted = (RGB 80 110 145); Accent = (RGB 160 205 245); AccentText = (RGB 10 70 150)
            Primary = (RGB 120 205 170); Warn = (RGB 255 205 140); BtnMuted = (RGB 210 225 240)
            ButtonText = (RGB 12 40 80); InputBg = (RGB 255 255 255); TabBg = (RGB 190 218 245)
            TabOn = (RGB 245 251 255); Border = (RGB 110 160 210); Ok = (RGB 0 120 90)
            Error = (RGB 180 40 50); LogBg = (RGB 248 252 255)
        }
        "石墨深色" = @{
            FormBg = (RGB 32 34 38); PanelBg = (RGB 40 42 48); Text = (RGB 228 230 235)
            Muted = (RGB 150 154 164); Accent = (RGB 70 120 180); AccentText = (RGB 140 190 240)
            Primary = (RGB 46 120 88); Warn = (RGB 170 110 50); BtnMuted = (RGB 58 62 70)
            ButtonText = (RGB 240 242 246); InputBg = (RGB 26 28 32); TabBg = (RGB 48 50 56)
            TabOn = (RGB 64 110 170); Border = (RGB 80 86 96); Ok = (RGB 110 200 140)
            Error = (RGB 230 90 90); LogBg = (RGB 24 26 30)
        }
        "薄荷綠" = @{
            FormBg = (RGB 232 248 240); PanelBg = (RGB 232 248 240); Text = (RGB 20 60 42)
            Muted = (RGB 70 115 95); Accent = (RGB 170 225 200); AccentText = (RGB 10 110 70)
            Primary = (RGB 140 215 170); Warn = (RGB 255 220 160); BtnMuted = (RGB 210 235 220)
            ButtonText = (RGB 16 50 36); InputBg = (RGB 255 255 255); TabBg = (RGB 200 232 214)
            TabOn = (RGB 245 255 250); Border = (RGB 110 170 140); Ok = (RGB 16 130 70)
            Error = (RGB 175 45 45); LogBg = (RGB 248 255 251)
        }
        "暮光橘" = @{
            FormBg = (RGB 255 244 232); PanelBg = (RGB 255 244 232); Text = (RGB 80 40 16)
            Muted = (RGB 140 95 55); Accent = (RGB 255 200 150); AccentText = (RGB 170 70 10)
            Primary = (RGB 255 186 120); Warn = (RGB 255 170 110); BtnMuted = (RGB 245 225 205)
            ButtonText = (RGB 70 35 10); InputBg = (RGB 255 252 247); TabBg = (RGB 245 220 190)
            TabOn = (RGB 255 248 240); Border = (RGB 210 150 90); Ok = (RGB 40 130 70)
            Error = (RGB 185 50 30); LogBg = (RGB 255 250 244)
        }
        "夜櫻紫" = @{
            FormBg = (RGB 36 28 48); PanelBg = (RGB 48 38 62); Text = (RGB 238 230 248)
            Muted = (RGB 170 155 190); Accent = (RGB 120 85 175); AccentText = (RGB 210 180 255)
            Primary = (RGB 80 130 100); Warn = (RGB 180 100 70); BtnMuted = (RGB 62 50 80)
            ButtonText = (RGB 245 240 255); InputBg = (RGB 28 22 38); TabBg = (RGB 52 42 68)
            TabOn = (RGB 110 75 165); Border = (RGB 100 80 130); Ok = (RGB 130 210 160)
            Error = (RGB 235 100 120); LogBg = (RGB 26 20 36)
        }
    }
}

function Get-ActivePqtTheme {
    $name = "預設淺色"
    if ($script:ThemeCombo -and $script:ThemeCombo.SelectedItem) {
        $name = [string]$script:ThemeCombo.SelectedItem
    } elseif ($script:CurrentSettings -and $script:CurrentSettings.Theme) {
        $name = [string]$script:CurrentSettings.Theme
    }
    $cat = Get-PqtThemeCatalog
    if ($cat.Contains($name)) { return $cat[$name] }
    return $cat["預設淺色"]
}

function Apply-PqtThemeToControl {
    param($Control, $Theme)
    if (-not $Control) { return }
    $role = $null
    if ($script:ThemeRoles.Contains($Control)) { $role = [string]$script:ThemeRoles[$Control] }
    $type = $Control.GetType().Name
    try {
        switch ($type) {
            "Form" { $Control.BackColor = $Theme.FormBg; $Control.ForeColor = $Theme.Text }
            "TabPage" { $Control.BackColor = $Theme.PanelBg; $Control.ForeColor = $Theme.Text }
            "Panel" { $Control.BackColor = $Theme.PanelBg; $Control.ForeColor = $Theme.Text }
            "Label" {
                if ($role -eq "status") { }
                elseif ($role -eq "hint") { $Control.ForeColor = $Theme.Ok }
                elseif ($role -eq "muted") { $Control.ForeColor = $Theme.Muted }
                elseif ($role -eq "accent") { $Control.ForeColor = $Theme.AccentText }
                else { $Control.ForeColor = $Theme.Text }
            }
            "Button" {
                $Control.UseVisualStyleBackColor = $false
                $Control.FlatStyle = "Flat"
                $Control.FlatAppearance.BorderSize = 1
                $bg = switch ($role) {
                    "primary" { $Theme.Primary }
                    "warn" { $Theme.Warn }
                    "muted" { $Theme.BtnMuted }
                    default { $Theme.Accent }
                }
                $Control.BackColor = $bg
                $Control.ForeColor = $Theme.ButtonText
                $Control.FlatAppearance.BorderColor = $Theme.Border
            }
            "TextBox" { $Control.BackColor = $Theme.InputBg; $Control.ForeColor = $Theme.Text }
            "ListView" { $Control.BackColor = $Theme.InputBg; $Control.ForeColor = $Theme.Text }
            "ComboBox" { $Control.BackColor = $Theme.InputBg; $Control.ForeColor = $Theme.Text }
            "CheckBox" { $Control.ForeColor = $Theme.Text; $Control.BackColor = $Theme.PanelBg }
            "RadioButton" { $Control.ForeColor = $Theme.Text; $Control.BackColor = $Theme.PanelBg }
            "NumericUpDown" { $Control.BackColor = $Theme.InputBg; $Control.ForeColor = $Theme.Text }
            "TabControl" { $Control.BackColor = $Theme.FormBg }
        }
    } catch {}
    foreach ($child in @($Control.Controls)) {
        Apply-PqtThemeToControl $child $Theme
    }
}

function Apply-PqtTheme {
    if (-not $script:MainForm -or $script:MainForm.IsDisposed) { return }
    $t = Get-ActivePqtTheme
    Apply-PqtThemeToControl $script:MainForm $t
    if ($script:UiLogBox -and -not $script:UiLogBox.IsDisposed) {
        $script:UiLogBox.BackColor = $t.LogBg
        $script:UiLogBox.ForeColor = $t.Text
    }
    if ($script:TabControl -and -not $script:TabControl.IsDisposed) {
        $script:TabControl.Invalidate()
    }
    try { Update-StatusPanel } catch {}
}

function Invoke-SilentAction {
    param([string]$Name)
    try {
        if (-not (Test-IsAdmin) -and $Name -ne "CancelAllJobs") {
            throw "此動作需要系統管理員權限"
        }
        switch ($Name) {
            "ReleaseSpooler" { Invoke-ReleasePrintServer }
            "RestartSpooler" { Invoke-RestartSpoolerOnly }
            "CancelAllJobs" { Invoke-CancelAllPrintJobs }
        }
        exit 0
    } catch {
        Write-PqtLog $_.Exception.Message "FATAL"
        try {
            [Windows.Forms.MessageBox]::Show(
                $_.Exception.Message, "釋放列印伺服器失敗",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        } catch {}
        exit 1
    }
}

function Show-PqtWindow {
    param([int]$TabIndex = -1)
    if (-not $script:MainForm -or $script:MainForm.IsDisposed) { return }
    $script:MainForm.Opacity = 1
    $script:MainForm.ShowInTaskbar = $true
    $script:MainForm.Show()
    $script:MainForm.WindowState = "Normal"
    $script:MainForm.Activate()
    [void]$script:MainForm.BringToFront()
    if ($TabIndex -ge 0 -and $script:TabControl) {
        $script:TabControl.SelectedIndex = $TabIndex
    }
}

function Hide-PqtToTray {
    if (-not $script:MainForm -or $script:MainForm.IsDisposed) { return }
    if ($script:MainForm.WindowState -eq "Minimized") {
        $script:MainForm.WindowState = "Normal"
    }
    $script:MainForm.ShowInTaskbar = $false
    $script:MainForm.Hide()
    if ($script:NotifyIcon) {
        $script:NotifyIcon.Visible = $true
        if (-not $script:HasShownBalloon) {
            try {
                $script:NotifyIcon.ShowBalloonTip(3000, "PQT007", "PQT007 已縮小到系統匣", [Windows.Forms.ToolTipIcon]::Info)
            } catch {}
            $script:HasShownBalloon = $true
        }
    }
}

function Close-PqtApp {
    $script:ReallyExit = $true
    try { if ($script:SchedTimer) { $script:SchedTimer.Stop() } } catch {}
    try { if ($script:UiTimer) { $script:UiTimer.Stop() } } catch {}
    if ($script:NotifyIcon) {
        try { $script:NotifyIcon.Visible = $false } catch {}
        try { $script:NotifyIcon.Dispose() } catch {}
        $script:NotifyIcon = $null
    }
    if ($script:MainForm -and -not $script:MainForm.IsDisposed) {
        $script:MainForm.Close()
    }
}

function Read-SettingsFromUi {
    $ips = ""
    if ($script:IpTextBox) { $ips = $script:IpTextBox.Text }
    $community = "public"
    if ($script:CommunityBox -and $script:CommunityBox.Text.Trim()) { $community = $script:CommunityBox.Text.Trim() }
    $region = "中壢區"
    if ($script:RegionCombo -and $script:RegionCombo.SelectedItem) { $region = [string]$script:RegionCombo.SelectedItem }
    $url = ""
    $sheet = "查詢結果"
    if ($script:SheetBox -and $script:SheetBox.Text.Trim()) { $sheet = $script:SheetBox.Text.Trim() }
    $googleOn = $true
    if ($script:ChkGoogle) { $googleOn = [bool]$script:ChkGoogle.Checked }
    $schedOn = $true
    if ($script:ChkSchedule) { $schedOn = [bool]$script:ChkSchedule.Checked }
    $mode = "monthly"
    if ($script:RbSelected -and $script:RbSelected.Checked) { $mode = "selected" }
    $months = @()
    foreach ($n in 1..12) {
        if ($script:MonthChecks.ContainsKey($n) -and $script:MonthChecks[$n].Checked) { $months += $n }
    }
    if ($mode -eq "monthly") { $months = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12) }
    $day = 1
    if ($script:NudDay) { $day = [int]$script:NudDay.Value }
    $time = "08:30"
    if ($script:DtpTime) { $time = $script:DtpTime.Value.ToString("HH:mm") }
    [PSCustomObject]@{
        IPs                 = $ips
        Community           = $community
        GoogleSheetsEnabled = $googleOn
        GoogleWebAppUrl     = ""
        GoogleSheetName     = $sheet
        GoogleRegion        = $region
        UnattendedEnabled   = $schedOn
        ScheduleMode        = $mode
        Months              = $months
        Day                 = $day
        ScheduleTime        = $time
        StartWithWindows    = if ($script:ChkStartup) { [bool]$script:ChkStartup.Checked } else { $false }
        UpdateCheckUrl      = $script:DefaultUpdateUrl
        Theme               = if ($script:ThemeCombo -and $script:ThemeCombo.SelectedItem) { [string]$script:ThemeCombo.SelectedItem } else { "預設淺色" }
        AutoUpdateEnabled   = if ($script:RbAutoUpdate) { [bool]$script:RbAutoUpdate.Checked } else { $false }
    }
}

function Apply-SettingsToUi {
    param($Settings)
    $script:SyncingUrl = $true
    try {
        if ($script:IpTextBox) { $script:IpTextBox.Text = [string]$Settings.IPs }
        if ($script:CommunityBox) { $script:CommunityBox.Text = [string]$Settings.Community }
        if ($script:NetCommunityBox) { $script:NetCommunityBox.Text = [string]$Settings.Community }
        if ($script:SheetBox) { $script:SheetBox.Text = [string]$Settings.GoogleSheetName }
        if ($script:ChkGoogle) { $script:ChkGoogle.Checked = [bool]$Settings.GoogleSheetsEnabled }
        if ($script:ChkSchedule) { $script:ChkSchedule.Checked = [bool]$Settings.UnattendedEnabled }
        if ([bool]$Settings.StartWithWindows) {
            try { Set-PqtRunAtStartup $true } catch {}
        }
        Sync-PqtStartupCheckbox
        $region = [string]$Settings.GoogleRegion
        if (-not $region -or -not $script:GoogleUrls.Contains($region)) {
            $region = Get-RegionFromUrl $Settings.GoogleWebAppUrl
        }
        if ($script:RegionCombo) {
            if ($script:RegionCombo.Items.Contains($region)) {
                $script:RegionCombo.SelectedItem = $region
            } else {
                $script:RegionCombo.SelectedItem = "中壢區"
            }
        }
        $isSelected = ([string]$Settings.ScheduleMode -eq "selected")
        if ($script:RbMonthly) { $script:RbMonthly.Checked = -not $isSelected }
        if ($script:RbSelected) { $script:RbSelected.Checked = $isSelected }
        $monthSet = @{}
        foreach ($m in @($Settings.Months)) { $monthSet[[int]$m] = $true }
        foreach ($n in 1..12) {
            if ($script:MonthChecks.ContainsKey($n)) {
                $script:MonthChecks[$n].Checked = if ($isSelected) { $monthSet.ContainsKey($n) } else { $true }
                $script:MonthChecks[$n].Enabled = $isSelected
            }
        }
        if ($script:NudDay) { $script:NudDay.Value = [Math]::Max(1, [Math]::Min(31, [int]$Settings.Day)) }
        if ($script:DtpTime -and $Settings.ScheduleTime -match '^(\d{1,2}):(\d{2})') {
            $script:DtpTime.Value = [datetime]::Today.AddHours([int]$Matches[1]).AddMinutes([int]$Matches[2])
        }
        if ($script:ThemeCombo) {
            $th = [string]$Settings.Theme
            if (-not $th -or -not $script:ThemeCombo.Items.Contains($th)) { $th = "預設淺色" }
            $script:ThemeCombo.SelectedItem = $th
        }
        $script:SyncingAutoUpdate = $true
        try {
            $au = [bool]$Settings.AutoUpdateEnabled
            if ($script:RbAutoUpdate) { $script:RbAutoUpdate.Checked = $au }
            if ($script:RbNoAutoUpdate) { $script:RbNoAutoUpdate.Checked = -not $au }
        } finally {
            $script:SyncingAutoUpdate = $false
        }
    } finally {
        $script:SyncingUrl = $false
    }
    Apply-PqtTheme
}

function Save-SettingsFromUi {
    $s = Read-SettingsFromUi
    $ipList = Get-IpListFromText $s.IPs
    if ($ipList.Count -eq 0) { throw "請至少填寫一個設備 IP" }
    if ($s.ScheduleMode -eq "selected" -and @($s.Months).Count -eq 0) {
        throw "指定月份請至少勾選一個月份"
    }
    if ($s.GoogleSheetsEnabled -and -not $script:GoogleUrls.Contains([string]$s.GoogleRegion)) {
        throw "已啟用 Google 上傳，請選擇地區"
    }
    Save-PqtSettings $s
    $script:CurrentSettings = $s
    Set-PqtRunAtStartup ([bool]$s.StartWithWindows)
    Sync-PqtStartupCheckbox
    if ($script:NetCommunityBox) { $script:NetCommunityBox.Text = $s.Community }
    Refresh-NetIpCombo
    Update-NextRunLabel
    Write-PqtLog "已儲存設定（pqt_settings.json、print.JSON、ricoh_settings.json）"
}

function Show-MainForm {
    $fontUi = New-Object Drawing.Font("Microsoft JhengHei UI", 10)
    $fontTitle = New-Object Drawing.Font("Microsoft JhengHei UI", 12, [Drawing.FontStyle]::Bold)
    $fontBig = New-Object Drawing.Font("Microsoft JhengHei UI", 14, [Drawing.FontStyle]::Bold)
    $fontMono = New-Object Drawing.Font("Consolas", 9)

    $form = New-Object Windows.Forms.Form
    $form.Text = "PQT007  $($script:AppVersion)"
    $form.Size = New-Object Drawing.Size(900, 720)
    $form.MinimumSize = New-Object Drawing.Size(820, 640)
    $form.StartPosition = "CenterScreen"
    $form.Font = $fontUi
    $form.KeyPreview = $true
    try { $form.Icon = Get-PqtAppIcon -Size 32 } catch {}
    $script:MainForm = $form
    if ($script:StartInTray) {
        $form.WindowState = "Minimized"
        $form.ShowInTaskbar = $false
        $form.Opacity = 0
    }

    $tabs = New-Object Windows.Forms.TabControl
    $tabs.Dock = "Fill"
    $tabs.DrawMode = "OwnerDrawFixed"
    $tabs.SizeMode = "Fixed"
    $tabs.ItemSize = New-Object Drawing.Size(104, 26)
    $tabs.Add_DrawItem({
        $e = $_
        $tc = $this
        $t = Get-ActivePqtTheme
        $g = $e.Graphics
        $bounds = $e.Bounds
        $sel = ($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0
        $bg = if ($sel) { $t.TabOn } else { $t.TabBg }
        $fg = if ($sel) { $t.AccentText } else { $t.Text }
        $b = New-Object Drawing.SolidBrush $bg
        $g.FillRectangle($b, $bounds)
        $b.Dispose()
        $sf = New-Object Drawing.StringFormat
        $sf.Alignment = [Drawing.StringAlignment]::Center
        $sf.LineAlignment = [Drawing.StringAlignment]::Center
        $tb = New-Object Drawing.SolidBrush $fg
        $title = $tc.TabPages[$e.Index].Text
        $g.DrawString($title, $tc.Font, $tb, [Drawing.RectangleF]$bounds, $sf)
        $tb.Dispose()
        $sf.Dispose()
    })
    $script:TabControl = $tabs

    $tabQuery = New-Object Windows.Forms.TabPage
    $tabQuery.Text = "時間設定"
    $tabSettings = New-Object Windows.Forms.TabPage
    $tabSettings.Text = "設備設定"
    $tabRelease = New-Object Windows.Forms.TabPage
    $tabRelease.Text = "釋放列印"
    $tabPrinter = New-Object Windows.Forms.TabPage
    $tabPrinter.Text = "印表機"
    $tabNet = New-Object Windows.Forms.TabPage
    $tabNet.Text = "網路檢測"
    $tabQuick = New-Object Windows.Forms.TabPage
    $tabQuick.Text = "常用捷徑"
    $tabRepair = New-Object Windows.Forms.TabPage
    $tabRepair.Text = "關於本公司"
    $tabUpdate = New-Object Windows.Forms.TabPage
    $tabUpdate.Text = "版本更新"

    [void]$tabs.TabPages.Add($tabQuery)
    [void]$tabs.TabPages.Add($tabSettings)
    [void]$tabs.TabPages.Add($tabRelease)
    [void]$tabs.TabPages.Add($tabPrinter)
    [void]$tabs.TabPages.Add($tabNet)
    [void]$tabs.TabPages.Add($tabQuick)
    [void]$tabs.TabPages.Add($tabRepair)
    [void]$tabs.TabPages.Add($tabUpdate)

    $panelLog = New-Object Windows.Forms.Panel
    $panelLog.Dock = "Bottom"
    $panelLog.Height = 176

    $btnClearLog = New-Btn "清除紀錄" 110 28 ([Drawing.Color]::FromArgb(240, 240, 240)) {
        Clear-PqtUiLog
    }
    $btnClearLog.Location = New-Object Drawing.Point(8, 4)
    $panelLog.Controls.Add($btnClearLog)

    $logBox = New-Object Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.ReadOnly = $true
    $logBox.Location = New-Object Drawing.Point(8, 36)
    $logBox.Size = New-Object Drawing.Size(860, 136)
    $logBox.Anchor = "Top,Bottom,Left,Right"
    $logBox.Font = $fontMono
    $script:UiLogBox = $logBox
    $panelLog.Controls.Add($logBox)

    $form.Controls.Add($tabs)
    $form.Controls.Add($panelLog)

    # ===== Tab 查詢張數 =====
    $panelQuery = New-Object Windows.Forms.Panel
    $panelQuery.Dock = "Top"
    $panelQuery.Height = 226

    $btnQueryNow = New-Btn "立即查詢張數" 160 36 ([Drawing.Color]::FromArgb(180, 230, 180)) {
        Start-PqtQueryAsync -Interactive -SkipUpload
    }
    $btnQueryNow.Location = New-Object Drawing.Point(12, 8)
    $script:BtnQueryNow = $btnQueryNow
    $panelQuery.Controls.Add($btnQueryNow)

    $btnQueryUpload = New-Btn "查詢並上傳" 160 36 ([Drawing.Color]::FromArgb(210, 230, 255)) {
        Start-PqtQueryAsync -Interactive -ForceUpload
    }
    $btnQueryUpload.Location = New-Object Drawing.Point(180, 8)
    $script:BtnQueryUpload = $btnQueryUpload
    $panelQuery.Controls.Add($btnQueryUpload)

    $lblQueryStatus = New-Object Windows.Forms.Label
    $lblQueryStatus.Location = New-Object Drawing.Point(352, 6)
    $lblQueryStatus.Size = New-Object Drawing.Size(500, 22)
    $lblQueryStatus.Text = "尚未查詢。請先到「設備設定」填 IP 與 SNMP。"
    $lblQueryStatus.Anchor = "Top,Left,Right"
    $script:QueryStatusLabel = $lblQueryStatus
    $panelQuery.Controls.Add($lblQueryStatus)

    $lblQueryHint = New-Object Windows.Forms.Label
    $lblQueryHint.Text = "立即查詢張數：只有查詢張數，並不上傳資料。"
    $lblQueryHint.ForeColor = [Drawing.Color]::DarkGreen
    $script:ThemeRoles[$lblQueryHint] = "hint"
    $lblQueryHint.Location = New-Object Drawing.Point(352, 28)
    $lblQueryHint.Size = New-Object Drawing.Size(500, 20)
    $lblQueryHint.Anchor = "Top,Left,Right"
    $panelQuery.Controls.Add($lblQueryHint)

    $chkSched = New-Object Windows.Forms.CheckBox
    $chkSched.Text = "啟用自動查詢"
    $chkSched.Location = New-Object Drawing.Point(12, 50)
    $chkSched.Size = New-Object Drawing.Size(130, 24)
    $chkSched.Checked = $true
    $script:ChkSchedule = $chkSched
    $panelQuery.Controls.Add($chkSched)

    $rbMonthly = New-Object Windows.Forms.RadioButton
    $rbMonthly.Text = "每月"
    $rbMonthly.Location = New-Object Drawing.Point(150, 50)
    $rbMonthly.Size = New-Object Drawing.Size(70, 24)
    $rbMonthly.Checked = $true
    $script:RbMonthly = $rbMonthly
    $panelQuery.Controls.Add($rbMonthly)

    $rbSelected = New-Object Windows.Forms.RadioButton
    $rbSelected.Text = "指定月份"
    $rbSelected.Location = New-Object Drawing.Point(226, 50)
    $rbSelected.Size = New-Object Drawing.Size(100, 24)
    $script:RbSelected = $rbSelected
    $panelQuery.Controls.Add($rbSelected)

    $chkStartup = New-Object Windows.Forms.CheckBox
    $chkStartup.Text = "開機自動執行"
    $chkStartup.Location = New-Object Drawing.Point(336, 50)
    $chkStartup.Size = New-Object Drawing.Size(140, 24)
    $chkStartup.Checked = $false
    $script:ChkStartup = $chkStartup
    $chkStartup.Add_CheckedChanged({
        if ($script:SyncingStartup) { return }
        $on = [bool]$this.Checked
        try {
            Set-PqtRunAtStartup $on
            if ($script:CurrentSettings) {
                $script:CurrentSettings | Add-Member -NotePropertyName StartWithWindows -NotePropertyValue $on -Force
                try { Save-PqtSettings $script:CurrentSettings } catch {}
            }
        } catch {
            Write-PqtLog $_.Exception.Message "ERROR"
            Show-ErrorBox $_.Exception.Message
            Sync-PqtStartupCheckbox
        }
    })
    $panelQuery.Controls.Add($chkStartup)

    $lblMonths = New-Object Windows.Forms.Label
    $lblMonths.Text = "查詢月份"
    $lblMonths.Location = New-Object Drawing.Point(12, 80)
    $lblMonths.Size = New-Object Drawing.Size(80, 22)
    $panelQuery.Controls.Add($lblMonths)

    $script:MonthChecks = @{}
    for ($n = 1; $n -le 12; $n++) {
        $cb = New-Object Windows.Forms.CheckBox
        $cb.Text = "{0}月" -f $n
        $col = ($n - 1) % 6
        $row = [Math]::Floor(($n - 1) / 6)
        $cb.Location = New-Object Drawing.Point((96 + $col * 72), (78 + $row * 26))
        $cb.Size = New-Object Drawing.Size(68, 24)
        $cb.Checked = $true
        $cb.Enabled = $false
        $script:MonthChecks[$n] = $cb
        $panelQuery.Controls.Add($cb)
    }

    $toggleMonths = {
        $enable = $script:RbSelected.Checked
        foreach ($n in 1..12) {
            if ($script:MonthChecks.ContainsKey($n)) {
                $script:MonthChecks[$n].Enabled = $enable
                if (-not $enable) { $script:MonthChecks[$n].Checked = $true }
            }
        }
    }
    $rbMonthly.Add_CheckedChanged($toggleMonths)
    $rbSelected.Add_CheckedChanged($toggleMonths)

    $lblDay = New-Object Windows.Forms.Label
    $lblDay.Text = "每月幾日"
    $lblDay.Location = New-Object Drawing.Point(12, 140)
    $lblDay.Size = New-Object Drawing.Size(80, 24)
    $panelQuery.Controls.Add($lblDay)

    $nudDay = New-Object Windows.Forms.NumericUpDown
    $nudDay.Location = New-Object Drawing.Point(96, 138)
    $nudDay.Size = New-Object Drawing.Size(60, 28)
    $nudDay.Minimum = 1
    $nudDay.Maximum = 31
    $nudDay.Value = 1
    $script:NudDay = $nudDay
    $panelQuery.Controls.Add($nudDay)

    $lblTime = New-Object Windows.Forms.Label
    $lblTime.Text = "幾點"
    $lblTime.Location = New-Object Drawing.Point(168, 140)
    $lblTime.Size = New-Object Drawing.Size(40, 24)
    $panelQuery.Controls.Add($lblTime)

    $dtpTime = New-Object Windows.Forms.DateTimePicker
    $dtpTime.Format = [Windows.Forms.DateTimePickerFormat]::Custom
    $dtpTime.CustomFormat = "HH:mm"
    $dtpTime.ShowUpDown = $true
    $dtpTime.Location = New-Object Drawing.Point(208, 138)
    $dtpTime.Size = New-Object Drawing.Size(80, 28)
    $dtpTime.Value = [datetime]::Today.AddHours(8).AddMinutes(30)
    $script:DtpTime = $dtpTime
    $panelQuery.Controls.Add($dtpTime)

    $btnSaveSched = New-Btn "儲存排程" 110 32 ([Drawing.Color]::FromArgb(210, 230, 255)) {
        Save-SettingsFromUi
        Update-NextRunLabel
        [Windows.Forms.MessageBox]::Show("排程已儲存。", "PQT007") | Out-Null
    }
    $btnSaveSched.Location = New-Object Drawing.Point(300, 136)
    $panelQuery.Controls.Add($btnSaveSched)

    $nextRun = New-Object Windows.Forms.Label
    $nextRun.Location = New-Object Drawing.Point(420, 142)
    $nextRun.Size = New-Object Drawing.Size(420, 24)
    $nextRun.ForeColor = [Drawing.Color]::DarkBlue
    $nextRun.Text = "下次執行："
    $script:ThemeRoles[$nextRun] = "accent"
    $nextRun.Anchor = "Top,Left,Right"
    $script:NextRunLabel = $nextRun
    $panelQuery.Controls.Add($nextRun)

    $lblRule = New-Object Windows.Forms.Label
    $lblRule.Location = New-Object Drawing.Point(12, 170)
    $lblRule.Size = New-Object Drawing.Size(840, 28)
    $lblRule.ForeColor = [Drawing.Color]::DimGray
    $lblRule.Text = "規則：15日→14、15、16；30日小月→29、30、次月1；31日大月→30、31、次月1。遇周六日不查，下次平日開機後自動查詢。"
    $script:ThemeRoles[$lblRule] = "muted"
    $lblRule.Anchor = "Top,Left,Right"
    $panelQuery.Controls.Add($lblRule)

    $lvResult = New-Object Windows.Forms.ListView
    $lvResult.Dock = "Fill"
    $lvResult.View = "Details"
    $lvResult.FullRowSelect = $true
    $lvResult.GridLines = $true
    $lvResult.HideSelection = $false
    $lvResult.Font = $fontMono
    foreach ($col in $script:DisplayColumns) {
        $w = 160
        if ($col -eq "設備 IP") { $w = 140 }
        elseif ($col -eq "設備位置") { $w = 160 }
        elseif ($col -eq "黑白合計") { $w = 110 }
        elseif ($col -eq "彩色合計") { $w = 110 }
        elseif ($col -eq "查詢時間") { $w = 150 }
        [void]$lvResult.Columns.Add($col, $w)
    }
    $script:ResultView = $lvResult
    $tabQuery.Controls.Add($lvResult)
    $tabQuery.Controls.Add($panelQuery)

    # ===== Tab 設定 =====
    $lblIp = New-Object Windows.Forms.Label
    $lblIp.Text = "設備 IP（每行一個）"
    $lblIp.Location = New-Object Drawing.Point(12, 10)
    $lblIp.Size = New-Object Drawing.Size(260, 24)
    $tabSettings.Controls.Add($lblIp)

    $ipText = New-Object Windows.Forms.TextBox
    $ipText.Multiline = $true
    $ipText.ScrollBars = "Vertical"
    $ipText.AcceptsReturn = $true
    $ipText.WordWrap = $false
    $ipText.Font = $fontMono
    $ipText.Location = New-Object Drawing.Point(12, 34)
    $ipText.Size = New-Object Drawing.Size(420, 168)
    $ipText.Anchor = "Top,Left"
    $script:IpTextBox = $ipText
    $tabSettings.Controls.Add($ipText)

    $lblComm = New-Object Windows.Forms.Label
    $lblComm.Text = "SNMP 社群"
    $lblComm.Location = New-Object Drawing.Point(12, 210)
    $lblComm.Size = New-Object Drawing.Size(100, 24)
    $tabSettings.Controls.Add($lblComm)

    $commBox = New-Object Windows.Forms.TextBox
    $commBox.Location = New-Object Drawing.Point(112, 208)
    $commBox.Size = New-Object Drawing.Size(160, 28)
    $script:CommunityBox = $commBox
    $tabSettings.Controls.Add($commBox)

    $lblRegion = New-Object Windows.Forms.Label
    $lblRegion.Text = "地區"
    $lblRegion.Location = New-Object Drawing.Point(12, 246)
    $lblRegion.Size = New-Object Drawing.Size(50, 24)
    $tabSettings.Controls.Add($lblRegion)

    $regionCombo = New-Object Windows.Forms.ComboBox
    $regionCombo.Location = New-Object Drawing.Point(62, 244)
    $regionCombo.Size = New-Object Drawing.Size(140, 28)
    $regionCombo.DropDownStyle = "DropDownList"
    [void]$regionCombo.Items.Add("中壢區")
    [void]$regionCombo.Items.Add("桃園區")
    [void]$regionCombo.Items.Add("楊梅區")
    $script:RegionCombo = $regionCombo
    $tabSettings.Controls.Add($regionCombo)

    $lblSheet = New-Object Windows.Forms.Label
    $lblSheet.Text = "試算表名稱"
    $lblSheet.Location = New-Object Drawing.Point(196, 246)
    $lblSheet.Size = New-Object Drawing.Size(90, 24)
    $tabSettings.Controls.Add($lblSheet)

    $sheetBox = New-Object Windows.Forms.TextBox
    $sheetBox.Location = New-Object Drawing.Point(288, 244)
    $sheetBox.Size = New-Object Drawing.Size(144, 28)
    $script:SheetBox = $sheetBox
    $tabSettings.Controls.Add($sheetBox)

    $chkGoogle = New-Object Windows.Forms.CheckBox
    $chkGoogle.Text = "上傳 Google 試算表"
    $chkGoogle.Location = New-Object Drawing.Point(12, 278)
    $chkGoogle.Size = New-Object Drawing.Size(220, 24)
    $chkGoogle.Checked = $true
    $script:ChkGoogle = $chkGoogle
    $tabSettings.Controls.Add($chkGoogle)

    $btnSave = New-Btn "儲存設定" 160 40 ([Drawing.Color]::FromArgb(210, 230, 255)) {
        Save-SettingsFromUi
        Update-NextRunLabel
        [Windows.Forms.MessageBox]::Show("設定已儲存。", "PQT007") | Out-Null
    }
    $btnSave.Location = New-Object Drawing.Point(12, 320)
    $script:BtnSave = $btnSave
    $tabSettings.Controls.Add($btnSave)

    $lblSchedHint = New-Object Windows.Forms.Label
    $lblSchedHint.Location = New-Object Drawing.Point(184, 326)
    $lblSchedHint.Size = New-Object Drawing.Size(640, 28)
    $lblSchedHint.ForeColor = [Drawing.Color]::DimGray
    $lblSchedHint.Text = "自動查詢的月份、每月幾日、幾點請到「時間設定」頁設定。"
    $script:ThemeRoles[$lblSchedHint] = "muted"
    $tabSettings.Controls.Add($lblSchedHint)

    # ===== Tab 釋放 =====
    $status = New-Object Windows.Forms.Label
    $status.Location = New-Object Drawing.Point(16, 14)
    $status.Size = New-Object Drawing.Size(840, 72)
    $status.Font = $fontTitle
    $script:StatusLabel = $status
    $script:ThemeRoles[$status] = "status"
    $tabRelease.Controls.Add($status)

    $btnRelease = New-Btn "立即釋放列印伺服器" 400 40 ([Drawing.Color]::FromArgb(180, 230, 180)) {
        Invoke-ReleaseFromUi
    }
    $btnRelease.Location = New-Object Drawing.Point(16, 96)
    $tabRelease.Controls.Add($btnRelease)

    $btnRestart = New-Btn "只重啟服務" 270 40 ([Drawing.Color]::LightYellow) {
        Invoke-MaybeElevated -Name RestartSpooler
        Update-StatusPanel
        Update-PrinterList
        [Windows.Forms.MessageBox]::Show("Print Spooler 已重啟。", "完成") | Out-Null
    }
    $btnRestart.Location = New-Object Drawing.Point(16, 172)

    $btnCancel = New-Btn "取消所有工作" 270 40 ([Drawing.Color]::FromArgb(255, 220, 180)) {
        if (-not (Confirm-Danger "取消所有工作" "將取消本機所有印表機佇列中的工作，確定？")) { return }
        Invoke-MaybeElevated -Name CancelAllJobs
        Update-StatusPanel
        Update-PrinterList
    }
    $btnCancel.Location = New-Object Drawing.Point(298, 172)

    $btnRefresh = New-Btn "重新整理狀態" 270 40 $null {
        Update-StatusPanel
        Update-PrinterList
        Write-PqtLog "已重新整理狀態"
    }
    $btnRefresh.Location = New-Object Drawing.Point(580, 172)

    $tabRelease.Controls.Add($btnRestart)
    $tabRelease.Controls.Add($btnCancel)
    $tabRelease.Controls.Add($btnRefresh)

    $hint = New-Object Windows.Forms.Label
    $hint.Location = New-Object Drawing.Point(16, 224)
    $hint.Size = New-Object Drawing.Size(840, 88)
    $hint.ForeColor = [Drawing.Color]::DimGray
    $script:ThemeRoles[$hint] = "muted"
    $hint.Text = @"
適用時機：印表機顯示離線、工作卡在佇列刪不掉、列印伺服器沒反應。
「立即釋放」= 停止 Print Spooler → 刪除 C:\Windows\System32\spool\PRINTERS 內檔案 → 再啟動。需要系統管理員。
「只重啟服務」不會刪已排隊的工作。「取消所有工作」走 Windows 列印 API，較溫和。
"@
    $tabRelease.Controls.Add($hint)

    $btnOpenSpool = New-Btn "開啟佇列資料夾" 200 36 $null {
        if (-not (Test-Path $spoolFolder)) { New-Item -ItemType Directory -Path $spoolFolder -Force | Out-Null }
        Start-Process explorer.exe $spoolFolder
    }
    $btnOpenSpool.Location = New-Object Drawing.Point(16, 318)

    $btnPrintMgmt = New-Btn "開啟列印管理" 200 36 $null {
        Start-Process printmanagement.msc
    }
    $btnPrintMgmt.Location = New-Object Drawing.Point(226, 318)

    $btnServerProp = New-Btn "列印伺服器內容" 200 36 $null {
        Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /s"
    }
    $btnServerProp.Location = New-Object Drawing.Point(436, 318)

    $tabRelease.Controls.Add($btnOpenSpool)
    $tabRelease.Controls.Add($btnPrintMgmt)
    $tabRelease.Controls.Add($btnServerProp)

    # ===== Tab 印表機 =====
    $lv = New-Object Windows.Forms.ListView
    $lv.Location = New-Object Drawing.Point(12, 12)
    $lv.Size = New-Object Drawing.Size(848, 300)
    $lv.View = "Details"
    $lv.FullRowSelect = $true
    $lv.GridLines = $true
    $lv.HideSelection = $false
    $lv.Anchor = "Top,Left,Right"
    [void]$lv.Columns.Add("印表機", 220)
    [void]$lv.Columns.Add("狀態", 90)
    [void]$lv.Columns.Add("工作", 50)
    [void]$lv.Columns.Add("連接埠", 120)
    [void]$lv.Columns.Add("預設", 50)
    [void]$lv.Columns.Add("共用", 50)
    [void]$lv.Columns.Add("驅動程式", 220)
    $script:PrinterList = $lv
    $tabPrinter.Controls.Add($lv)

    $printerBtns = @(
        @{ T = "重新整理"; A = { Update-PrinterList; Update-StatusPanel } }
        @{ T = "開啟佇列"; A = { $n = Get-SelectedPrinterName; Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /o /n `"$n`"" } }
        @{ T = "列印測試頁"; A = {
            $n = Get-SelectedPrinterName
            $p = Get-CimPrinter $n
            $r = Invoke-CimMethod -InputObject $p -MethodName PrintTestPage
            Write-PqtLog "已送出測試頁：$n（代碼 $($r.ReturnValue)）"
        } }
        @{ T = "設為預設"; A = {
            $n = Get-SelectedPrinterName
            $p = Get-CimPrinter $n
            [void](Invoke-CimMethod -InputObject $p -MethodName SetDefaultPrinter)
            Write-PqtLog "已設為預設：$n"
            Update-PrinterList
        } }
        @{ T = "暫停印表機"; A = {
            $n = Get-SelectedPrinterName
            [void](Invoke-CimMethod -InputObject (Get-CimPrinter $n) -MethodName Pause)
            Write-PqtLog "已暫停：$n"
            Update-PrinterList
        } }
        @{ T = "繼續印表機"; A = {
            $n = Get-SelectedPrinterName
            [void](Invoke-CimMethod -InputObject (Get-CimPrinter $n) -MethodName Resume)
            Write-PqtLog "已繼續：$n"
            Update-PrinterList
        } }
        @{ T = "取消此台工作"; A = {
            $n = Get-SelectedPrinterName
            $jobs = @(Get-PrintJob -PrinterName $n -ErrorAction SilentlyContinue)
            foreach ($j in $jobs) { Remove-PrintJob -InputObject $j -ErrorAction SilentlyContinue }
            Write-PqtLog "已取消 $n 的 $($jobs.Count) 筆工作"
            Update-PrinterList
            Update-StatusPanel
        } }
        @{ T = "印表機內容"; A = {
            $n = Get-SelectedPrinterName
            Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /p /n `"$n`""
        } }
    )
    $x = 12
    $y = 322
    foreach ($info in $printerBtns) {
        $b = New-Btn $info.T 145 34 $null $info.A
        $b.Location = New-Object Drawing.Point($x, $y)
        $tabPrinter.Controls.Add($b)
        $x += 152
        if ($x -gt 760) { $x = 12; $y += 42 }
    }

    $btnFixDefault = New-Btn "關閉 Windows 自動管理預設印表機" 360 34 ([Drawing.Color]::Honeydew) {
        $key = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        New-ItemProperty -Path $key -Name "LegacyDefaultPrinterMode" -PropertyType DWord -Value 1 -Force | Out-Null
        Write-PqtLog "已關閉「讓 Windows 管理預設印表機」（LegacyDefaultPrinterMode=1）"
        [Windows.Forms.MessageBox]::Show("已關閉 Windows 自動管理預設印表機。`r`n之後你設的預設機才會固定。", "完成") | Out-Null
    }
    $btnFixDefault.Location = New-Object Drawing.Point(12, 406)
    $tabPrinter.Controls.Add($btnFixDefault)

    $btnAddPrinter = New-Btn "新增印表機精靈" 180 34 $null {
        Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /il"
    }
    $btnAddPrinter.Location = New-Object Drawing.Point(380, 406)
    $tabPrinter.Controls.Add($btnAddPrinter)

    $btnDevices = New-Btn "裝置和印表機" 180 34 $null {
        Start-Process control.exe "printers"
    }
    $btnDevices.Location = New-Object Drawing.Point(568, 406)
    $tabPrinter.Controls.Add($btnDevices)

    # ===== Tab 網路 =====
    $lblNetIp = New-Object Windows.Forms.Label
    $lblNetIp.Text = "印表機 IP"
    $lblNetIp.Location = New-Object Drawing.Point(16, 16)
    $lblNetIp.Size = New-Object Drawing.Size(90, 28)
    $tabNet.Controls.Add($lblNetIp)

    $netIpBox = New-Object Windows.Forms.ComboBox
    $netIpBox.Location = New-Object Drawing.Point(110, 14)
    $netIpBox.Size = New-Object Drawing.Size(280, 28)
    $netIpBox.DropDownStyle = "DropDown"
    $script:NetIpBox = $netIpBox
    $tabNet.Controls.Add($netIpBox)

    $btnLoadIp = New-Btn "載入 IP 清單" 160 30 $null {
        Refresh-NetIpCombo
        Write-PqtLog ("已載入 {0} 筆 IP" -f $script:NetIpBox.Items.Count)
    }
    $btnLoadIp.Location = New-Object Drawing.Point(400, 12)
    $tabNet.Controls.Add($btnLoadIp)

    $lblNetComm = New-Object Windows.Forms.Label
    $lblNetComm.Text = "SNMP"
    $lblNetComm.Location = New-Object Drawing.Point(580, 16)
    $lblNetComm.Size = New-Object Drawing.Size(60, 28)
    $tabNet.Controls.Add($lblNetComm)

    $netCommBox = New-Object Windows.Forms.TextBox
    $netCommBox.Location = New-Object Drawing.Point(640, 14)
    $netCommBox.Size = New-Object Drawing.Size(200, 28)
    $script:NetCommunityBox = $netCommBox
    $tabNet.Controls.Add($netCommBox)

    $localIp = New-Object Windows.Forms.Label
    $localIp.Location = New-Object Drawing.Point(16, 52)
    $localIp.Size = New-Object Drawing.Size(840, 24)
    $script:LocalIpLabel = $localIp
    $tabNet.Controls.Add($localIp)

    $netResult = New-Object Windows.Forms.TextBox
    $netResult.Multiline = $true
    $netResult.ScrollBars = "Vertical"
    $netResult.ReadOnly = $true
    $netResult.Font = $fontMono
    $netResult.Location = New-Object Drawing.Point(16, 150)
    $netResult.Size = New-Object Drawing.Size(840, 250)
    $netResult.Anchor = "Top,Left,Right,Bottom"
    $script:NetResultBox = $netResult
    $tabNet.Controls.Add($netResult)

    function Add-NetResult([string]$Text) {
        $script:NetResultBox.AppendText((Get-Date -Format "HH:mm:ss") + "  " + $Text + [Environment]::NewLine)
        Write-PqtLog $Text
    }

    $netButtons = @(
        @{ T = "Ping"; A = {
            $ip = Get-CurrentIpText
            Add-NetResult "Ping $ip ..."
            $out = & ping.exe -n 2 -w 1000 $ip | Out-String
            Add-NetResult $out.Trim()
        } }
        @{ T = "測試 9100 RAW"; A = {
            $ip = Get-CurrentIpText
            $ok = Test-TcpPortFast $ip 9100
            Add-NetResult ("{0}:9100 RAW  {1}" -f $ip, $(if ($ok) { "通" } else { "不通" }))
        } }
        @{ T = "測試 80 網頁"; A = {
            $ip = Get-CurrentIpText
            $ok = Test-TcpPortFast $ip 80
            Add-NetResult ("{0}:80 HTTP  {1}" -f $ip, $(if ($ok) { "通" } else { "不通" }))
        } }
        @{ T = "測試 443"; A = {
            $ip = Get-CurrentIpText
            $ok = Test-TcpPortFast $ip 443
            Add-NetResult ("{0}:443 HTTPS  {1}" -f $ip, $(if ($ok) { "通" } else { "不通" }))
        } }
        @{ T = "開啟網頁"; A = {
            $ip = Get-CurrentIpText
            Start-Process "http://$ip"
            Add-NetResult "已開啟 http://$ip"
        } }
        @{ T = "SNMP 測試"; A = {
            $ip = Get-CurrentIpText
            $comm = $script:NetCommunityBox.Text.Trim()
            if (-not $comm) { $comm = "public" }
            Add-NetResult "SNMP $ip community=$comm ..."
            $snmp = New-Object -ComObject OlePrn.OleSNMP
            try {
                $snmp.Open($ip, $comm, 2, 1500)
                $sysName = ""
                $model = ""
                try { $sysName = [string]$snmp.Get(".1.3.6.1.2.1.1.5.0") } catch {}
                try { $model = [string]$snmp.Get(".1.3.6.1.2.1.25.3.2.1.3.1") } catch {}
                if (-not $model) {
                    try { $model = [string]$snmp.Get(".1.3.6.1.4.1.367.3.2.1.1.1.1.0") } catch {}
                }
                Add-NetResult ("SNMP 成功  名稱={0}  型號={1}" -f $sysName, $model)
            } catch {
                Add-NetResult ("SNMP 失敗：" + $_.Exception.Message)
            } finally {
                try { $snmp.Close() } catch {}
            }
        } }
        @{ T = "一次全測"; A = {
            $ip = Get-CurrentIpText
            Add-NetResult "===== $ip 一次全測 ====="
            $out = & ping.exe -n 1 -w 1000 $ip | Out-String
            Add-NetResult $out.Trim()
            foreach ($port in @(80, 443, 515, 9100, 8080)) {
                $ok = Test-TcpPortFast $ip $port
                Add-NetResult ("  TCP {0,-5} {1}" -f $port, $(if ($ok) { "通" } else { "不通" }))
            }
        } }
        @{ T = "複製結果"; A = {
            if ($script:NetResultBox.Text) {
                [Windows.Forms.Clipboard]::SetText($script:NetResultBox.Text)
                Add-NetResult "已複製檢測結果"
            }
        } }
    )
    $nx = 16
    foreach ($info in $netButtons) {
        $b = New-Btn $info.T 108 34 $null $info.A
        $b.Location = New-Object Drawing.Point($nx, 86)
        $tabNet.Controls.Add($b)
        $nx += 112
    }

    # ===== Tab 捷徑 =====
    $shortcuts = @(
        @{ T = "裝置和印表機"; A = { Start-Process control.exe "printers" } }
        @{ T = "列印管理"; A = { Start-Process printmanagement.msc } }
        @{ T = "列印伺服器內容"; A = { Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /s" } }
        @{ T = "新增印表機"; A = { Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /il" } }
        @{ T = "服務（Spooler）"; A = { Start-Process services.msc } }
        @{ T = "事件檢視器"; A = { Start-Process eventvwr.msc } }
        @{ T = "裝置管理員"; A = { Start-Process devmgmt.msc } }
        @{ T = "網路連線"; A = { Start-Process ncpa.cpl } }
        @{ T = "防火牆"; A = { Start-Process firewall.cpl } }
        @{ T = "Windows 網路設定"; A = { Start-Process "ms-settings:network-status" } }
        @{ T = "開啟佇列資料夾"; A = { Start-Process explorer.exe $spoolFolder } }
        @{ T = "清理 DNS 快取"; A = { ipconfig /flushdns | Out-Null; Write-PqtLog "已執行 ipconfig /flushdns"; [Windows.Forms.MessageBox]::Show("已清理 DNS 快取。") | Out-Null } }
        @{ T = "本機 IP 資訊"; A = {
            $txt = ipconfig.exe /all | Out-String
            $script:NetResultBox.Text = $txt
            $tabs.SelectedTab = $tabNet
            Write-PqtLog "已顯示 ipconfig /all"
        } }
    )
    $sx = 20; $sy = 20; $col = 0
    foreach ($info in $shortcuts) {
        $b = New-Btn $info.T 250 40 ([Drawing.Color]::FromArgb(235, 245, 255)) $info.A
        $b.Location = New-Object Drawing.Point($sx, $sy)
        $tabQuick.Controls.Add($b)
        $col++
        if ($col -ge 3) { $col = 0; $sx = 20; $sy += 50 } else { $sx += 260 }
    }

    # ===== Tab 關於本公司 =====
    $lblRepairTitle = New-Object Windows.Forms.Label
    $lblRepairTitle.Text = "關於本公司"
    $lblRepairTitle.Font = $fontTitle
    $lblRepairTitle.Location = New-Object Drawing.Point(24, 16)
    $lblRepairTitle.Size = New-Object Drawing.Size(400, 28)
    $tabRepair.Controls.Add($lblRepairTitle)

    $lblCompany = New-Object Windows.Forms.Label
    $lblCompany.Text = "富利久有限公司"
    $lblCompany.Font = $fontBig
    $lblCompany.Location = New-Object Drawing.Point(24, 52)
    $lblCompany.Size = New-Object Drawing.Size(420, 32)
    $tabRepair.Controls.Add($lblCompany)

    $lblPhone = New-Object Windows.Forms.Label
    $lblPhone.Text = "電話：(03)4579317"
    $lblPhone.Location = New-Object Drawing.Point(24, 96)
    $lblPhone.Size = New-Object Drawing.Size(420, 26)
    $tabRepair.Controls.Add($lblPhone)

    $lblFax = New-Object Windows.Forms.Label
    $lblFax.Text = "傳真：(03)4570035"
    $lblFax.Location = New-Object Drawing.Point(24, 126)
    $lblFax.Size = New-Object Drawing.Size(420, 26)
    $tabRepair.Controls.Add($lblFax)

    $lblLineId = New-Object Windows.Forms.Label
    $lblLineId.Text = "Line 加入：@383mdhuo"
    $lblLineId.Location = New-Object Drawing.Point(24, 156)
    $lblLineId.Size = New-Object Drawing.Size(420, 26)
    $tabRepair.Controls.Add($lblLineId)

    $btnCopyPhone = New-Btn "複製電話" 130 36 ([Drawing.Color]::FromArgb(235, 245, 255)) {
        [Windows.Forms.Clipboard]::SetText("(03)4579317")
        Write-PqtLog "已複製電話 (03)4579317"
        [Windows.Forms.MessageBox]::Show("已複製電話 (03)4579317", "關於本公司") | Out-Null
    }
    $btnCopyPhone.Location = New-Object Drawing.Point(24, 200)
    $tabRepair.Controls.Add($btnCopyPhone)

    $btnCopyLine = New-Btn "複製 Line ID" 130 36 ([Drawing.Color]::FromArgb(235, 245, 255)) {
        [Windows.Forms.Clipboard]::SetText("@383mdhuo")
        Write-PqtLog "已複製 Line ID @383mdhuo"
        [Windows.Forms.MessageBox]::Show("已複製 Line ID @383mdhuo", "關於本公司") | Out-Null
    }
    $btnCopyLine.Location = New-Object Drawing.Point(164, 200)
    $tabRepair.Controls.Add($btnCopyLine)

    $btnOpenLine = New-Btn "開啟 LINE" 130 36 ([Drawing.Color]::FromArgb(180, 230, 180)) {
        Start-Process "https://line.me/R/ti/p/@383mdhuo"
    }
    $btnOpenLine.Location = New-Object Drawing.Point(304, 200)
    $tabRepair.Controls.Add($btnOpenLine)

    $picQr = New-Object Windows.Forms.PictureBox
    $picQr.Location = New-Object Drawing.Point(500, 24)
    $picQr.Size = New-Object Drawing.Size(240, 240)
    $picQr.SizeMode = [Windows.Forms.PictureBoxSizeMode]::Zoom
    $picQr.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $picQr.BackColor = [Drawing.Color]::White
    try { $picQr.Image = Get-LineQrImage } catch {}
    $tabRepair.Controls.Add($picQr)

    $lblQrHint = New-Object Windows.Forms.Label
    $lblQrHint.Text = "官方 LINE QR（掃描加入報修）"
    $lblQrHint.Location = New-Object Drawing.Point(500, 270)
    $lblQrHint.Size = New-Object Drawing.Size(240, 24)
    $lblQrHint.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $tabRepair.Controls.Add($lblQrHint)

    # ===== Tab 版本更新 =====
    $lblVerNow = New-Object Windows.Forms.Label
    $lblVerNow.Text = "目前版本：$($script:AppVersion)"
    $lblVerNow.Font = $fontTitle
    $lblVerNow.Location = New-Object Drawing.Point(16, 16)
    $lblVerNow.Size = New-Object Drawing.Size(400, 28)
    $tabUpdate.Controls.Add($lblVerNow)

    $btnCheckUpdate = New-Btn "版本更新" 180 40 ([Drawing.Color]::FromArgb(180, 230, 180)) {
        Invoke-PqtUpdateCheck
    }
    $btnCheckUpdate.Location = New-Object Drawing.Point(16, 52)
    $tabUpdate.Controls.Add($btnCheckUpdate)

    $lblUpdateResult = New-Object Windows.Forms.Label
    $lblUpdateResult.Text = "按「版本更新」檢查並自動取代程式"
    $lblUpdateResult.Location = New-Object Drawing.Point(210, 60)
    $lblUpdateResult.Size = New-Object Drawing.Size(640, 24)
    $lblUpdateResult.Anchor = "Top,Left,Right"
    $script:UpdateResultLabel = $lblUpdateResult
    $tabUpdate.Controls.Add($lblUpdateResult)

    $rbAuto = New-Object Windows.Forms.RadioButton
    $rbAuto.Text = "自動更新"
    $rbAuto.Location = New-Object Drawing.Point(16, 100)
    $rbAuto.Size = New-Object Drawing.Size(110, 24)
    $script:RbAutoUpdate = $rbAuto
    $tabUpdate.Controls.Add($rbAuto)

    $rbNoAuto = New-Object Windows.Forms.RadioButton
    $rbNoAuto.Text = "關閉自動更新"
    $rbNoAuto.Location = New-Object Drawing.Point(130, 100)
    $rbNoAuto.Size = New-Object Drawing.Size(140, 24)
    $rbNoAuto.Checked = $true
    $script:RbNoAutoUpdate = $rbNoAuto
    $tabUpdate.Controls.Add($rbNoAuto)

    $saveAuto = {
        if ($script:SyncingAutoUpdate) { return }
        if (-not $script:CurrentSettings) { return }
        $on = [bool]$script:RbAutoUpdate.Checked
        $script:CurrentSettings | Add-Member -NotePropertyName AutoUpdateEnabled -NotePropertyValue $on -Force
        try { Save-PqtSettings $script:CurrentSettings } catch {}
        Write-PqtLog $(if ($on) { "已開啟自動更新（啟動時檢查並安裝新版）" } else { "已關閉自動更新（僅能手動按版本更新）" })
    }
    $rbAuto.Add_CheckedChanged($saveAuto)
    $rbNoAuto.Add_CheckedChanged($saveAuto)

    $lblTheme = New-Object Windows.Forms.Label
    $lblTheme.Text = "主題樣式"
    $lblTheme.Location = New-Object Drawing.Point(16, 136)
    $lblTheme.Size = New-Object Drawing.Size(80, 24)
    $tabUpdate.Controls.Add($lblTheme)

    $themeCombo = New-Object Windows.Forms.ComboBox
    $themeCombo.Location = New-Object Drawing.Point(96, 132)
    $themeCombo.Size = New-Object Drawing.Size(160, 28)
    $themeCombo.DropDownStyle = "DropDownList"
    foreach ($n in @((Get-PqtThemeCatalog).Keys)) { [void]$themeCombo.Items.Add($n) }
    $themeCombo.SelectedItem = "預設淺色"
    $script:ThemeCombo = $themeCombo
    $themeCombo.Add_SelectedIndexChanged({
        if ($script:SyncingUrl) { return }
        Apply-PqtTheme
        if ($script:CurrentSettings) {
            $script:CurrentSettings | Add-Member -NotePropertyName Theme -NotePropertyValue ([string]$script:ThemeCombo.SelectedItem) -Force
            try { Save-PqtSettings $script:CurrentSettings } catch {}
        }
        Write-PqtLog ("主題已切換為 {0}" -f $script:ThemeCombo.SelectedItem)
    })
    $tabUpdate.Controls.Add($themeCombo)

    $changelog = New-Object Windows.Forms.TextBox
    $changelog.Multiline = $true
    $changelog.ReadOnly = $true
    $changelog.ScrollBars = "Vertical"
    $changelog.Location = New-Object Drawing.Point(16, 172)
    $changelog.Size = New-Object Drawing.Size(840, 206)
    $changelog.Anchor = "Top,Left,Right,Bottom"
    $changelog.Font = $fontMono
    $changelog.WordWrap = $true
    $changelog.Text = Get-PqtChangelogText
    $tabUpdate.Controls.Add($changelog)

    $tabs.Add_SelectedIndexChanged({
        if ($script:TabControl.SelectedTab.Text -eq "網路檢測") {
            Refresh-NetIpCombo
            if ($script:CommunityBox -and $script:NetCommunityBox) {
                $script:NetCommunityBox.Text = $script:CommunityBox.Text
            }
        }
        if ($script:TabControl.SelectedTab.Text -eq "釋放列印") {
            Update-StatusPanel
        }
        if ($script:TabControl.SelectedTab.Text -eq "印表機") {
            Update-PrinterList
        }
    })

    $cms = New-Object Windows.Forms.ContextMenuStrip
    $itemShow = $cms.Items.Add("顯示介面")
    $itemShow.Add_Click({ Show-PqtWindow })
    $itemRelease = $cms.Items.Add("釋放列印")
    $itemRelease.Add_Click({
        try {
            Show-PqtWindow -TabIndex 2
            Invoke-ReleaseFromUi
        } catch {
            Write-PqtLog $_.Exception.Message "ERROR"
            Show-ErrorBox $_.Exception.Message
        }
    })
    $itemSettings = $cms.Items.Add("設備設定")
    $itemSettings.Add_Click({ Show-PqtWindow -TabIndex 1 })
    $itemUpdate = $cms.Items.Add("版本更新")
    $itemUpdate.Add_Click({
        try { Invoke-PqtUpdateCheck } catch {
            Write-PqtLog $_.Exception.Message "ERROR"
            Show-ErrorBox $_.Exception.Message
        }
    })
    [void]$cms.Items.Add("-")
    $itemExit = $cms.Items.Add("結束")
    $itemExit.Add_Click({ Close-PqtApp })

    $ni = New-Object Windows.Forms.NotifyIcon
    try { $ni.Icon = Get-PqtAppIcon -Size 16 } catch { $ni.Icon = [Drawing.SystemIcons]::Application }
    $ni.Text = "PQT007"
    $ni.Visible = $true
    $ni.ContextMenuStrip = $cms
    $ni.Add_DoubleClick({ Show-PqtWindow })
    $script:NotifyIcon = $ni

    $uiTimer = New-Object Windows.Forms.Timer
    $uiTimer.Interval = 400
    $uiTimer.Add_Tick({
        try {
            if ($script:ShowEvent -and $script:ShowEvent.WaitOne(0)) { Show-PqtWindow }
            if ($script:ShowSettingsEvent -and $script:ShowSettingsEvent.WaitOne(0)) { Show-PqtWindow -TabIndex 1 }
            Complete-PqtQueryIfDone
        } catch {}
    })
    $script:UiTimer = $uiTimer
    $uiTimer.Start()

    $schedTimer = New-Object Windows.Forms.Timer
    $schedTimer.Interval = 20000
    $schedTimer.Add_Tick({
        try {
            Invoke-ScheduleCheck
            Update-NextRunLabel
        } catch {
            Write-PqtLog $_.Exception.Message "ERROR"
        }
    })
    $script:SchedTimer = $schedTimer
    $schedTimer.Start()

    $form.Add_Shown({
        Write-PqtLog "PQT007 已啟動"
        Apply-SettingsToUi $script:CurrentSettings
        Update-NextRunLabel
        Update-StatusPanel
        Update-PrinterList
        Update-LocalIpLabel
        Refresh-NetIpCombo
        if (Test-IsAdmin) { Write-PqtLog "目前以系統管理員執行" } else { Write-PqtLog "目前為一般權限，釋放列印伺服器時會要求 UAC" }
        if ($script:CurrentSettings.UnattendedEnabled) {
            if ($script:NextRunTime) {
                Write-PqtLog ("排程已啟用，下次執行 {0}" -f $script:NextRunTime.ToString("yyyy-MM-dd HH:mm"))
            }
            try { Invoke-ScheduleCheck } catch { Write-PqtLog $_.Exception.Message "ERROR" }
        }
        if ($script:CurrentSettings -and [bool]$script:CurrentSettings.AutoUpdateEnabled) {
            try { Invoke-PqtUpdateCheck -Auto } catch { Write-PqtLog $_.Exception.Message "ERROR" }
        }
        if ($script:NotifyIcon) { $script:NotifyIcon.Visible = $true }
        if ($script:StartInTray) {
            Hide-PqtToTray
            if ($script:MainForm -and -not $script:MainForm.IsDisposed) { $script:MainForm.Opacity = 1 }
            Write-PqtLog "開機啟動，已縮小到系統匣"
        }
    })

    $form.Add_Resize({
        if ($script:ReallyExit) { return }
        if ($form.WindowState -eq "Minimized") { Hide-PqtToTray }
    })

    $form.Add_FormClosing({
        param($sender, $e)
        if (-not $e -and $_) { $e = $_ }
        if ($script:ReallyExit) { return }
        if ($e -and $e.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
            $e.Cancel = $true
            Hide-PqtToTray
        }
    })

    Apply-PqtTheme
    [Windows.Forms.Application]::Run($form)
}

if ([string]::IsNullOrWhiteSpace($Action)) {
    foreach ($a in @($args)) {
        $s = [string]$a
        if ($s -match '^-?Action[=:](.+)$') { $Action = $Matches[1]; break }
        if (@("ReleaseSpooler", "RestartSpooler", "CancelAllJobs", "Install") -contains $s) { $Action = $s; break }
        if ($s -match '^-?Tray$') { $script:StartInTray = $true }
    }
}
if ($Action -eq "Install") {
    try {
        [void](Copy-PqtIntoInstallDir)
        exit 0
    } catch {
        exit 1
    }
}
if (-not [string]::IsNullOrWhiteSpace($Action)) {
    Invoke-SilentAction -Name $Action
    return
}

if (Invoke-PqtFirstRunInstall) {
    return
}

$createdNew = $false
try {
    $script:Mutex = New-Object System.Threading.Mutex($true, $script:MutexName, [ref]$createdNew)
} catch {
    $createdNew = $true
}

if (-not $createdNew) {
    $signaled = $false
    for ($i = 0; $i -lt 15; $i++) {
        try {
            $ev = [System.Threading.EventWaitHandle]::OpenExisting($script:ShowEventName)
            [void]$ev.Set()
            $ev.Close()
            $signaled = $true
            break
        } catch {
            Start-Sleep -Milliseconds 80
        }
    }
    if (-not $signaled) {
        try {
            [Windows.Forms.MessageBox]::Show("PQT007 已在執行中。", "PQT007") | Out-Null
        } catch {}
    }
    if ($script:Mutex) { try { $script:Mutex.Dispose() } catch {} }
    return
}

try {
    $dummy = $false
    $script:ShowEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $script:ShowEventName, [ref]$dummy)
    $script:ShowSettingsEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $script:ShowSettingsEventName, [ref]$dummy)
} catch {}

try {
    $script:CurrentSettings = Load-PqtSettings
    Load-ScheduleState
    Show-MainForm
} catch {
    try { Write-PqtLog $_.Exception.Message "FATAL" } catch {}
    try {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "PQT007") | Out-Null
    } catch {}
} finally {
    $script:ReallyExit = $true
    try { if ($script:UiTimer) { $script:UiTimer.Stop(); $script:UiTimer.Dispose() } } catch {}
    try { if ($script:SchedTimer) { $script:SchedTimer.Stop(); $script:SchedTimer.Dispose() } } catch {}
    if ($script:NotifyIcon) {
        try { $script:NotifyIcon.Visible = $false } catch {}
        try { $script:NotifyIcon.Dispose() } catch {}
        $script:NotifyIcon = $null
    }
    if ($script:QueryPs) {
        try { $script:QueryPs.Stop() } catch {}
        try { if ($script:QueryPs.Runspace) { $script:QueryPs.Runspace.Dispose() } } catch {}
        try { $script:QueryPs.Dispose() } catch {}
    }
    if ($script:ShowEvent) { try { $script:ShowEvent.Dispose() } catch {} }
    if ($script:ShowSettingsEvent) { try { $script:ShowSettingsEvent.Dispose() } catch {} }
    if ($script:Mutex) {
        try { [void]$script:Mutex.ReleaseMutex() } catch {}
        try { $script:Mutex.Dispose() } catch {}
    }
}
