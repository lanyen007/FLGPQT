# lanyen 工具箱 快速建立 SMB 共用資料夾（影印機掃描到資料夾）
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/smb.ps1 | iex
# 需要系統管理員權限（會嘗試自動提權）

$ErrorActionPreference = 'Stop'
$script:FlgSmbLog = Join-Path ([IO.Path]::GetTempPath()) 'lanyen_smb.log'
trap { Write-FlgSmbLog ('FATAL: ' + ($_ | Out-String) + $_.ScriptStackTrace); Write-Host ('錯誤 / Error: ' + $_.Exception.Message) -ForegroundColor Red; Write-Host ('Log: ' + $script:FlgSmbLog) -ForegroundColor Yellow; try { [void](Read-Host 'Press Enter / 按 Enter 結束') } catch {}; break }
function Write-FlgSmbLog([string]$Message) { try { Add-Content -LiteralPath $script:FlgSmbLog -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message) -Encoding UTF8 } catch {} }
# Old RICOH (e.g. MP C6004ex) may only speak TLS 1.0/1.1, and copiers redirect SOAP to HTTPS with a self-signed cert.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls } catch {}
# 192.168.x.x 會把 SOAP 從 HTTP 轉到 HTTPS，憑證是自簽的。只接受區網位址。
try {
if (-not ('FlgCopierCert' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography.X509Certificates;
public static class FlgCopierCert {
    public static bool Allow(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
        if (errors == SslPolicyErrors.None) return true;
        HttpWebRequest req = sender as HttpWebRequest;
        if (req == null || req.RequestUri == null) return false;
        IPAddress ip;
        if (!IPAddress.TryParse(req.RequestUri.Host, out ip)) return false;
        if (ip.AddressFamily != AddressFamily.InterNetwork) return false;
        byte[] b = ip.GetAddressBytes();
        if (b[0] == 10 || b[0] == 127) return true;
        if (b[0] == 192 && b[1] == 168) return true;
        if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
        return false;
    }
    public static void Install() {
        ServicePointManager.ServerCertificateValidationCallback = new RemoteCertificateValidationCallback(Allow);
    }
}
'@
}
} catch { Write-FlgSmbLog ('cert helper: ' + $_.Exception.Message) }
try { [FlgCopierCert]::Install() } catch {}

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
function Get-FlgExitLabel {
    if ($env:FLG_FROM_MENU -eq '1') { return (Get-FlgT '回到上一頁' 'Back') }
    return (Get-FlgT '離開' 'Exit')
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

function Find-FlgCopiers {
    # Parallel LAN scan: TCP 9100, then SNMP v2c/v1 'public' GET sysDescr / hrDeviceDescr
    $hosts = New-Object System.Collections.ArrayList
    foreach ($ip in @(Get-LocalIPv4List)) {
        if ($ip -notmatch '^(\d+\.\d+\.\d+)\.\d+$') { continue }
        $pre = $Matches[1]
        for ($i = 1; $i -le 254; $i++) { $h = "$pre.$i"; if ($h -ne $ip -and $hosts -notcontains $h) { [void]$hosts.Add($h) } }
    }
    if ($hosts.Count -eq 0) { return @() }
    Write-Info ((Get-FlgT '掃描區網影印機（TCP 9100 + SNMP）… {0} 台' 'Scanning LAN for copiers (TCP 9100 + SNMP)… {0} hosts') -f $hosts.Count)
    $sb = {
        param($Ip)
        function L([int]$n) { if ($n -lt 0x80) { ,[byte[]]@($n) } else { ,[byte[]]@(0x81, $n) } }
        function W([byte]$tag, [byte[]]$c) { ,([byte[]]@($tag) + (L $c.Length) + $c) }
        function Get-Str($Ip, [byte[]]$oid, [int]$ver) {
            $vb = W 0x30 (W 0x30 ($oid + [byte[]]@(5, 0)))
            $pdu = W 0xA0 ([byte[]]@(2, 1, 1, 2, 1, 0, 2, 1, 0) + $vb)
            $pkt = W 0x30 ([byte[]]@(2, 1, $ver) + (W 4 ([Text.Encoding]::ASCII.GetBytes('public'))) + $pdu)
            $u = New-Object Net.Sockets.UdpClient
            try {
                $u.Client.ReceiveTimeout = 1200
                [void]$u.Send($pkt, $pkt.Length, $Ip, 161)
                $ep = New-Object Net.IPEndPoint ([Net.IPAddress]::Any, 0)
                $r = $u.Receive([ref]$ep)
                # last OCTET STRING in response = value
                $i = 0; $val = $null
                while ($i -lt $r.Length - 1) {
                    $tag = $r[$i]; $len = [int]$r[$i + 1]; $hs = 2
                    if ($len -ge 0x80) { $n = $len -band 0x7F; $len = 0; for ($k = 0; $k -lt $n; $k++) { $len = ($len -shl 8) -bor $r[$i + 2 + $k] }; $hs = 2 + $n }
                    if ($tag -eq 0x30 -or $tag -ge 0xA0) { $i += $hs; continue }
                    if ($tag -eq 4 -and ($i + $hs + $len) -le $r.Length) { $val = [Text.Encoding]::UTF8.GetString($r, $i + $hs, $len) }
                    $i += $hs + $len
                }
                if ($val -and $val -ne 'public') { return $val.Trim([char]0).Trim() }
            } catch {} finally { $u.Close() }
            return $null
        }
        $tcp = New-Object Net.Sockets.TcpClient
        $open = $false
        try { $iar = $tcp.BeginConnect($Ip, 9100, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(400, $false)) { $tcp.EndConnect($iar); $open = $tcp.Connected } } catch {} finally { $tcp.Close() }
        $sysDescr = [byte[]]@(6, 8, 0x2B, 6, 1, 2, 1, 1, 1, 0)
        $hrDev = [byte[]]@(6, 11, 0x2B, 6, 1, 2, 1, 0x19, 3, 2, 1, 3, 1)
        if (-not $open) {
            # quick SNMP-only probe (some copiers block 9100)
            $m = Get-Str $Ip $sysDescr 1
            if (-not $m) { return $null }
        } else { $m = $null }
        $hr = $null
        foreach ($v in 1, 0) { $hr = Get-Str $Ip $hrDev $v; if ($hr) { break } }
        if (-not $m) { foreach ($v in 1, 0) { $m = Get-Str $Ip $sysDescr $v; if ($m) { break } } }
        $model = $m
        $isRicohOid = $false
        try {
            $oidPkt = W 0x30 ([byte[]]@(2, 1, 1) + (W 4 ([Text.Encoding]::ASCII.GetBytes('public'))) + (W 0xA0 ([byte[]]@(2, 1, 2, 2, 1, 0, 2, 1, 0) + (W 0x30 (W 0x30 ([byte[]]@(6, 8, 0x2B, 6, 1, 2, 1, 1, 2, 0, 5, 0)))))))
            $u2 = New-Object Net.Sockets.UdpClient; $u2.Client.ReceiveTimeout = 1200
            [void]$u2.Send($oidPkt, $oidPkt.Length, $Ip, 161); $ep2 = New-Object Net.IPEndPoint ([Net.IPAddress]::Any, 0); $rr = $u2.Receive([ref]$ep2); $u2.Close()
            $hex = [BitConverter]::ToString($rr)
            if ($hex -match '2B-06-01-04-01-82-6F') { $isRicohOid = $true }
        } catch {}
        if ($hr -and ($hr -match '(?i)RICOH|SHARP|FUJI|XEROX|Apeos|Canon|KONICA|bizhub|Kyocera|Epson|Brother|HP|Printer|MFP')) { $model = $hr }
        if (-not $model) { $model = $(if ($open) { '?' } else { $null }) }
        if (-not $model) { return $null }
        if ($model.Contains("`n")) { $model = ($model -split "`n")[0].Trim() }
        if ($isRicohOid -and $model -notmatch '(?i)RICOH') { $model = 'RICOH ' + $model }
        return [pscustomobject]@{ Ip = $Ip; Model = $model }
    }
    $pool = [runspacefactory]::CreateRunspacePool(1, 64); $pool.Open()
    $jobs = foreach ($h in $hosts) { $ps = [powershell]::Create().AddScript($sb).AddArgument($h); $ps.RunspacePool = $pool; [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() } }
    $found = New-Object System.Collections.ArrayList
    foreach ($j in $jobs) { try { foreach ($r in $j.PS.EndInvoke($j.H)) { if ($r) { [void]$found.Add($r) } } } catch {}; $j.PS.Dispose() }
    $pool.Close(); $pool.Dispose()
    return @($found | Sort-Object { [version]$_.Ip })
}

function Add-FlgFujiSmbContact {
    # Based on a recorded CWIS session (ApeosPort C5570): SOAP AddContact to /ssm/Management/Anonymous/Contact
    param([string]$CopierIp, [string]$DisplayName, [string]$Server, [string]$Share, [string]$User, [string]$Pass, [pscredential]$Credential)
    function X([string]$s) { return [Security.SecurityElement]::Escape([string]$s) }
    $ns = 'http://www.fujixerox.co.jp/2014/08/ssm/management'
    $action = "$ns/contact#AddContact"
    $body = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Header><msg:MessageInformation xmlns:msg="' + $ns + '/message"><msg:MessageExchangeType>RequestResponse</msg:MessageExchangeType><msg:MessageType>Request</msg:MessageType><msg:Action>' + $action + '</msg:Action><msg:From><msg:Address>' + $ns + '/soap/epr/client</msg:Address><msg:ReferenceParameters/></msg:From></msg:MessageInformation></soap:Header>' +
        '<soap:Body><ct:AddContact xmlns:ct="' + $ns + '/contact"><ct:DataSource>Local</ct:DataSource><ct:Contacts><ct:Contact><ct:Type>Destination</ct:Type><ct:Favorite>false</ct:Favorite>' +
        '<ct:DisplayName xml:space="preserve">' + (X $DisplayName) + '</ct:DisplayName><ct:SurName xml:space="preserve"></ct:SurName><ct:GivenName xml:space="preserve"></ct:GivenName><ct:CompanyName xml:space="preserve"></ct:CompanyName><ct:Key xml:space="preserve"></ct:Key>' +
        '<ct:Destination><ct:Type>Server</ct:Type><ct:Favorite>false</ct:Favorite><ct:Server><ct:Type>SMB</ct:Type><ct:Address xml:space="preserve">' + (X $Server) + '</ct:Address><ct:Port>0</ct:Port>' +
        '<ct:UserName xml:space="preserve">' + (X $User) + '</ct:UserName><ct:Password xml:space="preserve">' + (X $Pass) + '</ct:Password><ct:Volume xml:space="preserve">' + (X $Share) + '</ct:Volume><ct:Path xml:space="preserve"></ct:Path></ct:Server></ct:Destination></ct:Contact></ct:Contacts>' +
        '<ct:Responds><cmn:Respond xmlns:cmn="http://www.fujixerox.co.jp/2012/07/ssm/management/common">#DESCENDANT</cmn:Respond></ct:Responds></ct:AddContact></soap:Body></soap:Envelope>'
    $headers = @{ 'soapAction' = '"' + $action + '"'; 'X-Requested-With' = 'XMLHttpRequest'; 'Referer' = "http://$CopierIp/addressbook/index.html" }
    $args2 = @{ Uri = "http://$CopierIp/ssm/Management/Anonymous/Contact"; Method = 'Post'; Body = [Text.Encoding]::UTF8.GetBytes($body); ContentType = 'text/xml; charset=UTF-8'; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 15 }
    if ($Credential) { $args2.Credential = $Credential }
    try {
        $r = Invoke-WebRequest @args2
        $txt = $(if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content })
        if ($txt -match 'AddContactResponse' -and $txt -match '<Identifier') { return [pscustomobject]@{ Ok = $true; Message = '' } }
        $fault = [regex]::Match($txt, '<faultstring[^>]*>([^<]*)').Groups[1].Value
        return [pscustomobject]@{ Ok = $false; Message = $(if ($fault) { $fault } else { $txt.Substring(0, [Math]::Min(200, $txt.Length)) }) }
    } catch {
        $code = $null; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        return [pscustomobject]@{ Ok = $false; Code = $code; Message = $_.Exception.Message }
    }
}

# ---- RICOH Web Image Monitor login: port of RICOH使用者計數下載.exe 1.0.1 (Login/Get/Post/Prepare/Read/AddCookie) ----
function Invoke-FlgRicohHttp {
    param([Net.CookieContainer]$Cookies, [string]$Method, [string]$Url, [string]$Form, [string]$Referer, [hashtable]$Headers)
    $req = [Net.HttpWebRequest][Net.WebRequest]::Create($Url)
    $req.CookieContainer = $Cookies
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36'
    $req.Timeout = 90000; $req.ReadWriteTimeout = 90000
    $req.AllowAutoRedirect = $true; $req.MaximumAutomaticRedirections = 5
    $req.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
    $req.KeepAlive = $true
    if ($Referer) { $req.Referer = $Referer }
    # headers as recorded from Chrome on MP C5504 / MP C6004ex (WIM answers AJAX calls with a JS array only for XHR-style requests)
    $isXhr = ($Headers -and $Headers.ContainsKey('X-Requested-With'))
    $req.Accept = $(if ($isXhr) { 'text/plain, */*' } else { 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' })
    $req.Headers['Accept-Language'] = 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7'
    if ($Method -eq 'POST') { try { $u0 = [Uri]$Url; $req.Headers['Origin'] = $u0.Scheme + '://' + $u0.Authority } catch {} }
    if ($Headers) { foreach ($k in $Headers.Keys) { $req.Headers[$k] = [string]$Headers[$k] } }
    if ($isXhr -and $Method -ne 'POST') { $req.ContentType = 'application/x-www-form-urlencoded; charset=UTF-8' }
    $req.Method = $Method
    if ($Method -eq 'POST') {
        $req.ContentType = $(if ($Headers -and $Headers.ContainsKey('X-Requested-With')) { 'application/x-www-form-urlencoded; charset=UTF-8' } else { 'application/x-www-form-urlencoded' })
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Form)
        $req.ContentLength = $bytes.Length
        $st = $req.GetRequestStream(); try { $st.Write($bytes, 0, $bytes.Length) } finally { $st.Close() }
    }
    $logForm = ([string]$Form) -replace '((?i)password\w*=)[^&]*', '$1***'
    try { $resp = [Net.HttpWebResponse]$req.GetResponse() } catch {
        $code = ''; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        Write-FlgSmbLog ("RICOH HTTP $Method $Url form=[$logForm] -> ERROR $code " + $_.Exception.Message)
        throw
    }
    try {
        $ms = New-Object IO.MemoryStream
        $rs = $resp.GetResponseStream(); if ($rs) { $rs.CopyTo($ms); $rs.Close() }
        $enc = [Text.Encoding]::UTF8
        try { if ($resp.CharacterSet) { $enc = [Text.Encoding]::GetEncoding($resp.CharacterSet) } } catch {}
        $txt = $enc.GetString($ms.ToArray())
        $snip = ($txt -replace '\s+', ' ')
        $bi = $snip.IndexOf('<body'); if ($bi -gt 0) { $snip = $snip.Substring($bi) }   # skip <head> (scripts/css) so the log shows the real message
        $snip = $snip -replace '<script.*?</script>', '' -replace '<style.*?</style>', ''
        if ($snip.Length -gt 1200) { $snip = $snip.Substring(0, 1200) }
        $snip = $snip -replace '(name="password[^"]*"[^>]*value=")[^"]*', '$1***'
        if ($txt -match 'class="errorMessage"') {
            $plain = (($txt -replace '(?s)<script.*?</script>', '' -replace '(?s)<style.*?</style>', '' -replace '<[^>]+>', ' ') -replace '&nbsp;', ' ' -replace '\s+', ' ').Trim()
            Write-FlgSmbLog ('RICOH ERROR PAGE TEXT: ' + $(if ($plain.Length -gt 1500) { $plain.Substring(0, 1500) } else { $plain }))
            $script:FlgRicohLastError = $plain
        }
        Write-FlgSmbLog ("RICOH HTTP $Method $Url form=[$logForm] -> " + [int]$resp.StatusCode + " len=" + $txt.Length + " body: " + $snip)
        return $txt
    } finally { $resp.Close() }
}

function Invoke-FlgRicohLogin {
    # Same as RICOH使用者計數下載.exe Login(host, lang, user, pass, cookies)
    param([string]$HostName, [string]$Lang, [string]$User, [string]$Pass, [Net.CookieContainer]$Cookies)
    $authUrl = "http://$HostName/web/guest/$Lang/websys/webArch/authForm.cgi"
    $loginUrl = "http://$HostName/web/guest/$Lang/websys/webArch/login.cgi"
    foreach ($n in 'cookieOnOffChecker', 'cookieOnOffChecker1') { try { $Cookies.Add((New-Object Uri ("http://$HostName/")), (New-Object Net.Cookie ($n, 'on', '/'))) } catch {} }
    $tok = ''
    try {
        $html = Invoke-FlgRicohHttp -Cookies $Cookies -Method GET -Url $authUrl
        $m = [regex]::Match([string]$html, 'name="wimToken"[^>]*value="([^"]+)"')
        if ($m.Success) { $tok = $m.Groups[1].Value }
    } catch {}
    $u = [Uri]::EscapeDataString([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$User)))
    $p = [Uri]::EscapeDataString([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Pass)))
    $form = 'wimToken=' + [Uri]::EscapeDataString($tok) + '&userid_work=&userid=' + $u + '&password_work=&password=' + $p + '&open='
    try {
        $r = Invoke-FlgRicohHttp -Cookies $Cookies -Method POST -Url $loginUrl -Form $form -Referer $authUrl
        return ([string]$r -match 'topPage\.cgi|header\.cgi|frameset')
    } catch { return $false }
}
# ---- end of counter-download login ----

