# lanyen.de 驅動下載進度與安裝失敗提醒。
# 由雲端安裝、自動安裝、驅動下載選單載入。不修改 PQT。
# 沒有可靠的程式化方式關閉「Windows 受保護的列印」或組織原則時，只開啟設定頁，不寫登錄。

$script:FlgPrintAssistLoaded = $true

function Test-FlgYes([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return ($Value.Trim() -match '^(?i)(y|yes|是)$')
}

function Format-FlgByteCount {
    param([int64]$Bytes)
    if ($Bytes -lt 0) { $Bytes = 0 }
    if ($Bytes -lt 1024) { return ('{0} B' -f $Bytes) }
    if ($Bytes -lt 1MB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return ('{0:N1} MB' -f ($Bytes / 1MB))
}

function Get-FlgDownloadsFolder {
    param([string]$Override)
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        if (-not (Test-Path -LiteralPath $Override)) {
            New-Item -ItemType Directory -Path $Override -Force | Out-Null
        }
        return ([IO.Path]::GetFullPath($Override))
    }
    $known = $null
    try {
        if (-not ('FlgKnownFolder' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FlgKnownFolder {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SHGetKnownFolderPath([MarshalAs(UnmanagedType.LPStruct)] Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr pszPath);
    public static string Downloads() {
        Guid id = new Guid("374DE290-123F-4565-9164-39C4925E467B");
        IntPtr p;
        int hr = SHGetKnownFolderPath(id, 0, IntPtr.Zero, out p);
        if (hr != 0) throw new System.ComponentModel.Win32Exception(hr);
        try { return Marshal.PtrToStringUni(p); }
        finally { if (p != IntPtr.Zero) Marshal.FreeCoTaskMem(p); }
    }
}
'@
        }
        $known = [FlgKnownFolder]::Downloads()
    } catch {}
    if ([string]::IsNullOrWhiteSpace($known)) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $known = [string]$shell.NameSpace('shell:Downloads').Self.Path
        } catch {}
    }
    if (-not [string]::IsNullOrWhiteSpace($known)) {
        return ([IO.Path]::GetFullPath($known))
    }
    $profile = ''
    try { $profile = [Environment]::GetFolderPath('UserProfile') } catch {}
    if ([string]::IsNullOrWhiteSpace($profile)) { $profile = [string]$env:USERPROFILE }
    if ([string]::IsNullOrWhiteSpace($profile)) {
        throw '找不到 Windows 下載資料夾（Known Folder）。不會使用寫死的 C:\Users 路徑。'
    }
    return (Join-Path $profile 'Downloads')
}

