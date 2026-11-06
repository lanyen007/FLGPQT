# Legacy FUJI model map. Loaded by auto-driver-main.ps1 and cloud-install-main.ps1.
# Names come from the INF inside each hosted installer. Newer Apeos models with no
# IV/V/VI generation stay on the universal driver.

$script:FujiOldRawBase = 'https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/packages/fuji-old/'

function Get-FujiOldOsProfile {
    $is64 = $false
    try { $is64 = [bool][Environment]::Is64BitOperatingSystem } catch {}
    $major = 6
    try {
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        if ($null -ne $cv.CurrentMajorVersionNumber) { $major = [int]$cv.CurrentMajorVersionNumber }
        elseif ($cv.CurrentVersion) { $major = [int](([string]$cv.CurrentVersion).Split('.')[0]) }
    } catch {}
    return [pscustomobject]@{ Is64 = $is64; Win10 = ($major -ge 10) }
}

function Get-FujiOldPackageTable {
    if ($script:FujiOldPackageTable) { return $script:FujiOldPackageTable }
    $script:FujiOldPackageTable = @(
        @{
            Gen = 'IV'; Families = @('DocuCentre'); Models = @('C2263','C2265')
            HasT2 = $false; Win10Only = $false; Style = 'fx'
            Files = @{ X64 = 'IV2265_64bit.exe'; X86 = 'IV2265_windows7_32bit.exe' }
        },
        @{
            Gen = 'V'; Families = @('DocuCentre'); Models = @('C2263','C2265')
            HasT2 = $false; Win10Only = $false; Style = 'fx'
            Files = @{ X64 = 'DC_2263_2265_64bit.exe'; X86 = 'DC_2263_2265_32bit.exe' }
        },
        @{
            Gen = 'IV'; Families = @('ApeosPort','DocuCentre'); Models = @('3070','4070','5070')
            FamilyModels = @{ ApeosPort = @('3070','4070','5070'); DocuCentre = @('4070','5070') }
            HasT2 = $false; Win10Only = $false; Style = 'fx'
            Files = @{ X64 = 'IV5070_64bit.exe'; X86 = 'IV5070_32bit.exe' }
        },
        @{
            Gen = 'IV'; Families = @('ApeosPort','DocuCentre')
            Models = @('C2270','C3370','C3371','C4470','C5570')
            HasT2 = $false; Win10Only = $false; Style = 'fx'
            Files = @{ X64 = 'DocuCentre-IV_C5570.exe'; Win10x64 = 'DocuCentre-IV_C5570_win10_64bit.exe' }
        },
        @{
            Gen = 'VI'; Families = @('ApeosPort','DocuCentre')
            Models = @('C2271','C3370','C3371','C4471','C5571','C6671','C7771')
            HasT2 = $false; Win10Only = $true; Style = 'vi'
            Files = @{ Win10x64 = 'DocuCentre-VI_C5571_win10_64bit.exe' }
        },
        @{
            Gen = 'IV'; Families = @('ApeosPort','DocuCentre')
            Models = @('C2275','C3373','C3375','C4475','C5575')
            HasT2 = $false; Win10Only = $false; Style = 'fx'
            Files = @{ X64 = 'AP-IV3375_5575_64bit.exe'; X86 = 'AP-IV3375_5575_32bit.exe' }
        },
        @{
            Gen = 'V'; Families = @('ApeosPort','DocuCentre')
            Models = @('C2275','C3373','C3375','C4475','C5575','C6675','C7775')
            HasT2 = $true; Win10Only = $false; Style = 'fx'
            Files = @{ X64 = 'ApeosPort_V_3375_5575_64bit.exe'; X86 = 'ApeosPort_V_3375_5575_32bit.exe' }
        },
        @{
            Gen = 'V'; Families = @('ApeosPort','DocuCentre')
            Models = @('C2276','C3374','C3376','C4476','C5576','C6676','C7776')
            HasT2 = $false; Win10Only = $false; Style = 'k533'
            Files = @{ X64 = 'ffap5c7776pcl6240110w646izc.exe'; X86 = 'ffap5c7776pcl6240110w643izc.exe' }
        }
    )
    return $script:FujiOldPackageTable
}

