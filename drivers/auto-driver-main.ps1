# FLG 自動偵測機型下載／安裝驅動 + 區網掃描
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/auto-driver.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/auto-driver-scan.ps1 | iex
#   & script 192.168.1.50
#   & script scan
# 環境變數 FLG_AUTO_MODE=scan 直接進入區網掃描

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$IsWindowsOs = $false
try {
    if ($PSVersionTable.PSEdition -eq 'Desktop') { $IsWindowsOs = $true }
    elseif ($PSVersionTable.Platform -eq 'Win32NT') { $IsWindowsOs = $true }
    elseif ($env:OS -match 'Windows') { $IsWindowsOs = $true }
} catch {}

$RawBase = 'https://lanyen007.github.io/FLGPQT'
$PagesBase = 'https://lanyen007.github.io/FLGPQT/drivers/'
$script:UserProfile = $env:USERPROFILE
if ([string]::IsNullOrWhiteSpace($script:UserProfile)) { $script:UserProfile = $env:HOME }
if ([string]::IsNullOrWhiteSpace($script:UserProfile)) { $script:UserProfile = [IO.Path]::GetTempPath() }
$DestRoot = Join-Path $script:UserProfile 'Downloads\lanyen-drivers'
$CloudJsonUrl = "$RawBase/drivers/cloud.json" + '?t=' + [DateTime]::UtcNow.Ticks

$script:Mode = 'auto'
$script:ArgIp = ''
$script:NonInteractive = $false
if ($env:FLG_AUTO_MODE -and ([string]$env:FLG_AUTO_MODE).Trim().ToLowerInvariant() -eq 'scan') {
    $script:Mode = 'scan'
}
$argList = @($args)
if ($argList.Count -gt 0) {
    $a0 = [string]$argList[0]
    if ($a0 -match '^(?i)(-?scan|/scan)$') {
        $script:Mode = 'scan'
        $argList = @($argList | Select-Object -Skip 1)
    } elseif ($a0 -match '^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$') {
        $script:ArgIp = $a0.Trim()
        $script:NonInteractive = $true
        $argList = @($argList | Select-Object -Skip 1)
    }
}

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
        $principal = New-Object Security.Principal.WindowsPrincipal($id)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-Ipv4Address([string]$Ip) {
    if ([string]::IsNullOrWhiteSpace($Ip)) { return $false }
    return [regex]::IsMatch($Ip.Trim(), '^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$')
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-FileSha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $fs = [IO.File]::OpenRead($Path)
    try {
        $hash = $sha.ComputeHash($fs)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } finally {
        $fs.Close()
        $sha.Dispose()
    }
}

