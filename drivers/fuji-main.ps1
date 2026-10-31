# FLG FUJIFILM／全錄 驅動程式一鍵下載（包裝共用腳本）
# 用法：
#   irm https://lanyen007.github.io/FLGPQT/drivers/fuji.ps1 | iex
#   & ([scriptblock]::Create((irm https://lanyen007.github.io/FLGPQT/drivers/fuji.ps1))) "C3070"

$FlgDriverBrand = 'FUJIFILM'
$FlgDriverJson = 'fuji.json'
$FlgSearchHint = 'C3070、Apeos、SC2022、MMD2'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__b = (New-Object Net.WebClient).DownloadData("https://lanyen007.github.io/FLGPQT/drivers/common-main.ps1?t=" + [DateTime]::Now.Ticks)
$__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
& ([scriptblock]::Create($__s)) @args