function Get-FlgDriverDownloadDir {
    param([Parameter(Mandatory = $true)][string]$Child, [string]$Override)
    $root = Get-FlgDownloadsFolder -Override $Override
    $dir = Join-Path $root $Child
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Test-FlgPathIsRunningProcess {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try {
        $proc = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if ([string]::IsNullOrWhiteSpace($proc)) { return $false }
        $full = [IO.Path]::GetFullPath($Path)
        return ([IO.Path]::GetFullPath($proc) -eq $full)
    } catch {
        return $false
    }
}

function Write-FlgDownloadProgressLine {
    param([int64]$Received, [int64]$Total)
    $known = ($Total -gt 0)
    $bar = ''
    $pctText = ''
    $percent = $null
    if ($known) {
        $ratio = [double]$Received / [double]$Total
        if ($ratio -gt 1) { $ratio = 1 }
        if ($ratio -lt 0) { $ratio = 0 }
        $percent = [int][Math]::Floor($ratio * 100)
        if ($percent -gt 100) { $percent = 100 }
        $filled = [int][Math]::Floor($ratio * 20)
        if ($filled -gt 20) { $filled = 20 }
        $bar = ('#' * $filled) + ('-' * (20 - $filled))
        $pctText = ('{0,3}%  ' -f $percent)
    } else {
        $bar = '下載中（總容量未知）'
    }
    $sizeText = $(if ($known) {
        (Format-FlgByteCount $Received) + ' / ' + (Format-FlgByteCount $Total)
    } else {
        (Format-FlgByteCount $Received)
    })
    $line = ('[{0}] {1}{2}' -f $bar, $pctText, $sizeText)
    return @{ Line = $line; Percent = $percent; Indeterminate = (-not $known); Received = $Received; Total = $Total }
}

function Save-FlgHttpWithProgress {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [hashtable]$Headers,
        [scriptblock]$OnProgress,
        [int]$TimeoutSec = 180
    )
    if (Test-FlgPathIsRunningProcess $OutFile) {
        $dir0 = Split-Path -Parent $OutFile
        $leaf = [IO.Path]::GetFileNameWithoutExtension($OutFile)
        $ext = [IO.Path]::GetExtension($OutFile)
        $OutFile = Join-Path $dir0 ($leaf + '-download' + $ext)
        Write-Host ('目的檔正在執行，不覆寫，改存：' + $OutFile) -ForegroundColor Yellow
    }
    $destDir = Split-Path -Parent $OutFile
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $partial = $OutFile + '.partial'
    if (Test-Path -LiteralPath $partial) {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    }
    $resp = $null
    $inputStream = $null
    $output = $null
    $failed = $true
    try {
        $req = [Net.HttpWebRequest]::Create($Url)
        $req.Method = 'GET'
        $req.AllowAutoRedirect = $true
        $req.Timeout = $TimeoutSec * 1000
        $req.ReadWriteTimeout = $TimeoutSec * 1000
        $req.UserAgent = 'FLG-Driver-Downloader'
        if ($Headers) {
            foreach ($k in $Headers.Keys) {
                $name = [string]$k
                $val = [string]$Headers[$k]
                if ($name -eq 'User-Agent') { $req.UserAgent = $val }
                elseif ($name -eq 'Referer') { $req.Referer = $val }
                else { $req.Headers[$name] = $val }
            }
        }
        $resp = $req.GetResponse()
        $total = [int64]$resp.ContentLength
        $inputStream = $resp.GetResponseStream()
        $output = [IO.File]::Create($partial)
        $buffer = New-Object byte[] 65536
        $received = [int64]0
        $lastTick = [Environment]::TickCount
        while (($n = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $n)
            $received += $n
            $now = [Environment]::TickCount
            if (($now - $lastTick) -ge 200 -or ($total -gt 0 -and $received -ge $total)) {
                $lastTick = $now
                $snap = Write-FlgDownloadProgressLine -Received $received -Total $total
                Write-Host ("`r" + $snap.Line.PadRight(78)) -NoNewline
                if ($OnProgress) { & $OnProgress $snap }
            }
        }
        $output.Flush()
        $output.Dispose(); $output = $null
        if ($inputStream) { $inputStream.Dispose(); $inputStream = $null }
        if ($resp) { $resp.Dispose(); $resp = $null }
        Write-Host ''
        if ($total -gt 0 -and $received -ne $total) {
            throw ('下載中斷：已取得 {0}，預期 {1}' -f $received, $total)
        }
        if ($received -le 0 -or -not (Test-Path -LiteralPath $partial) -or (Get-Item -LiteralPath $partial).Length -le 0) {
            throw '下載失敗：沒有取得檔案內容'
        }
        Move-Item -LiteralPath $partial -Destination $OutFile -Force
        $failed = $false
        $finalSnap = Write-FlgDownloadProgressLine -Received $received -Total $(if ($total -gt 0) { $total } else { 0 })
        if ($OnProgress) { & $OnProgress $finalSnap }
        Write-Host ('已存到：' + $OutFile) -ForegroundColor Green
        return $OutFile
    } finally {
        if ($output) { try { $output.Dispose() } catch {} }
        if ($inputStream) { try { $inputStream.Dispose() } catch {} }
        if ($resp) { try { $resp.Dispose() } catch {} }
        if ($failed -and (Test-Path -LiteralPath $partial)) {
            Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        }
        if ($failed -and (Test-Path -LiteralPath $OutFile)) {
            $len = (Get-Item -LiteralPath $OutFile).Length
            if ($len -le 0) { Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue }
        }
    }
}