function Get-FujiOldIdentity([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $s = [regex]::Replace($Text, '\s+', ' ').Trim()
    $s = [regex]::Replace($s, '(?i)\s+Multifunction\b.*$', '')
    $s = [regex]::Replace($s, '(?i)\s+v\s+\d[\d\.\s]*$', '')
    $s = $s.Trim()
    $family = $null
    if ($s -match '(?i)DocuCentre') { $family = 'DocuCentre' }
    elseif ($s -match '(?i)Apeos\s*Port') { $family = 'ApeosPort' }
    elseif ($s -match '(?i)\bApeos\b') { $family = 'Apeos' }
    $gen = $null
    $genAt = -1
    $m = [regex]::Match($s, '(?i)(?:DocuCentre|Apeos\s*Port|Apeos)\s*-\s*(VII|VI|IV|V)\b')
    if ($m.Success) {
        $gen = $m.Groups[1].Value.ToUpperInvariant()
        $genAt = $m.Index + $m.Length
    } else {
        $m2 = [regex]::Match($s, '(?i)(?<![A-Za-z])(VII|VI|IV|V)\s+(?=(?:C\s*)?\d{4}\b)')
        if ($m2.Success) {
            $gen = $m2.Groups[1].Value.ToUpperInvariant()
            $genAt = $m2.Index + $m2.Length
        }
    }
    if (-not $gen) { return $null }
    $tail = $s.Substring($genAt)
    $nm = [regex]::Match($tail, '(?i)^\s*((?:C\s*)?)(\d{4})\b')
    if (-not $nm.Success) { return $null }
    $prefix = ''
    if ($nm.Groups[1].Value -match '(?i)C') { $prefix = 'C' }
    $num = $nm.Groups[2].Value
    $t2 = $false
    $after = $tail.Substring($nm.Index + $nm.Length)
    if ($after -match '(?i)^\s+T2?\b') { $t2 = $true }
    return [pscustomobject]@{ Family = $family; Gen = $gen; Prefix = $prefix; Num = $num; T2 = $t2 }
}

function Select-FujiOldFilename($Pkg, $Os) {
    $files = $Pkg.Files
    if ($Pkg.Win10Only) {
        if ($Os.Is64 -and $Os.Win10 -and $files.Win10x64) { return [string]$files.Win10x64 }
        return $null
    }
    if ($Os.Is64 -and $Os.Win10 -and $files.Win10x64) { return [string]$files.Win10x64 }
    if ($Os.Is64 -and $files.X64) { return [string]$files.X64 }
    if ((-not $Os.Is64) -and $files.X86) { return [string]$files.X86 }
    return $null
}

function Select-FujiOldFamily($Pkg, [string]$Wanted, [string]$Token) {
    $limited = $Pkg.FamilyModels
    if ($limited) {
        if ($Wanted) {
            $list = $limited[$Wanted]
            if ($list -and ($list -contains $Token)) { return $Wanted }
            return $null
        }
        foreach ($name in @('DocuCentre','ApeosPort')) {
            $list = $limited[$name]
            if ($list -and ($list -contains $Token)) { return $name }
        }
        return $null
    }
    if ($Wanted) {
        if ($Pkg.Families -contains $Wanted) { return $Wanted }
        return $null
    }
    if ($Pkg.Families -contains 'DocuCentre') { return 'DocuCentre' }
    return [string]$Pkg.Families[0]
}

function Resolve-FujiOldHit($Id, $Os, [bool]$WantT2) {
    foreach ($pkg in (Get-FujiOldPackageTable)) {
        if ([string]$pkg.Gen -ne [string]$Id.Gen) { continue }
        if ($WantT2 -and -not $pkg.HasT2) { continue }
        $exact = [string]$Id.Prefix + [string]$Id.Num
        $token = $null
        if ($pkg.Models -contains $exact) { $token = $exact }
        elseif ([string]$Id.Prefix -eq '' -and ($pkg.Models -contains ('C' + [string]$Id.Num))) {
            $token = 'C' + [string]$Id.Num
        }
        if (-not $token) { continue }
        $fam = Select-FujiOldFamily $pkg ([string]$Id.Family) $token
        if (-not $fam) { continue }
        $file = Select-FujiOldFilename $pkg $Os
        return [pscustomobject]@{
            Family = $fam; Gen = [string]$pkg.Gen; Token = $token; UseT2 = [bool]($WantT2 -and $pkg.HasT2)
            Style = [string]$pkg.Style; Filename = $file
        }
    }
    return $null
}

function Find-FujiOldDriver {
    param([string]$ModelText, $OsProfile)
    if (-not $OsProfile) { $OsProfile = Get-FujiOldOsProfile }
    if ($ModelText -match '(?i)DocuPrint\s+(2065|3055)\b') {
        $token = $Matches[1]
        $file = $(if ($OsProfile.Is64) { 'ffdp3055pcl623121nw646izc.exe' } else { 'ffdp3055pcl623121nw643izc.exe' })
        $driverName = ('FF K573p for DocuPrint {0} PCL 6' -f $token)
        return [pscustomobject]@{
            Filename = $file
            Url = ($script:FujiOldRawBase + $file)
            DriverName = $driverName
            Model = ('DocuPrint ' + $token)
            Title = ('舊版 FUJI · ' + $driverName)
        }
    }
    $id = Get-FujiOldIdentity $ModelText
    if (-not $id) { return $null }
    if (-not $OsProfile) { $OsProfile = Get-FujiOldOsProfile }
    $hit = $null
    if ($id.T2) { $hit = Resolve-FujiOldHit $id $OsProfile $true }
    if (-not $hit) { $hit = Resolve-FujiOldHit $id $OsProfile $false }
    if (-not $hit) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$hit.Filename)) {
        if (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue) {
            Write-WarnMsg '這台電腦的 Windows 沒有對應的舊版 FUJI 安裝檔，改用通用驅動。'
        }
        return $null
    }
    $shown = [string]$hit.Token
    if ($hit.UseT2) { $shown = $shown + ' T2' }
    $driverName = $null
    if ($hit.Style -eq 'vi') {
        $driverName = ('FF K529p for {0}-{1} {2} PCL 6' -f $hit.Family, $hit.Gen, $hit.Token)
    } elseif ($hit.Style -eq 'k533') {
        $driverName = ('FF K533p for {0}-{1} {2} PCL 6' -f $hit.Family, $hit.Gen, $shown)
    } else {
        $driverName = ('FX {0}-{1} {2} PCL 6' -f $hit.Family, $hit.Gen, $shown)
    }
    $model = ('{0}-{1} {2}' -f $hit.Family, $hit.Gen, $shown)
    $file = [string]$hit.Filename
    return [pscustomobject]@{
        Filename = $file
        Url = ($script:FujiOldRawBase + $file)
        DriverName = $driverName
        Model = $model
        Title = ('舊版 FUJI · ' + $driverName)
    }
}