function Test-PrinterDriverInStore([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    try {
        $null = Get-PrinterDriver -Name $Name -ErrorAction Stop
        return $true
    } catch { return $false }
}

# ---- SNMP v1/v2c GET（純 PowerShell BER + UdpClient）----
function ConvertTo-BerLength([int]$Len) {
    if ($Len -lt 0x80) { return ,[byte[]]@([byte]$Len) }
    if ($Len -le 0xFF) { return ,[byte[]]@(0x81, [byte]$Len) }
    return ,[byte[]]@(0x82, [byte](($Len -shr 8) -band 0xFF), [byte]($Len -band 0xFF))
}
function ConvertTo-BerInteger([int]$Value) {
    $bytes = New-Object System.Collections.ArrayList
    if ($Value -eq 0) {
        [void]$bytes.Add([byte]0)
    } elseif ($Value -gt 0) {
        $tmp = $Value
        $stack = New-Object System.Collections.ArrayList
        while ($tmp -gt 0) {
            [void]$stack.Insert(0, [byte]($tmp -band 0xFF))
            $tmp = $tmp -shr 8
        }
        if (($stack[0] -band 0x80) -ne 0) { [void]$stack.Insert(0, [byte]0) }
        foreach ($b in $stack) { [void]$bytes.Add($b) }
    } else {
        [void]$bytes.Add([byte]($Value -band 0xFF))
    }
    $content = [byte[]]$bytes.ToArray()
    $len = ConvertTo-BerLength $content.Length
    $out = New-Object byte[] (1 + $len.Length + $content.Length)
    $out[0] = 0x02
    [Buffer]::BlockCopy($len, 0, $out, 1, $len.Length)
    [Buffer]::BlockCopy($content, 0, $out, 1 + $len.Length, $content.Length)
    return ,$out
}
function ConvertTo-BerOctetString([string]$Text) {
    $content = [Text.Encoding]::ASCII.GetBytes($Text)
    $len = ConvertTo-BerLength $content.Length
    $out = New-Object byte[] (1 + $len.Length + $content.Length)
    $out[0] = 0x04
    [Buffer]::BlockCopy($len, 0, $out, 1, $len.Length)
    [Buffer]::BlockCopy($content, 0, $out, 1 + $len.Length, $content.Length)
    return ,$out
}
function ConvertTo-BerNull { return ,[byte[]]@(0x05, 0x00) }
function ConvertTo-BerOid([string]$Oid) {
    $parts = @($Oid.Trim('.').Split('.') | ForEach-Object { [int]$_ })
    if ($parts.Count -lt 2) { throw "OID 無效：$Oid" }
    $encoded = New-Object System.Collections.ArrayList
    [void]$encoded.Add([byte](40 * $parts[0] + $parts[1]))
    for ($i = 2; $i -lt $parts.Count; $i++) {
        $n = $parts[$i]
        if ($n -lt 0x80) {
            [void]$encoded.Add([byte]$n)
        } else {
            $stack = New-Object System.Collections.ArrayList
            [void]$stack.Insert(0, [byte]($n -band 0x7F))
            $n = $n -shr 7
            while ($n -gt 0) {
                [void]$stack.Insert(0, [byte](($n -band 0x7F) -bor 0x80))
                $n = $n -shr 7
            }
            foreach ($b in $stack) { [void]$encoded.Add($b) }
        }
    }
    $content = [byte[]]$encoded.ToArray()
    $len = ConvertTo-BerLength $content.Length
    $out = New-Object byte[] (1 + $len.Length + $content.Length)
    $out[0] = 0x06
    [Buffer]::BlockCopy($len, 0, $out, 1, $len.Length)
    [Buffer]::BlockCopy($content, 0, $out, 1 + $len.Length, $content.Length)
    return ,$out
}
function ConvertTo-BerSequence([byte]$Tag, [byte[]]$Content) {
    $len = ConvertTo-BerLength $Content.Length
    $out = New-Object byte[] (1 + $len.Length + $Content.Length)
    $out[0] = $Tag
    [Buffer]::BlockCopy($len, 0, $out, 1, $len.Length)
    [Buffer]::BlockCopy($Content, 0, $out, 1 + $len.Length, $Content.Length)
    return ,$out
}
function Join-ByteArrays([byte[][]]$Parts) {
    $total = 0
    foreach ($p in $Parts) { $total += $p.Length }
    $out = New-Object byte[] $total
    $off = 0
    foreach ($p in $Parts) {
        [Buffer]::BlockCopy($p, 0, $out, $off, $p.Length)
        $off += $p.Length
    }
    return ,$out
}
function New-SnmpGetRequestPacket([string]$Community, [string]$Oid, [int]$RequestId, [int]$Version) {
    $vbOid = ConvertTo-BerOid $Oid
    $vbNull = ConvertTo-BerNull
    $vbInner = Join-ByteArrays @($vbOid, $vbNull)
    $vb = ConvertTo-BerSequence 0x30 $vbInner
    $vbList = ConvertTo-BerSequence 0x30 $vb
    $reqId = ConvertTo-BerInteger $RequestId
    $errSt = ConvertTo-BerInteger 0
    $errIdx = ConvertTo-BerInteger 0
    $pduBody = Join-ByteArrays @($reqId, $errSt, $errIdx, $vbList)
    $pdu = ConvertTo-BerSequence 0xA0 $pduBody
    $ver = ConvertTo-BerInteger $Version
    $com = ConvertTo-BerOctetString $Community
    $msgBody = Join-ByteArrays @($ver, $com, $pdu)
    return ,(ConvertTo-BerSequence 0x30 $msgBody)
}
function Get-BerLengthAt([byte[]]$Buf, [int]$Offset) {
    $b = $Buf[$Offset]
    if ($b -lt 0x80) { return @{ Length = [int]$b; Size = 1 } }
    $n = $b -band 0x7F
    $len = 0
    for ($i = 1; $i -le $n; $i++) { $len = ($len -shl 8) -bor $Buf[$Offset + $i] }
    return @{ Length = $len; Size = (1 + $n) }
}
function Get-SnmpOctetStringValue([byte[]]$Response) {
    $candidates = New-Object System.Collections.ArrayList
    $i = 0
    while ($i -lt $Response.Length) {
        $tag = $Response[$i]
        if (($i + 1) -ge $Response.Length) { break }
        $lr = Get-BerLengthAt $Response ($i + 1)
        $contentStart = $i + 1 + $lr.Size
        $contentLen = $lr.Length
        if (($contentStart + $contentLen) -gt $Response.Length) { break }
        if ($tag -eq 0x04 -or $tag -eq 0x44) {
            $slice = New-Object byte[] $contentLen
            [Buffer]::BlockCopy($Response, $contentStart, $slice, 0, $contentLen)
            $text = [Text.Encoding]::UTF8.GetString($slice).Trim([char]0)
            if (-not $text) { $text = [Text.Encoding]::ASCII.GetString($slice).Trim([char]0) }
            if ($text -and $text -ne 'public' -and $text.Length -ge 2) { [void]$candidates.Add($text) }
            $i = $contentStart + $contentLen
            continue
        }
        if ($tag -eq 0x30 -or $tag -eq 0xA0 -or $tag -eq 0xA2 -or ($tag -band 0x20) -ne 0) {
            $i = $contentStart
            continue
        }
        $i = $contentStart + $contentLen
    }
    if ($candidates.Count -eq 0) { return $null }
    return [string]$candidates[$candidates.Count - 1]
}
function Invoke-SnmpGet {
    param([string]$Ip, [string]$Oid, [string]$Community = 'public', [int]$TimeoutMs = 2000, [int]$Version = 1)
    $reqId = Get-Random -Minimum 1 -Maximum 2000000000
    $packet = New-SnmpGetRequestPacket -Community $Community -Oid $Oid -RequestId $reqId -Version $Version
    $udp = $null
    try {
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = $TimeoutMs
        $udp.Client.SendTimeout = $TimeoutMs
        $null = $udp.Send($packet, $packet.Length, $Ip, 161)
        $remote = New-Object System.Net.IPEndPoint ([Net.IPAddress]::Any, 0)
        $resp = $udp.Receive([ref]$remote)
        return (Get-SnmpOctetStringValue $resp)
    } catch { return $null } finally {
        if ($udp) { try { $udp.Close() } catch {} }
    }
}
function Get-PrinterModelViaSnmp([string]$Ip, [switch]$Quiet) {
    if (-not $Quiet) { Write-Info ("SNMP 偵測機型 $Ip （community public，UDP 161）…") }
    $oids = @(
        '1.3.6.1.2.1.1.1.0',
        '1.3.6.1.2.1.25.3.2.1.3.1',
        '1.3.6.1.2.1.43.5.1.1.16.1'
    )
    $hits = New-Object System.Collections.ArrayList
    foreach ($ver in @(1, 0)) {
        foreach ($oid in $oids) {
            $val = Invoke-SnmpGet -Ip $Ip -Oid $oid -Community 'public' -TimeoutMs 1500 -Version $ver
            if ($val) {
                if (-not $Quiet) { Write-Host ("  OID $oid => $val") -ForegroundColor DarkGray }
                [void]$hits.Add($val)
            }
        }
        if ($hits.Count -gt 0) { break }
    }
    if ($hits.Count -eq 0) {
        if (-not $Quiet) { Write-WarnMsg 'SNMP 無回應或無法取得機型。' }
        return $null
    }
    $model = [string]$hits[$hits.Count - 1]
    foreach ($h in $hits) {
        $s = [string]$h
        if ($s -match '(?i)RICOH|SHARP|FUJIFILM|Xerox|Apeos|DocuCentre|DocuPrint|Canon|imageRUNNER|imageFORCE|KONICA|MINOLTA|bizhub|IM\s*C|MP\s*C|MX-|BP-|Aficio') {
            $model = $s
        }
    }
    if ($model.Contains("`n")) { $model = ($model -split "`n")[0].Trim() }
    if ($model.Length -gt 80) {
        $m2 = [regex]::Match($model, '(?i)((?:RICOH|SHARP|FUJIFILM|Fuji\s*Xerox|Xerox|Canon|KONICA\s*MINOLTA|Konica\s*Minolta)\s+)?[A-Z0-9][A-Z0-9 \-/]{2,40}')
        if ($m2.Success) { $model = $m2.Value.Trim() }
    }
    if (-not $Quiet) { Write-Ok ("偵測到機型：$model") }
    return $model
}

function Get-BrandFromModel([string]$ModelText) {
    if ([string]::IsNullOrWhiteSpace($ModelText)) { return $null }
    if ($ModelText -match '(?i)RICOH|Gestetner|LANIER|SAVIN|Aficio|\bIM\s*C|\bMP\s*C|\bIMC') { return 'Ricoh' }
    if ($ModelText -match '(?i)FUJIFILM|Fuji\s*Xerox|Xerox|Apeos|DocuCentre|DocuPrint|ApeosPort') { return 'FUJIFILM' }
    if ($ModelText -match '(?i)SHARP|\bMX-|\bBP-|\bAR-') { return 'Sharp' }
    if ($ModelText -match '(?i)Canon|imageRUNNER|iR-ADV|imageFORCE|imageCLASS|i-SENSYS|imagePRESS') { return 'Canon' }
    if ($ModelText -match '(?i)KONICA|MINOLTA|bizhub|Accurio|Develop|\bineo\b') { return 'KONICA MINOLTA' }
    return $null
}

function Get-OfficialSupportUrl([string]$Brand, [string]$Model) {
    $q = [Uri]::EscapeDataString([string]$Model)
    switch -Regex ($Brand) {
        '^(?i)Ricoh$' { return "https://www.ricoh.com.tw/support/  （搜尋：$Model）" }
        '^(?i)FUJIFILM$' { return "https://support-fb.fujifilm.com/  （搜尋：$Model）" }
        '^(?i)Sharp$' { return "https://www.sharp.com.tw/support/  （搜尋：$Model）" }
        '^(?i)Canon$' { return "https://www.canon.com.tw/support/downloads  （搜尋：$Model）`nhttps://asia.canon/en/support?query=$q" }
        '^(?i)KONICA' { return "https://www.konicaminolta.com.tw/support/  （搜尋：$Model）`nhttps://onyxweb.mykonicaminolta.com/OneStopProductSupport" }
        default { return "請至原廠支援網站搜尋：$Model" }
    }
}

function Normalize-ModelKey([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $s = $Text.ToUpperInvariant()
    $s = [regex]::Replace($s, '(?i)\b(RICOH|FUJIFILM|FUJI\s*XEROX|XEROX|SHARP|CANON|KONICA\s*MINOLTA|KONICA|MINOLTA|AFICIO|GESTETNER|LANIER|SAVIN|DEVELOP)\b', ' ')
    $s = [regex]::Replace($s, '[_/\\]+', ' ')
    $s = [regex]::Replace($s, '\s+', ' ')
    $s = $s.Trim()
    # also produce compact form without spaces/hyphens for comparison
    return $s
}
function Get-ModelCompact([string]$Text) {
    $n = Normalize-ModelKey $Text
    return (($n -replace '[-\s]', ''))
}

function Get-MatchScore([string]$Query, [string]$Candidate) {
    $qn = Normalize-ModelKey $Query
    $cn = Normalize-ModelKey $Candidate
    if (-not $qn -or -not $cn) { return 0 }
    $qc = Get-ModelCompact $Query
    $cc = Get-ModelCompact $Candidate
    if ($qn -eq $cn -or $qc -eq $cc) { return 1000 }
    # slash-group catalogs e.g. IM C2000/C2500/C3000/C3500
    if ($cn -match '/') {
        $parts = @($cn -split '[/\s]+' | Where-Object { $_ })
        foreach ($p in $parts) {
            $pc = ($p -replace '[-\s]', '')
            if ($pc -and ($qc -eq $pc -or $qc.Contains($pc) -or $pc.Contains($qc))) {
                if ($qc -eq $pc) { return 950 }
                return 800
            }
        }
        # rebuild with shared prefix tokens: "IM C2000/C2500/C3000" vs "IM C3000"
        if ($qn -match '(?i)\b(IM|MP|MX|BP|AR|Apeos(?:Port)?|DocuCentre|DocuPrint|bizhub|iR-?ADV|imageRUNNER)\b') {
            $prefix = $Matches[1].ToUpperInvariant()
            $numQ = [regex]::Match($qc, '([A-Z]*\d{3,5}[A-Z]*)').Groups[1].Value
            if ($numQ -and $cc.Contains($numQ) -and $cn.Contains($prefix.Substring(0, [Math]::Min(2, $prefix.Length)))) {
                return 900
            }
            if ($numQ -and $cc.Contains($numQ)) { return 850 }
        }
    }
    if ($qc -and $cc -and ($qc.Contains($cc) -or $cc.Contains($qc))) {
        $ratio = [Math]::Min($qc.Length, $cc.Length) / [Math]::Max($qc.Length, $cc.Length)
        return [int](700 + 200 * $ratio)
    }
    $qTokens = @([regex]::Split($qn, '[\s\-]+') | Where-Object { $_.Length -ge 2 })
    $cTokens = @([regex]::Split($cn, '[\s\-]+') | Where-Object { $_.Length -ge 2 })
    if ($qTokens.Count -eq 0 -or $cTokens.Count -eq 0) { return 0 }
    $hit = 0
    foreach ($t in $qTokens) {
        foreach ($u in $cTokens) {
            if ($t -eq $u -or $t.Contains($u) -or $u.Contains($t)) { $hit++; break }
        }
    }
    if ($hit -eq 0) { return 0 }
    return [int](100 + (400.0 * $hit / [Math]::Max($qTokens.Count, $cTokens.Count)))
}

function Get-OsPreferenceScore([string]$Os) {
    $o = [string]$Os
    if ($o -match '(?i)Win64|x64|64') { return 30 }
    if ($o -match '(?i)^Windows$') { return 20 }
    if ($o -match '(?i)Win32|x86|32') { return 5 }
    return 10
}
function Get-TypePreferenceScore([string]$Type) {
    $t = [string]$Type
    if ($t -match '(?i)PCL6') { return 40 }
    if ($t -match '(?i)PCL') { return 30 }
    if ($t -match '(?i)UPD|Universal|MMD|UD3|Generic') { return 25 }
    if ($t -match '(?i)PS') { return 15 }
    if ($t -match '(?i)Driver') { return 10 }
    if ($t -match '(?i)TWAIN|Scan|PC-FAX|Mac|教學|備用') { return -50 }
    return 0
}

function Find-CatalogMatches {
    param($Drivers, [string]$Query, [int]$Top = 8)
    $scored = New-Object System.Collections.ArrayList
    foreach ($d in @($Drivers)) {
        if ($d.kind -eq 'backup' -or $d.kind -eq 'guide') { continue }
        if ([string]$d.type -match '(?i)教學|備用|TWAIN|WIA|PC-FAX|Mac|Scan') { continue }
        $base = Get-MatchScore $Query ([string]$d.model)
        # Require strong model similarity (avoid MX-3071 → MX452 style weak token hits)
        if ($base -lt 700) { continue }
        $score = $base + (Get-OsPreferenceScore ([string]$d.os)) + (Get-TypePreferenceScore ([string]$d.type))
        [void]$scored.Add([pscustomobject]@{ Score = $score; Item = $d })
    }
    $sorted = @($scored | Sort-Object Score -Descending)
    if ($sorted.Count -eq 0) { return @() }
    # Prefer unique models: take best per model then overall
    return @($sorted | Select-Object -First $Top)
}

function Select-BestDriverItem {
    param($Matches)
    if (-not $Matches -or $Matches.Count -eq 0) { return $null }
    $bestScore = [int]$Matches[0].Score
    $top = @($Matches | Where-Object { $_.Score -ge ($bestScore - 50) })
    # among top, prefer PCL6 + Win64
    $pref = @($top | Sort-Object `
        @{ Expression = { Get-TypePreferenceScore ([string]$_.Item.type) }; Descending = $true }, `
        @{ Expression = { Get-OsPreferenceScore ([string]$_.Item.os) }; Descending = $true }, `
        @{ Expression = { $_.Score }; Descending = $true })
    return $pref[0].Item
}

function Load-JsonUrl([string]$Url) {
    $bytes = (New-Object Net.WebClient).DownloadData($Url)
    $text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
    return ($text | ConvertFrom-Json)
}

function Load-BrandCatalog([string]$Brand) {
    $file = $null
    if ($Brand -match '^(?i)Ricoh$') { $file = 'ricoh.json' }
    elseif ($Brand -match '^(?i)FUJIFILM$') { $file = 'fuji.json' }
    elseif ($Brand -match '^(?i)Sharp$') { $file = 'sharp.json' }
    else { return $null }
    Write-Info ("讀取 $Brand 驅動清單…")
    $text = Get-FlgOfflineCatalogText $file
    if ($text) {
        Write-Ok ("離線模式：讀取本機 " + $file)
        return ($text | ConvertFrom-Json)
    }
    if (Test-FlgOffline) {
        if (-not (Test-FlgNetworkAvailable)) {
            Write-WarnMsg ('離線版找不到 drivers\' + $file)
            return $null
        }
        Write-WarnMsg '離線模式找不到本機清單，改從網路讀取…'
    }
    $url = "$RawBase/drivers/$file" + '?t=' + [DateTime]::UtcNow.Ticks
    return (Load-JsonUrl $url)
}

function Load-CloudCatalog {
    Write-Info '讀取通用雲端驅動清單…'
    $text = Get-FlgOfflineCatalogText 'cloud.json'
    if ($text) {
        Write-Ok '離線模式：讀取本機 cloud.json'
        return ($text | ConvertFrom-Json)
    }
    if (Test-FlgOffline) {
        if (-not (Test-FlgNetworkAvailable)) {
            throw '離線版找不到 drivers\cloud.json，且目前無法連網。'
        }
        Write-WarnMsg '離線模式找不到本機 cloud.json，改從網路讀取…'
    }
    return (Load-JsonUrl $CloudJsonUrl)
}

function Find-CloudDriverByBrand($CloudCatalog, [string]$Brand) {
    foreach ($d in @($CloudCatalog.drivers)) {
        if ([string]$d.brand -eq $Brand) { return $d }
        if ($Brand -match '^(?i)FUJIFILM$' -and [string]$d.brand -match '(?i)FUJI') { return $d }
        if ($Brand -match '^(?i)KONICA' -and [string]$d.brand -match '(?i)KONICA') { return $d }
    }
    return $null
}

# ---- download helpers (subset of common-main) ----
function Get-GDriveId([string]$Url) {
    if ($Url -match '[?&]id=([^&]+)') { return $Matches[1] }
    if ($Url -match '/file/d/([^/]+)') { return $Matches[1] }
    return $null
}
function Get-DropboxDirect([string]$Url) {
    if ($Url -match '[?&]dl=0') { return ($Url -replace 'dl=0', 'dl=1') }
    if ($Url -notmatch '[?&]dl=') {
        if ($Url.Contains('?')) { return ($Url + '&dl=1') }
        return ($Url + '?dl=1')
    }
    return $Url
}
function Download-GoogleDrive {
    param([string]$FileId, [string]$OutDir, [string]$PreferredName)
    Ensure-Dir $OutDir
    $name = $(if ($PreferredName) { $PreferredName } else { "$FileId.bin" })
    $out = Join-Path $OutDir $name
    $wc = New-Object Net.WebClient
    $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FLG-AutoDriver'
    $confirmUrl = "https://drive.google.com/uc?export=download&id=$FileId"
    Write-Info "Google Drive 下載：$name"
    $tmp = Join-Path $OutDir ($name + '.tmp')
    try {
        $wc.DownloadFile($confirmUrl, $tmp)
        $bytes = [IO.File]::ReadAllBytes($tmp)
        $head = [Text.Encoding]::UTF8.GetString($bytes[0..([Math]::Min(800, $bytes.Length - 1))])
        if ($head -match 'confirm=([0-9A-Za-z_]+)' -or $head -match 'name="confirm"\s+value="([^"]+)"') {
            $confirm = $Matches[1]
            $confirmUrl2 = "https://drive.google.com/uc?export=download&confirm=$confirm&id=$FileId"
            $wc.DownloadFile($confirmUrl2, $tmp)
        } elseif ($head -match 'uuid=([^"&]+)') {
            $uuid = $Matches[1]
            $confirmUrl2 = "https://drive.google.com/uc?export=download&id=$FileId&confirm=t&uuid=$uuid"
            $wc.DownloadFile($confirmUrl2, $tmp)
        }
        if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 1024) { throw "Google Drive 下載失敗：$FileId" }
        if (Test-Path $out) { Remove-Item $out -Force }
        Move-Item $tmp $out -Force
        return $out
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}
function Download-MediaFire {
    param([string]$Url, [string]$OutDir, [string]$PreferredName)
    Ensure-Dir $OutDir
    Write-Info '解析 MediaFire 直連…'
    $html = (New-Object Net.WebClient).DownloadString($Url)
    $m = [regex]::Match($html, 'href="(https://download\d*\.mediafire\.com/[^"]+)"')
    if (-not $m.Success) { $m = [regex]::Match($html, '(https://download\d*\.mediafire\.com/[^"\s]+)') }
    if (-not $m.Success) { throw "MediaFire 下載失敗：$Url" }
    $direct = $m.Groups[1].Value
    $name = $(if ($PreferredName) { $PreferredName } else { [IO.Path]::GetFileName(([Uri]$direct).AbsolutePath) })
    $out = Join-Path $OutDir $name
    Write-Info "直連下載：$name"
    Invoke-WebRequest -Uri $direct -OutFile $out -UseBasicParsing -MaximumRedirection 8 -UserAgent 'Mozilla/5.0'
    if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 1024) { throw "MediaFire 下載失敗：$Url" }
    return $out
}
function Save-HttpWithProgress {
    param([string]$Url, [string]$OutFile, [hashtable]$Headers = $null)
    Write-Info ("下載中…")
    Write-Host ("  " + $Url) -ForegroundColor DarkGray
    if ($Headers) {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -MaximumRedirection 8 -Headers $Headers
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -MaximumRedirection 8 -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FLG-AutoDriver'
    }
}
function Download-CatalogItem {
    param($Item, [string]$ModelLabel)
    $label = $(if ($ModelLabel) { $ModelLabel } else { [string]$Item.model })
    $safe = ($label -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $safe) { $safe = 'unknown' }
    $modelDir = Join-Path $DestRoot $safe
    Ensure-Dir $modelDir
    $hostName = [string]$Item.host
    $url = [string]$Item.url
    $pref = [string]$Item.filename
    if ($Item.kind -eq 'guide' -or $hostName -eq 'blogger' -or $hostName -eq 'mega') {
        if (Test-FlgOffline -and -not (Test-FlgNetworkAvailable)) {
            Write-WarnMsg '離線版無法下載，請連網'
            return $null
        }
        Write-WarnMsg "此項目會開啟瀏覽器：$($Item.title)"
        try { Start-Process $url } catch {}
        return $null
    }
    if (Test-FlgOffline) {
        $bundledName = $null
        if ($pref) { $bundledName = $pref }
        elseif ($url) {
            try { $bundledName = [IO.Path]::GetFileName(([Uri]$url).LocalPath) } catch {}
        }
        $bundled = $null
        if ($bundledName) {
            $bundled = Resolve-FlgOfflinePath ("drivers\packages\" + $bundledName)
            if (-not $bundled) { $bundled = Resolve-FlgOfflinePath ("drivers\extras\" + $bundledName) }
        }
        if ($bundled) {
            $path = Join-Path $modelDir ([IO.Path]::GetFileName($bundled))
            Copy-Item -LiteralPath $bundled -Destination $path -Force
            Write-Ok ("離線模式：已複製本機檔案 " + $path)
            return $path
        }
        if (-not (Test-FlgNetworkAvailable)) {
            Write-WarnMsg '離線版無法下載，請連網'
            return $null
        }
        Write-WarnMsg '離線模式：機種專用驅動改從網路下載…'
    }
    Write-Info ("下載：$($Item.title)")
    $path = $null
    switch ($hostName) {
        'gdrive' {
            $id = Get-GDriveId $url
            if (-not $id) { throw "無法解析 Google Drive 檔案 ID：$url" }
            $path = Download-GoogleDrive -FileId $id -OutDir $modelDir -PreferredName $pref
        }
        'mediafire' { $path = Download-MediaFire -Url $url -OutDir $modelDir -PreferredName $pref }
        'dropbox' {
            $durl = Get-DropboxDirect $url
            if (-not $pref) { $pref = 'dropbox-download.bin' }
            $path = Join-Path $modelDir $pref
            Save-HttpWithProgress -Url $durl -OutFile $path
        }
        'ricoh' {
            if (-not $pref) { $pref = ([Uri]$url).Segments[-1] }
            $path = Join-Path $modelDir $pref
            Save-HttpWithProgress -Url $url -OutFile $path
        }
        'fujifilm' {
            if (-not $pref) { $pref = ([Uri]$url).Segments[-1] }
            $path = Join-Path $modelDir $pref
            $headers = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'; 'Referer' = 'https://support-fb.fujifilm.com/' }
            Save-HttpWithProgress -Url $url -OutFile $path -Headers $headers
        }
        default {
            if (-not $pref) {
                try { $pref = ([Uri]$url).Segments[-1] } catch { $pref = 'download.bin' }
            }
            if (-not $pref) { $pref = 'download.bin' }
            $path = Join-Path $modelDir $pref
            Save-HttpWithProgress -Url $url -OutFile $path
        }
    }
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { throw '沒有下載到檔案。' }
    $len = (Get-Item -LiteralPath $path).Length
    if ($len -le 0) { throw '下載檔案大小為 0。' }
    Write-Ok ("完成：{0}（{1:N1} MB）" -f $path, ($len / 1MB))
    return $path
}

function Download-CloudUniversalZip {
    param($Driver, [string]$ModelLabel)
    $safe = (($ModelLabel -replace '[\\/:*?"<>|]', '_').Trim())
    if (-not $safe) { $safe = [string]$Driver.brand }
    $modelDir = Join-Path $DestRoot ($safe + '_UPD')
    Ensure-Dir $modelDir
    $zipPath = Join-Path $modelDir $Driver.zip_name
    Write-Info ("準備通用驅動包（約 {0:N1} MB）…" -f ($Driver.size / 1MB))
    $gotLocal = Copy-FlgOfflineDriverZip -Driver $Driver -DestZip $zipPath
    if (-not $gotLocal) {
        if (Test-FlgOffline -and -not (Test-FlgNetworkAvailable)) {
            throw ('離線版找不到驅動包：' + $Driver.zip_name)
        }
        if (Test-FlgOffline) { Write-WarnMsg '本機無此驅動包，改從網路下載…' }
        Save-HttpWithProgress -Url ([string]$Driver.url) -OutFile $zipPath
    }
    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -le 0) { throw '通用驅動下載失敗。' }
    if ($Driver.sha256) {
        Write-Info '驗證 SHA256…'
        $actual = Get-FileSha256 $zipPath
        $expect = ([string]$Driver.sha256).ToLowerInvariant()
        if ($actual -ne $expect) { throw "SHA256 不符`n  期望：$expect`n  實際：$actual" }
        Write-Ok 'SHA256 正確'
    }
    Write-Ok ("完成：$zipPath")
    return $zipPath
}

function Get-PrinterDisplayName([string]$Prefix, [string]$Model, [string]$Ip) {
    if ([string]::IsNullOrWhiteSpace($Model)) { return ($Prefix + ' ' + $Ip) }
    $clean = $Model -replace '[\\/:\*\?"<>\|]', ' '
    $clean = [regex]::Replace($clean, '\s+', ' ').Trim()
    if ($clean.Length -gt 40) { $clean = $clean.Substring(0, 40).Trim() }
    return ($clean + ' (' + $Ip + ')')
}

function Request-Elevation([string]$BootstrapUrl) {
    Write-WarnMsg '需要系統管理員權限才能安裝驅動，即將跳出 UAC 提示…'
    $parts = @()
    foreach ($a in $args) {
        $s = [string]$a
        $parts += ("'" + $s.Replace("'", "''") + "'")
    }
    if ($script:Mode -eq 'scan' -and ($parts -notcontains "'scan'")) {
        $parts = @("'scan'") + $parts
    }
    $argStr = $parts -join ' '
    $preamble = Get-FlgOfflineEnvPreamble
    $localMain = Resolve-FlgOfflinePath 'drivers\auto-driver-main.ps1'
    if ($localMain) {
        $esc = $localMain.Replace("'", "''")
        $inner = $preamble + "& '$esc' $argStr"
    } else {
        $inner = $preamble + "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$BootstrapUrl'))) $argStr"
    }
    $argList2 = "-NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList2 | Out-Null
        Write-Info '已啟動提權視窗，請在新視窗完成安裝。'
    } catch {
        Write-ErrMsg ("無法提權：" + $_.Exception.Message)
        Write-Host '請以「系統管理員」開啟 PowerShell 後再執行一次。' -ForegroundColor Yellow
        if ($env:FLG_FROM_MENU -eq '1') { return 'fail' }
        exit 1
    }
    if ($env:FLG_FROM_MENU -eq '1') { return 'elevated' }
    exit 0
}

function Install-UniversalDriver {
    param($Driver, [string]$Ip, [string]$PrinterName)
    if (-not $IsWindowsOs) {
        Write-WarnMsg '目前不是 Windows，略過實際安裝（僅驗證下載流程）。'
        return
    }
    $work = Join-Path $env:TEMP ('FLG-AutoDriver-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $zipPath = Join-Path $work $Driver.zip_name
    $extractDir = Join-Path $work 'extract'
    try {
        Write-Info ("安裝用驅動包（約 {0:N1} MB）…" -f ($Driver.size / 1MB))
        $gotLocal = Copy-FlgOfflineDriverZip -Driver $Driver -DestZip $zipPath
        if (-not $gotLocal) {
            if (Test-FlgOffline -and -not (Test-FlgNetworkAvailable)) {
                throw ('離線版找不到驅動包：' + $Driver.zip_name)
            }
            if (Test-FlgOffline) { Write-WarnMsg '本機無此驅動包，改從網路下載…' }
            Invoke-WebRequest -Uri $Driver.url -OutFile $zipPath -UseBasicParsing
        }
        $actual = Get-FileSha256 $zipPath
        $expect = ([string]$Driver.sha256).ToLowerInvariant()
        if ($actual -ne $expect) { throw "SHA256 不符：期望 $expect 實際 $actual" }
        Write-Ok 'SHA256 正確'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        $infPath = Join-Path $extractDir $Driver.inf
        if (-not (Test-Path -LiteralPath $infPath)) {
            $infLeaf = [IO.Path]::GetFileName([string]$Driver.inf)
            $found = Get-ChildItem -Path $extractDir -Filter $infLeaf -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $found) { $found = Get-ChildItem -Path $extractDir -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if ($found) { $infPath = $found.FullName } else { throw "找不到 INF：$($Driver.inf)" }
        }
        Write-Info '安裝驅動套件（pnputil）…'
        $pnp = & pnputil.exe /add-driver $infPath /install 2>&1
        $pnp | ForEach-Object { Write-Host ("  " + $_) }
        $pnpCode = $LASTEXITCODE
        $drvName = [string]$Driver.driver_name
        $alt = [string]$Driver.driver_name_alt
        $inStore = (Test-PrinterDriverInStore $drvName) -or ($alt -and (Test-PrinterDriverInStore $alt))
        if ($pnpCode -ne 0 -and $pnpCode -ne $null -and -not $inStore) {
            throw ("pnputil 安裝驅動失敗（結束碼 $pnpCode）。")
        }
        if (-not (Get-PrinterDriver -Name $drvName -ErrorAction SilentlyContinue)) {
            try { Add-PrinterDriver -Name $drvName -ErrorAction Stop }
            catch {
                if ($alt) {
                    $drvName = $alt
                    if (-not (Get-PrinterDriver -Name $drvName -ErrorAction SilentlyContinue)) {
                        Add-PrinterDriver -Name $drvName -ErrorAction Stop
                    }
                } else { throw }
            }
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
        Add-Printer -Name $PrinterName -DriverName $drvName -PortName $portName -ErrorAction Stop
        try {
            Set-PrintConfiguration -PrinterName $PrinterName -Color $false -DuplexingMode OneSided -ErrorAction Stop
            Write-Ok '已設定預設：黑白、單面'
        } catch { Write-WarnMsg ("設定黑白單面失敗：" + $_.Exception.Message) }
        $esc = $PrinterName.Replace("'", "''")
        try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name 'LegacyDefaultPrinterMode' -Value 1 -Type DWord -ErrorAction Stop } catch {}
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter | Out-Null
            Write-Ok '已設為預設印表機'
        } catch {
            try { (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName) | Out-Null; Write-Ok '已設為預設印表機' }
            catch { Write-WarnMsg ("設預設失敗：" + $_.Exception.Message) }
        }
        Start-Sleep -Seconds 2
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            $null = Invoke-CimMethod -InputObject $printer -MethodName PrintTestPage
            Write-Ok '已送出測試頁'
        } catch {
            try { Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /k /n "' + $PrinterName + '"') -Wait; Write-Ok '已送出測試頁' }
            catch { Write-WarnMsg ("測試頁失敗：" + $_.Exception.Message) }
        }
        Write-Ok '安裝完成。'
        Write-Host ("  驅動：$drvName  v$($Driver.version)") -ForegroundColor Green
        Write-Host ("  印表機：$PrinterName") -ForegroundColor Green
        Write-Host ("  連接埠：$portName → $Ip") -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $work) {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-AfterMenu([string]$Path) {
    if (-not $Path) { return }
    $dir = Split-Path -Parent $Path
    Write-Host ''
    Write-Host '下載完成，接下來？' -ForegroundColor White
    Write-Host '  [1] 開啟資料夾'
    Write-Host '  [2] 執行安裝程式（.exe）'
    Write-Host ('  [0] ' + (Get-FlgExitLabel))
    $c = (Read-Host '請輸入編號（預設 1）').Trim()
    if ([string]::IsNullOrWhiteSpace($c)) { $c = '1' }
    if ($c -eq '2') {
        $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
        if ($ext -eq '.exe') {
            try { Start-Process -FilePath $Path -WorkingDirectory $dir } catch { Write-WarnMsg $_.Exception.Message }
        } else {
            Write-WarnMsg '此檔不是 .exe，改開資料夾。'
            try { Start-Process explorer.exe -ArgumentList $dir } catch {}
        }
    } elseif ($c -eq '0') {
        Write-Host ('已' + (Get-FlgExitLabel) + '。')
    } else {
        try { Start-Process explorer.exe -ArgumentList $dir } catch { Write-Info "資料夾：$dir" }
    }
}

function Resolve-ModelAndDrivers {
    param([string]$ModelText, $CloudCatalog)
    $brand = Get-BrandFromModel $ModelText
    $result = [ordered]@{
        Brand = $brand
        Model = $ModelText
        CatalogItem = $null
        Candidates = @()
        CloudDriver = $null
        SupportUrl = $null
        Ambiguous = $false
    }
    if (-not $brand) {
        Write-WarnMsg '無法辨識品牌，請確認機型名稱。'
        return [pscustomobject]$result
    }
    $result.CloudDriver = Find-CloudDriverByBrand $CloudCatalog $brand
    $result.SupportUrl = Get-OfficialSupportUrl $brand $ModelText
    $cat = Load-BrandCatalog $brand
    if ($cat -and $cat.drivers) {
        $matches = Find-CatalogMatches -Drivers $cat.drivers -Query $ModelText -Top 10
        $result.Candidates = $matches
        if ($matches.Count -eq 0 -or [int]$matches[0].Score -lt 750) {
            Write-WarnMsg ("清單中找不到「$ModelText」的專用驅動，將使用通用版。")
            $result.CatalogItem = $null
            $result.Candidates = @()
        } elseif ($matches.Count -eq 1 -or ([int]$matches[0].Score -ge 900 -and ($matches.Count -eq 1 -or [int]$matches[1].Score -lt 850))) {
            $result.CatalogItem = Select-BestDriverItem $matches
            Write-Ok ("對應驅動：$($result.CatalogItem.title)")
        } else {
            # ambiguous if multiple different models near top
            $models = @($matches | ForEach-Object { [string]$_.Item.model } | Select-Object -Unique)
            if ($models.Count -gt 1 -and [int]$matches[0].Score -lt 950) {
                $result.Ambiguous = $true
            } else {
                $result.CatalogItem = Select-BestDriverItem $matches
                Write-Ok ("對應驅動：$($result.CatalogItem.title)")
            }
        }
    } else {
        Write-WarnMsg ("$brand 目前沒有專用下載清單，將使用通用版。")
        Write-Host ("原廠支援：" + $result.SupportUrl) -ForegroundColor DarkGray
    }
    return [pscustomobject]$result
}

function Prompt-PickCandidate($Matches) {
    Write-Host ''
    Write-Host '找到多個可能的驅動，請選擇：' -ForegroundColor Yellow
    $show = @($Matches | Select-Object -First 8)
    for ($i = 0; $i -lt $show.Count; $i++) {
        $it = $show[$i].Item
        Write-Host ("  [{0}] {1}  （分數 {2}）" -f ($i + 1), $it.title, $show[$i].Score)
    }
    Write-Host '  [0] 改用通用版（不下載專用檔）'
    $c = (Read-Host '請輸入編號').Trim()
    $n = 0
    if (-not [int]::TryParse($c, [ref]$n) -or $n -lt 0 -or $n -gt $show.Count) {
        Write-WarnMsg '無效，改用最高分項目。'
        return (Select-BestDriverItem $Matches)
    }
    if ($n -eq 0) { return $null }
    return $show[$n - 1].Item
}

function Invoke-ProcessPrinter {
    param(
        [string]$Ip,
        [string]$ModelHint = '',
        $CloudCatalog,
        [switch]$SkipAfterMenu,
        [switch]$Install
    )
    $model = $ModelHint
    if (-not $model) { $model = Get-PrinterModelViaSnmp $Ip }
    if (-not $model) {
        $model = (Read-Host '請手動輸入機型名稱（例如 IM C3000、Apeos C3570）').Trim()
        if (-not $model) { throw '未提供機型，已取消。' }
    }
    $resolved = Resolve-ModelAndDrivers -ModelText $model -CloudCatalog $CloudCatalog
    if (-not $resolved.Brand) { throw "無法辨識品牌：$model" }
    if ($resolved.Ambiguous -and $resolved.Candidates.Count -gt 0) {
        $resolved.CatalogItem = Prompt-PickCandidate $resolved.Candidates
    }
    $downloaded = $null
    if ($resolved.CatalogItem) {
        try {
            $downloaded = Download-CatalogItem -Item $resolved.CatalogItem -ModelLabel $model
        } catch {
            Write-WarnMsg ("專用驅動下載失敗：" + $_.Exception.Message)
            Write-Host ("原廠支援：" + $resolved.SupportUrl) -ForegroundColor DarkGray
        }
    } else {
        Write-Info '改下載品牌通用驅動…'
        if ($resolved.CloudDriver) {
            try { $downloaded = Download-CloudUniversalZip -Driver $resolved.CloudDriver -ModelLabel $model }
            catch { Write-WarnMsg ("通用驅動下載失敗：" + $_.Exception.Message) }
        }
        if ($resolved.SupportUrl) {
            Write-Host ("原廠支援搜尋：" + $resolved.SupportUrl) -ForegroundColor DarkGray
        }
    }

    if ($Install) {
        if (-not $resolved.CloudDriver) { throw "找不到 $($resolved.Brand) 的通用雲端驅動。" }
        $prefix = [string]$resolved.CloudDriver.name_prefix
        if (-not $prefix) { $prefix = $resolved.Brand }
        $printerName = Get-PrinterDisplayName -Prefix $prefix -Model $model -Ip $Ip
        Write-Info ("準備安裝印表機：$printerName")
        Install-UniversalDriver -Driver $resolved.CloudDriver -Ip $Ip -PrinterName $printerName
        $slug = 'ricoh'
        if ($resolved.Brand -match '(?i)FUJI') { $slug = 'fuji' }
        elseif ($resolved.Brand -match '(?i)Sharp') { $slug = 'sharp' }
        elseif ($resolved.Brand -match '(?i)Canon') { $slug = 'canon' }
        elseif ($resolved.Brand -match '(?i)KONICA') { $slug = 'konica' }
        Invoke-FlgCounterHit ('install-ok-' + $slug)
    }

    if (-not $SkipAfterMenu) { Show-AfterMenu $downloaded }
    return [pscustomobject]@{ Ip = $Ip; Model = $model; Brand = $resolved.Brand; Downloaded = $downloaded }
}

# ---- LAN scan ----
function ConvertTo-Ipv4UInt([string]$Ip) {
    $addr = [Net.IPAddress]::Parse($Ip)
    $bytes = $addr.GetAddressBytes()
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }
    return [BitConverter]::ToUInt32($bytes, 0)
}
function ConvertFrom-Ipv4UInt([uint32]$Value) {
    $hb = [BitConverter]::GetBytes([uint32]$Value)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($hb) }
    return ([Net.IPAddress]::new($hb)).ToString()
}
function Get-Slash24NetworkUInt([uint32]$IpInt) {
    # 0xFFFFFF00 as uint32 (PS may treat bare 0xFFFFFF00 as signed -256)
    $mask24 = [Convert]::ToUInt32('FFFFFF00', 16)
    return [uint32]($IpInt -band $mask24)
}
function Get-PrefixMaskUInt([int]$Prefix) {
    if ($Prefix -le 0) { return [uint32]0 }
    if ($Prefix -ge 32) { return [Convert]::ToUInt32('FFFFFFFF', 16) }
    # mask = not (2^(32-prefix) - 1)
    $hostBits = 32 - $Prefix
    $hostMask = [uint32]([Math]::Pow(2, $hostBits) - 1)
    return [uint32](-bnot $hostMask)
}

function Get-DefaultGatewayIp {
    param([string]$InterfaceAlias = '')
    if (-not $IsWindowsOs) { return $null }
    try {
        $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
            Sort-Object RouteMetric, InterfaceMetric)
        if ($InterfaceAlias) {
            $hit = @($routes | Where-Object { $_.InterfaceAlias -eq $InterfaceAlias })
            if ($hit.Count -gt 0) { return [string]$hit[0].NextHop }
        }
        if ($routes.Count -gt 0) { return [string]$routes[0].NextHop }
    } catch {}
    try {
        $cfg = Get-NetIPConfiguration -ErrorAction Stop
        foreach ($c in @($cfg)) {
            if ($InterfaceAlias -and $c.InterfaceAlias -ne $InterfaceAlias) { continue }
            $gw = $null
            try { $gw = $c.IPv4DefaultGateway } catch {}
            if ($gw) {
                $nh = $null
                try { $nh = [string]$gw.NextHop } catch { try { $nh = [string]$gw[0].NextHop } catch {} }
                if ($nh -and $nh -ne '0.0.0.0') { return $nh }
            }
        }
    } catch {}
    return $null
}

function Get-LocalSubnets {
    $nets = New-Object System.Collections.ArrayList
    if ($IsWindowsOs) {
        try {
            $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object {
                    $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
                    $_.PrefixOrigin -ne 'WellKnown' -and
                    $_.PrefixLength -ge 8 -and $_.PrefixLength -le 30
                }
            foreach ($a in @($addrs)) {
                $alias = ''
                try { $alias = [string]$a.InterfaceAlias } catch {}
                if (-not $alias) {
                    try { $alias = [string](Get-NetIPAddress -IPAddress $a.IPAddress -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty InterfaceAlias) } catch {}
                }
                if ($alias -match '(?i)Loopback|vEthernet|Hyper-V|WSL|Docker|VirtualBox|VMware|VPN|TAP|Bluetooth|Pseudo') { continue }
                $gw = Get-DefaultGatewayIp -InterfaceAlias $alias
                [void]$nets.Add([pscustomobject]@{ IP = [string]$a.IPAddress; Prefix = [int]$a.PrefixLength; Alias = $alias; Gateway = $gw })
            }
        } catch {
            Write-WarnMsg ("Get-NetIPAddress 失敗，改用 ipconfig：" + $_.Exception.Message)
        }
    }
    if ($nets.Count -eq 0) {
        try {
            if ($IsWindowsOs) {
                $cfg = ipconfig
                $curIp = $null; $mask = $null; $gw = $null; $alias = 'ipconfig'
                foreach ($line in $cfg) {
                    if ($line -match '^\s*(Ethernet|無線|Wi-?Fi|乙太|區域連線|adapter)\s') { $alias = $line.Trim() }
                    if ($line -match 'IPv4.*:\s*([0-9.]+)') { $curIp = $Matches[1] }
                    if ($line -match 'Default Gateway.*:\s*([0-9.]+)' -or $line -match '預設閘道.*:\s*([0-9.]+)') {
                        if ($Matches[1]) { $gw = $Matches[1] }
                    }
                    if ($line -match 'Subnet Mask.*:\s*([0-9.]+)' -or $line -match '子網路遮罩.*:\s*([0-9.]+)') {
                        $mask = $Matches[1]
                        if ($curIp -and $curIp -notmatch '^(127\.|169\.254\.)' -and $mask) {
                            $parts = $mask.Split('.') | ForEach-Object { [int]$_ }
                            $bits = 0
                            foreach ($p in $parts) {
                                $b = [Convert]::ToString($p, 2).Replace('0','').Length
                                $bits += $b
                            }
                            [void]$nets.Add([pscustomobject]@{ IP = $curIp; Prefix = $bits; Alias = $alias; Gateway = $gw })
                        }
                        $curIp = $null; $mask = $null
                    }
                }
            } else {
                $ipOut = @()
                try { $ipOut = & ip -4 -o addr show 2>$null } catch { $ipOut = @() }
                $gw = $null
                try {
                    $r = & ip -4 route show default 2>$null
                    if ("$r" -match 'via\s+([0-9.]+)') { $gw = $Matches[1] }
                } catch {}
                foreach ($line in @($ipOut)) {
                    if ($line -match 'inet\s+([0-9.]+)/(\d+)') {
                        $ip = $Matches[1]; $pre = [int]$Matches[2]
                        if ($ip -notmatch '^(127\.|169\.254\.)') {
                            [void]$nets.Add([pscustomobject]@{ IP = $ip; Prefix = $pre; Alias = 'linux'; Gateway = $gw })
                        }
                    }
                }
            }
        } catch {}
    }
    return @($nets)
}

# 依遮罩展開要掃的 /24 網段：/24→1、/23→2、/22→4…；大於 /20 只掃本機+/閘道 /24
function Get-ScanSegments {
    param(
        [string]$HostIp,
        [int]$Prefix,
        [string]$Gateway = '',
        [switch]$Quiet
    )
    if (-not (Test-Ipv4Address $HostIp)) { throw "IP 無效：$HostIp" }
    if ($Prefix -lt 0 -or $Prefix -gt 32) { throw "Prefix 無效：$Prefix" }

    $notes = New-Object System.Collections.ArrayList
    $segSet = New-Object 'System.Collections.Generic.List[uint32]'
    $hostInt = ConvertTo-Ipv4UInt $HostIp
    $host24 = Get-Slash24NetworkUInt $hostInt

    if ($Prefix -ge 24) {
        [void]$segSet.Add($host24)
    } elseif ($Prefix -ge 20) {
        $mask = Get-PrefixMaskUInt $Prefix
        $network = [uint32]($hostInt -band $mask)
        $num24 = [int][Math]::Pow(2, (24 - $Prefix))
        for ($i = 0; $i -lt $num24; $i++) {
            $seg = [uint32]($network + [uint32]($i * 256))
            if (-not $segSet.Contains($seg)) { [void]$segSet.Add($seg) }
        }
    } else {
        [void]$notes.Add(("介面遮罩 /{0} 大於 /20（超過 16 個 /24），為避免掃描過久，只掃本機與閘道所在 /24。" -f $Prefix))
        [void]$segSet.Add($host24)
    }

    if ($Gateway -and (Test-Ipv4Address $Gateway)) {
        $gwInt = ConvertTo-Ipv4UInt $Gateway
        # 閘道應在同一介面子網內（或至少可作為掃描目標）
        if ($Prefix -le 32) {
            $mask = Get-PrefixMaskUInt $Prefix
            $same = ([uint32]($hostInt -band $mask) -eq [uint32]($gwInt -band $mask))
            if (-not $same -and $Prefix -ge 20) {
                [void]$notes.Add(("閘道 {0} 不在本機子網 /{1} 內，仍一併掃描其所在 /24。" -f $Gateway, $Prefix))
            }
        }
        $gw24 = Get-Slash24NetworkUInt $gwInt
        if (-not $segSet.Contains($gw24)) { [void]$segSet.Add($gw24) }
    }

    $labels = @($segSet | Sort-Object | ForEach-Object { (ConvertFrom-Ipv4UInt $_) + '/24' })
    return [pscustomobject]@{
        Segments = @($segSet | Sort-Object)
        Labels = $labels
        Notes = @($notes)
        HostIp = $HostIp
        Prefix = $Prefix
        Gateway = $Gateway
    }
}

function Get-HostsFromSegments {
    param(
        $SegmentResult,
        [string]$SkipIp = ''
    )
    $list = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($seg in @($SegmentResult.Segments)) {
        for ($i = 1; $i -le 254; $i++) {
            $hip = ConvertFrom-Ipv4UInt ([uint32]($seg + [uint32]$i))
            if ($SkipIp -and $hip -eq $SkipIp) { continue }
            if ($seen.ContainsKey($hip)) { continue }
            $seen[$hip] = $true
            [void]$list.Add($hip)
        }
    }
    return @($list)
}

function Get-HostsToScan($Subnet) {
    # 相容舊呼叫：展開該介面要掃的所有 /24
    $gw = ''
    try { if ($Subnet.Gateway) { $gw = [string]$Subnet.Gateway } } catch {}
    $segs = Get-ScanSegments -HostIp ([string]$Subnet.IP) -Prefix ([int]$Subnet.Prefix) -Gateway $gw
    return ,(Get-HostsFromSegments -SegmentResult $segs -SkipIp ([string]$Subnet.IP))
}

function Test-TcpPortQuick([string]$Ip, [int]$Port, [int]$TimeoutMs = 400) {
    $tcp = $null
    try {
        $tcp = New-Object Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($Ip, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            try { $tcp.EndConnect($iar) } catch { return $false }
            return $tcp.Connected
        }
        return $false
    } catch { return $false } finally {
        if ($tcp) { try { $tcp.Close() } catch {} }
    }
}

function Invoke-LanPrinterScan {
    Write-Info '掃描本機區網，尋找印表機（TCP 9100/631/515 + SNMP）…'
    $subnets = Get-LocalSubnets
    if ($subnets.Count -eq 0) { throw '找不到可用的本機 IPv4 網段。' }
    $allHosts = New-Object System.Collections.ArrayList
    $allLabels = New-Object System.Collections.ArrayList
    foreach ($s in $subnets) {
        $gw = ''
        try { if ($s.Gateway) { $gw = [string]$s.Gateway } } catch {}
        Write-Host ("  網卡 {0}  {1}/{2}{3}" -f $s.Alias, $s.IP, $s.Prefix, $(if ($gw) { "  閘道 $gw" } else { '' })) -ForegroundColor DarkGray
        $segs = Get-ScanSegments -HostIp ([string]$s.IP) -Prefix ([int]$s.Prefix) -Gateway $gw
        foreach ($n in @($segs.Notes)) { Write-WarnMsg $n }
        foreach ($lab in @($segs.Labels)) {
            if ($allLabels -notcontains $lab) { [void]$allLabels.Add($lab) }
        }
        foreach ($h in (Get-HostsFromSegments -SegmentResult $segs -SkipIp ([string]$s.IP))) {
            if ($allHosts -notcontains $h) { [void]$allHosts.Add($h) }
        }
    }
    if ($allLabels.Count -gt 0) {
        Write-Info ('掃描網段：' + ($allLabels -join '、'))
    }
    Write-Info ("待探測主機：{0} 台（平行掃描，逾時約 400ms）" -f $allHosts.Count)

    $ports = @(9100, 631, 515)
    $open = New-Object System.Collections.ArrayList
    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Min(128, [Math]::Max(16, [Math]::Min($allHosts.Count, 128))))
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList
    $scriptBlock = {
        param($Ip, $Ports, $TimeoutMs)
        foreach ($p in $Ports) {
            $tcp = $null
            try {
                $tcp = New-Object Net.Sockets.TcpClient
                $iar = $tcp.BeginConnect($Ip, [int]$p, $null, $null)
                if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
                    try { $tcp.EndConnect($iar) } catch { continue }
                    if ($tcp.Connected) { return @{ Ip = $Ip; Port = $p } }
                }
            } catch {} finally { if ($tcp) { try { $tcp.Close() } catch {} } }
        }
        return $null
    }
    foreach ($h in $allHosts) {
        $ps = [powershell]::Create().AddScript($scriptBlock).AddArgument($h).AddArgument($ports).AddArgument(400)
        $ps.RunspacePool = $pool
        [void]$jobs.Add([pscustomobject]@{ PS = $ps; Handle = $ps.BeginInvoke() })
    }
    $done = 0
    foreach ($j in $jobs) {
        $res = $j.PS.EndInvoke($j.Handle)
        $j.PS.Dispose()
        $done++
        if (($done % 100) -eq 0 -or $done -eq $jobs.Count) { Write-Host ("  …已掃 {0}/{1}" -f $done, $jobs.Count) -ForegroundColor DarkGray }
        if ($res -and $res.Ip) { [void]$open.Add([pscustomobject]@{ Ip = [string]$res.Ip; Port = [int]$res.Port }) }
    }
    $pool.Close()
    $pool.Dispose()

    if ($open.Count -eq 0) {
        Write-WarnMsg '沒有發現開放列印埠的裝置。可改手動輸入 IP。'
        return @()
    }

    Write-Info ("發現 {0} 台疑似印表機，讀取 SNMP 機型…" -f $open.Count)
    $found = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($o in $open) {
        if ($seen.ContainsKey($o.Ip)) { continue }
        $seen[$o.Ip] = $true
        $model = Get-PrinterModelViaSnmp -Ip $o.Ip -Quiet
        $brand = Get-BrandFromModel $model
        if (-not $brand -and -not $model) { $brand = '?'; $model = '(無 SNMP／未知機型)' }
        elseif (-not $brand) { $brand = '?' }
        [void]$found.Add([pscustomobject]@{ Ip = $o.Ip; Port = $o.Port; Brand = $brand; Model = $model })
    }
    return @($found)
}

function Show-ScanTable($Found) {
    Write-Host ''
    Write-Host '======== 掃描結果 ========' -ForegroundColor White
    Write-Host ('  {0,-3} {1,-15} {2,-16} {3}' -f 'No', 'IP', '品牌', '機型')
    Write-Host ('  ' + ('-' * 70))
    for ($i = 0; $i -lt $Found.Count; $i++) {
        $f = $Found[$i]
        Write-Host ('  {0,-3} {1,-15} {2,-16} {3}' -f ($i + 1), $f.Ip, $f.Brand, $f.Model)
    }
    Write-Host ''
    Write-Host '  [A] 全部安裝'
    Write-Host '  [I] 手動輸入 IP'
    Write-Host ('  [0] ' + (Get-FlgExitLabel))
}

# ---- main ----
Write-Host ''
Write-Host '======== FLG 自動偵測機型／區網掃描 ========' -ForegroundColor White
Write-Host 'SNMP 讀機型 → 對應專用驅動下載 → 通用版安裝（黑白單面＋預設＋測試頁）' -ForegroundColor Gray
Write-Host ''

if ($script:Mode -eq 'scan') {
    Invoke-FlgCounterHit 'lan-scan'
} else {
    Invoke-FlgCounterHit 'auto-driver'
}

$cloud = $null
try { $cloud = Load-CloudCatalog } catch {
    Write-ErrMsg ('讀取 cloud.json 失敗：' + $_.Exception.Message)
    return
}

$doInstall = $true
if ($IsWindowsOs -and $doInstall -and -not (Test-IsAdmin)) {
    $boot = $(if ($script:Mode -eq 'scan') { 'auto-driver-scan.ps1' } else { 'auto-driver.ps1' })
    $null = Request-Elevation ($PagesBase + $boot) @args
    return
}

try {
    if ($script:Mode -eq 'scan') {
        $found = Invoke-LanPrinterScan
        if ($found.Count -eq 0) {
            $mip = (Read-Host ("請輸入印表機 IP（空白或 0 = {0}）" -f (Get-FlgExitLabel))).Trim()
            if (-not $mip -or $mip -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
            if (-not (Test-Ipv4Address $mip)) { throw "IP 無效：$mip" }
            Invoke-ProcessPrinter -Ip $mip -CloudCatalog $cloud -Install | Out-Null
            return
        }
        while ($true) {
            Show-ScanTable $found
            $choice = (Read-Host '請選擇編號').Trim()
            if ($choice -eq '0' -or $choice -eq '') { Write-Host ('已' + (Get-FlgExitLabel) + '。'); break }
            if ($choice -match '^(?i)i$') {
                $mip = (Read-Host '印表機 IP').Trim()
                if (-not (Test-Ipv4Address $mip)) { Write-WarnMsg 'IP 無效'; continue }
                Invoke-ProcessPrinter -Ip $mip -CloudCatalog $cloud -Install | Out-Null
                break
            }
            if ($choice -match '^(?i)a$') {
                foreach ($f in $found) {
                    Write-Host ''
                    Write-Info ("==== 安裝 $($f.Ip) / $($f.Model) ====")
                    try {
                        $hint = $f.Model
                        if ($hint -match '無 SNMP') { $hint = '' }
                        Invoke-ProcessPrinter -Ip $f.Ip -ModelHint $hint -CloudCatalog $cloud -Install -SkipAfterMenu | Out-Null
                    } catch {
                        Write-ErrMsg ("$($f.Ip) 失敗：" + $_.Exception.Message)
                        Invoke-FlgCounterHit 'install-fail-ricoh'
                    }
                }
                Write-Ok '全部處理完畢。'
                break
            }
            $n = 0
            if (-not [int]::TryParse($choice, [ref]$n) -or $n -lt 1 -or $n -gt $found.Count) {
                Write-WarnMsg '無效的編號。'; continue
            }
            $f = $found[$n - 1]
            $hint = $f.Model
            if ($hint -match '無 SNMP') { $hint = '' }
            Invoke-ProcessPrinter -Ip $f.Ip -ModelHint $hint -CloudCatalog $cloud -Install | Out-Null
            break
        }
    } else {
        $ip = $script:ArgIp
        if (-not $ip) {
            Write-Host ('請輸入印表機 IP（空白=掃描區網；0 = {0}；或輸入機型名稱）' -f (Get-FlgExitLabel)) -ForegroundColor White
            $raw = (Read-Host 'IP / 機型').Trim()
            if ($raw -eq '0') {
                Write-Info ('已' + (Get-FlgExitLabel) + '。')
                return
            }
            if ([string]::IsNullOrWhiteSpace($raw)) {
                $script:Mode = 'scan'
                Invoke-FlgCounterHit 'lan-scan'
                $found = Invoke-LanPrinterScan
                if ($found.Count -eq 0) { return }
                Show-ScanTable $found
                $choice = (Read-Host '請選擇編號').Trim()
                if ($choice -eq '0' -or $choice -eq '') { Write-Host ('已' + (Get-FlgExitLabel) + '。'); return }
                if ($choice -match '^(?i)a$') {
                    foreach ($f in $found) {
                        try {
                            $hint = $f.Model; if ($hint -match '無 SNMP') { $hint = '' }
                            Invoke-ProcessPrinter -Ip $f.Ip -ModelHint $hint -CloudCatalog $cloud -Install -SkipAfterMenu | Out-Null
                        } catch { Write-ErrMsg $_.Exception.Message }
                    }
                } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $found.Count) {
                    $f = $found[[int]$choice - 1]
                    $hint = $f.Model; if ($hint -match '無 SNMP') { $hint = '' }
                    Invoke-ProcessPrinter -Ip $f.Ip -ModelHint $hint -CloudCatalog $cloud -Install | Out-Null
                }
                return
            }
            if (Test-Ipv4Address $raw) {
                $ip = $raw
            } else {
                # treat as manual model name without IP — download only
                Write-WarnMsg '未提供 IP，只下載驅動、不安裝印表機。'
                $resolved = Resolve-ModelAndDrivers -ModelText $raw -CloudCatalog $cloud
                if ($resolved.Ambiguous) { $resolved.CatalogItem = Prompt-PickCandidate $resolved.Candidates }
                $downloaded = $null
                if ($resolved.CatalogItem) {
                    $downloaded = Download-CatalogItem -Item $resolved.CatalogItem -ModelLabel $raw
                } elseif ($resolved.CloudDriver) {
                    $downloaded = Download-CloudUniversalZip -Driver $resolved.CloudDriver -ModelLabel $raw
                    Write-Host ("原廠支援：" + $resolved.SupportUrl) -ForegroundColor DarkGray
                } else { throw "找不到可用驅動：$raw" }
                Show-AfterMenu $downloaded
                return
            }
        }
        Invoke-ProcessPrinter -Ip $ip -CloudCatalog $cloud -Install | Out-Null
    }
} catch {
    Write-ErrMsg ('失敗：' + $_.Exception.Message)
    if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    return
}
