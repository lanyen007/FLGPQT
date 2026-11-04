# RICOH address book: Add-UserEmail (ASCII bootstrap; downloads the UTF-8 scripts to TEMP and runs them with -File)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__d = Join-Path ([IO.Path]::GetTempPath()) 'lanyen-ricoh-ab'
New-Item -ItemType Directory -Force -Path $__d | Out-Null
$__wc = New-Object Net.WebClient
$__utf8Bom = New-Object Text.UTF8Encoding($true)
foreach ($__f in 'RicohAddressBookSoap.ps1', 'Add-UserEmail.ps1') {
    # decode as UTF-8 and always write with BOM so Windows PowerShell 5.1 does not read it as Big5/ANSI
    $__b = $__wc.DownloadData('https://lanyen007.github.io/FLGPQT/drivers/ricoh-ab/' + $__f + '?t=' + [DateTime]::Now.Ticks)
    $__t = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
    [IO.File]::WriteAllText((Join-Path $__d $__f), $__t, $__utf8Bom)
}
$__exe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path $__exe)) { $__exe = (Get-Process -Id $PID).Path }
$__p = (Join-Path $__d 'Add-UserEmail.ps1').Replace("'", "''")
$__cmd = "try { [Console]::OutputEncoding = [Text.Encoding]::UTF8; [Console]::InputEncoding = [Text.Encoding]::UTF8; `$OutputEncoding = [Text.Encoding]::UTF8 } catch {}; & '" + $__p + "'"
& $__exe -NoProfile -ExecutionPolicy Bypass -Command $__cmd