function Get-FlgIpv4ForCopier([string]$CopierIp) {
    $ips = @(Get-LocalIPv4List | Where-Object { $_ -and $_ -ne '127.0.0.1' })
    if ($CopierIp -match '^(\d+\.\d+\.\d+)\.') {
        $pre = $Matches[1] + '.'
        $same = @($ips | Where-Object { [string]$_ -like ($pre + '*') })
        if ($same.Count -gt 0) { return [string]$same[0] }
    }
    if ($ips.Count -gt 0) { return [string]$ips[0] }
    return [string]$env:COMPUTERNAME
}

function ConvertTo-FlgRicohLoginMessage([string]$Text) {
    if ($Text -match '帳號或密碼錯誤|通訊錄使用中|無法連上影印機|沒有回傳登入') { return $Text }
    if ($Text -match 'NOT_AUTHENTICATED') { return (Get-FlgT '帳號或密碼錯誤。' 'The admin account or password was rejected.') }
    if ($Text -match 'SYSTEM_BUSY') { return (Get-FlgT '通訊錄使用中或被鎖定，請稍後再試。' 'The address book is busy or locked. Try again in a moment.') }
    if ($Text -match '信任關係|遠端憑證|SSL|TLS|secure channel') { return (Get-FlgT '無法連上影印機的 HTTPS。' 'Could not connect to the copier over HTTPS.') }
    if ([string]::IsNullOrWhiteSpace($Text)) { return (Get-FlgT '登入失敗。' 'Login failed.') }
    return $Text
}