function Test-FlgPnpInstallFailed {
    param($ExitCode, [bool]$DriverInStore)
    if ($null -eq $ExitCode -or [string]$ExitCode -eq '') { return (-not $DriverInStore) }
    $code = 0
    if (-not [int]::TryParse([string]$ExitCode, [ref]$code)) { return (-not $DriverInStore) }
    if ($code -eq 0) { return $false }
    # 3010 ERROR_SUCCESS_REBOOT_REQUIRED, 1641 ERROR_SUCCESS_REBOOT_INITIATED
    if ($code -eq 3010 -or $code -eq 1641) { return $false }
    if ($DriverInStore) { return $false }
    return $true
}

function Get-FlgPnpRebootNote {
    param($ExitCode)
    $code = 0
    if (-not [int]::TryParse([string]$ExitCode, [ref]$code)) { return $null }
    if ($code -eq 3010 -or $code -eq 1641) {
        return ('pnputil 結束碼 {0}：需要重新開機才能完成驅動安裝。這不是安裝失敗。' -f $code)
    }
    return $null
}

function Read-FlgWindowsPrintState {
    $caption = ''
    $build = 0
    try {
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $caption = [string]$cv.ProductName
        [void][int]::TryParse([string]$cv.CurrentBuildNumber, [ref]$build)
    } catch {}
    if ($build -le 0) {
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $caption = [string]$os.Caption
            if ($os.BuildNumber) { [void][int]::TryParse([string]$os.BuildNumber, [ref]$build) }
        } catch {}
    }
    $policyPresent = $false
    $policyState = $null
    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP'
    try {
        if (Test-Path -LiteralPath $key) {
            $item = Get-ItemProperty -Path $key -ErrorAction Stop
            if ($item.PSObject.Properties.Name -contains 'WindowsProtectedPrintGroupPolicyState') {
                $policyPresent = $true
                $policyState = [int]$item.WindowsProtectedPrintGroupPolicyState
            }
        }
    } catch {}
    return @{
        OsCaption = $caption
        OsBuild = $build
        PolicyPresent = $policyPresent
        PolicyState = $policyState
    }
}

