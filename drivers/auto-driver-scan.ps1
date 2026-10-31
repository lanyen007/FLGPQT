# FLG LAN-scan printer discovery + install bootstrap (ASCII only; loads UTF-8 main script)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:FLG_AUTO_MODE = 'scan'
$__b = (New-Object Net.WebClient).DownloadData("https://lanyen007.github.io/FLGPQT/drivers/auto-driver-main.ps1?t=" + [DateTime]::Now.Ticks)
$__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
& ([scriptblock]::Create($__s)) @args
