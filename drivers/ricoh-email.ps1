# RICOH address book: Add-UserEmail (ASCII bootstrap; downloads UTF-8 scripts, then runs the file)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$__dir = Join-Path ([IO.Path]::GetTempPath()) 'lanyen-ricoh-ab'
try {
    New-Item -ItemType Directory -Force -Path $__dir | Out-Null
    $__base = 'https://lanyen007.github.io/FLGPQT/drivers/ricoh-ab/'
    $__wc = New-Object Net.WebClient
    foreach ($__n in @('RicohAddressBookSoap.ps1','Add-UserEmail.ps1')) {
        $__wc.DownloadFile(($__base + $__n + '?t=' + [DateTime]::Now.Ticks), (Join-Path $__dir $__n))
    }
    & (Join-Path $__dir 'Add-UserEmail.ps1') @args
} finally {
    if ($__dir -and (Test-Path -LiteralPath $__dir)) {
        Remove-Item -LiteralPath $__dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
