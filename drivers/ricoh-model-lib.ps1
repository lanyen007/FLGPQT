# Ricoh model PCL6 map for SNMP auto-install.
# The Desktop folders c3504, c3054ex (3504ex.exe), c6004 and c6004ex are the same
# PCL6 3.2.0.0 package. c4503 is the PCL6 3.1.0.0 package.
# SNMP model text such as "RICOH MP C3504ex" selects the driver name inside that package.
# ex is a different driver from the non-ex model.
# imc3000.exe and imc6000.exe are the same PCL6 3.4.0.0 package (IM C2000 through IM C6000).
# IMC300F.exe is the PCL6 3.2.0.0 package whose driver name is RICOH IM C300 PCL 6.

$script:RicohModelPackages = @{
    'pcl6-04' = @{
        File = 'RICOH_PCL6_C3004_C6004_3.2.0.0.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-ricoh-pcl6-model-3.2.0.0/RICOH_PCL6_C3004_C6004_3.2.0.0.zip'
        Sha256 = 'a4782c7ae8f031d344d1173222cd98fd260bfbd0b87dcf44cbda04afba846d0b'
        Version = '3.2.0.0'
    }
    'pcl6-03' = @{
        File = 'RICOH_PCL6_C4503_3.1.0.0.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-ricoh-pcl6-model-3.2.0.0/RICOH_PCL6_C4503_3.1.0.0.zip'
        Sha256 = '3a47fc98aff3426ee9ae9b2dc928975f8cdbd62d99f1e69ba5d2b1febb751722'
        Version = '3.1.0.0'
    }
    'pcl6-im' = @{
        File = 'RICOH_PCL6_IM_C3000_C6000_3.4.0.0.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-ricoh-pcl6-model-3.2.0.0/RICOH_PCL6_IM_C3000_C6000_3.4.0.0.zip'
        Sha256 = '3aae8f3be8b1ea5f2833c6ec9e9951083a24162f11972de7cf68208f8f0d9b7d'
        Version = '3.4.0.0'
    }
    'pcl6-im300' = @{
        File = 'RICOH_PCL6_IM_C300_3.2.0.0.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-ricoh-pcl6-model-3.2.0.0/RICOH_PCL6_IM_C300_3.2.0.0.zip'
        Sha256 = '45e3077145667d9b44d2c9e1d053bc3ccb9ba54eddbdc293ed61089a1abb1308'
        Version = '3.2.0.0'
    }
}

