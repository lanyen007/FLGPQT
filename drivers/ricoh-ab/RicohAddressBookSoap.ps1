# Ricoh 通訊錄 SOAP（/DH/udirectory）。供「新增使用者代碼」「新增使用者EMAIL」使用。
# 可用檔案執行，也可用 irm | iex 的 scriptblock 執行。
$ErrorActionPreference = 'Stop'

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
}

# 192.168.x.x 會把 SOAP 從 HTTP 轉到 HTTPS，憑證是自簽的。只接受區網位址。
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
function Enable-RicohCopierCert { [FlgCopierCert]::Install() }

function Get-RicohHostFile {
    $name = 'lanyen-ricoh-host.txt'
    # The irm download folder is deleted on exit, so the remembered IP stays beside it.
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $leaf = Split-Path -Leaf $PSScriptRoot
        if ($leaf -ne 'lanyen-ricoh-ab') {
            return (Join-Path $PSScriptRoot $name)
        }
    }
    return (Join-Path ([IO.Path]::GetTempPath()) $name)
}

function ConvertTo-RicohUserMessage {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return '影印機沒有回傳錯誤說明。'
    }
    if ($Text -match '帳號或密碼錯誤|通訊錄使用中|無法連上影印機') {
        return $Text
    }
    if ($Text -match 'NOT_AUTHENTICATED') {
        return '帳號或密碼錯誤。'
    }
    if ($Text -match 'SYSTEM_BUSY') {
        return '通訊錄使用中或被鎖定，請稍後再試。'
    }
    if ($Text -match '信任關係|遠端憑證|SSL|TLS|secure channel') {
        return '無法連上影印機的 HTTPS。機器使用自簽憑證，請改用最新版腳本。'
    }
    if ($Text -match '空字串|它是 Null|PSScriptRoot') {
        return '腳本找不到自己的資料夾。請改用最新版腳本。'
    }
    return $Text
}

$script:RicohStartSessionXml = @'
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:startSession xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="http://www.ricoh.co.jp/xmlns/soap/rdh/udirectory">
      <stringIn />
      <timeLimit>60</timeLimit>
      <lockMode>X</lockMode>
    </u:startSession>
  </s:Body>
</s:Envelope>
'@

$script:RicohPutObjectsXml = @'
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:putObjects xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="http://www.ricoh.co.jp/xmlns/soap/rdh/udirectory">
      <sessionId />
      <objectClass>entry</objectClass>
      <propListList xsi:type="soap-enc:Array" soap-enc:arrayType="ricoh:propertyList[]" />
    </u:putObjects>
  </s:Body>
</s:Envelope>
'@

$script:RicohEndSessionXml = @'
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:terminateSession xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ricoh="http://www.ricoh.co.jp/xmlns/schema/rdh/commontypes" xmlns:u="http://www.ricoh.co.jp/xmlns/soap/rdh/udirectory">
      <sessionId />
    </u:terminateSession>
  </s:Body>
</s:Envelope>
'@

function ConvertTo-RicohBase64 {
    param([string]$Text)
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Text))
}

function ConvertTo-RicohUri {
    param([string]$Text)
    $Text = $Text.Trim().TrimEnd('/')
    if ($Text -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $Text = 'http://' + $Text
    }
    [uri]$Text
}

function Get-RicohKeyDisplay {
    param([string]$Name)
    if ($Name.Length -le 16) {
        return $Name
    }
    $Name.Substring(0, 16)
}

