# FLG Ricoh 驅動程式一鍵下載（包裝共用腳本）
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/ricoh.ps1 | iex
#   & ([scriptblock]::Create((irm https://lanyen007.github.io/FLGPQT/drivers/ricoh.ps1))) "C3503"

$FlgDriverBrand = 'Ricoh'
$FlgDriverJson = 'ricoh.json'
$FlgSearchHint = 'C3503、IM C3000'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__b = (New-Object Net.WebClient).DownloadData("https://lanyen007.github.io/FLGPQT/drivers/common-main.ps1?t=" + [DateTime]::Now.Ticks)
$__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
& ([scriptblock]::Create($__s)) @args