$script:RicohModelDrivers = @{
    'MPC2004'    = @{ Name = 'RICOH MP C2004 PCL 6';    Package = 'pcl6-04' }
    'MPC2504'    = @{ Name = 'RICOH MP C2504 PCL 6';    Package = 'pcl6-04' }
    'MPC2004EX'  = @{ Name = 'RICOH MP C2004ex PCL 6';  Package = 'pcl6-04' }
    'MPC2504EX'  = @{ Name = 'RICOH MP C2504ex PCL 6';  Package = 'pcl6-04' }
    'MPC3004'    = @{ Name = 'RICOH MP C3004 PCL 6';    Package = 'pcl6-04' }
    'MPC3504'    = @{ Name = 'RICOH MP C3504 PCL 6';    Package = 'pcl6-04' }
    'MPC3004EX'  = @{ Name = 'RICOH MP C3004ex PCL 6';  Package = 'pcl6-04' }
    'MPC3504EX'  = @{ Name = 'RICOH MP C3504ex PCL 6';  Package = 'pcl6-04' }
    'MPC4504'    = @{ Name = 'RICOH MP C4504 PCL 6';    Package = 'pcl6-04' }
    'MPC5504'    = @{ Name = 'RICOH MP C5504 PCL 6';    Package = 'pcl6-04' }
    'MPC6004'    = @{ Name = 'RICOH MP C6004 PCL 6';    Package = 'pcl6-04' }
    'MPC4504EX'  = @{ Name = 'RICOH MP C4504ex PCL 6';  Package = 'pcl6-04' }
    'MPC5504EX'  = @{ Name = 'RICOH MP C5504ex PCL 6';  Package = 'pcl6-04' }
    'MPC6004EX'  = @{ Name = 'RICOH MP C6004ex PCL 6';  Package = 'pcl6-04' }
    'MPC3003'    = @{ Name = 'RICOH MP C3003 PCL 6';    Package = 'pcl6-03' }
    'MPC3503'    = @{ Name = 'RICOH MP C3503 PCL 6';    Package = 'pcl6-03' }
    'MPC4503'    = @{ Name = 'RICOH MP C4503 PCL 6';    Package = 'pcl6-03' }
    'MPC5503'    = @{ Name = 'RICOH MP C5503 PCL 6';    Package = 'pcl6-03' }
    'MPC6003'    = @{ Name = 'RICOH MP C6003 PCL 6';    Package = 'pcl6-03' }
    'IMC2000'    = @{ Name = 'RICOH IM C2000 PCL 6';    Package = 'pcl6-im' }
    'IMC2500'    = @{ Name = 'RICOH IM C2500 PCL 6';    Package = 'pcl6-im' }
    'IMC3000'    = @{ Name = 'RICOH IM C3000 PCL 6';    Package = 'pcl6-im' }
    'IMC3500'    = @{ Name = 'RICOH IM C3500 PCL 6';    Package = 'pcl6-im' }
    'IMC4500'    = @{ Name = 'RICOH IM C4500 PCL 6';    Package = 'pcl6-im' }
    'IMC5500'    = @{ Name = 'RICOH IM C5500 PCL 6';    Package = 'pcl6-im' }
    'IMC6000'    = @{ Name = 'RICOH IM C6000 PCL 6';    Package = 'pcl6-im' }
    'IMC300'     = @{ Name = 'RICOH IM C300 PCL 6';     Package = 'pcl6-im300' }
    'IMC300F'    = @{ Name = 'RICOH IM C300 PCL 6';     Package = 'pcl6-im300' }
    'IMC400'     = @{ Name = 'RICOH IM C400 PCL 6';     Package = 'pcl6-im300' }
    'IMC400SR'   = @{ Name = 'RICOH IM C400SR PCL 6';   Package = 'pcl6-im300' }
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
function Get-RicohModelKey([string]$ModelText) {
    if ([string]::IsNullOrWhiteSpace($ModelText)) { return $null }
    $t = $ModelText.ToUpperInvariant()
    $m = [regex]::Match($t, '(?<fam>IM|MP)\s*C\s*(?<num>\d{3,4})(?<tail>EX|FB|SR|F)?\b')
    if (-not $m.Success) { return $null }
    $key = $m.Groups['fam'].Value + 'C' + $m.Groups['num'].Value
    $tail = $m.Groups['tail'].Value
    if ($tail -eq 'EX') { $key += 'EX' }
    elseif ($tail) { $key += $tail }
    return $key
}

function Find-RicohModelDriver {
    param([string]$ModelText)
    $key = Get-RicohModelKey $ModelText
    if (-not $key) { return $null }
    if (-not $script:RicohModelDrivers.ContainsKey($key)) { return $null }
    $hit = $script:RicohModelDrivers[$key]
    $pkgId = [string]$hit.Package
    if (-not $script:RicohModelPackages.ContainsKey($pkgId)) { return $null }
    return [pscustomobject]@{
        Key = $key
        DriverName = [string]$hit.Name
        PackageId = $pkgId
        Package = $script:RicohModelPackages[$pkgId]
    }
}

function Find-RicohModelInfFile {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$DriverName)
    $needle = '"' + $DriverName + '"'
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
    return [string]$hits[0]
}

