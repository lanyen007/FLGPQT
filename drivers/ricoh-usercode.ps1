# RICOH address book: Add-UserCode (ASCII bootstrap; downloads the UTF-8 scripts to TEMP and runs them with -File)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__d = Join-Path ([IO.Path]::GetTempPath()) 'lanyen-ricoh-ab'
New-Item -ItemType Directory -Force -Path $__d | Out-Null
$__wc = New-Object Net.WebClient
foreach ($__f in 'RicohAddressBookSoap.ps1', 'Add-UserCode.ps1') {
    $__wc.DownloadFile('https://lanyen007.github.io/FLGPQT/drivers/ricoh-ab/' + $__f + '?t=' + [DateTime]::Now.Ticks, (Join-Path $__d $__f))
}
$__exe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path $__exe)) { $__exe = (Get-Process -Id $PID).Path }
& $__exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $__d 'Add-UserCode.ps1')