function Get-FlgPrintProtectionStep {
    param(
        [string]$ErrorMessage,
        [string]$OsCaption,
        [int]$OsBuild,
        [bool]$PolicyPresent,
        $PolicyState,
        [bool]$Interactive,
        [string[]]$Answers
    )
    $clean = [string]$ErrorMessage
    $clean = $clean -replace '^FLG_DRIVER_INSTALL_FAILED:\s*', ''
    $managedBlock = $false
    if ($PolicyPresent -and ($null -ne $PolicyState) -and ([int]$PolicyState -eq 1)) { $managedBlock = $true }
    if ($PolicyPresent -and ($null -ne $PolicyState) -and ([int]$PolicyState -ne 0) -and ([int]$PolicyState -ne 1)) { $managedBlock = $true }
    $notice = @(
        '驅動安裝沒有完成。',
        ('錯誤：{0}' -f $clean),
        '可能原因（不是每次失敗都是這個）：',
        '・Windows 列印被組織管理（公司原則或 MDM），不允許安裝這個驅動。',
        '・Windows 11 24H2（組建 26100）以後若開啟「Windows 受保護的列印」，只能用系統內建驅動，廠牌驅動會被擋下。',
        '檔案不完整、權限不足或驅動名稱不符也會失敗。不會把所有失敗都算成保護機制。',
        '預設不修改任何設定，也不會關閉 Defender、UAC，或放寬 Point and Print。',
        ('這台電腦：{0}，組建 {1}。' -f $(if ($OsCaption) { $OsCaption } else { 'Windows' }), $OsBuild)
    )
    if ($OsBuild -gt 0 -and $OsBuild -lt 26100) {
        $notice += '這個組建沒有「Windows 受保護的列印」開關（從 Windows 11 24H2／組建 26100 才有）。仍可能是印表機被組織管理。'
    }
    $base = @{
        Done = $false
        Action = 'stop'
        OpenSettings = $false
        Retry = $false
        ChangedSettings = $false
        Managed = [bool]$managedBlock
        NextPrompt = $null
        Lines = @()
    }
    if (-not $Interactive) {
        $base.Done = $true
        $base.Lines = @($notice + '目前不是互動模式，維持原設定，不重試安裝。')
        return $base
    }
    $list = @($Answers)
    if ($list.Count -lt 1) {
        $base.Lines = $notice
        $base.NextPrompt = '是否要協助調整成可以安裝？(Y/N，預設 N)'
        return $base
    }
    if (-not (Test-FlgYes $list[0])) {
        $base.Done = $true
        $base.Lines = @('已維持原設定，沒有修改，也不重試安裝。')
        return $base
    }
    $osLine = ('這台電腦：{0}，組建 {1}。' -f $(if ($OsCaption) { $OsCaption } else { 'Windows' }), $OsBuild)
    $explain = @($osLine)
    if ($OsBuild -gt 0 -and $OsBuild -lt 26100) {
        $explain += '這個組建沒有「Windows 受保護的列印」（從 Windows 11 24H2／組建 26100 才有）。仍可能是印表機被組織管理。'
    } elseif ($OsBuild -ge 26100) {
        $explain += '這個組建有「Windows 受保護的列印」。若設定頁看得到而且是開啟的，廠牌驅動會裝不進去。'
    }
    if ($PolicyPresent -and ($null -ne $PolicyState) -and ([int]$PolicyState -eq 0)) {
        $explain += '已讀到原則「設定 Windows 受保護的列印」的值是停用（WindowsProtectedPrintGroupPolicyState=0）。這條原則不是擋住的原因，程式也不會改它。'
    }
    if ($managedBlock) {
        $explain += '已讀到組織原則強制這項設定（HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP\WindowsProtectedPrintGroupPolicyState）。'
        $explain += '不會寫入或刪除這個登錄，也不會繞過 GPO／MDM。請系統管理員調整「設定 Windows 受保護的列印」。'
        $explain += '沒有可自動還原的備份，因為不會改設定。也不會重試安裝。'
        if ($list.Count -lt 2) {
            $base.Lines = $explain
            $base.NextPrompt = '要開啟「印表機與掃描器」設定頁查看嗎？(Y/N，預設 N)'
            return $base
        }
        $base.Done = $true
        $base.OpenSettings = (Test-FlgYes $list[1])
        $base.Lines = @($(if ($base.OpenSettings) { '將開啟設定 > 藍牙與裝置 > 印表機與掃描器。設定仍不會被程式修改。' } else { '不開啟設定頁，設定維持原狀。' }))
        return $base
    }
    $explain += '沒有看到由原則強制開啟。若是在設定裡手動打開的，請到「印表機與掃描器」關掉「Windows 受保護的列印」。'
    $explain += '微軟沒有提供可在這裡安全關閉的程式化開關，所以不會寫登錄，也不會聲稱已經解除。'
    $explain += '不會關閉 Defender 或 UAC，也不會放寬 Point and Print。沒有需要備份還原的項目。'
    $explain += '若你在設定裡關閉保護：之後可以再安裝廠牌驅動；先前被移除的印表機可能要重新安裝。'
    if ($list.Count -lt 2) {
        $base.Lines = $explain
        $base.NextPrompt = '確定只開啟設定頁，不改其他安全設定？(Y/N，預設 N)'
        return $base
    }
    if (-not (Test-FlgYes $list[1])) {
        $base.Done = $true
        $base.Lines = @('已維持原設定，沒有開啟設定頁，也不重試安裝。')
        return $base
    }
    if ($list.Count -lt 3) {
        $base.OpenSettings = $true
        $base.Lines = @('將開啟設定 > 藍牙與裝置 > 印表機與掃描器。請看「Windows 受保護的列印」；若顯示由貴組織管理，請交給系統管理員，不要在這台電腦硬改。')
        $base.NextPrompt = '若你已在設定裡關閉保護，是否重試安裝一次？(Y/N，預設 N)'
        return $base
    }
    $base.Done = $true
    $base.OpenSettings = $true
    $base.Retry = (Test-FlgYes $list[2])
    if ($base.Retry) { $base.Action = 'retry' }
    $base.Lines = @($(if ($base.Retry) { '將重試安裝一次。若再失敗就停止，不會一直重試。' } else { '不重試安裝，設定維持你剛剛看到的狀態。' }))
    return $base
}