function Add-FlgRicohSmbEntry {
    # SOAP http://IP/DH/udirectory, not the Web Image Monitor address wizard.
    # On MP C6004ex the wizard returns "too many users" / session-timeout HTML, and SOAP port 21 returns result code 302.
    # The body must be UTF-8 bytes. Windows PowerShell 5.1 Invoke-WebRequest stores CJK names as "??".
    # The path is \\<PC hostname>\<share name> (user rule).
    param([string]$CopierIp, [string]$Name, [string]$Path, [string]$User, [string]$Pass, [string]$AdminUser = 'admin', [string]$AdminPass = '', [string]$Lang = 'tw', [int]$Port = 80)
    $hostName = $(if ($Port -eq 80) { $CopierIp } else { "${CopierIp}:$Port" })
    $script:FlgSoapUrl = $null
    $ns = 'http://www.ricoh.co.jp/xmlns/soap/rdh/udirectory'
    function XmlEscape([string]$s) {
        if ($null -eq $s) { return '' }
        return (([string]$s).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;'))
    }
    function New-PropItems([object[]]$Pairs) {
        $sb = New-Object Text.StringBuilder
        for ($i = 0; $i -lt $Pairs.Count; $i += 2) {
            [void]$sb.Append('<item><propName>')
            [void]$sb.Append((XmlEscape ([string]$Pairs[$i])))
            [void]$sb.Append('</propName><propVal>')
            [void]$sb.Append((XmlEscape ([string]$Pairs[$i + 1])))
            [void]$sb.Append('</propVal></item>')
        }
        return $sb.ToString()
    }
    function New-Soap([string]$Inner) {
        return @"
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
$Inner
  </s:Body>
</s:Envelope>
"@
    }
    function Send-FlgSoap([string]$Action, [string]$Xml) {
        # Copier may 301/302/307 the SOAP POST to https://; re-POST there (HttpWebRequest would turn it into a GET).
        if (-not $script:FlgSoapUrl) { $script:FlgSoapUrl = "http://$hostName/DH/udirectory" }
        for ($hop = 0; $hop -lt 4; $hop++) {
            $r = Send-FlgSoapOnce $script:FlgSoapUrl $Action $Xml
            if (-not $r.Redirect) { return $r.Text }
            $next = [string]$r.Redirect
            if ($next -notmatch '^https?://') { $next = ([Uri]::new([Uri]$script:FlgSoapUrl, $next)).AbsoluteUri }
            Write-FlgSmbLog ('SOAP redirect -> ' + $next)
            $script:FlgSoapUrl = $next
        }
        throw ('SOAP redirect loop: ' + $script:FlgSoapUrl)
    }
    function Send-FlgSoapOnce([string]$Url, [string]$Action, [string]$Xml) {
        $req = [Net.HttpWebRequest]::Create($Url)
        $req.AllowAutoRedirect = $false
        $req.Method = 'POST'
        $req.ContentType = 'text/xml; charset=utf-8'
        $req.Timeout = 90000
        $req.ReadWriteTimeout = 90000
        $req.Headers.Add('SOAPAction', ($ns + '#' + $Action))
        $bytes = [Text.Encoding]::UTF8.GetBytes($Xml)
        $req.ContentLength = $bytes.Length
        $st = $req.GetRequestStream()
        try { $st.Write($bytes, 0, $bytes.Length) } finally { $st.Close() }
        try {
            $resp = [Net.HttpWebResponse]$req.GetResponse()
            if ([int]$resp.StatusCode -ge 300 -and [int]$resp.StatusCode -lt 400) { $loc = [string]$resp.Headers['Location']; $resp.Close(); return [pscustomobject]@{ Redirect = $loc; Text = '' } }
        } catch [System.Net.WebException] {
            $txt = ''
            $er = $_.Exception.Response
            if ($er -and [int]$er.StatusCode -ge 300 -and [int]$er.StatusCode -lt 400 -and $er.Headers['Location']) { return [pscustomobject]@{ Redirect = [string]$er.Headers['Location']; Text = '' } }
            if ($er) {
                try {
                    $sr = New-Object IO.StreamReader($er.GetResponseStream(), [Text.Encoding]::UTF8)
                    $txt = $sr.ReadToEnd()
                    $sr.Close()
                } catch {}
            }
            $detail = ''
            if ($txt -match 'errorDescription>([^<]+)') { $detail = $Matches[1] }
            elseif ($txt -match 'errorCode>([^<]+)') { $detail = $Matches[1] }
            elseif ($txt -match 'faultstring>([^<]+)') { $detail = $Matches[1] }
            $ex = New-Object System.Exception($(if ($detail) { $detail } else { $_.Exception.Message }))
            $ex | Add-Member -NotePropertyName FaultText -NotePropertyValue $txt -Force
            throw $ex
        }
        try {
            $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd()
            $sr.Close()
            return [pscustomobject]@{ Redirect = ''; Text = $txt }
        } finally { $resp.Close() }
    }
    function Read-FlgEntryMaps([string]$XmlText) {
        $doc = New-Object Xml.XmlDocument
        $doc.LoadXml($XmlText)
        $list = @()
        foreach ($entry in $doc.GetElementsByTagName('item')) {
            $props = @($entry.SelectNodes('./item[propName]'))
            if ($props.Count -eq 0) { continue }
            $map = @{}
            foreach ($p in $props) { $map[[string]$p.propName] = [string]$p.propVal }
            if ($map.ContainsKey('id')) {
                $wrap = New-Object psobject
                $wrap | Add-Member -NotePropertyName Map -NotePropertyValue $map
                $list += $wrap
            }
        }
        return $list
    }
    $entryName = [string]$Name
    if ($entryName.Length -gt 20) { $entryName = $entryName.Substring(0, 20) }
    $disp = $entryName
    if ($disp.Length -gt 16) { $disp = $disp.Substring(0, 16) }
    $pw = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Pass))
    $props = New-PropItems @(
        'entryType', 'user',
        'name', $entryName,
        'longName', $disp,
        'displayedOrder', '5',
        'tagId', '1',
        'isDestination', 'true',
        'remoteFolder:', 'true',
        'remoteFolder:type', 'smb',
        'remoteFolder:path', [string]$Path,
        'remoteFolder:port', '445',
        'remoteFolder:select', 'private',
        'remoteFolder:accountName', [string]$User,
        'remoteFolder:password', $pw
    )
    $sid = ''
    try {
        $scheme = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('BASIC'))
        $u = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$AdminUser))
        $p = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$AdminPass))
        $start = New-Soap @"
    <u:startSession xmlns:u="$ns">
      <stringIn>SCHEME=$scheme;UID:UserName=$u;PWD:Password=$p;PES:Encoding=</stringIn>
      <timeLimit>60</timeLimit>
      <lockMode>X</lockMode>
    </u:startSession>
