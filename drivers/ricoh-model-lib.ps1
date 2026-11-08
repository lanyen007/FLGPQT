# Ricoh model PCL6 map for SNMP auto-install.
# SNMP text is matched to the longest model token inside these packages.
# ex, A, J, Z, SR and FB are different drivers from the base model.
# IM C300F is the exception: that SNMP name installs RICOH IM C300 PCL 6.
# pcl6-04 is PCL6 3.2.0.0 (MP C2004 through MP C6004, including ex).
# pcl6-03 is PCL6 3.1.0.0 (MP C3003 through MP C6003, one package).
# pcl6-02 is PCL6 1.10.0.0 (Aficio MP C4502 / C5502, including A).
# pcl6-im is PCL6 3.4.0.0 (IM C2000 through IM C6000).
# pcl6-im300 is PCL6 3.2.0.0 (IM C300 / IM C400 / IM C400SR).

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
    'pcl6-02' = @{
        File = 'RICOH_PCL6_C4502_C5502_1.10.0.0.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-ricoh-pcl6-model-3.2.0.0/RICOH_PCL6_C4502_C5502_1.10.0.0.zip'
        Sha256 = 'd8c9b0196907d476a8203de46b70bb707ece4d1ef59ff3da2254b2cbd943708a'
        Version = '1.10.0.0'
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
    # MP C2004-C6004, ex, and the other models in the same 3.2.0.0 package.
    'MP2554' = @{ Name = 'RICOH MP 2554 PCL 6'; Package = 'pcl6-04' }
    'MP2554J' = @{ Name = 'RICOH MP 2554J PCL 6'; Package = 'pcl6-04' }
    'MP305+' = @{ Name = 'RICOH MP 305+ PCL 6'; Package = 'pcl6-04' }
    'MP3054' = @{ Name = 'RICOH MP 3054 PCL 6'; Package = 'pcl6-04' }
    'MP3054J' = @{ Name = 'RICOH MP 3054J PCL 6'; Package = 'pcl6-04' }
    'MP3554' = @{ Name = 'RICOH MP 3554 PCL 6'; Package = 'pcl6-04' }
    'MP3554J' = @{ Name = 'RICOH MP 3554J PCL 6'; Package = 'pcl6-04' }
    'MP4054' = @{ Name = 'RICOH MP 4054 PCL 6'; Package = 'pcl6-04' }
    'MP501' = @{ Name = 'RICOH MP 501 PCL 6'; Package = 'pcl6-04' }
    'MP5054' = @{ Name = 'RICOH MP 5054 PCL 6'; Package = 'pcl6-04' }
    'MP601' = @{ Name = 'RICOH MP 601 PCL 6'; Package = 'pcl6-04' }
    'MP6054' = @{ Name = 'RICOH MP 6054 PCL 6'; Package = 'pcl6-04' }
    'MPC2004' = @{ Name = 'RICOH MP C2004 PCL 6'; Package = 'pcl6-04' }
    'MPC2004EX' = @{ Name = 'RICOH MP C2004ex PCL 6'; Package = 'pcl6-04' }
    'MPC2094EXJ' = @{ Name = 'RICOH MP C2094exJ PCL 6'; Package = 'pcl6-04' }
    'MPC2094J' = @{ Name = 'RICOH MP C2094J PCL 6'; Package = 'pcl6-04' }
    'MPC2504' = @{ Name = 'RICOH MP C2504 PCL 6'; Package = 'pcl6-04' }
    'MPC2504EX' = @{ Name = 'RICOH MP C2504ex PCL 6'; Package = 'pcl6-04' }
    'MPC2594EXJ' = @{ Name = 'RICOH MP C2594exJ PCL 6'; Package = 'pcl6-04' }
    'MPC2594J' = @{ Name = 'RICOH MP C2594J PCL 6'; Package = 'pcl6-04' }
    'MPC3004' = @{ Name = 'RICOH MP C3004 PCL 6'; Package = 'pcl6-04' }
    'MPC3004EX' = @{ Name = 'RICOH MP C3004ex PCL 6'; Package = 'pcl6-04' }
    'MPC306Z' = @{ Name = 'RICOH MP C306Z PCL 6'; Package = 'pcl6-04' }
    'MPC3504' = @{ Name = 'RICOH MP C3504 PCL 6'; Package = 'pcl6-04' }
    'MPC3504EX' = @{ Name = 'RICOH MP C3504ex PCL 6'; Package = 'pcl6-04' }
    'MPC401' = @{ Name = 'RICOH MP C401 PCL 6'; Package = 'pcl6-04' }
    'MPC401SR' = @{ Name = 'RICOH MP C401SR PCL 6'; Package = 'pcl6-04' }
    'MPC406Z' = @{ Name = 'RICOH MP C406Z PCL 6'; Package = 'pcl6-04' }
    'MPC4504' = @{ Name = 'RICOH MP C4504 PCL 6'; Package = 'pcl6-04' }
    'MPC4504EX' = @{ Name = 'RICOH MP C4504ex PCL 6'; Package = 'pcl6-04' }
    'MPC501' = @{ Name = 'RICOH MP C501 PCL 6'; Package = 'pcl6-04' }
    'MPC5504' = @{ Name = 'RICOH MP C5504 PCL 6'; Package = 'pcl6-04' }
    'MPC5504EX' = @{ Name = 'RICOH MP C5504ex PCL 6'; Package = 'pcl6-04' }
    'MPC6004' = @{ Name = 'RICOH MP C6004 PCL 6'; Package = 'pcl6-04' }
    'MPC6004EX' = @{ Name = 'RICOH MP C6004ex PCL 6'; Package = 'pcl6-04' }
    'PROC7100' = @{ Name = 'RICOH Pro C7100 PCL 6'; Package = 'pcl6-04' }
    'PROC7100S' = @{ Name = 'RICOH Pro C7100S PCL 6'; Package = 'pcl6-04' }
    'PROC7110' = @{ Name = 'RICOH Pro C7110 PCL 6'; Package = 'pcl6-04' }
    'PROC7110S' = @{ Name = 'RICOH Pro C7110S PCL 6'; Package = 'pcl6-04' }
    'SP5300' = @{ Name = 'RICOH SP 5300 PCL 6'; Package = 'pcl6-04' }
    'SP5310' = @{ Name = 'RICOH SP 5310 PCL 6'; Package = 'pcl6-04' }
    'SPC340DN' = @{ Name = 'RICOH SP C340DN PCL 6'; Package = 'pcl6-04' }
    'SPC342DN' = @{ Name = 'RICOH SP C342DN PCL 6'; Package = 'pcl6-04' }
    'SPC352DN' = @{ Name = 'RICOH SP C352DN PCL 6'; Package = 'pcl6-04' }
    'SPC435DN' = @{ Name = 'RICOH SP C435DN PCL 6'; Package = 'pcl6-04' }
    'SPC440DN' = @{ Name = 'RICOH SP C440DN PCL 6'; Package = 'pcl6-04' }
    'SPC840DN' = @{ Name = 'RICOH SP C840DN PCL 6'; Package = 'pcl6-04' }
    'SPC842DN' = @{ Name = 'RICOH SP C842DN PCL 6'; Package = 'pcl6-04' }

    # MP C3003-C6003 and the other models in the same 3.1.0.0 package.
    'MP2001' = @{ Name = 'RICOH MP 2001 PCL 6'; Package = 'pcl6-03' }
    'MP2001J' = @{ Name = 'RICOH MP 2001J PCL 6'; Package = 'pcl6-03' }
    'MP2501' = @{ Name = 'RICOH MP 2501 PCL 6'; Package = 'pcl6-03' }
    'MP2553' = @{ Name = 'RICOH MP 2553 PCL 6'; Package = 'pcl6-03' }
    'MP3053' = @{ Name = 'RICOH MP 3053 PCL 6'; Package = 'pcl6-03' }
    'MP3353' = @{ Name = 'RICOH MP 3353 PCL 6'; Package = 'pcl6-03' }
    'MP401SPF' = @{ Name = 'RICOH MP 401SPF PCL 6'; Package = 'pcl6-03' }
    'MPC2003' = @{ Name = 'RICOH MP C2003 PCL 6'; Package = 'pcl6-03' }
    'MPC2003J' = @{ Name = 'RICOH MP C2003J PCL 6'; Package = 'pcl6-03' }
    'MPC2003Z' = @{ Name = 'RICOH MP C2003Z PCL 6'; Package = 'pcl6-03' }
    'MPC2011' = @{ Name = 'RICOH MP C2011 PCL 6'; Package = 'pcl6-03' }
    'MPC2503' = @{ Name = 'RICOH MP C2503 PCL 6'; Package = 'pcl6-03' }
    'MPC2503J' = @{ Name = 'RICOH MP C2503J PCL 6'; Package = 'pcl6-03' }
    'MPC2503Z' = @{ Name = 'RICOH MP C2503Z PCL 6'; Package = 'pcl6-03' }
    'MPC3003' = @{ Name = 'RICOH MP C3003 PCL 6'; Package = 'pcl6-03' }
    'MPC3503' = @{ Name = 'RICOH MP C3503 PCL 6'; Package = 'pcl6-03' }
    'MPC4503' = @{ Name = 'RICOH MP C4503 PCL 6'; Package = 'pcl6-03' }
    'MPC5503' = @{ Name = 'RICOH MP C5503 PCL 6'; Package = 'pcl6-03' }
    'MPC6003' = @{ Name = 'RICOH MP C6003 PCL 6'; Package = 'pcl6-03' }
    'MPC6502' = @{ Name = 'RICOH MP C6502 PCL 6'; Package = 'pcl6-03' }
    'MPC8002' = @{ Name = 'RICOH MP C8002 PCL 6'; Package = 'pcl6-03' }
    'PRO8100S' = @{ Name = 'RICOH Pro 8100S PCL 6'; Package = 'pcl6-03' }
    'PRO8110' = @{ Name = 'RICOH Pro 8110 PCL 6'; Package = 'pcl6-03' }
    'PRO8110S' = @{ Name = 'RICOH Pro 8110S PCL 6'; Package = 'pcl6-03' }
    'PRO8120' = @{ Name = 'RICOH Pro 8120 PCL 6'; Package = 'pcl6-03' }
    'PRO8120S' = @{ Name = 'RICOH Pro 8120S PCL 6'; Package = 'pcl6-03' }
    'PROC5100S' = @{ Name = 'RICOH Pro C5100S PCL 6'; Package = 'pcl6-03' }
    'PROC5110S' = @{ Name = 'RICOH Pro C5110S PCL 6'; Package = 'pcl6-03' }
    'SP3600DN' = @{ Name = 'RICOH SP 3600DN PCL 6'; Package = 'pcl6-03' }
    'SP3600SF' = @{ Name = 'RICOH SP 3600SF PCL 6'; Package = 'pcl6-03' }
    'SP3610SF' = @{ Name = 'RICOH SP 3610SF PCL 6'; Package = 'pcl6-03' }
    'SP400DN' = @{ Name = 'RICOH SP 400DN PCL 6'; Package = 'pcl6-03' }
    'SP450DN' = @{ Name = 'RICOH SP 450DN PCL 6'; Package = 'pcl6-03' }
    'SP4510DN' = @{ Name = 'RICOH SP 4510DN PCL 6'; Package = 'pcl6-03' }
    'SP4510SF' = @{ Name = 'RICOH SP 4510SF PCL 6'; Package = 'pcl6-03' }
    'SP4520DN' = @{ Name = 'RICOH SP 4520DN PCL 6'; Package = 'pcl6-03' }
    'SP6430DN' = @{ Name = 'RICOH SP 6430DN PCL 6'; Package = 'pcl6-03' }
    'SP8300DN' = @{ Name = 'RICOH Aficio SP 8300DN PCL 6'; Package = 'pcl6-03' }
    'SPC730DN' = @{ Name = 'RICOH Aficio SP C730DN PCL 6'; Package = 'pcl6-03' }
    'SPC830DN' = @{ Name = 'RICOH Aficio SP C830DN PCL 6'; Package = 'pcl6-03' }
    'SPC831DN' = @{ Name = 'RICOH Aficio SP C831DN PCL 6'; Package = 'pcl6-03' }

    # Aficio MP C4502 / C5502 / C4502A / C5502A. PCL6 1.10.0.0.
    'MPC4502' = @{ Name = 'RICOH Aficio MP C4502 PCL 6'; Package = 'pcl6-02' }
    'MPC4502A' = @{ Name = 'RICOH Aficio MP C4502A PCL 6'; Package = 'pcl6-02' }
    'MPC5502' = @{ Name = 'RICOH Aficio MP C5502 PCL 6'; Package = 'pcl6-02' }
    'MPC5502A' = @{ Name = 'RICOH Aficio MP C5502A PCL 6'; Package = 'pcl6-02' }

    # IM C2000-C6000 and the other models in the same 3.4.0.0 package.
    'IM2702' = @{ Name = 'RICOH IM 2702 PCL 6'; Package = 'pcl6-im' }
    'IM550' = @{ Name = 'RICOH IM 550 PCL 6'; Package = 'pcl6-im' }
    'IM600' = @{ Name = 'RICOH IM 600 PCL 6'; Package = 'pcl6-im' }
    'IM600SR' = @{ Name = 'RICOH IM 600SR PCL 6'; Package = 'pcl6-im' }
    'IMC2000' = @{ Name = 'RICOH IM C2000 PCL 6'; Package = 'pcl6-im' }
    'IMC2500' = @{ Name = 'RICOH IM C2500 PCL 6'; Package = 'pcl6-im' }
    'IMC2509J' = @{ Name = 'RICOH IM C2509J PCL 6'; Package = 'pcl6-im' }
    'IMC3000' = @{ Name = 'RICOH IM C3000 PCL 6'; Package = 'pcl6-im' }
    'IMC3500' = @{ Name = 'RICOH IM C3500 PCL 6'; Package = 'pcl6-im' }
    'IMC3509J' = @{ Name = 'RICOH IM C3509J PCL 6'; Package = 'pcl6-im' }
    'IMC4500' = @{ Name = 'RICOH IM C4500 PCL 6'; Package = 'pcl6-im' }
    'IMC5500' = @{ Name = 'RICOH IM C5500 PCL 6'; Package = 'pcl6-im' }
    'IMC6000' = @{ Name = 'RICOH IM C6000 PCL 6'; Package = 'pcl6-im' }
    'MC2001' = @{ Name = 'RICOH M C2001 PCL 6'; Package = 'pcl6-im' }
    'MC2501' = @{ Name = 'RICOH M C2501 PCL 6'; Package = 'pcl6-im' }
    'P800' = @{ Name = 'RICOH P 800 PCL 6'; Package = 'pcl6-im' }
    'P801' = @{ Name = 'RICOH P 801 PCL 6'; Package = 'pcl6-im' }
    'PC600' = @{ Name = 'RICOH P C600 PCL 6'; Package = 'pcl6-im' }
    'PROC7200' = @{ Name = 'RICOH Pro C7200 PCL 6'; Package = 'pcl6-im' }
    'PROC7200S' = @{ Name = 'RICOH Pro C7200S PCL 6'; Package = 'pcl6-im' }
    'PROC7200SLIGHT' = @{ Name = 'RICOH Pro C7200S Light PCL 6'; Package = 'pcl6-im' }
    'PROC7210' = @{ Name = 'RICOH Pro C7210 PCL 6'; Package = 'pcl6-im' }
    'PROC7210S' = @{ Name = 'RICOH Pro C7210S PCL 6'; Package = 'pcl6-im' }

    # IM C300 / C400 and the other models in the same 3.2.0.0 package. IM C300F uses the IM C300 driver.
    'IM2500' = @{ Name = 'RICOH IM 2500 PCL 6'; Package = 'pcl6-im300' }
    'IM2509J' = @{ Name = 'RICOH IM 2509J PCL 6'; Package = 'pcl6-im300' }
    'IM3000' = @{ Name = 'RICOH IM 3000 PCL 6'; Package = 'pcl6-im300' }
    'IM3009J' = @{ Name = 'RICOH IM 3009J PCL 6'; Package = 'pcl6-im300' }
    'IM3500' = @{ Name = 'RICOH IM 3500 PCL 6'; Package = 'pcl6-im300' }
    'IM3509J' = @{ Name = 'RICOH IM 3509J PCL 6'; Package = 'pcl6-im300' }
    'IM4000' = @{ Name = 'RICOH IM 4000 PCL 6'; Package = 'pcl6-im300' }
    'IM5000' = @{ Name = 'RICOH IM 5000 PCL 6'; Package = 'pcl6-im300' }
    'IM6000' = @{ Name = 'RICOH IM 6000 PCL 6'; Package = 'pcl6-im300' }
    'IM7000' = @{ Name = 'RICOH IM 7000 PCL 6'; Package = 'pcl6-im300' }
    'IM8000' = @{ Name = 'RICOH IM 8000 PCL 6'; Package = 'pcl6-im300' }
    'IM9000' = @{ Name = 'RICOH IM 9000 PCL 6'; Package = 'pcl6-im300' }
    'IMC300' = @{ Name = 'RICOH IM C300 PCL 6'; Package = 'pcl6-im300' }
    'IMC300F' = @{ Name = 'RICOH IM C300 PCL 6'; Package = 'pcl6-im300'; Match = 'IM C300F' }
    'IMC400' = @{ Name = 'RICOH IM C400 PCL 6'; Package = 'pcl6-im300' }
    'IMC400SR' = @{ Name = 'RICOH IM C400SR PCL 6'; Package = 'pcl6-im300' }
    'IMC530F' = @{ Name = 'RICOH IM C530F PCL 6'; Package = 'pcl6-im300' }
    'IMC530FB' = @{ Name = 'RICOH IM C530FB PCL 6'; Package = 'pcl6-im300' }
    'IMC6500' = @{ Name = 'RICOH IM C6500 PCL 6'; Package = 'pcl6-im300' }
    'IMC8000' = @{ Name = 'RICOH IM C8000 PCL 6'; Package = 'pcl6-im300' }
    'PROC5300S' = @{ Name = 'RICOH Pro C5300S PCL 6'; Package = 'pcl6-im300' }
    'PROC5300SL' = @{ Name = 'RICOH Pro C5300SL PCL 6'; Package = 'pcl6-im300' }
    'PROC5310S' = @{ Name = 'RICOH Pro C5310S PCL 6'; Package = 'pcl6-im300' }
}