function Invoke-RicohSoapOnce {
    param(
        [uri]$Endpoint,
        [byte[]]$Bytes,
        [string]$Method
    )

    Enable-RicohCopierCert
    $req = [Net.HttpWebRequest]::Create($Endpoint)
    $req.Method = 'POST'
    $req.AllowAutoRedirect = $false
    $req.ContentType = 'text/xml; charset=utf-8'
    $req.Timeout = 90000
    $req.ReadWriteTimeout = 90000
    $req.Headers.Add('SOAPAction', "http://www.ricoh.co.jp/xmlns/soap/rdh/udirectory#$Method")
    $req.ContentLength = $Bytes.Length
    $stream = $req.GetRequestStream()
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Close() }

    $response = $null
    try {
        $response = [Net.HttpWebResponse]$req.GetResponse()
    } catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        $code = 0
        try { if ($errorResponse) { $code = [int]$errorResponse.StatusCode } } catch {}
        if ($code -ge 300 -and $code -lt 400 -and $errorResponse) {
            $location = [string]$errorResponse.Headers['Location']
            try { $errorResponse.Close() } catch {}
            return [pscustomobject]@{ Redirect = $location; Text = '' }
        }
        $faultText = ''
        if ($errorResponse) {
            try {
                $reader = New-Object System.IO.StreamReader($errorResponse.GetResponseStream(), [Text.Encoding]::UTF8)
                $faultText = $reader.ReadToEnd()
                $reader.Close()
            } catch {}
            try { $errorResponse.Close() } catch {}
        }
        $detail = $_.Exception.Message
        if ($faultText -match 'errorDescription>([^<]+)') { $detail = $Matches[1] }
        elseif ($faultText -match 'errorCode>([^<]+)') { $detail = $Matches[1] }
        elseif ($faultText -match 'faultstring>([^<]+)') { $detail = $Matches[1] }
        throw (ConvertTo-RicohUserMessage $detail)
    }

    try {
        $code = [int]$response.StatusCode
        if ($code -ge 300 -and $code -lt 400) {
            return [pscustomobject]@{ Redirect = [string]$response.Headers['Location']; Text = '' }
        }
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream(), [Text.Encoding]::UTF8)
        $text = $reader.ReadToEnd()
        $reader.Close()
        return [pscustomobject]@{ Redirect = ''; Text = $text }
    } finally {
        $response.Close()
    }
}

function Invoke-RicohSoap {
    param(
        [uri]$PrinterUri,
        [xml]$Body,
        [string]$Method
    )

    $endpoint = [uri]::new($PrinterUri, '/DH/udirectory')
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body.OuterXml)
    $result = Invoke-RicohSoapOnce -Endpoint $endpoint -Bytes $bytes -Method $Method
    if ($result.Redirect) {
        $next = [string]$result.Redirect
        if ($next -notmatch '^https?://') {
            $next = ([uri]::new($endpoint, $next)).AbsoluteUri
        }
        $result = Invoke-RicohSoapOnce -Endpoint ([uri]$next) -Bytes $bytes -Method $Method
        if ($result.Redirect) {
            throw ('影印機轉址沒有完成：' + $result.Redirect)
        }
    }
    if ([string]::IsNullOrWhiteSpace($result.Text)) {
        return $null
    }
    return [xml]$result.Text
}

function Open-RicohSession {
    param(
        [uri]$PrinterUri,
        [pscredential]$Credential
    )

    [xml]$xml = $script:RicohStartSessionXml
    $node = $xml.Envelope.Body.startSession
    $scheme = ConvertTo-RicohBase64 'BASIC'
    $user = ConvertTo-RicohBase64 $Credential.UserName
    $password = ConvertTo-RicohBase64 $Credential.GetNetworkCredential().Password
    $node.stringIn = "SCHEME=$scheme;UID:UserName=$user;PWD:Password=$password;PES:Encoding="
    $node.lockMode = 'X'
    $node.timeLimit = '60'

    $lastError = $null
    $response = $null
    for ($try = 1; $try -le 3; $try++) {
        try {
            $response = Invoke-RicohSoap -PrinterUri $PrinterUri -Body $xml -Method 'startSession'
            $lastError = $null
            break
        } catch {
            $lastError = [string]$_.Exception.Message
            if ($lastError -match 'SYSTEM_BUSY|通訊錄使用中' -and $try -lt 3) {
                Start-Sleep -Seconds 2
                continue
            }
            throw (ConvertTo-RicohUserMessage $lastError)
        }
    }
    $sessionId = [string]$response.Envelope.Body.startSessionResponse.stringOut
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        throw '登入失敗，機器沒有回傳登入階段。'
    }
    $sessionId
}

