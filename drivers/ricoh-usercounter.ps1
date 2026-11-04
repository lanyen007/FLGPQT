#Requires -Version 5.1
param(
    [string]$OutDir = "",
    [string]$User   = "admin",
    [string]$Pass   = "",
    [string]$Lang   = "tw",
    [string[]]$Ip   = @(),
    [switch]$Interactive
)
$ErrorActionPreference = "Continue"
if (-not $Interactive -and $PSBoundParameters.Count -eq 0) { $Interactive = $true }
$Printers = @("192.168.1.200")
$TimeoutMs = 25000
if (-not $OutDir) {
    $root = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = Join-Path $env:USERPROFILE "Downloads\FLG-UserCounter"
    }
    $d = Get-Date
    $roc = "{0}年{1:00}月{2:00}日" -f ($d.Year - 1911), $d.Month, $d.Day
    $OutDir = Join-Path $root $roc
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
function Get-PrinterList($items) {
    $list = @()
    $seen = @{}
    foreach ($raw in @($items)) {
        $line = [string]$raw
        if ($line.Trim().StartsWith("#")) { continue }
        foreach ($part in ($line -split '[,\s;]+')) {
            $h = $part.Trim()
            if (-not $h -or $h.StartsWith("#")) { continue }
            $h = $h -replace '^https?://', ''
            $h = ($h -split '/')[0].Trim()
            if (-not $h) { continue }
            if ($seen.ContainsKey($h)) { continue }
            $seen[$h] = $true
            $list += $h
        }
    }
    return ,$list
}
$listFile = ""
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $listFile = Join-Path $PSScriptRoot "printers.txt"
}
if ($listFile -and (Test-Path $listFile)) {
    $fromFile = Get-Content $listFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    if ($fromFile) { $Printers = $fromFile }
}
if ($Ip.Count -gt 0) { $Printers = @(Get-PrinterList $Ip) }

