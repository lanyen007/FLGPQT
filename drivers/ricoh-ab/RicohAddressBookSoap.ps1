# Ricoh 通訊錄 SOAP（/DH/udirectory）。供「新增使用者代碼」「新增使用者EMAIL」使用。
$ErrorActionPreference = 'Stop'

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
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
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text))
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

function Get-RicohFaultText {
    param($ErrorRecord)

    $text = $null
    if ($ErrorRecord.ErrorDetails) {
        $text = [string]$ErrorRecord.ErrorDetails.Message
    }
    if ([string]::IsNullOrWhiteSpace($text) -and $ErrorRecord.Exception.Response) {
        try {
            $stream = $ErrorRecord.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $text = $reader.ReadToEnd()
            $reader.Dispose()
        } catch {
        }
    }
    if ($text -and $text.TrimStart().StartsWith('<')) {
        try {
            [xml]$xml = $text
            $fault = $xml.Envelope.Body.Fault
            $desc = [string]$fault.detail.rdhError.errorDescription
            if ([string]::IsNullOrWhiteSpace($desc)) {
                $desc = [string]$fault.detail.rdhError.errorCode
            }
            if ([string]::IsNullOrWhiteSpace($desc)) {
                $desc = [string]$fault.faultstring
            }
            if (-not [string]::IsNullOrWhiteSpace($desc)) {
                return $desc
            }
        } catch {
        }
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $ErrorRecord.Exception.Message
    }
    return $text
}

function Invoke-RicohSoap {
    param(
        [uri]$PrinterUri,
        [xml]$Body,
        [string]$Method
    )

    $endpoint = [uri]::new($PrinterUri, '/DH/udirectory')
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body.OuterXml)
    $headers = @{
        SOAPAction = "http://www.ricoh.co.jp/xmlns/soap/rdh/udirectory#$Method"
    }
    $skipCert = $PrinterUri.Scheme -eq 'https'
    $previous = [Net.ServicePointManager]::ServerCertificateValidationCallback
    try {
        if ($skipCert) {
            [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -ContentType 'text/xml; charset=utf-8' -Headers $headers -Body $bytes -UseBasicParsing
        if ([string]::IsNullOrWhiteSpace($response.Content)) {
            return $null
        }
        return [xml]$response.Content
    } catch {
        throw (Get-RicohFaultText $_)
    } finally {
        if ($skipCert) {
            [Net.ServicePointManager]::ServerCertificateValidationCallback = $previous
        }
    }
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

    $response = Invoke-RicohSoap -PrinterUri $PrinterUri -Body $xml -Method 'startSession'
    $sessionId = [string]$response.Envelope.Body.startSessionResponse.stringOut
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        throw '登入失敗，機器沒有回傳 session。'
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
    $hostFile = Join-Path $PSScriptRoot 'ricoh-host.txt'
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
    Write-Host "登入成功：$($printerUri.AbsoluteUri)"
    Write-Host ''

    [PSCustomObject]@{
        PrinterUri = $printerUri
        Credential = $credential
    }
}
