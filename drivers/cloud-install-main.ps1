# FLG 雲端安裝驅動（Ricoh / FUJIFILM / Sharp / Canon / Konica Minolta 通用 PCL6）
# 用法（各品牌獨立指令，只問 IP）：
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-install.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-fuji.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-sharp.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-canon.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-konica.ps1 | iex
# 參數：$args[0]=印表機 IP；$args[1]=印表機名稱（可省略）
# 品牌由 bootstrap 透過 $env:FLG_CLOUD_DRIVER_ID 指定。
# 取得 IP 後會以 SNMP v2c community public 偵測機型，必要時自動切換品牌驅動。

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$CloudJsonUrl = 'https://lanyen007.github.io/FLGPQT/drivers/cloud.json'
$PagesBase = 'https://lanyen007.github.io/FLGPQT/drivers/'
$IsWindowsOs = $true
try {
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { $IsWindowsOs = $false }
} catch {}
if ($env:OS -notmatch 'Windows' -and $PSVersionTable.Platform -eq 'Unix') { $IsWindowsOs = $false }

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrMsg([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-FlgExitLabel {
    if ($env:FLG_FROM_MENU -eq '1') { return '回到上一頁' }
    return '離開'
}
function Exit-FlgOrReturn([int]$Code = 0) {
    if ($env:FLG_FROM_MENU -eq '1') { return }
    exit $Code
}

function Get-FlgBrandSlug([string]$IdOrBrand) {
    $s = [string]$IdOrBrand
    if ($s -match '(?i)fuji|fujifilm|xerox|apeos|docucentre|docuprint') { return 'fuji' }
    if ($s -match '(?i)sharp') { return 'sharp' }
    if ($s -match '(?i)canon|imagerunner|imageforce|imageclass|i-sensys|imagepress|ir-adv') { return 'canon' }
    if ($s -match '(?i)konica|minolta|bizhub|accurio|develop|ineo') { return 'konica' }
    return 'ricoh'
}

# Silent usage counter (Abacus). Never throws; max ~2s.
function Invoke-FlgCounterHit([string]$Key) {
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
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
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BootstrapUrl([string]$BootstrapFile) {
    if ([string]::IsNullOrWhiteSpace($BootstrapFile)) { $BootstrapFile = 'cloud-install.ps1' }
    return ($PagesBase + $BootstrapFile)
}

function Request-Elevation([string]$BootstrapUrl) {
    Write-WarnMsg '需要系統管理員權限才能安裝驅動，即將跳出 UAC 提示…'
    $parts = @()
    foreach ($a in $args) {
        $s = [string]$a
        $parts += ("'" + $s.Replace("'", "''") + "'")
    }
    $argStr = $parts -join ' '
    $inner = "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$BootstrapUrl'))) $argStr"
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList | Out-Null
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

function Test-Ipv4Address([string]$Ip) {
    if ([string]::IsNullOrWhiteSpace($Ip)) { return $false }
    $m = [regex]::Match($Ip.Trim(), '^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$')
    return $m.Success
}

# ---- SNMP v1/v2c GET（純 PowerShell BER + UdpClient，相容 Windows PowerShell 5.1）----
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
        # negative not needed for SNMP request fields we use
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

function ConvertTo-BerNull {
    return ,[byte[]]@(0x05, 0x00)
}

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
    # Version: 0=SNMPv1, 1=SNMPv2c
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
    if ($b -lt 0x80) {
        return @{ Length = [int]$b; Size = 1 }
    }
    $n = $b -band 0x7F
    $len = 0
    for ($i = 1; $i -le $n; $i++) {
        $len = ($len -shl 8) -bor $Buf[$Offset + $i]
    }
    return @{ Length = $len; Size = (1 + $n) }
}

function Get-SnmpOctetStringValue([byte[]]$Response) {
    # Walk BER tree; return first OCTET STRING / Opaque that looks like a non-community printable value after OID
    # Simpler: collect all OCTET STRING contents; skip community "public"; return longest printable
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
            if ($text -and $text -ne 'public' -and $text.Length -ge 2) {
                [void]$candidates.Add($text)
            }
            $i = $contentStart + $contentLen
            continue
        }
        if ($tag -eq 0x30 -or $tag -eq 0xA0 -or $tag -eq 0xA2 -or ($tag -band 0x20) -ne 0) {
            $i = $contentStart
            continue
        }
        # skip primitive
        $i = $contentStart + $contentLen
    }
    if ($candidates.Count -eq 0) { return $null }
    # Prefer later values (varbind value comes after community); take last
    return [string]$candidates[$candidates.Count - 1]
}

function Invoke-SnmpGet {
    param(
        [string]$Ip,
        [string]$Oid,
        [string]$Community = 'public',
        [int]$TimeoutMs = 2000,
        [int]$Version = 1
    )
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
    } catch {
        return $null
    } finally {
        if ($udp) { try { $udp.Close() } catch {} }
    }
}