if (-not ("RicohLanCert" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class RicohLanCert {
    public static void Install() {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        ServicePointManager.Expect100Continue = false;
        ServicePointManager.ServerCertificateValidationCallback = new RemoteCertificateValidationCallback(Accept);
    }
    public static bool Accept(object sender, X509Certificate cert, X509Chain chain, SslPolicyErrors errors) {
        if (errors == SslPolicyErrors.None) return true;
        var req = sender as HttpWebRequest;
        string host = (req != null && req.RequestUri != null) ? req.RequestUri.Host : "";
        IPAddress ip;
        if (!IPAddress.TryParse(host, out ip)) return false;
        byte[] b = ip.GetAddressBytes();
        if (b.Length != 4) return false;
        if (b[0] == 10 || b[0] == 127) return true;
        if (b[0] == 192 && b[1] == 168) return true;
        if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
        return false;
    }
}
"@
}
[RicohLanCert]::Install()

$log = Join-Path $OutDir "download.log"
function Write-Log([string]$msg) {
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $msg
    Write-Host $line
    Add-Content -Path $log -Value $line -Encoding UTF8
}
function Save-Text($name, $text) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText((Join-Path $OutDir $name), [string]$text, $enc)
}
function Get-SafeName([string]$name) {
    if (-not $name) { return "" }
    $safe = $name -replace "[\x00-\x1F]", ""
    foreach ($c in [IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace([string]$c, "_") }
    $safe = $safe.Trim().Trim(".")
    if ($safe.Length -gt 80) { $safe = $safe.Substring(0, 80).Trim().Trim(".") }
    return $safe
}
function Get-SnmpLocation([string]$ip) {
    $snmp = $null
    try {
        $snmp = New-Object -ComObject OlePrn.OleSNMP
        $snmp.Open($ip, "public", 2, 3000)
        foreach ($oid in @(".1.3.6.1.2.1.1.6.0", ".1.3.6.1.4.1.367.3.2.1.1.1.4.0")) {
            try {
                $v = ([string]$snmp.Get($oid)) -replace "[\x00]", ""
                $v = $v.Trim()
                if ($v -and $v -notmatch '^(?i)no such') { return $v }
            } catch {}
        }
    } catch {
        Write-Log ("snmp " + $_.Exception.Message)
    } finally {
        if ($snmp) { try { $snmp.Close() } catch {} }
    }
    return ""
}

$script:Jar = @{}
function Reset-Jar {
    $script:Jar = @{ cookieOnOffChecker = "on"; cookieOnOffChecker1 = "on" }
}
function Update-Jar([string]$header) {
    if (-not $header) { return }
    foreach ($p in [regex]::Split($header, ',(?=\s*[A-Za-z0-9_\-]+=)')) {
        $nv = ($p -split ';')[0].Trim()
        $i = $nv.IndexOf("=")
        if ($i -lt 1) { continue }
        $name = $nv.Substring(0, $i).Trim()
        $val = $nv.Substring($i + 1).Trim()
        if ($val -eq "" -or $val -eq "--") { [void]$script:Jar.Remove($name) }
        else { $script:Jar[$name] = $val }
    }
}
function Get-CookieHeader {
    ($script:Jar.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join "; "
}
function Convert-ToBase64Url([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return "" }
    return [uri]::EscapeDataString([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)))
}
function Join-Form($map, $order) {
    $used = @{}
    $pairs = @()
    foreach ($k in $order) {
        $val = ""
        if ($map.Contains($k)) { $val = [string]$map[$k] }
        $pairs += ([uri]::EscapeDataString([string]$k) + "=" + [uri]::EscapeDataString($val))
        $used[$k] = $true
    }
    foreach ($k in @($map.Keys)) {
        if ($used.Contains($k)) { continue }
        $pairs += ([uri]::EscapeDataString([string]$k) + "=" + [uri]::EscapeDataString([string]$map[$k]))
    }
    return ($pairs -join "&")
}
function Get-MainForm([string]$html) {
    $map = @{}
    $m = [regex]::Match($html, '<form name="mainForm"[^>]*>(.*)</form>', 'Singleline')
    if (-not $m.Success) { return $map }
    $block = $m.Groups[1].Value
    foreach ($tag in [regex]::Matches($block, '<input\b[^>]*>')) {
        $t = $tag.Value
        if ($t -match 'type\s*=\s*["'']?(button|submit|image)') { continue }
        $n = [regex]::Match($t, 'name\s*=\s*["'']([^"'']+)["'']')
        if (-not $n.Success) { continue }
        $v = [regex]::Match($t, 'value\s*=\s*["'']([^"'']*)["'']')
        $map[$n.Groups[1].Value] = $(if ($v.Success) { $v.Groups[1].Value } else { "" })
    }
    $count = "10"
    $sel = [regex]::Match($block, '<select\b[^>]*name\s*=\s*["'']count["''][^>]*>(.*?)</select>', 'Singleline')
    if ($sel.Success) {
        $opt = [regex]::Match($sel.Groups[1].Value, '<option[^>]*selected[^>]*value\s*=\s*["'']([^"'']+)["'']')
        if (-not $opt.Success) {
            $opt = [regex]::Match($sel.Groups[1].Value, '<option[^>]*value\s*=\s*["'']([^"'']+)["''][^>]*selected')
        }
        if ($opt.Success) { $count = $opt.Groups[1].Value }
    }
    if (-not $map.Contains("userCounterListPage")) { $map["userCounterListPage"] = "" }
    if (-not $map.Contains("count")) { $map["count"] = $count }
    return $map
}
function Invoke-Once {
    param([string]$Url, [string]$Method = "GET", [string]$Body, [string]$Referer)
    $req = [Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.AllowAutoRedirect = $false
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs
    $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
    $req.Accept = "*/*"
    $req.Headers["Cookie"] = (Get-CookieHeader)
    if ($Referer) { $req.Referer = $Referer }
    if ($Body -and $Method -ne "GET") {
        $bytes = [Text.Encoding]::ASCII.GetBytes($Body)
        $req.ContentType = "application/x-www-form-urlencoded"
        $req.ContentLength = $bytes.Length
        $s = $req.GetRequestStream()
        $s.Write($bytes, 0, $bytes.Length)
        $s.Close()
    }
    try { $resp = $req.GetResponse() }
    catch [Net.WebException] {
        if ($_.Exception.Response) { $resp = $_.Exception.Response }
        else { throw }
    }
    $vals = $resp.Headers.GetValues("Set-Cookie")
    if ($vals) { foreach ($one in $vals) { Update-Jar $one } }
    $status = [int]$resp.StatusCode
    $loc = [string]$resp.Headers["Location"]
    $ct = [string]$resp.ContentType
    $cd = [string]$resp.Headers["Content-Disposition"]
    $ms = New-Object IO.MemoryStream
    $stream = $resp.GetResponseStream()
    if ($stream) { $stream.CopyTo($ms) }
    $resp.Close()
    $raw = $ms.ToArray()
    return @{
        Url = $Url; Status = $status; Location = $loc; Ct = $ct; Cd = $cd
        Bytes = $raw; Text = [Text.Encoding]::UTF8.GetString($raw)
    }
}
function Invoke-Ricoh {
    param([string]$Url, [string]$Method = "GET", [string]$Body, [string]$Referer)
    $r = Invoke-Once -Url $Url -Method $Method -Body $Body -Referer $Referer
    if ($Url -like "http://*" -and @(301, 302, 307, 308) -contains $r.Status) {
        $httpsUrl = "https://" + $Url.Substring(7)
        $ref = $Referer
        if ($ref -like "http://*") { $ref = "https://" + $ref.Substring(7) }
        $r = Invoke-Once -Url $httpsUrl -Method $Method -Body $Body -Referer $ref
    }
    return $r
}
function Get-AbsoluteUrl([string]$baseUrl, [string]$location) {
    if (-not $location) { return "" }
    if ($location -match '^https?://') { return $location }
    $u = [Uri]$baseUrl
    if ($location.StartsWith("/")) { return ($u.Scheme + "://" + $u.Authority + $location) }
    $dir = $baseUrl.Substring(0, $baseUrl.LastIndexOf("/") + 1)
    return ($dir + $location)
}

if ($Interactive) {
    try {
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $OutputEncoding = [Text.Encoding]::UTF8
    } catch {}
    Write-Host ""
    Write-Host "使用者計數批次下載"
    Write-Host "登入方式：先走 HTTP，若回 301/302/307/308，再用相同路徑改走 HTTPS。"
    Write-Host ""
    $inUser = Read-Host "帳號（直接按 Enter 代表 admin）"
    if ($inUser -and $inUser.Trim()) { $User = $inUser.Trim() }
    Write-Host "這台 192.168.1.200 的密碼是空白。別台機器要改密碼時，在這裡輸入。"
    $sec = Read-Host "密碼（直接按 Enter 代表空白）" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $Pass = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $inLang = Read-Host "語系（直接按 Enter 代表 tw）"
    if ($inLang -and $inLang.Trim()) { $Lang = $inLang.Trim() }
    Write-Host ""
    Write-Host "IP：一行一台，可以一次貼上多行，再按一次 Enter 結束。"
    Write-Host "不輸入就用預設的 192.168.1.200。"
    $typed = @()
    while ($true) {
        $line = Read-Host
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $typed += $line
    }
    $typedList = Get-PrinterList $typed
    if ($typedList.Count -gt 0) { $Printers = @($typedList) }
    Write-Host ""
    Write-Host ("帳號：{0}" -f $User)
    if ([string]::IsNullOrEmpty($Pass)) { Write-Host "密碼：空白" } else { Write-Host "密碼：已輸入" }
    Write-Host ("語系：{0}" -f $Lang)
    Write-Host ("IP 共 {0} 台：" -f @($Printers).Count)
    foreach ($one in @($Printers)) { Write-Host ("  {0}" -f $one) }
    Write-Host ""
}

Write-Log "OutDir=$OutDir User=$User Lang=$Lang Printers=$(@($Printers).Count)"
$ok = 0
$fail = 0
$usedNames = @{}
foreach ($ip in $Printers) {
    Reset-Jar
    $safeIp = ($ip -replace '[^\w\.-]', '_')
    $place = Get-SnmpLocation $ip
    if ($place) { Write-Log ("snmp location={0}" -f $place) } else { Write-Log "snmp location empty" }
    Write-Log "---- $ip ----"
    $loggedIn = $false
    $schemeHost = "http://$ip"
    try {
        $authPath = "/web/guest/$Lang/websys/webArch/authForm.cgi"
        $auth = Invoke-Ricoh -Url "$schemeHost$authPath"
        if ($auth.Url -like "https://*") {
            $schemeHost = "https://$ip"
            Write-Log "stage2 https same-path"
        } else {
            Write-Log "stage1 http"
        }
        $token = [regex]::Match($auth.Text, 'name="wimToken"[^>]*value="([^"]*)"').Groups[1].Value
        Write-Log ("auth status={0} tokenLen={1} session={2}" -f $auth.Status, $token.Length, $script:Jar.ContainsKey("risessionid"))
        if (-not $token) {
            Save-Text "debug_auth_$safeIp.html" $auth.Text
            Write-Log "FAIL auth form"
            $fail++
            continue
        }
        $uid = Convert-ToBase64Url $User
        $pwd = Convert-ToBase64Url $Pass
        $loginBody = "wimToken=$([uri]::EscapeDataString($token))&userid_work=&userid=$uid&password_work=&password=$pwd&open="
        $loginUrl = "$schemeHost/web/guest/$Lang/websys/webArch/login.cgi"
        $login = Invoke-Once -Url $loginUrl -Method "POST" -Body $loginBody -Referer $auth.Url
        $failMsg = [regex]::Match($login.Text, "showMessage\('([^']*)'\)")
        Write-Log ("login status={0} loc={1} msg={2}" -f $login.Status, $login.Location, $(if ($failMsg.Success) { $failMsg.Groups[1].Value } else { "-" }))
        $loggedIn = ($login.Status -eq 302 -and $login.Location -match "mainFrame\.cgi")
        if (-not $loggedIn) {
            Save-Text "debug_login_$safeIp.html" $login.Text
            Write-Log "FAIL login"
            $fail++
            continue
        }
        $next = Get-AbsoluteUrl $login.Url $login.Location
        if ($next) { Invoke-Once -Url $next -Referer $login.Url | Out-Null }

        $listUrl = "$schemeHost/web/entry/$Lang/websys/status/getUserCounter.cgi"
        $list = Invoke-Once -Url $listUrl -Referer ($schemeHost + "/web/entry/$Lang/websys/webArch/topPage.cgi")
        Write-Log ("list status={0} len={1}" -f $list.Status, $list.Bytes.Length)
        $fields = Get-MainForm $list.Text
        if (-not $fields.Contains("wimToken")) {
            Save-Text "debug_getUserCounter_$safeIp.html" $list.Text
            Write-Log "FAIL counter page"
            $fail++
            continue
        }
        $dlBody = Join-Form $fields @("wimToken", "accessConf", "offset", "userCounterListPage", "count")
        $dlUrl = "$schemeHost/web/entry/$Lang/websys/status/downloadUserCounter.cgi"
        $dl = Invoke-Once -Url $dlUrl -Method "POST" -Body $dlBody -Referer $listUrl
        $isCsv = ($dl.Cd -match "csv") -or ($dl.Ct -match "csv") -or ($dl.Text.StartsWith([string][char]0xFEFF + "使用者,")) -or ($dl.Text.StartsWith("使用者,"))
        if (-not $isCsv) {
            Save-Text "debug_download_$safeIp.html" $dl.Text
            Write-Log ("FAIL download status={0} ct={1} len={2}" -f $dl.Status, $dl.Ct, $dl.Bytes.Length)
            $fail++
            continue
        }
        $label = Get-SafeName $place
        if (-not $label) { $label = $safeIp }
        $fname = "$label.csv"
        if ($usedNames.ContainsKey($fname.ToLowerInvariant())) {
            $fname = "{0}_{1}.csv" -f $label, $safeIp
        }
        $out = Join-Path $OutDir $fname
        if (Test-Path -LiteralPath $out) {
            $base = [IO.Path]::GetFileNameWithoutExtension($fname)
            $fname = "{0}_{1:HHmmss}.csv" -f $base, (Get-Date)
            $out = Join-Path $OutDir $fname
        }
        $usedNames[$fname.ToLowerInvariant()] = $true
        [IO.File]::WriteAllBytes($out, $dl.Bytes)
        Write-Log ("OK {0} {1}" -f $out, (Get-Item $out).Length)
        $ok++
    } catch {
        Write-Log ("FAIL " + $_.Exception.Message)
        $fail++
    } finally {
        if ($loggedIn) {
            try {
                Invoke-Once -Url "$schemeHost/web/entry/$Lang/websys/webArch/logout.cgi" -Referer "$schemeHost/web/entry/$Lang/websys/webArch/header.cgi" | Out-Null
                Write-Log "logout"
            } catch {
                Write-Log ("logout " + $_.Exception.Message)
            }
        }
    }
}
Write-Log "done OK=$ok FAIL=$fail"
if ($Interactive) {
    Write-Host ""
    Write-Host ("完成。成功 {0} 台，失敗 {1} 台。" -f $ok, $fail)
    Write-Host ("檔案在：{0}" -f $OutDir)
    try { Start-Process explorer.exe $OutDir } catch {}
    Read-Host "按 Enter 結束"
}
if ($env:FLG_FROM_MENU -eq "1" -or $MyInvocation.ScriptName) { return }
exit $(if ($fail -gt 0) { 1 } else { 0 })