function Get-RicohMatchToken([string]$DriverName) {
    if ([string]::IsNullOrWhiteSpace($DriverName)) { return '' }
    $t = $DriverName.ToUpperInvariant()
    $t = [regex]::Replace($t, '^RICOH\s+', '')
    $t = [regex]::Replace($t, '^AFICIO\s+', '')
    $t = [regex]::Replace($t, '\s+PCL\s*6\s*$', '')
    return ([regex]::Replace($t, '\s+', ' ')).Trim()
}

function Test-RicohTokenInText([string]$Text, [string]$Token) {
    if ([string]::IsNullOrWhiteSpace($Token)) { return $false }
    $parts = @($Token -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) { return $false }
    $body = ($parts | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    return [regex]::IsMatch($Text, '(?<![A-Z0-9])' + $body + '(?![A-Z0-9])')
}

function Find-RicohModelDriver {
    param([string]$ModelText)
    if ([string]::IsNullOrWhiteSpace($ModelText)) { return $null }
    $text = $ModelText.ToUpperInvariant()
    $best = $null
    $bestKey = $null
    $bestLen = -1
    foreach ($key in @($script:RicohModelDrivers.Keys)) {
        $hit = $script:RicohModelDrivers[$key]
        $token = [string]$hit['Match']
        if ([string]::IsNullOrWhiteSpace($token)) { $token = Get-RicohMatchToken ([string]$hit.Name) }
        if (-not (Test-RicohTokenInText $text $token)) { continue }
        $len = ($token -replace '\s', '').Length
        if ($len -gt $bestLen) {
            $best = $hit
            $bestKey = [string]$key
            $bestLen = $len
        }
    }
    if (-not $best) { return $null }
    $pkgId = [string]$best.Package
    if (-not $script:RicohModelPackages.ContainsKey($pkgId)) { return $null }
    return [pscustomobject]@{
        Key = $bestKey
        DriverName = [string]$best.Name
        PackageId = $pkgId
        Package = $script:RicohModelPackages[$pkgId]
    }
}

function Get-RicohModelKey([string]$ModelText) {
    $hit = Find-RicohModelDriver $ModelText
    if (-not $hit) { return $null }
    return [string]$hit.Key
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
    $root = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($root)) { $root = [IO.Path]::GetTempPath() }
    $dir = Join-Path $root 'Downloads\lanyen-drivers\Ricoh'
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
        Invoke-WebRequest -Uri ([string]$pkg.Url) -OutFile $dest -UseBasicParsing
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
        [Parameter(Mandatory = $true)][string]$PrinterName
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
        if ($pnpCode -ne 0 -and $null -ne $pnpCode -and -not $inStore) {
            throw ('pnputil 安裝驅動失敗（結束碼 ' + $pnpCode + '）。')
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
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $portName -ErrorAction Stop
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