function Get-PrinterModelViaSnmp([string]$Ip) {
    Write-Info ("SNMP 偵測機型 $Ip （community public，UDP 161）…")
    $oids = @(
        '1.3.6.1.2.1.1.1.0',           # sysDescr
        '1.3.6.1.2.1.25.3.2.1.3.1',    # hrDeviceDescr
        '1.3.6.1.2.1.43.5.1.1.16.1'    # prtGeneralPrinterName
    )
    $hits = New-Object System.Collections.ArrayList
    foreach ($ver in @(1, 0)) {
        foreach ($oid in $oids) {
            $val = Invoke-SnmpGet -Ip $Ip -Oid $oid -Community 'public' -TimeoutMs 2000 -Version $ver
            if ($val) {
                Write-Host ("  OID $oid => $val") -ForegroundColor DarkGray
                [void]$hits.Add($val)
            }
        }
        if ($hits.Count -gt 0) { break }
    }
    if ($hits.Count -eq 0) {
        Write-WarnMsg 'SNMP 無回應或無法取得機型，將使用通用驅動與預設名稱。'
        return $null
    }
    # Prefer hrDeviceDescr / printer name over long sysDescr when available
    $model = [string]$hits[$hits.Count - 1]
    foreach ($h in $hits) {
        $s = [string]$h
        if ($s -match '(?i)RICOH|SHARP|FUJIFILM|Xerox|Apeos|DocuCentre|DocuPrint|Canon|imageRUNNER|imageFORCE|KONICA|MINOLTA|bizhub|IM\s*C|MP\s*C|MX-|BP-') {
            $model = $s
        }
    }
    # Trim noisy sysDescr: take first line / before comma if very long
    if ($model.Contains("`n")) { $model = ($model -split "`n")[0].Trim() }
    if ($model.Length -gt 80) {
        $m2 = [regex]::Match($model, '(?i)((?:RICOH|SHARP|FUJIFILM|Fuji\s*Xerox|Xerox|Canon|KONICA\s*MINOLTA|Konica\s*Minolta)\s+)?[A-Z0-9][A-Z0-9 \-/]{2,40}')
        if ($m2.Success) { $model = $m2.Value.Trim() }
    }
    Write-Ok ("偵測到機型：$model")
    return $model
}

function Test-DriverModelsMatch($Driver, [string]$ModelText) {
    if (-not $Driver) { return $false }
    $patterns = @()
    try { $patterns = @($Driver.models) } catch { $patterns = @() }
    foreach ($pat in $patterns) {
        if ([string]::IsNullOrWhiteSpace([string]$pat)) { continue }
        try {
            if ([regex]::IsMatch($ModelText, [string]$pat)) { return $true }
        } catch {}
    }
    return $false
}

function Find-CloudDriverForModel($Catalog, [string]$ModelText, $PreferredDriver) {
    if ([string]::IsNullOrWhiteSpace($ModelText)) { return $PreferredDriver }
    # 若目前指令品牌已符合機型，維持不變
    if ($PreferredDriver -and (Test-DriverModelsMatch $PreferredDriver $ModelText)) {
        return $PreferredDriver
    }
    $list = @($Catalog.drivers)
    foreach ($d in $list) {
        if (Test-DriverModelsMatch $d $ModelText) {
            if ($PreferredDriver -and $d.id -ne $PreferredDriver.id) {
                Write-WarnMsg ("SNMP 機型對應到其他品牌驅動：從「$($PreferredDriver.brand)」改為「$($d.brand)」→ $($d.title)")
            }
            return $d
        }
    }
    return $PreferredDriver
}

function Get-PrinterDisplayName([string]$Prefix, [string]$Model, [string]$Ip) {
    if ([string]::IsNullOrWhiteSpace($Model)) {
        return ($Prefix + ' ' + $Ip)
    }
    # Sanitize model for printer name
    $clean = $Model -replace '[\\/:\*\?"<>\|]', ' '
    $clean = ($clean -replace '\s+', ' ').Trim()
    if ($clean.Length -gt 60) { $clean = $clean.Substring(0, 60).Trim() }
    # Avoid duplicating brand prefix if model already starts with it
    if ($clean.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return ($clean + ' (' + $Ip + ')')
    }
    return ($Prefix + ' ' + $clean + ' (' + $Ip + ')')
}

