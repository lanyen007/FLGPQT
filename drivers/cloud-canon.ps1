# FLG cloud printer driver install bootstrap - Canon (ASCII only; loads UTF-8 main script)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:FLG_CLOUD_DRIVER_ID = 'canon-genericplus-pcl6-3.50.0.0'
$__b = (New-Object Net.WebClient).DownloadData("https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/cloud-install-main.ps1?t=" + [DateTime]::Now.Ticks)
$__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
& ([scriptblock]::Create($__s)) @args
