# FLG Sharp 驅動程式一鍵下載（包裝共用腳本）
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/sharp.ps1 | iex
#   & ([scriptblock]::Create((irm https://lanyen007.github.io/FLGPQT/drivers/sharp.ps1))) "MX2600"

$FlgDriverBrand = 'Sharp'
$FlgDriverJson = 'sharp.json'
$FlgSearchHint = 'MX2600、M266、452'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__b = (New-Object Net.WebClient).DownloadData("https://lanyen007.github.io/FLGPQT/drivers/common-main.ps1?t=" + [DateTime]::Now.Ticks)
$__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
& ([scriptblock]::Create($__s)) @args
