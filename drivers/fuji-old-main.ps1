# lanyen 工具箱 舊版 FUJI／全錄 驅動程式一鍵下載（包裝共用腳本）
# 用法：
#   irm https://lanyen.de/fuji-old | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/fuji-old.ps1 | iex
#   & ([scriptblock]::Create((irm https://lanyen.de/fuji-old))) "C5570"

$FlgDriverBrand = '舊版 FUJI'
$FlgDriverJson = 'fuji-old.json'
$FlgSearchHint = '3375、5575、C5570、C2265、5070、3376、2263'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$__common = $null
if ($env:FLG_OFFLINE -eq '1' -and $env:FLG_ROOT) {
    $__p = Join-Path $env:FLG_ROOT 'drivers\common-main.ps1'
    if (-not (Test-Path -LiteralPath $__p)) { $__p = Join-Path $env:FLG_ROOT 'drivers/common-main.ps1' }
    if (Test-Path -LiteralPath $__p) { $__common = $__p }
}
if ($__common) {
    & $__common @args
} else {
    $__b = (New-Object Net.WebClient).DownloadData("https://lanyen007.github.io/FLGPQT/drivers/common-main.ps1?t=" + [DateTime]::Now.Ticks)
    $__s = [Text.Encoding]::UTF8.GetString($__b).TrimStart([char]0xFEFF)
    & ([scriptblock]::Create($__s)) @args
}