"@
        $raw = $null
        $loginError = $null
        for ($loginTry = 1; $loginTry -le 3; $loginTry++) {
            try {
                $raw = Send-FlgSoap 'startSession' $start
                $loginError = $null
                break
            } catch {
                $loginError = [string]$_.Exception.Message
                if ($loginError -match 'SYSTEM_BUSY' -and $loginTry -lt 3) {
                    Start-Sleep -Seconds 2
                    continue
                }
                break
            }
        }
        if ($loginError) {
            $needPassword = [string]::IsNullOrEmpty([string]$AdminPass) -or ($loginError -match 'NOT_AUTHENTICATED')
            return [pscustomobject]@{ Ok = $false; Auth = [bool]$needPassword; Message = (ConvertTo-FlgRicohLoginMessage $loginError) }
        }
        $sm = [regex]::Match([string]$raw, '<stringOut>([^<]+)</stringOut>')
        if (-not $sm.Success) { return [pscustomobject]@{ Ok = $false; Auth = $false; Message = (Get-FlgT '機器沒有回傳登入階段。' 'The copier did not return a login session.') } }
        $sid = $sm.Groups[1].Value
        $existingId = ''
        try {
            $search = New-Soap @"
    <u:searchObjects xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="$ns">
      <sessionId>$(XmlEscape $sid)</sessionId>
      <selectProps xsi:type="soap-enc:Array" soap-enc:arrayType="xs:string[]"><item>id</item></selectProps>
      <fromClass>entry</fromClass>
      <rowOffset>0</rowOffset>
      <rowCount>50</rowCount>
    </u:searchObjects>
"@
            $found = Send-FlgSoap 'searchObjects' $search
            $ids = New-Object System.Collections.Generic.List[string]
            foreach ($m in [regex]::Matches([string]$found, '<propName>id</propName>\s*<propVal>(\d+)</propVal>')) {
                $n = [int64]$m.Groups[1].Value
                if ($n -gt 0 -and $n -lt 100000) { [void]$ids.Add([string]$n) }
            }
            if ($ids.Count -gt 0) {
                $idXml = ($ids | ForEach-Object { '<item>entry:' + $_ + '</item>' }) -join ''
                $get = New-Soap @"
    <u:getObjectsProps xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="$ns">
      <sessionId>$(XmlEscape $sid)</sessionId>
      <objectIdList xsi:type="soap-enc:Array" soap-enc:arrayType="xs:string[]">$idXml</objectIdList>
      <selectProps xsi:type="soap-enc:Array" soap-enc:arrayType="xs:string[]"><item>id</item><item>index</item><item>name</item><item>remoteFolder:path</item></selectProps>
    </u:getObjectsProps>
"@
                $maps = @(Read-FlgEntryMaps (Send-FlgSoap 'getObjectsProps' $get))
                $hit = @($maps | Where-Object { [string]$_.Map['name'] -eq $entryName } | Select-Object -First 1)
                if ($hit.Count -gt 0) { $existingId = [string]$hit[0].Map['id'] }
            }
        } catch {
            Write-FlgSmbLog ('RICOH search skipped: ' + $_.Exception.Message)
        }
        if ($existingId) {
            $upd = New-Soap @"
    <u:putObjectProps xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="$ns">
      <sessionId>$(XmlEscape $sid)</sessionId>
      <objectId>entry:$(XmlEscape $existingId)</objectId>
      <propList xsi:type="soap-enc:Array" soap-enc:arrayType="ricoh:property[]">$props</propList>
    </u:putObjectProps>
"@
            [void](Send-FlgSoap 'putObjectProps' $upd)
            $wroteId = $existingId
            Write-FlgSmbLog ("RICOH updated entry id=$wroteId")
        } else {
            $add = New-Soap @"
    <u:putObjects xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="$ns">
      <sessionId>$(XmlEscape $sid)</sessionId>
      <objectClass>entry</objectClass>
      <propListList xsi:type="soap-enc:Array" soap-enc:arrayType="ricoh:propertyList[]"><item>$props</item></propListList>
    </u:putObjects>
"@
            $added = Send-FlgSoap 'putObjects' $add
            $im = [regex]::Match([string]$added, '<item>(\d+)</item>')
            if (-not $im.Success) { return [pscustomobject]@{ Ok = $false; Message = 'putObjects returned no id' } }
            $wroteId = $im.Groups[1].Value
            Write-FlgSmbLog ("RICOH added entry id=$wroteId")
        }
        $check = New-Soap @"
    <u:getObjectsProps xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="$ns">
      <sessionId>$(XmlEscape $sid)</sessionId>
      <objectIdList xsi:type="soap-enc:Array" soap-enc:arrayType="xs:string[]"><item>entry:$(XmlEscape $wroteId)</item></objectIdList>
      <selectProps xsi:type="soap-enc:Array" soap-enc:arrayType="xs:string[]"><item>id</item><item>index</item><item>name</item><item>longName</item><item>remoteFolder:type</item><item>remoteFolder:path</item><item>remoteFolder:port</item><item>remoteFolder:accountName</item></selectProps>
    </u:getObjectsProps>
"@
        $back = @(Read-FlgEntryMaps (Send-FlgSoap 'getObjectsProps' $check) | Select-Object -First 1)
        if ($back.Count -eq 0) { return [pscustomobject]@{ Ok = $false; Message = 'wrote the entry but could not read it back' } }
        $row = $back[0].Map
        $readPath = [string]$row['remoteFolder:path']
        $readName = [string]$row['name']
        $readUser = [string]$row['remoteFolder:accountName']
        $readPort = [string]$row['remoteFolder:port']
        Write-FlgSmbLog ("RICOH readback index=$($row['index']) name=$readName path=$readPath port=$readPort account=$readUser")
        if ($readPath -ne [string]$Path -or $readName -ne $entryName -or $readUser -ne [string]$User -or $readPort -ne '445') {
            return [pscustomobject]@{ Ok = $false; Index = [string]$row['index']; Id = $wroteId; Name = $readName; Path = $readPath; Account = $readUser; Message = "readback mismatch path=$readPath name=$readName account=$readUser port=$readPort" }
        }
        return [pscustomobject]@{ Ok = $true; Index = [string]$row['index']; Id = $wroteId; Name = $readName; Path = $readPath; Account = $readUser; Message = '' }
    } catch {
        $fault = [string]$_.Exception.Message
        $auth = $fault -match 'NOT_AUTHENTICATED'
        return [pscustomobject]@{ Ok = $false; Auth = [bool]$auth; Message = (ConvertTo-FlgRicohLoginMessage $fault) }
    } finally {
        if ($sid) {
            try {
                $end = New-Soap @"
    <u:terminateSession xmlns:u="$ns"><sessionId>$(XmlEscape $sid)</sessionId></u:terminateSession>
"@
                [void](Send-FlgSoap 'terminateSession' $end)
            } catch {
                Write-FlgSmbLog ('RICOH terminate failed: ' + $_.Exception.Message)
            }
        }
    }
}

