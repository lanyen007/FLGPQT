#Requires -Version 5.1
<#
.SYNOPSIS
    在 Windows 把同目錄 PQT.ps1 編成 PQT.exe（ps2exe）
.USAGE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Compile-PQT.ps1"
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'PQT.ps1'
$out = Join-Path $here 'PQT.exe'
$icon = Join-Path $here 'icon.ico'

if (-not (Test-Path -LiteralPath $src)) {
    throw "找不到 PQT.ps1：$src"
}

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "安裝 ps2exe 模組..."
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
    Import-Module ps2exe -Force
}

$params = @{
    inputFile      = $src
    outputFile     = $out
    title          = 'PQT007'
    product        = 'PQT007'
    version        = '4.1.20.0'
    noConsole      = $true
    requireAdmin   = $false
    supportOS      = $true
    longPaths      = $true
    unicodeEncoding= $true
}
if (Test-Path -LiteralPath $icon) { $params.iconFile = $icon }

Write-Host "編譯 $src -> $out"
Invoke-ps2exe @params
if (-not (Test-Path -LiteralPath $out)) { throw '編譯失敗，沒有產生 PQT.exe' }
Write-Host ("完成：{0} ({1} bytes)" -f $out, (Get-Item $out).Length)