function Save-RicohModelPackage {
    param([Parameter(Mandatory = $true)][string]$PackageId)
    if (-not $script:RicohModelPackages.ContainsKey($PackageId)) { throw ('沒有這個 Ricoh 驅動包：' + $PackageId) }
    $pkg = $script:RicohModelPackages[$PackageId]
    $file = [string]$pkg.File
    $expect = ([string]$pkg.Sha256).ToLowerInvariant()
    Import-FlgPrintAssist | Out-Null
    if (Get-Command Get-FlgDriverDownloadDir -ErrorAction SilentlyContinue) {
        $dir = Get-FlgDriverDownloadDir -Child 'lanyen-drivers\Ricoh'
    } else {
        $root = ''
        try { $root = [Environment]::GetFolderPath('UserProfile') } catch {}
        if ([string]::IsNullOrWhiteSpace($root)) { $root = $env:USERPROFILE }
        if ([string]::IsNullOrWhiteSpace($root)) { $root = [IO.Path]::GetTempPath() }
        $dir = Join-Path $root 'Downloads\lanyen-drivers\Ricoh'
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $dest = Join-Path $dir $file
    $copied = $false
    if (Get-Command Resolve-FlgOfflinePath -ErrorAction SilentlyContinue) {
        foreach ($rel in @((Join-Path 'drivers\packages' $file), (Join-Path 'drivers\packages\ricoh' $file))) {
            $local = Resolve-FlgOfflinePath $rel
            if ($local) {
                Copy-Item -LiteralPath $local -Destination $dest -Force
                if (Get-Command Write-Ok -ErrorAction SilentlyContinue) { Write-Ok ('離線模式：使用本機驅動包 ' + $file) }
                $copied = $true
                break
            }
        }
    }
    $have = $false
    if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 1MB) {
        $actual = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -eq $expect) { $have = $true }
        elseif ($copied) { throw ('離線驅動包 SHA256 不符：' + $file) }
    }
    if (-not $have) {
        $offline = $false
        if (Get-Command Test-FlgOffline -ErrorAction SilentlyContinue) { $offline = [bool](Test-FlgOffline) }
        if ($offline) {
            $net = $false
            if (Get-Command Test-FlgNetworkAvailable -ErrorAction SilentlyContinue) { $net = [bool](Test-FlgNetworkAvailable) }
            if (-not $net) { throw ('離線版找不到 Ricoh 驅動包：' + $file) }
            if (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue) { Write-WarnMsg '離線模式找不到本機驅動包，改從網路下載…' }
        }
        if (Get-Command Write-Info -ErrorAction SilentlyContinue) { Write-Info ('下載 Ricoh 機型驅動：' + $file) }
        if (Get-Command Save-FlgHttpWithProgress -ErrorAction SilentlyContinue) {
            [void](Save-FlgHttpWithProgress -Url ([string]$pkg.Url) -OutFile $dest)
        } else {
            Invoke-WebRequest -Uri ([string]$pkg.Url) -OutFile $dest -UseBasicParsing
        }
        if (-not (Test-Path -LiteralPath $dest) -or (Get-Item -LiteralPath $dest).Length -lt 1MB) {
            throw ('Ricoh 驅動包下載失敗：' + $file)
        }
        $actual2 = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual2 -ne $expect) { throw ('Ricoh 驅動包 SHA256 不符：期望 ' + $expect + ' 實際 ' + $actual2) }
        if (Get-Command Write-Ok -ErrorAction SilentlyContinue) { Write-Ok 'SHA256 正確' }
    }
    return $dest
}

function Install-RicohModelDriverPackage {
    param(
        [Parameter(Mandatory = $true)][string]$DriverName,
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Ip,
        [Parameter(Mandatory = $true)][string]$PrinterName,
        [switch]$Retry
    )
    $zipPath = Save-RicohModelPackage -PackageId $PackageId
    $work = Join-Path $env:TEMP ('FLG-RicohModel-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        Write-Info '解開 Ricoh 機型驅動…'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $work -Force
        $inf = Find-RicohModelInfFile -Root $work -DriverName $DriverName
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
        if ($rebootNote -and (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue)) { Write-WarnMsg $rebootNote }
        $pnpFailed = ($pnpCode -ne 0 -and $null -ne $pnpCode -and -not $inStore)
        if (Get-Command Test-FlgPnpInstallFailed -ErrorAction SilentlyContinue) {
            $pnpFailed = Test-FlgPnpInstallFailed -ExitCode $pnpCode -DriverInStore ([bool]$inStore)
        }
        if ($pnpFailed) {
            $pnpMsg = 'FLG_DRIVER_INSTALL_FAILED: pnputil 安裝驅動失敗（結束碼 ' + $pnpCode + '）。'
            if (-not $Retry -and (Get-Command Invoke-FlgInstallFailure -ErrorAction SilentlyContinue)) {
                Invoke-FlgInstallFailure -Message $pnpMsg -RetryAction { Install-RicohModelDriverPackage -DriverName $DriverName -PackageId $PackageId -Ip $Ip -PrinterName $PrinterName -Retry }
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
                    Invoke-FlgInstallFailure -Message $addMsg -RetryAction { Install-RicohModelDriverPackage -DriverName $DriverName -PackageId $PackageId -Ip $Ip -PrinterName $PrinterName -Retry }
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
        Write-Ok 'Ricoh 機型驅動安裝完成。'
        Write-Host ('  驅動：' + $DriverName) -ForegroundColor Green
        Write-Host ('  印表機：' + $PrinterName) -ForegroundColor Green
        Write-Host ('  連接埠：' + $portName + ' → ' + $Ip) -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $work) {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