function Get-CloudCatalog {
    Write-Info '讀取雲端驅動清單…'
    $wc = New-Object Net.WebClient
    $wc.Encoding = [Text.Encoding]::UTF8
    $raw = $wc.DownloadString("$CloudJsonUrl`?t=$([DateTime]::UtcNow.Ticks)")
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
    return ($raw | ConvertFrom-Json)
}

function Select-CloudDriver($Catalog, [string]$DriverId, [switch]$Quiet) {
    $list = @($Catalog.drivers)
    if ($list.Count -eq 0) { throw 'cloud.json 沒有可用驅動。' }
    if ($DriverId) {
        $found = $list | Where-Object { $_.id -eq $DriverId } | Select-Object -First 1
        if (-not $found) {
            throw ("找不到驅動 id：$DriverId`n可用：" + (($list | ForEach-Object { $_.id }) -join ', '))
        }
        if (-not $Quiet) { Write-Ok ("選用：" + $found.title + "  v" + $found.version) }
        return $found
    }
    $ricoh = $list | Where-Object { $_.brand -eq 'Ricoh' } | Select-Object -First 1
    if ($ricoh) {
        if (-not $Quiet) { Write-Ok ("選用：" + $ricoh.title + "  v" + $ricoh.version) }
        return $ricoh
    }
    if (-not $Quiet) { Write-Ok ("選用：" + $list[0].title + "  v" + $list[0].version) }
    return $list[0]
}

function Get-PrinterIpFromArgsOrPrompt {
    $ip = ''
    if ($script:ArgIp) { $ip = $script:ArgIp }
    while (-not (Test-Ipv4Address $ip)) {
        if ($ip) { Write-WarnMsg "IP 格式不正確：$ip" }
        $hint = Get-FlgExitLabel
        $ip = Read-Host ("請輸入印表機 IP（例如 192.168.1.50；空白或 0 = {0}）" -f $hint)
        if ([string]::IsNullOrWhiteSpace($ip) -or $ip.Trim() -eq '0') {
            return $null
        }
    }
    return $ip.Trim()
}

function Test-PrinterReachable([string]$Ip) {
    Write-Info ("檢查連線 " + $Ip + " …")
    $pingOk = $false
    try {
        if ($IsWindowsOs) {
            $pingOk = Test-Connection -ComputerName $Ip -Count 1 -Quiet -ErrorAction SilentlyContinue
        } else {
            & ping -c 1 -W 2 $Ip 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $pingOk = $true }
        }
    } catch {}
    if ($pingOk) { Write-Ok 'Ping 成功' } else { Write-WarnMsg 'Ping 失敗（部分機台會關閉 ICMP，可略過）' }

    $tcpOk = $false
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($Ip, 9100, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait -and $client.Connected) { $tcpOk = $true }
        try { $client.Close() } catch {}
    } catch {}
    if ($tcpOk) { Write-Ok 'TCP 9100（Raw）可連' } else { Write-WarnMsg 'TCP 9100 無法連線（仍可繼續安裝驅動）' }
    return @{ Ping = $pingOk; Tcp9100 = $tcpOk }
}

function Get-FileSha256([string]$Path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($Path)
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
    $d = Get-PrinterDriver -Name $Name -ErrorAction SilentlyContinue
    return [bool]$d
}