# ---- SHARP (MX series) web UI address book: replay of sharpMX-M5070.har ----
# GET /addressbook_entry.html -> POST action=tab_06 (網路資料夾頁籤) -> POST action=addrbook_smbadd_btn -> POST action=submitbtn
# Every page carries a one-time token2, so each POST re-reads the whole form from the previous response (browser rules).
# Fields: ggt_textbox(11)=搜尋號碼 (N+1), (14)=位址名稱, (17)=起始字母, (178)=路徑, (179)=用戶, (180)=密碼 + ggt_checkbox(181)=變更密碼
function Invoke-FlgSharpHttp([string]$Method, [string]$Rel, [string]$Body = $null) {
    $url = $script:FlgSharpBase + $Rel
    $req = [Net.HttpWebRequest]::Create($url)
    $req.Method = $Method; $req.CookieContainer = $script:FlgSharpCookies
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) lanyen-smb'
    $req.Accept = 'text/html,*/*'; $req.KeepAlive = $false; $req.AllowAutoRedirect = $true
    $req.Timeout = 20000; $req.ReadWriteTimeout = 20000
    $req.Headers.Add('Accept-Language', 'zh-TW,zh;q=0.9')
    $req.ServicePoint.Expect100Continue = $false
    if ($Method -eq 'POST') {
        $bytes = [Text.Encoding]::ASCII.GetBytes($Body)
        $req.ContentType = 'application/x-www-form-urlencoded'; $req.Referer = $url; $req.Headers.Add('Origin', $script:FlgSharpBase)
        $req.ContentLength = $bytes.Length
        $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
    }
    try { $resp = $req.GetResponse() } catch [Net.WebException] { if ($_.Exception.Response) { $resp = $_.Exception.Response } else { throw } }
    $ms = New-Object IO.MemoryStream; $rs = $resp.GetResponseStream(); $rs.CopyTo($ms); $rs.Close()
    $raw = $ms.ToArray(); $ct = [string]$resp.ContentType; $code = [int]$resp.StatusCode; $final = $resp.ResponseUri.PathAndQuery; $resp.Close()
    $enc = [Text.Encoding]::UTF8
    if ($ct -match '(?i)charset\s*=\s*"?(big5|x-big5|cp950)') { $enc = [Text.Encoding]::GetEncoding(950) }
    $script:FlgSharpEnc = $enc
    $html = $enc.GetString($raw)
    Write-FlgSmbLog ("SHARP HTTP $Method $Rel -> $code len=" + $html.Length)
    if ($code -ge 400) { throw ("HTTP {0} {1}" -f $code, $Rel) }
    return [pscustomobject]@{ Html = $html; Url = $final }
}
function Get-FlgSharpAttrs([string]$tag) {
    $h = @{}
    $inner = $tag -replace '^<\w+', '' -replace '/?>$', ''
    foreach ($m in [regex]::Matches($inner, '(?is)([\w:\-\(\)]+)\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s>]+))')) {
        $v = $(if ($m.Groups[2].Success) { $m.Groups[2].Value } elseif ($m.Groups[3].Success) { $m.Groups[3].Value } else { $m.Groups[4].Value })
        $h[$m.Groups[1].Value.ToLower()] = [Net.WebUtility]::HtmlDecode($v)
    }
    $stripped = [regex]::Replace($inner, '(?s)"[^"]*"|''[^'']*''', '""')
    foreach ($b in 'checked', 'disabled', 'selected', 'multiple') { if ($stripped -match "(?i)(^|\s)$b(\s|=|$)" -and -not $h.ContainsKey($b)) { $h[$b] = '' } }
    return $h
}
function Get-FlgSharpForm([string]$html, [string]$formName) {
    $m = [regex]::Match($html, "(?is)<form\b[^>]*name\s*=\s*""$formName""[^>]*>(.*?)(</form>|$)")
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function Get-FlgSharpFields([string]$formHtml) {
    $list = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches($formHtml, '(?is)<input\b[^>]*>|<select\b[^>]*>.*?</select>|<textarea\b[^>]*>.*?</textarea>')) {
        $t = $m.Value
        $a = Get-FlgSharpAttrs ([regex]::Match($t, '(?is)^<\w+[^>]*>').Value)
        $name = $a['name']
        if (-not $name -or $a.ContainsKey('disabled')) { continue }
        if ($t -match '(?is)^<input') {
            $type = $(if ($a['type']) { $a['type'].ToLower() } else { 'text' })
            if ($type -in 'button', 'image', 'submit', 'reset', 'file') { continue }
            if ($type -in 'checkbox', 'radio') { if ($a.ContainsKey('checked')) { [void]$list.Add(@($name, $(if ($a.ContainsKey('value')) { $a['value'] } else { 'on' }))) }; continue }
            [void]$list.Add(@($name, $(if ($a.ContainsKey('value')) { $a['value'] } else { '' })))
        } elseif ($t -match '(?is)^<select') {
            $opts = @()
            foreach ($o in [regex]::Matches($t, '(?is)<option\b([^>]*)>(.*?)(?=<option\b|</select>)')) {
                $oa = Get-FlgSharpAttrs ('<option ' + $o.Groups[1].Value + '>')
                $val = $(if ($oa.ContainsKey('value')) { $oa['value'] } else { ([Net.WebUtility]::HtmlDecode(($o.Groups[2].Value -replace '<[^>]+>', ''))).Trim() })
                $opts += , @($val, $oa.ContainsKey('selected'))
            }
            $sel = @($opts | Where-Object { $_[1] })
            if ($a.ContainsKey('multiple')) { foreach ($s in $sel) { [void]$list.Add(@($name, $s[0])) } }
            elseif ($sel.Count -gt 0) { [void]$list.Add(@($name, $sel[-1][0])) }
            elseif ($opts.Count -gt 0) { [void]$list.Add(@($name, $opts[0][0])) }
        } else {
            [void]$list.Add(@($name, [Net.WebUtility]::HtmlDecode([regex]::Match($t, '(?is)^<textarea[^>]*>(.*?)</textarea>').Groups[1].Value)))
        }
    }
    return , $list
}
function Set-FlgSharpField($list, [string]$name, [string]$value) {
    for ($i = 0; $i -lt $list.Count; $i++) { if ($list[$i][0] -eq $name) { $list[$i] = @($name, $value); return } }
    [void]$list.Add(@($name, $value))
}
function Remove-FlgSharpField($list, [string]$name) { for ($i = $list.Count - 1; $i -ge 0; $i--) { if ($list[$i][0] -eq $name) { $list.RemoveAt($i) } } }
function Get-FlgSharpField($list, [string]$name) { foreach ($f in $list) { if ($f[0] -eq $name) { return $f[1] } }; return $null }
function ConvertTo-FlgSharpBody($list) {
    $enc = $script:FlgSharpEnc; if (-not $enc) { $enc = [Text.Encoding]::UTF8 }
    $parts = foreach ($f in $list) {
        $kv = foreach ($s in @($f[0], $f[1])) {
            $sb = New-Object Text.StringBuilder
            foreach ($b in $enc.GetBytes([string]$s)) {
                if (($b -ge 0x30 -and $b -le 0x39) -or ($b -ge 0x41 -and $b -le 0x5A) -or ($b -ge 0x61 -and $b -le 0x7A) -or $b -in 0x2D, 0x5F, 0x2E, 0x2A) { [void]$sb.Append([char]$b) }
                elseif ($b -eq 0x20) { [void]$sb.Append('+') } else { [void]$sb.Append(('%{0:X2}' -f $b)) }
            }
            $sb.ToString()
        }
        $kv[0] + '=' + $kv[1]
    }
    return ($parts -join '&')
}
function Get-FlgSharpMessage([string]$html) {
    $m = [regex]::Match($html, '(?is)<p\s+class="(\w*)"\s+id="err_msg"[^>]*>(.*?)</p>')
    if (-not $m.Success) { return $null }
    $txt = (([Net.WebUtility]::HtmlDecode(($m.Groups[2].Value -replace '<[^>]+>', ' '))).Trim() -replace '\s+', ' ').Trim('"', ' ')
    return [pscustomobject]@{ Ok = ($m.Groups[1].Value -eq 'ok'); Text = $txt }
}
function Invoke-FlgSharpLogin([string]$ReturnPage, [string]$AdminPass) {
    $r = Invoke-FlgSharpHttp GET ('/login.html?/' + $ReturnPage)
    $formHtml = $null
    foreach ($f in [regex]::Matches($r.Html, '(?is)<form\b[^>]*>(.*?)(</form>|$)')) { if ($f.Groups[1].Value -match '(?i)type\s*=\s*"?password') { $formHtml = $f.Groups[1].Value; break } }
    if (-not $formHtml) { return $false }
    $fields = Get-FlgSharpFields $formHtml
    foreach ($s in [regex]::Matches($formHtml, '(?is)<select\b[^>]*>.*?</select>')) {
        $sname = (Get-FlgSharpAttrs ([regex]::Match($s.Value, '(?is)^<select[^>]*>').Value))['name']
        foreach ($o in [regex]::Matches($s.Value, '(?is)<option\b([^>]*)>(.*?)(?=<option\b|</select>)')) {
            if ($o.Groups[2].Value -match '(?i)管理員|管理员|Admin') { Set-FlgSharpField $fields $sname ((Get-FlgSharpAttrs ('<option ' + $o.Groups[1].Value + '>'))['value']) }
        }
    }
    foreach ($i in [regex]::Matches($formHtml, '(?is)<input\b[^>]*>')) {
        $a = Get-FlgSharpAttrs $i.Value
        $type = $(if ($a['type']) { $a['type'].ToLower() } else { 'text' })
        if ($type -eq 'password') { Set-FlgSharpField $fields $a['name'] $AdminPass }
        elseif ($type -eq 'text' -and $a['name'] -and -not (Get-FlgSharpField $fields $a['name'])) { Set-FlgSharpField $fields $a['name'] 'admin' }
        elseif ($type -in 'button', 'submit' -and $a['value'] -match '(?i)登入|登录|Login|OK') {
            if ($null -ne (Get-FlgSharpField $fields 'action')) { Set-FlgSharpField $fields 'action' $a['name'] } else { Set-FlgSharpField $fields $a['name'] $a['value'] }
        }
    }
    if ($null -ne (Get-FlgSharpField $fields 'ordinate')) { Set-FlgSharpField $fields 'ordinate' '0' }
    $r2 = Invoke-FlgSharpHttp POST $r.Url (ConvertTo-FlgSharpBody $fields)
    $msg = Get-FlgSharpMessage $r2.Html
    $stillLogin = ($r2.Html -match '(?is)<input[^>]*type\s*=\s*"?password') -and -not (Get-FlgSharpForm $r2.Html 'adrbook') -and -not (Get-FlgSharpForm $r2.Html 'addressentry')
    $ok = -not $stillLogin -and -not ($msg -and -not $msg.Ok)
    Write-FlgSmbLog ("SHARP login ok=$ok")
    return $ok
}
function Get-FlgSharpPage([string]$Page, [string]$FormName, [string]$AdminPass) {
    $r = Invoke-FlgSharpHttp GET ('/' + $Page)
    if (-not (Get-FlgSharpForm $r.Html $FormName) -and -not $script:FlgSharpLoginTried) {
        $script:FlgSharpLoginTried = $true
        if ($AdminPass -and (Invoke-FlgSharpLogin $Page $AdminPass)) { $r = Invoke-FlgSharpHttp GET ('/' + $Page) }
    }
    if (-not (Get-FlgSharpForm $r.Html $FormName)) {
        if ($r.Html -match '(?is)type\s*=\s*"?password') { throw 'SHARP_LOGIN_REQUIRED' }
        throw ((Get-FlgT '讀不到 {0} 的表單（機型／韌體不同，或有人正在編輯通訊錄）。' 'Could not read the {0} form (different model/firmware, or the address book is being edited).') -f $Page)
    }
    return $r
}
function Get-FlgSharpRows([string]$html) {
    $rows = @()
    $tb = [regex]::Match($html, '(?is)<table[^>]*class="matrix"[^>]*>.*?<tbody>(.*?)</tbody>')
    if (-not $tb.Success) { return $rows }
    foreach ($tr in [regex]::Matches($tb.Groups[1].Value, '(?is)<tr\b[^>]*>(.*?)</tr>')) {
        $cells = @(foreach ($td in [regex]::Matches($tr.Groups[1].Value, '(?is)<td\b[^>]*>(.*?)</td>')) { (([Net.WebUtility]::HtmlDecode(($td.Groups[1].Value -replace '<[^>]+>', ' '))) -replace '[\s\u200e\u200f\u202a-\u202e]+', ' ').Trim() })
        if ($cells.Count -lt 2) { continue }
        for ($k = $cells.Count - 1; $k -ge 0; $k--) { if ($cells[$k] -match '^\d{1,4}$') { $rows += [pscustomobject]@{ No = [int]$cells[$k]; Name = $cells[0] }; break } }
    }
    return $rows
}
function Get-FlgSharpList([string]$AdminPass) {
    $r = Get-FlgSharpPage 'addressbook.html' 'adrbook' $AdminPass
    $html = $r.Html
    $tm = [regex]::Match($html, '(?is)(?:全部位址|All Addresses)[:：]?\s*</label>(?:\s|&nbsp;)*(\d+)')
    $total = $(if ($tm.Success) { [int]$tm.Groups[1].Value } else { -1 })
    if ($total -eq 0) { return [pscustomobject]@{ Total = 0; Rows = @(); Complete = $true } }
    $f = Get-FlgSharpFields (Get-FlgSharpForm $html 'adrbook')
    if ((Get-FlgSharpField $f 'ggt_select(9)') -ne '4') {
        Set-FlgSharpField $f 'ggt_select(9)' '4'; Set-FlgSharpField $f 'action' 'ggt_select(9)'; Set-FlgSharpField $f 'ordinate' '0'
        $html = (Invoke-FlgSharpHttp POST '/addressbook.html' (ConvertTo-FlgSharpBody $f)).Html
    }
    $all = @(Get-FlgSharpRows $html)
    $guard = 0
    while ($guard -lt 30 -and $html -match '(?is)<input\b(?=[^>]*name="nextbtn")(?![^>]*disabled)[^>]*>') {
        $guard++
        $f = Get-FlgSharpFields (Get-FlgSharpForm $html 'adrbook')
        Set-FlgSharpField $f 'action' 'nextbtn'; Set-FlgSharpField $f 'ordinate' '0'
        $html = (Invoke-FlgSharpHttp POST '/addressbook.html' (ConvertTo-FlgSharpBody $f)).Html
        $all += @(Get-FlgSharpRows $html)
    }
    $uniq = @($all | Sort-Object No -Unique)
    return [pscustomobject]@{ Total = $total; Rows = $uniq; Complete = ($total -lt 0 -or $uniq.Count -ge $total) }
}
function Add-FlgSharpSmbEntry {
    # Returns Ok / Auth (needs admin password) / Index (搜尋號碼) / Message. AdminPass '' = try without login first.
    param([string]$CopierIp, [string]$Name, [string]$Initial = 'A', [string]$Path, [string]$User, [string]$Pass, [string]$AdminPass = 'admin')
    $script:FlgSharpBase = 'http://' + $CopierIp
    $script:FlgSharpCookies = New-Object Net.CookieContainer
    $script:FlgSharpEnc = [Text.Encoding]::UTF8
    $script:FlgSharpLoginTried = $false
    try {
        $list = Get-FlgSharpList $AdminPass
        $hit = @($list.Rows | Where-Object { $_.Name -eq $Name })
        if ($hit.Count -gt 0) {
            Write-FlgSmbLog ("SHARP name exists no=$($hit[0].No)")
            return [pscustomobject]@{ Ok = $true; Auth = $false; Index = [string]$hit[0].No; Existed = $true; Message = (Get-FlgT '同名位址已存在，未重複新增。' 'An entry with this name already exists; not added again.') }
        }
        $no = ''
        if ($list.Complete) {
            $nums = @($list.Rows | ForEach-Object { $_.No })
            if ($nums.Count -eq 0) { $no = '1' }
            else {
                $max = [int](($nums | Measure-Object -Maximum).Maximum)
                if ($max -lt 2000) { $no = [string]($max + 1) } else { for ($n = 1; $n -le 2000; $n++) { if ($nums -notcontains $n) { $no = [string]$n; break } } }
            }
        }
        Write-FlgSmbLog ("SHARP total=$($list.Total) parsed=$($list.Rows.Count) next=$no")
        # 1) new entry page -> 2) network folder tab
        $r = Get-FlgSharpPage 'addressbook_entry.html' 'addressentry' $AdminPass
        $f = Get-FlgSharpFields (Get-FlgSharpForm $r.Html 'addressentry')
        Set-FlgSharpField $f 'action' 'tab_06'; Set-FlgSharpField $f 'ordinate' '0'; Set-FlgSharpField $f 'ggt_select(7)' '1'
        Set-FlgSharpField $f 'ggt_textbox(11)' $no; Set-FlgSharpField $f 'ggt_textbox(14)' $Name; Set-FlgSharpField $f 'ggt_textbox(17)' $Initial
        Remove-FlgSharpField $f 'ggt_checkbox(24)'
        $r = Invoke-FlgSharpHttp POST '/addressbook_entry.html' (ConvertTo-FlgSharpBody $f)
        $m = Get-FlgSharpMessage $r.Html
        if (($m -and -not $m.Ok) -or -not (Get-FlgSharpForm $r.Html 'addressentry')) { throw ((Get-FlgT '切換網路資料夾頁籤失敗：' 'Switching to the network folder tab failed: ') + $(if ($m) { $m.Text } else { '' })) }
        # 3) 增加此位址
        $f = Get-FlgSharpFields (Get-FlgSharpForm $r.Html 'addressentry')
        Set-FlgSharpField $f 'action' 'addrbook_smbadd_btn'; Set-FlgSharpField $f 'ordinate' '0'
        Set-FlgSharpField $f 'ggt_textbox(11)' $no; Set-FlgSharpField $f 'ggt_textbox(14)' $Name; Set-FlgSharpField $f 'ggt_textbox(17)' $Initial
        Set-FlgSharpField $f 'ggt_select(177)' '0'; Set-FlgSharpField $f 'ggt_textbox(178)' $Path; Set-FlgSharpField $f 'ggt_textbox(179)' $User
        if ($Pass) { Set-FlgSharpField $f 'ggt_checkbox(181)' '1'; Set-FlgSharpField $f 'ggt_textbox(180)' $Pass } else { Remove-FlgSharpField $f 'ggt_checkbox(181)' }
        $r = Invoke-FlgSharpHttp POST '/addressbook_entry.html' (ConvertTo-FlgSharpBody $f)
        $m = Get-FlgSharpMessage $r.Html
        if ($m -and -not $m.Ok) { throw ((Get-FlgT '增加網路資料夾位址失敗：' 'Adding the network folder failed: ') + $m.Text) }
        $f = Get-FlgSharpFields (Get-FlgSharpForm $r.Html 'addressentry')
        $sel = Get-FlgSharpField $f 'ggt_select(177)'
        if (-not $sel -or $sel -eq '0') { throw (Get-FlgT '網路資料夾位址沒有加入（路徑或帳密被拒）。' 'The network folder was not added (path or credentials rejected).') }
        # 4) 發送
        Set-FlgSharpField $f 'action' 'submitbtn'; Set-FlgSharpField $f 'ordinate' '0'
        $r = Invoke-FlgSharpHttp POST '/addressbook_entry.html' (ConvertTo-FlgSharpBody $f)
        $m = Get-FlgSharpMessage $r.Html
        if (-not $m -or -not $m.Ok) { throw ((Get-FlgT '發送失敗：' 'Submit failed: ') + $(if ($m) { $m.Text } else { '(no message)' })) }
        $got = Get-FlgSharpField (Get-FlgSharpFields (Get-FlgSharpForm $r.Html 'addressentry')) 'ggt_textbox(11)'
        if ($got -match '^\d+$') { $no = $got }
        # 5) read back
        $after = Get-FlgSharpList $AdminPass
        $back = @($after.Rows | Where-Object { $_.Name -eq $Name })
        Write-FlgSmbLog ("SHARP submitted no=$no readback=" + ($back | Out-String).Trim())
        if ($back.Count -eq 0 -and $after.Complete) { return [pscustomobject]@{ Ok = $false; Auth = $false; Index = $no; Message = (Get-FlgT '已送出但通訊錄清單找不到這筆，請到機器網頁確認。' 'Submitted, but the entry is not in the address list; check the copier web page.') } }
        if ($back.Count -gt 0) { $no = [string]$back[0].No }
        return [pscustomobject]@{ Ok = $true; Auth = $false; Index = $no; Message = $m.Text }
    } catch {
        $msg = [string]$_.Exception.Message
        Write-FlgSmbLog ('SHARP error: ' + $msg)
        if ($msg -eq 'SHARP_LOGIN_REQUIRED') { return [pscustomobject]@{ Ok = $false; Auth = $true; Message = (Get-FlgT '影印機要求管理員登入，或管理員密碼錯誤。' 'The copier requires an admin login, or the admin password is wrong.') } }
        return [pscustomobject]@{ Ok = $false; Auth = $false; Message = $msg }
    }
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
    # Win11 24H2 預設要求 SMB 簽章，舊款 Ricoh 會連不上：改為不強制（仍支援簽章）
    try {
        Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $true -Force -ErrorAction Stop
        Write-Ok '已設定 SMB 簽章為「不強制」（相容舊款影印機）。'
    } catch {
        Write-WarnMsg ("設定 SMB 簽章失敗：" + $_.Exception.Message)
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
            New-LocalUser -Name $localUser -Password $secure -FullName 'lanyen 工具箱 Scan' -Description 'lanyen 工具箱 scan-to-folder' -PasswordNeverExpires -UserMayNotChangePassword:$false -ErrorAction Stop | Out-Null
            # ensure not in Administrators
            try { Remove-LocalGroupMember -Group 'Administrators' -Member $localUser -ErrorAction SilentlyContinue } catch {}
            Write-Ok ("已建立本機使用者：{0}" -f $localUser)
        }
        try { Set-LocalUser -Name $localUser -PasswordNeverExpires $true -ErrorAction SilentlyContinue } catch {}
        try { Enable-LocalUser -Name $localUser -ErrorAction SilentlyContinue } catch {}
        # 從登入畫面隱藏掃描帳號
        try {
            $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
            if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
            New-ItemProperty -Path $k -Name $localUser -Value 0 -PropertyType DWord -Force | Out-Null
        } catch {}
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

    New-SmbShare -Name $ShareName -Path $Folder -FullAccess $accessAccount -Description 'lanyen 工具箱 scan-to-folder' -ErrorAction Stop | Out-Null
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
Write-Host ('======== ' + (Get-FlgT 'lanyen 工具箱 快速建立 SMB 共用' 'lanyen Toolkit Quick SMB share') + ' ========') -ForegroundColor White
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

Write-Host (Get-FlgT '請選擇：' 'Choose:')
Write-Host '  [1] 建立／更新掃描共用'
Write-Host '  [2] 移除掃描共用（可選刪除使用者，保留檔案）'
Write-Host ('  [0] ' + (Get-FlgExitLabel))
Write-Host ''
$choice = (Read-Host (Get-FlgT '請輸入編號' 'Enter number')).Trim()
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
    $userToRemove = 'scanner'
    if ($un) {
        if ($un -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
        $userToRemove = $un
        $removeUser = $true
    } else {
        $ask = (Read-Host '要一併刪除本機使用者 scan 嗎？(Y/N，預設 N)').Trim()
        if ($ask -match '^(?i)y|yes|是$') { $removeUser = $true; $userToRemove = 'scanner' }
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
$hasD = $false
try { $hasD = [bool](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:' AND DriveType=3" -ErrorAction Stop) } catch { $hasD = Test-Path 'D:\' }
$defaultFolder = $(if ($hasD) { 'D:\scan' } else { 'C:\scan' })
$altFolder = $(if ($hasD) { 'C:\scan' } else { $null })
Write-Host ("預設資料夾：{0}" -f $defaultFolder) -ForegroundColor White
if ($altFolder) { Write-Host ("也可以用：{0}" -f $altFolder) -ForegroundColor DarkGray }
$prompt = $(if ($altFolder) { "直接 Enter 用 $defaultFolder；輸入 C 用 C:\scan；或貼上其他路徑" } else { "直接 Enter 用 $defaultFolder；或貼上其他路徑" })
$folderIn = (Read-Host $prompt).Trim()
if ($folderIn -eq '0') { Write-Info ('已' + (Get-FlgExitLabel) + '。'); return }
$folder = $defaultFolder
if ($altFolder -and $folderIn -match '^(?i)c$') { $folder = $altFolder }
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

$userName = 'scanner'
$password = 'scanner1234'
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

$copiers = @()
try { $copiers = @(Find-FlgCopiers) } catch { Write-WarnMsg ((Get-FlgT '掃描影印機失敗：' 'Copier scan failed: ') + $_.Exception.Message) }
$copier = $null
if ($copiers.Count -eq 1) { $copier = $copiers[0] }
elseif ($copiers.Count -gt 1) {
    Write-Host ''
    Write-Host (Get-FlgT '找到多台影印機：' 'Multiple copiers found:') -ForegroundColor White
    for ($i = 0; $i -lt $copiers.Count; $i++) { Write-Host ('  [{0}] {1}  {2}' -f ($i + 1), $copiers[$i].Ip, $copiers[$i].Model) }
    $pick = (Read-Host (Get-FlgT '選擇要設定的機器編號（Enter=1）' 'Pick the copier number (Enter=1)')).Trim()
    $pn = 1; if (-not [int]::TryParse($pick, [ref]$pn) -or $pn -lt 1 -or $pn -gt $copiers.Count) { $pn = 1 }
    $copier = $copiers[$pn - 1]
}
$userShown = $(if ($useCurrent) { [string]$result.AccessAccount } else { "$pc\$($result.UserName)" })

Write-Host ''
Write-Host ('======== ' + (Get-FlgT 'SMB 設定' 'SMB setup') + ' ========') -ForegroundColor Yellow
if ($copier) {
    Write-Host ((Get-FlgT '  抓到機器名稱：' '  Copier model: ') + $copier.Model) -ForegroundColor Green
    Write-Host ((Get-FlgT '  抓到機器 IP：  ' '  Copier IP:    ') + $copier.Ip) -ForegroundColor Green
} else {
    Write-Host (Get-FlgT '  抓到機器名稱：（未找到，請確認影印機已開機並開啟 SNMP）' '  Copier model: (not found; check the copier is on and SNMP is enabled)') -ForegroundColor DarkYellow
    Write-Host (Get-FlgT '  抓到機器 IP：  （未找到）' '  Copier IP:    (not found)') -ForegroundColor DarkYellow
}
$isFuji = ($copier -and ([string]$copier.Model -match '(?i)FUJI\s*XEROX|FUJIFILM|Apeos|DocuCentre'))
$isRicoh = ($copier -and -not $isFuji -and ([string]$copier.Model -match '(?i)RICOH'))
$isSharp = ($copier -and -not $isFuji -and -not $isRicoh -and ([string]$copier.Model -match '(?i)SHARP|\bMX-[A-Z0-9]'))
if (-not $useCurrent -and -not ($isFuji -or $isRicoh -or $isSharp)) {
    # 沒偵測到支援的廠牌：讓使用者手動選廠牌 + IP（自動偵測到 RICOH／FUJI／SHARP 時不會出現）
    Write-Host ''
    Write-Host (Get-FlgT '選擇影印機廠牌，自動登錄到通訊錄：' 'Pick the copier brand to add the address book entry:') -ForegroundColor White
    Write-Host '  [1] RICOH'
    Write-Host '  [2] SHARP'
    Write-Host '  [3] FUJIFILM／富士全錄'
    Write-Host ('  [Enter] ' + (Get-FlgT '略過' 'Skip'))
    $bp = (Read-Host (Get-FlgT '請輸入編號' 'Enter number')).Trim()
    if ($bp -in '1', '2', '3') {
        $defIp = $(if ($copier) { [string]$copier.Ip } else { '' })
        $mip = (Read-Host ((Get-FlgT '影印機 IP（Enter = {0}）' 'Copier IP (Enter = {0})') -f $defIp)).Trim()
        if (-not $mip) { $mip = $defIp }
        if ($mip) {
            $brandName = @{ '1' = 'RICOH'; '2' = 'SHARP'; '3' = 'FUJIFILM' }[$bp]
            $copier = [pscustomobject]@{ Ip = $mip; Model = ($brandName + (Get-FlgT '（手動選擇）' ' (manual)')) }
            $isRicoh = ($bp -eq '1'); $isSharp = ($bp -eq '2'); $isFuji = ($bp -eq '3')
            Write-FlgSmbLog ("manual brand=$brandName ip=$mip")
        }
    }
}
if ($isFuji -or $isRicoh -or $isSharp) {
    if (($isRicoh -or $isSharp) -and -not $useCurrent) { $userShown = [string]$result.UserName }
    Write-Host ''
    Write-Host (Get-FlgT '登錄資訊' 'Login info') -ForegroundColor White
    Write-Host ((Get-FlgT '  主機名稱  {0}（設定的電腦主機名稱）' '  Host name  {0} (this PC host name)') -f $pc) -ForegroundColor Green
    Write-Host ((Get-FlgT '  共用名稱  {0}（設定固定資料夾名稱）' '  Share name {0} (fixed shared folder name)') -f $result.ShareName) -ForegroundColor Green
    Write-Host ((Get-FlgT '  使用者名稱 {0}（電腦主機\設定的登錄使用者）' '  User name  {0} (PC host\login user)') -f $userShown) -ForegroundColor Green
    Write-Host ((Get-FlgT '  密碼      {0}（預設使用者登錄密碼）' '  Password   {0} (default login password)') -f $result.Password) -ForegroundColor Green
    Write-Host ((Get-FlgT '  本機資料夾 {0}' '  Local folder {0}') -f $result.Folder) -ForegroundColor DarkGray
} elseif ($copier) {
    Write-Host ''
    Write-Host (Get-FlgT '  此廠牌的掃描登錄資訊暫不支援（目前只支援 FUJIFILM／富士全錄、RICOH、SHARP）。' '  Scan login info for this brand is not supported yet (FUJIFILM / Fuji Xerox, RICOH and SHARP only for now).') -ForegroundColor DarkYellow
} else {
    Write-Host ''
    Write-Host (Get-FlgT '  未偵測到 FUJIFILM／富士全錄、RICOH 或 SHARP 機器，略過登錄資訊。' '  No FUJIFILM / Fuji Xerox, RICOH or SHARP copier detected; login info skipped.') -ForegroundColor DarkYellow
}
try {
if ($isFuji -and -not $useCurrent) {
    Write-Host ''
    $abName = (Read-Host ((Get-FlgT '通訊錄名稱（Enter = {0}）' 'Address book name (Enter = {0})') -f $pc)).Trim()
    if (-not $abName) { $abName = $pc }
    if ($true) {
        $abUser = "$pc\$($result.UserName)"
        Write-Info ((Get-FlgT '登錄到 {0} 通訊錄…' 'Adding to {0} address book…') -f $copier.Ip)
        $ab = Add-FlgFujiSmbContact -CopierIp $copier.Ip -DisplayName $abName -Server $pc -Share $result.ShareName -User $abUser -Pass $result.Password
        if (-not $ab.Ok -and ($ab.Code -eq 401 -or $ab.Code -eq 403 -or $ab.Message -match '(?i)auth|permission|denied')) {
            Write-WarnMsg (Get-FlgT '影印機要求管理員登入。' 'The copier requires an admin login.')
            $au = (Read-Host (Get-FlgT '管理員帳號（預設 11111）' 'Admin user (default 11111)')).Trim(); if (-not $au) { $au = '11111' }
            $ap = Read-Host (Get-FlgT '管理員密碼（預設 x-admin）' 'Admin password (default x-admin)'); if (-not $ap) { $ap = 'x-admin' }
            $cred = New-Object pscredential ($au, (ConvertTo-SecureString $ap -AsPlainText -Force))
            $ab = Add-FlgFujiSmbContact -CopierIp $copier.Ip -DisplayName $abName -Server $pc -Share $result.ShareName -User $abUser -Pass $result.Password -Credential $cred
        }
        if ($ab.Ok) {
            Write-Ok ((Get-FlgT '已登錄到影印機通訊錄：{0}（伺服器 {1}，共用 {2}，使用者 {3}）' 'Added to copier address book: {0} (server {1}, share {2}, user {3})') -f $abName, $pc, $result.ShareName, $abUser)
        } else {
            Write-ErrMsg ((Get-FlgT '自動登錄失敗：' 'Automatic add failed: ') + $ab.Message)
            Write-Host ((Get-FlgT '  請開啟 http://{0}/ → 通訊錄 → 新增，手動輸入上面的登錄資訊。' '  Open http://{0}/ → Address Book → Add, and enter the login info above manually.') -f $copier.Ip) -ForegroundColor Yellow
        }
    }
}
} catch {
    Write-FlgSmbLog ('FUJI address book error: ' + ($_ | Out-String) + $_.ScriptStackTrace)
    Write-ErrMsg ((Get-FlgT '自動登錄發生錯誤：' 'Automatic add error: ') + $_.Exception.Message)
    if ($copier) { Write-Host ((Get-FlgT '  請開啟 http://{0}/ 手動輸入上面的登錄資訊。記錄檔：{1}' '  Open http://{0}/ and enter the login info above manually. Log: {1}') -f $copier.Ip, $script:FlgSmbLog) -ForegroundColor Yellow }
}
try {
if ($isRicoh -and -not $useCurrent) {
    Write-Host ''
    $abName = (Read-Host ((Get-FlgT '名稱（Enter = {0}）' 'Name (Enter = {0})') -f '掃描')).Trim()
    if (-not $abName) { $abName = '掃描' }   # 名稱 = 按鍵名稱
    $abUser = [string]$result.UserName   # both Ricoh recordings use the bare user name (scanner)
    $abHost = $pc   # user rule: \\<PC hostname>\<share name>
    $abPath = "\\$abHost\$($result.ShareName)"
    Write-Info ((Get-FlgT '登錄到 {0} 通訊錄…' 'Adding to {0} address book…') -f $copier.Ip)
    $ab = Add-FlgRicohSmbEntry -CopierIp $copier.Ip -Name $abName -Path $abPath -User $abUser -Pass $result.Password
    if (-not $ab.Ok -and $ab.Auth) {
        Write-WarnMsg $ab.Message
        Write-WarnMsg (Get-FlgT '請輸入影印機 admin 密碼（Enter = 略過）。' 'Enter the copier admin password (Enter = skip).')
        $ap = Read-Host (Get-FlgT 'admin 密碼' 'Admin password')
        if ($ap) { $ab = Add-FlgRicohSmbEntry -CopierIp $copier.Ip -Name $abName -Path $abPath -User $abUser -Pass $result.Password -AdminPass $ap }
    }
    Write-FlgSmbLog ('RICOH result: ' + ($ab | Out-String))
    if ($ab.Ok) {
        Write-Ok ((Get-FlgT '已登錄到影印機通訊錄：{0}（編號 {1}，路徑 {2}，使用者 {3}）' 'Added to copier address book: {0} (no. {1}, path {2}, user {3})') -f $abName, $ab.Index, $abPath, $abUser)
    } else {
        Write-ErrMsg ((Get-FlgT '自動登錄失敗：' 'Automatic add failed: ') + $ab.Message)
        Write-Host ((Get-FlgT '  請開啟 http://{0}/ → 登入 admin → 通訊錄 → 新增使用者 → 資料夾（SMB），手動輸入上面的登錄資訊。' '  Open http://{0}/ → log in as admin → Address Book → Add User → Folder (SMB), and enter the login info above manually.') -f $copier.Ip) -ForegroundColor Yellow
    }
}
} catch {
    Write-FlgSmbLog ('RICOH address book error: ' + ($_ | Out-String) + $_.ScriptStackTrace)
    Write-ErrMsg ((Get-FlgT '自動登錄發生錯誤：' 'Automatic add error: ') + $_.Exception.Message)
    if ($copier) { Write-Host ((Get-FlgT '  請開啟 http://{0}/ 手動輸入上面的登錄資訊。記錄檔：{1}' '  Open http://{0}/ and enter the login info above manually. Log: {1}') -f $copier.Ip, $script:FlgSmbLog) -ForegroundColor Yellow }
}
try {
if ($isSharp -and -not $useCurrent) {
    Write-Host ''
    $abName = (Read-Host ((Get-FlgT '位址名稱（Enter = {0}）' 'Address name (Enter = {0})') -f $pc)).Trim()
    if (-not $abName) { $abName = $pc }
    if ($abName.Length -gt 36) { $abName = $abName.Substring(0, 36) }
    $abInit = (Read-Host (Get-FlgT '起始字母（Enter = A）' 'Initial (Enter = A)')).Trim()
    if (-not $abInit) { $abInit = 'A' }
    $abUser = [string]$result.UserName   # HAR: 用戶名稱 = scanner (bare user name)
    $abPath = "\\$pc\$($result.ShareName)"
    Write-Info ((Get-FlgT '登錄到 {0} 通訊錄（SHARP 網路資料夾）…' 'Adding to {0} address book (SHARP network folder)…') -f $copier.Ip)
    $ab = Add-FlgSharpSmbEntry -CopierIp $copier.Ip -Name $abName -Initial $abInit -Path $abPath -User $abUser -Pass $result.Password -AdminPass 'admin'
    if (-not $ab.Ok -and $ab.Auth) {
        Write-WarnMsg $ab.Message
        Write-WarnMsg (Get-FlgT '請輸入影印機管理員密碼（Enter = 略過）。' 'Enter the copier admin password (Enter = skip).')
        $ap = Read-Host (Get-FlgT '管理員密碼' 'Admin password')
        if ($ap) { $ab = Add-FlgSharpSmbEntry -CopierIp $copier.Ip -Name $abName -Initial $abInit -Path $abPath -User $abUser -Pass $result.Password -AdminPass $ap }
    }
    Write-FlgSmbLog ('SHARP result: ' + ($ab | Out-String))
    if ($ab.Ok) {
        Write-Ok ((Get-FlgT '已登錄到影印機通訊錄：{0}（搜尋號碼 {1}，路徑 {2}，使用者 {3}）{4}' 'Added to copier address book: {0} (no. {1}, path {2}, user {3}) {4}') -f $abName, $ab.Index, $abPath, $abUser, $(if ($ab.Existed) { $ab.Message } else { '' }))
    } else {
        Write-ErrMsg ((Get-FlgT '自動登錄失敗：' 'Automatic add failed: ') + $ab.Message)
        Write-Host ((Get-FlgT '  請開啟 http://{0}/ → 位址目錄 → 增加 → 網路資料夾，手動輸入上面的登錄資訊。' '  Open http://{0}/ → Address Book → Add → Network Folder, and enter the login info above manually.') -f $copier.Ip) -ForegroundColor Yellow
    }
}
} catch {
    Write-FlgSmbLog ('SHARP address book error: ' + ($_ | Out-String) + $_.ScriptStackTrace)
    Write-ErrMsg ((Get-FlgT '自動登錄發生錯誤：' 'Automatic add error: ') + $_.Exception.Message)
    if ($copier) { Write-Host ((Get-FlgT '  請開啟 http://{0}/ 手動輸入上面的登錄資訊。記錄檔：{1}' '  Open http://{0}/ and enter the login info above manually. Log: {1}') -f $copier.Ip, $script:FlgSmbLog) -ForegroundColor Yellow }
}
foreach ($ip in $ips) { Write-Host ((Get-FlgT '  路徑（IP） \\{0}\{1}' '  Path (IP)  \\{0}\{1}') -f $ip, $result.ShareName) -ForegroundColor DarkGray }

Write-Host ''
Write-Host '各品牌提示：' -ForegroundColor Cyan
Write-Host '  Ricoh：掃描到資料夾 → SMB／FTP 選 SMB；路徑 \\IP\scan 或 /scan；填網域可留空或填電腦名。'
Write-Host '  Sharp：位址目錄 → 增加 → 網路資料夾；路徑 \\電腦名稱\scan；用戶名稱 scanner（本工具可自動登錄）。'
Write-Host '  FUJIFILM／全錄：SMB 傳輸；共用名稱 scan；使用者 PC名\scan。'
Write-Host '  Canon：檔案傳送 → Windows (SMB)；主機名稱填 IP；資料夾路徑 \scan。'
Write-Host '  美樂達／KM：SMB；Host=IP；File Path=\scan；User=PC名\scan。'
Write-Host '  若連不上：確認影印機與電腦同一網段、網路設為私人、防火牆已放行。'
Write-Host ''
Write-Ok '完成。可用檔案總管測試：\\localhost\scan'
Write-FlgSmbLog 'smb-main finished'
try { [void](Read-Host (Get-FlgT '按 Enter 結束' 'Press Enter to exit')) } catch {}
