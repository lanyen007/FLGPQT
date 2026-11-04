# 新增使用者代碼。名稱只輸入一次，按鍵名稱自動使用同一個名稱。
$ErrorActionPreference = 'Stop'
$soapPath = $null
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $soapPath = Join-Path $PSScriptRoot 'RicohAddressBookSoap.ps1'
}
if (-not $soapPath -or -not (Test-Path -LiteralPath $soapPath)) {
    throw '找不到 RicohAddressBookSoap.ps1。請與本腳本放在同一資料夾。'
}
. $soapPath

Write-Host '新增使用者代碼'
Write-Host '名稱會自動帶入按鍵名稱。接著輸入使用者代碼（1 到 8 位數字）。'
Write-Host '名稱留白就結束。'
Write-Host ''

try {
    $connection = Read-RicohConnection
} catch {
    Write-Host ('登入失敗：' + (ConvertTo-RicohUserMessage $_.Exception.Message))
    return
}

while ($true) {
    $name = (Read-Host '名稱').Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
        break
    }
    if ($name.Length -gt 20) {
        Write-Host '名稱最多 20 個字，請重填。'
        Write-Host ''
        continue
    }

    $keyDisplay = Get-RicohKeyDisplay $name
    $userCode = (Read-Host '使用者代碼').Trim()
    if ($userCode -notmatch '^\d{1,8}$') {
        Write-Host '使用者代碼必須是 1 到 8 位數字。這台機器不接受更長的代碼，請重填這筆。'
        Write-Host ''
        continue
    }

    Write-Host "名稱：$name"
    Write-Host "按鍵名稱：$keyDisplay"
    if ($keyDisplay -ne $name) {
        Write-Host '按鍵名稱最多 16 個字，已取名稱的前 16 個字。'
    }
    Write-Host "使用者代碼：$userCode"
    $confirm = Read-Host '按 Enter 送出，輸入 n 取消這筆'
    if ($confirm -eq 'n' -or $confirm -eq 'N') {
        Write-Host '已取消這筆。'
        Write-Host ''
        continue
    }

    $properties = New-RicohCommonProperties -Name $name -KeyDisplay $keyDisplay
    $properties['auth:'] = 'true'
    $properties['auth:name'] = $userCode
    $properties['isDestination'] = 'true'

    try {
        Send-RicohEntry -PrinterUri $connection.PrinterUri -Credential $connection.Credential -Properties $properties
        Write-Host '已新增。'
    } catch {
        Write-Host ('新增失敗：' + (ConvertTo-RicohUserMessage $_.Exception.Message))
    }
    Write-Host ''
}

Write-Host '結束。'