function Install-CloudDriverWindows($Driver, [string]$Ip, [string]$PrinterName) {
    $work = Join-Path $env:TEMP ('FLG-CloudDriver-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $zipPath = Join-Path $work $Driver.zip_name
    $extractDir = Join-Path $work 'extract'

    try {
        Write-Info ("下載驅動包（約 {0:N1} MB）…" -f ($Driver.size / 1MB))
        Write-Host ("  " + $Driver.url)
        Invoke-WebRequest -Uri $Driver.url -OutFile $zipPath -UseBasicParsing
        if (-not (Test-Path -LiteralPath $zipPath)) { throw '下載失敗：找不到檔案。' }

        Write-Info '驗證 SHA256…'
        $actual = Get-FileSha256 $zipPath
        $expect = ([string]$Driver.sha256).ToLowerInvariant()
        if ($actual -ne $expect) {
            throw ("SHA256 不符`n  期望：$expect`n  實際：$actual")
        }
        Write-Ok 'SHA256 正確'

        Write-Info '解壓縮…'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        $infPath = Join-Path $extractDir $Driver.inf
        if (-not (Test-Path -LiteralPath $infPath)) {
            $infLeaf = [IO.Path]::GetFileName([string]$Driver.inf)
            $found = Get-ChildItem -Path $extractDir -Filter $infLeaf -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $found) {
                $found = Get-ChildItem -Path $extractDir -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            }
            if ($found) { $infPath = $found.FullName } else { throw "找不到 INF：$($Driver.inf)" }
        }
        Write-Ok ("INF：" + $infPath)

        Write-Info '安裝驅動套件（pnputil）…'
        $pnp = & pnputil.exe /add-driver $infPath /install 2>&1
        $pnp | ForEach-Object { Write-Host ("  " + $_) }
        $pnpCode = $LASTEXITCODE

        $drvName = [string]$Driver.driver_name
        $alt = [string]$Driver.driver_name_alt
        $inStore = (Test-PrinterDriverInStore $drvName) -or ($alt -and (Test-PrinterDriverInStore $alt))
        if ($pnpCode -ne 0 -and $pnpCode -ne $null -and -not $inStore) {
            throw ("pnputil 安裝驅動失敗（結束碼 $pnpCode）。驅動「$drvName」不在驅動程式存放區中。請確認套件完整且未被竄改（WHQL 目錄雜湊）。")
        }
        if ($pnpCode -ne 0 -and $pnpCode -ne $null -and $inStore) {
            Write-WarnMsg ("pnputil 結束碼：$pnpCode（驅動已在存放區，繼續）")
        }

        Write-Info ("登錄印表機驅動：$drvName")
        $existing = Get-PrinterDriver -Name $drvName -ErrorAction SilentlyContinue
        if (-not $existing) {
            try {
                Add-PrinterDriver -Name $drvName -ErrorAction Stop
            } catch {
                if ($alt) {
                    Write-WarnMsg ("改用備用名稱：$alt")
                    $drvName = $alt
                    if (-not (Get-PrinterDriver -Name $drvName -ErrorAction SilentlyContinue)) {
                        Add-PrinterDriver -Name $drvName -ErrorAction Stop
                    }
                } else { throw }
            }
        } else {
            Write-Ok '驅動已存在，略過 Add-PrinterDriver'
        }

        $portName = 'IP_' + $Ip
        Write-Info ("建立 TCP/IP 連接埠：$portName")
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $portName -PrinterHostAddress $Ip -ErrorAction Stop
            Write-Ok '連接埠已建立'
        } else {
            Write-Ok '連接埠已存在，略過'
        }

        Write-Info ("新增印表機：$PrinterName")
        $prev = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($prev) {
            Write-WarnMsg '同名印表機已存在，將移除後重建…'
            Remove-Printer -Name $PrinterName -ErrorAction Stop
        }
        Add-Printer -Name $PrinterName -DriverName $drvName -PortName $portName -ErrorAction Stop
        Write-Ok '印表機已新增'

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

        Write-Host ''
        Write-Ok '雲端安裝完成。'
        Write-Host ("  驅動：$drvName  v$($Driver.version)") -ForegroundColor Green
        Write-Host ("  印表機：$PrinterName") -ForegroundColor Green
        Write-Host ("  連接埠：$portName → $Ip") -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $work) {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-CloudDriverMock($Driver, [string]$Ip, [string]$PrinterName) {
    Write-WarnMsg '目前不是 Windows，改走模擬流程（驗證下載與 SHA256）。'
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('FLG-CloudDriver-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $zipPath = Join-Path $work $Driver.zip_name
    try {
        Write-Info ("下載 " + $Driver.url)
        Invoke-WebRequest -Uri $Driver.url -OutFile $zipPath -UseBasicParsing
        $actual = Get-FileSha256 $zipPath
        $expect = ([string]$Driver.sha256).ToLowerInvariant()
        if ($actual -ne $expect) { throw "SHA256 不符：期望 $expect 實際 $actual" }
        Write-Ok ("SHA256 OK  size=" + (Get-Item $zipPath).Length)
        Write-Info '解壓縮（驗證 INF）…'
        Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $work 'extract') -Force
        $inf = Join-Path $work ('extract/' + $Driver.inf)
        if (-not (Test-Path $inf)) {
            $infLeaf = [IO.Path]::GetFileName([string]$Driver.inf)
            $found = Get-ChildItem -Path (Join-Path $work 'extract') -Filter $infLeaf -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $inf = $found.FullName } else { throw "找不到 INF：$inf" }
        }
        Write-Ok ("INF OK：" + $inf)
        # Confirm INF hash if fuji (unmodified check note)
        Write-Host '[MOCK] pnputil /add-driver … /install' -ForegroundColor DarkGray
        Write-Host ("[MOCK] Add-PrinterDriver -Name '" + $Driver.driver_name + "'") -ForegroundColor DarkGray
        Write-Host ("[MOCK] Add-PrinterPort -Name 'IP_" + $Ip + "' -PrinterHostAddress " + $Ip) -ForegroundColor DarkGray
        Write-Host ("[MOCK] Add-Printer -Name '" + $PrinterName + "'") -ForegroundColor DarkGray
        Write-Host '[MOCK] Set-PrintConfiguration -Color $false -DuplexingMode OneSided' -ForegroundColor DarkGray
        Write-Ok 'Linux 模擬流程通過（Windows 安裝步驟未實測）。'
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- args ---
$script:ArgIp = ''
$script:ArgName = ''
$script:NonInteractive = $false
$script:ArgDriverId = ''
if ($env:FLG_CLOUD_DRIVER_ID) { $script:ArgDriverId = [string]$env:FLG_CLOUD_DRIVER_ID }

if ($args -and $args.Count -ge 1) {
    if (Test-Ipv4Address ([string]$args[0])) {
        $script:ArgIp = [string]$args[0]
        $script:NonInteractive = $true
        if ($args.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace([string]$args[1])) {
            $script:ArgName = [string]$args[1]
        }
    } else {
        $script:ArgDriverId = [string]$args[0]
        if ($args.Count -ge 2 -and (Test-Ipv4Address ([string]$args[1]))) {
            $script:ArgIp = [string]$args[1]
            $script:NonInteractive = $true
            if ($args.Count -ge 3 -and -not [string]::IsNullOrWhiteSpace([string]$args[2])) {
                $script:ArgName = [string]$args[2]
            }
        }
    }
}

Write-Host ''
Write-Host '======== FLG 雲端安裝驅動 ========' -ForegroundColor White
Write-Host '通用 PCL6（Win64）｜只輸入 IP｜SNMP 偵測機型｜自動黑白單面＋預設＋測試頁' -ForegroundColor Gray
Write-Host ''

$catalog = $null
$driverPreview = $null
try {
    $catalog = Get-CloudCatalog
    $driverPreview = Select-CloudDriver $catalog $script:ArgDriverId
} catch {
    Write-ErrMsg ('讀取清單失敗：' + $_.Exception.Message)
    return
}

$script:FlgBrandSlug = Get-FlgBrandSlug $driverPreview.id
if (-not $script:FlgBrandSlug) { $script:FlgBrandSlug = Get-FlgBrandSlug $script:ArgDriverId }
Invoke-FlgCounterHit ('cloud-' + $script:FlgBrandSlug)

$bootstrapFile = 'cloud-install.ps1'
if ($driverPreview.bootstrap) { $bootstrapFile = [string]$driverPreview.bootstrap }
$BootstrapUrl = Get-BootstrapUrl $bootstrapFile

if ($IsWindowsOs -and -not (Test-IsAdmin)) {
    $null = Request-Elevation $BootstrapUrl @args
    return
}

try {
    $driver = $driverPreview
    $ip = Get-PrinterIpFromArgsOrPrompt
    if (-not $ip) {
        Write-Info ('已' + (Get-FlgExitLabel) + '。')
        return
    }

    if (-not $script:NonInteractive) {
        $null = Test-PrinterReachable $ip
    }

    $detectedModel = Get-PrinterModelViaSnmp $ip
    if ($detectedModel) {
        $matched = Find-CloudDriverForModel $catalog $detectedModel $driver
        if ($matched.id -ne $driver.id) {
            $driver = $matched
            Write-Ok ("改用：" + $driver.title + "  v" + $driver.version)
            $script:FlgBrandSlug = Get-FlgBrandSlug $driver.id
        }
    }

    $prefix = 'RICOH'
    if ($driver.name_prefix) { $prefix = [string]$driver.name_prefix }
    if ($script:ArgName) {
        $printerName = $script:ArgName
    } else {
        $printerName = Get-PrinterDisplayName -Prefix $prefix -Model $detectedModel -Ip $ip
    }

    if ($script:NonInteractive) {
        Write-Info ("非互動模式：IP=$ip  Name=$printerName  Driver=$($driver.id)")
    } else {
        Write-Info ("印表機名稱：$printerName")
    }

    if ($IsWindowsOs) {
        Install-CloudDriverWindows -Driver $driver -Ip $ip -PrinterName $printerName
    } else {
        Install-CloudDriverMock -Driver $driver -Ip $ip -PrinterName $printerName
    }
    Invoke-FlgCounterHit ('install-ok-' + $script:FlgBrandSlug)
} catch {
    Invoke-FlgCounterHit ('install-fail-' + $script:FlgBrandSlug)
    Write-ErrMsg ('安裝失敗：' + $_.Exception.Message)
    if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    return
}