function Close-RicohSession {
    param(
        [uri]$PrinterUri,
        [string]$SessionId
    )

    if ([string]::IsNullOrWhiteSpace($SessionId)) {
        return
    }
    [xml]$xml = $script:RicohEndSessionXml
    $xml.Envelope.Body.terminateSession.sessionId = $SessionId
    Invoke-RicohSoap -PrinterUri $PrinterUri -Body $xml -Method 'terminateSession' | Out-Null
}

function New-RicohPutDocument {
    param(
        [string]$SessionId,
        [System.Collections.Specialized.OrderedDictionary]$Properties
    )

    [xml]$xml = $script:RicohPutObjectsXml
    $put = $xml.Envelope.Body.putObjects
    $put.sessionId = $SessionId
    $entry = $xml.CreateElement('item')
    foreach ($key in $Properties.Keys) {
        $item = $xml.CreateElement('item')
        $propName = $xml.CreateElement('propName')
        $propVal = $xml.CreateElement('propVal')
        $propName.InnerText = [string]$key
        $propVal.InnerText = [string]$Properties[$key]
        [void]$item.AppendChild($propName)
        [void]$item.AppendChild($propVal)
        [void]$entry.AppendChild($item)
    }
    [void]$put.propListList.AppendChild($entry)
    $xml
}

function Send-RicohEntry {
    param(
        [uri]$PrinterUri,
        [pscredential]$Credential,
        [System.Collections.Specialized.OrderedDictionary]$Properties
    )

    $sessionId = Open-RicohSession -PrinterUri $PrinterUri -Credential $Credential
    try {
        $document = New-RicohPutDocument -SessionId $sessionId -Properties $Properties
        Invoke-RicohSoap -PrinterUri $PrinterUri -Body $document -Method 'putObjects' | Out-Null
    } finally {
        try {
            Close-RicohSession -PrinterUri $PrinterUri -SessionId $sessionId
        } catch {
        }
    }
}

function New-RicohCommonProperties {
    param(
        [string]$Name,
        [string]$KeyDisplay
    )

    $properties = New-Object System.Collections.Specialized.OrderedDictionary
    $properties['entryType'] = 'user'
    $properties['name'] = $Name
    $properties['longName'] = $KeyDisplay
    $properties['displayedOrder'] = '5'
    $properties['tagId'] = '1'
    $properties
}

function Read-RicohConnection {
    $hostFile = Get-RicohHostFile
    $defaultHost = ''
    if (Test-Path -LiteralPath $hostFile) {
        $defaultHost = (Get-Content -LiteralPath $hostFile -Encoding UTF8 | Select-Object -First 1)
        if ($defaultHost) {
            $defaultHost = $defaultHost.Trim()
        }
    }

    $hostPrompt = '影印機 IP'
    if ($defaultHost) {
        $hostPrompt = "影印機 IP（直接 Enter 使用 $defaultHost）"
    }
    $enteredHost = Read-Host $hostPrompt
    if ([string]::IsNullOrWhiteSpace($enteredHost)) {
        $enteredHost = $defaultHost
    }
    if ([string]::IsNullOrWhiteSpace($enteredHost)) {
        throw '尚未輸入影印機 IP。'
    }
    $printerUri = ConvertTo-RicohUri $enteredHost

    $admin = Read-Host '管理員帳號（直接 Enter 使用 admin）'
    if ([string]::IsNullOrWhiteSpace($admin)) {
        $admin = 'admin'
    }
    $secure = Read-Host '管理員密碼（沒有密碼就直接 Enter）' -AsSecureString
    $credential = New-Object System.Management.Automation.PSCredential($admin, $secure)

    Write-Host '正在登入...'
    $sessionId = Open-RicohSession -PrinterUri $printerUri -Credential $credential
    Close-RicohSession -PrinterUri $printerUri -SessionId $sessionId
    Set-Content -LiteralPath $hostFile -Value $printerUri.AbsoluteUri -Encoding UTF8
    Write-Host "登入成功：$($printerUri.Host)"
    Write-Host ''

    [PSCustomObject]@{
        PrinterUri = $printerUri
        Credential = $credential
    }
}