function Expand-FujiOldInstaller {
    param([Parameter(Mandatory = $true)][string]$ExePath, [Parameter(Mandatory = $true)][string]$DestDir)
    if (-not (Test-Path -LiteralPath $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }
    $zip = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        $zip = [IO.Compression.ZipFile]::OpenRead($ExePath)
        foreach ($entry in $zip.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            $rel = ($entry.FullName -replace '/', '\')
            if ($rel -match '\.\.') { continue }
            $target = Join-Path $DestDir $rel
            $parent = Split-Path -Parent $target
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            $inStream = $entry.Open()
            try {
                $outStream = [IO.File]::Create($target)
                try { $inStream.CopyTo($outStream) } finally { $outStream.Close() }
            } finally { $inStream.Close() }
        }
        $zip.Dispose()
        $zip = $null
        $hit = Get-ChildItem -LiteralPath $DestDir -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $true }
    } catch {
        if ($zip) { try { $zip.Dispose() } catch {} }
    }
    # WinRAR GUI SFX: -s1 hides the start dialog, -d sets the destination folder.
    $proc = Start-Process -FilePath $ExePath -ArgumentList @('-s1', ('-d' + $DestDir)) -PassThru -WindowStyle Hidden
    if (-not $proc.WaitForExit(180000)) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    $hit2 = Get-ChildItem -LiteralPath $DestDir -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    return [bool]$hit2
}