function Invoke-FlgInstallFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [scriptblock]$RetryAction
    )
    if ($Message -notlike 'FLG_DRIVER_INSTALL_FAILED:*') {
        $Message = 'FLG_DRIVER_INSTALL_FAILED: ' + $Message
    }
    if ($script:FlgInstallRetried -or -not $RetryAction) { throw $Message }
    if (-not (Get-Command Invoke-FlgReportDriverInstallFailure -ErrorAction SilentlyContinue)) { throw $Message }
    $decision = Invoke-FlgReportDriverInstallFailure -ErrorMessage $Message
    if ($decision -ne 'retry') { throw $Message }
    $script:FlgInstallRetried = $true
    Write-Host '再試一次安裝。若仍失敗就停止。' -ForegroundColor Yellow
    & $RetryAction
}

function Invoke-FlgReportDriverInstallFailure {
    param(
        [string]$ErrorMessage,
        [hashtable]$State,
        [string[]]$Answers,
        [switch]$SuppressOpen
    )
    if (-not $State) { $State = Read-FlgWindowsPrintState }
    $interactive = $true
    if ($script:NonInteractive) { $interactive = $false }
    if ($State.ContainsKey('Interactive')) { $interactive = [bool]$State.Interactive }
    $pool = @($Answers)
    $fromPool = $PSBoundParameters.ContainsKey('Answers')
    $used = @()
    $guard = 0
    while ($guard -lt 6) {
        $guard++
        $step = Get-FlgPrintProtectionStep -ErrorMessage $ErrorMessage -OsCaption ([string]$State.OsCaption) -OsBuild ([int]$State.OsBuild) -PolicyPresent ([bool]$State.PolicyPresent) -PolicyState $State.PolicyState -Interactive $interactive -Answers $used
        foreach ($line in @($step.Lines)) { Write-Host $line }
        if ($step.OpenSettings -and -not $SuppressOpen -and -not $script:FlgSettingsOpened) {
            $script:FlgSettingsOpened = $true
            try { Start-Process 'ms-settings:printers' } catch {
                Write-Host '無法自動開啟設定頁。請手動打開：設定 > 藍牙與裝置 > 印表機與掃描器。'
            }
        }
        if ($step.Done) {
            if ($step.Retry) { return 'retry' }
            return 'stop'
        }
        if ($fromPool) {
            if ($used.Count -ge $pool.Count) { return 'stop' }
            $used += [string]$pool[$used.Count]
            continue
        }
        $typed = 'N'
        if ($step.NextPrompt) {
            $typed = Read-Host $step.NextPrompt
            if ([string]::IsNullOrWhiteSpace($typed)) { $typed = 'N' }
        }
        $used += $typed
    }
    return 'stop'
}
