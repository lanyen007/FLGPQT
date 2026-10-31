# FLG file box installer bootstrap (ASCII only; loads UTF-8 main script)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__b = (New-Object Net.WebClient).DownloadData("https://lanyen007.github.io/FLGPQT/install-main.ps1?t=" + [DateTime]::Now.Ticks)
$__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
& ([scriptblock]::Create($__s)) @args