function Find-FujiOldInfFile {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$DriverName)
    $needle = '"' + $DriverName + '"'
    $is64 = $false
    try { $is64 = [bool][Environment]::Is64BitOperatingSystem } catch {}
    $prefer = $(if ($is64) { '\\amd64\\' } else { '\\i386\\' })
    $hits = New-Object System.Collections.ArrayList
    Get-ChildItem -LiteralPath $Root -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $bytes = $null
        try { $bytes = [IO.File]::ReadAllBytes($_.FullName) } catch { return }
        $text = $null
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
            $text = [Text.Encoding]::Unicode.GetString($bytes)
        } else {
            $text = [Text.Encoding]::ASCII.GetString($bytes)
        }
        if ($text.Contains($needle)) { [void]$hits.Add($_.FullName) }
    }
    if ($hits.Count -eq 0) { return $null }
    foreach ($path in $hits) {
        if ($path -match $prefer) { return $path }
    }
    return [string]$hits[0]
}

function Import-FlgPrintAssist {
    if (Get-Command Save-FlgHttpWithProgress -ErrorAction SilentlyContinue) { return $true }
    $local = $null
    if (Get-Command Resolve-FlgOfflinePath -ErrorAction SilentlyContinue) {
        $local = Resolve-FlgOfflinePath 'drivers\flg-print-assist.ps1'
    }
    if (-not $local -and $PSScriptRoot) {
        $cand = Join-Path $PSScriptRoot 'flg-print-assist.ps1'
        if (Test-Path -LiteralPath $cand) { $local = $cand }
    }
    $code = $null
    if ($local) { $code = [IO.File]::ReadAllText($local) }
    else {
        try {
            $bytes = (New-Object Net.WebClient).DownloadData('https://lanyen007.github.io/FLGPQT/drivers/flg-print-assist.ps1?t=' + [DateTime]::UtcNow.Ticks)
            $code = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
        } catch { return $false }
    }
    if (-not $code) { return $false }
    . ([scriptblock]::Create($code))
    return [bool](Get-Command Save-FlgHttpWithProgress -ErrorAction SilentlyContinue)
}
function Save-FujiOldExe {
    param([Parameter(Mandatory = $true)][string]$Url, [Parameter(Mandatory = $true)][string]$Filename)
    Import-FlgPrintAssist | Out-Null
    if (Get-Command Get-FlgDriverDownloadDir -ErrorAction SilentlyContinue) {
        $dir = Get-FlgDriverDownloadDir -Child 'lanyen-drivers\舊版 FUJI'
    } else {
        $root = ''
        try { $root = [Environment]::GetFolderPath('UserProfile') } catch {}
        if ([string]::IsNullOrWhiteSpace($root)) { $root = $env:USERPROFILE }
        if ([string]::IsNullOrWhiteSpace($root)) { $root = [IO.Path]::GetTempPath() }
        $dir = Join-Path $root 'Downloads\lanyen-drivers\舊版 FUJI'
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    $dest = Join-Path $dir $Filename
    $copied = $false
    if (Get-Command Resolve-FlgOfflinePath -ErrorAction SilentlyContinue) {
        foreach ($rel in @((Join-Path 'drivers\packages\fuji-old' $Filename), (Join-Path 'drivers\packages' $Filename))) {
            $local = Resolve-FlgOfflinePath $rel
            if ($local) {
                Copy-Item -LiteralPath $local -Destination $dest -Force
                Write-Ok ('離線模式：使用本機安裝檔 ' + $Filename)
                $copied = $true
                break
            }
        }
    }
    if (-not $copied) {
        $offline = $false
        if (Get-Command Test-FlgOffline -ErrorAction SilentlyContinue) { $offline = [bool](Test-FlgOffline) }
        if ($offline) {
            $net = $false
            if (Get-Command Test-FlgNetworkAvailable -ErrorAction SilentlyContinue) { $net = [bool](Test-FlgNetworkAvailable) }
            if (-not $net) { throw ('離線版找不到舊版 FUJI 安裝檔：' + $Filename) }
            Write-WarnMsg '離線模式找不到本機安裝檔，改從網路下載…'
        }
        Write-Info ('下載舊版 FUJI：' + $Filename)
        Write-Host ('  ' + $Url) -ForegroundColor DarkGray
        if (Get-Command Save-FlgHttpWithProgress -ErrorAction SilentlyContinue) {
            [void](Save-FlgHttpWithProgress -Url $Url -OutFile $dest)
        } else {
            Invoke-WebRequest -Uri $Url -OutFile $dest -UseBasicParsing
        }
    }
    if (-not (Test-Path -LiteralPath $dest)) { throw ('舊版 FUJI 安裝檔下載失敗：' + $Filename) }
    if ((Get-Item -LiteralPath $dest).Length -lt 1MB) { throw ('舊版 FUJI 安裝檔太小：' + $Filename) }
    return $dest
}

function Install-FujiOldDriverPackage {
    param(
        [Parameter(Mandatory = $true)][string]$DriverName,
        [Parameter(Mandatory = $true)][string]$Ip,
        [Parameter(Mandatory = $true)][string]$PrinterName,
        [string]$ExePath,
        [string]$DownloadUrl,
        [string]$DownloadName,
        [switch]$Retry
    )
    if ([string]::IsNullOrWhiteSpace($ExePath)) {
        if ([string]::IsNullOrWhiteSpace($DownloadUrl) -or [string]::IsNullOrWhiteSpace($DownloadName)) {
            throw '沒有舊版 FUJI 安裝檔。'
        }
        $ExePath = Save-FujiOldExe -Url $DownloadUrl -Filename $DownloadName
    }
    $work = Join-Path $env:TEMP ('FLG-FujiOld-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        Write-Info '解開舊版 FUJI 安裝檔…'
        $opened = Expand-FujiOldInstaller -ExePath $ExePath -DestDir $work
        if (-not $opened) { throw '無法解開舊版安裝檔。檔案已留在下載資料夾，可手動執行。' }
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ExecutablePath -and $_.ExecutablePath.StartsWith($work, [StringComparison]::OrdinalIgnoreCase)
        } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        $inf = Find-FujiOldInfFile -Root $work -DriverName $DriverName
        if (-not $inf) { throw ('安裝檔裡找不到驅動：' + $DriverName) }
        Write-Ok ('INF：' + $inf)
        Write-Info '安裝驅動套件（pnputil）…'
        $pnp = & pnputil.exe /add-driver $inf /install 2>&1
        $pnp | ForEach-Object { Write-Host ('  ' + $_) }
        $pnpCode = $LASTEXITCODE
        $inStore = $false
        if (Get-Command Test-PrinterDriverInStore -ErrorAction SilentlyContinue) {
            $inStore = [bool](Test-PrinterDriverInStore $DriverName)
        } else {
            $inStore = [bool](Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)
        }
        Import-FlgPrintAssist | Out-Null
        $rebootNote = $null
        if (Get-Command Get-FlgPnpRebootNote -ErrorAction SilentlyContinue) { $rebootNote = Get-FlgPnpRebootNote $pnpCode }
        if ($rebootNote) { Write-WarnMsg $rebootNote }
        $pnpFailed = ($pnpCode -ne 0 -and $null -ne $pnpCode -and -not $inStore)
        if (Get-Command Test-FlgPnpInstallFailed -ErrorAction SilentlyContinue) {
            $pnpFailed = Test-FlgPnpInstallFailed -ExitCode $pnpCode -DriverInStore ([bool]$inStore)
        }
        if ($pnpFailed) {
            $pnpMsg = 'FLG_DRIVER_INSTALL_FAILED: pnputil 安裝驅動失敗（結束碼 ' + $pnpCode + '）。'
            if (-not $Retry -and (Get-Command Invoke-FlgInstallFailure -ErrorAction SilentlyContinue)) {
                Invoke-FlgInstallFailure -Message $pnpMsg -RetryAction {
                    Install-FujiOldDriverPackage -DriverName $DriverName -Ip $Ip -PrinterName $PrinterName -ExePath $ExePath -DownloadUrl $DownloadUrl -DownloadName $DownloadName -Retry
                }
                return
            }
            throw $pnpMsg
        }
        if (-not (Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)) {
            Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        } else {
            Write-Ok '驅動已存在，略過 Add-PrinterDriver'
        }
        $portName = 'IP_' + $Ip
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $portName -PrinterHostAddress $Ip -ErrorAction Stop
        }
        $prev = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($prev) {
            Write-WarnMsg '同名印表機已存在，將移除後重建…'
            Remove-Printer -Name $PrinterName -ErrorAction Stop
        }
        try {
            Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $portName -ErrorAction Stop
        } catch {
            if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {
                $addMsg = 'FLG_DRIVER_INSTALL_FAILED: 新增印表機失敗：' + $_.Exception.Message
                if (-not $Retry -and (Get-Command Invoke-FlgInstallFailure -ErrorAction SilentlyContinue)) {
                    Invoke-FlgInstallFailure -Message $addMsg -RetryAction {
                        Install-FujiOldDriverPackage -DriverName $DriverName -Ip $Ip -PrinterName $PrinterName -ExePath $ExePath -DownloadUrl $DownloadUrl -DownloadName $DownloadName -Retry
                    }
                    return
                }
                throw $addMsg
            }
        }
        try {
            Set-PrintConfiguration -PrinterName $PrinterName -Color $false -DuplexingMode OneSided -ErrorAction Stop
            Write-Ok '已設定預設：黑白、單面'
        } catch { Write-WarnMsg ('設定黑白單面失敗：' + $_.Exception.Message) }
        $esc = $PrinterName.Replace("'", "''")
        try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name 'LegacyDefaultPrinterMode' -Value 1 -Type DWord -ErrorAction Stop } catch {}
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter | Out-Null
            Write-Ok '已設為預設印表機'
        } catch {
            try { (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName) | Out-Null; Write-Ok '已設為預設印表機' }
            catch { Write-WarnMsg ('設預設失敗：' + $_.Exception.Message) }
        }
        Start-Sleep -Seconds 2
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            $null = Invoke-CimMethod -InputObject $printer -MethodName PrintTestPage
            Write-Ok '已送出測試頁'
        } catch {
            try { Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /k /n "' + $PrinterName + '"') -Wait; Write-Ok '已送出測試頁' }
            catch { Write-WarnMsg ('測試頁失敗：' + $_.Exception.Message) }
        }
        Write-Ok '舊版 FUJI 安裝完成。'
        Write-Host ('  驅動：' + $DriverName) -ForegroundColor Green
        Write-Host ('  印表機：' + $PrinterName) -ForegroundColor Green
        Write-Host ('  連接埠：' + $portName + ' → ' + $Ip) -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $work) {
            Get-ChildItem -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { $_.Attributes = 'Normal' } catch {}
            }
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
