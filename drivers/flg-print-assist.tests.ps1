# 靜態測試：同意／拒絕／受管理，以及下載進度與中斷不留檔。
# 用法：pwsh -NoProfile -File drivers/flg-print-assist.tests.ps1 -BaseUrl http://127.0.0.1:8765
param([string]$BaseUrl = '')

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'flg-print-assist.ps1')

$script:failed = 0
function Assert-True([bool]$Cond, [string]$Name) {
    if ($Cond) { Write-Host ("PASS " + $Name) -ForegroundColor Green }
    else { Write-Host ("FAIL " + $Name) -ForegroundColor Red; $script:failed++ }
}

function Run-Step([hashtable]$State, [string[]]$Answers) {
    $used = @()
    $last = $null
    foreach ($a in @($Answers)) {
        $last = Get-FlgPrintProtectionStep -ErrorMessage $State.Error -OsCaption $State.Caption -OsBuild $State.Build -PolicyPresent $State.PolicyPresent -PolicyState $State.PolicyState -Interactive $true -Answers $used
        if ($last.Done) { return $last }
        $used += $a
    }
    return (Get-FlgPrintProtectionStep -ErrorMessage $State.Error -OsCaption $State.Caption -OsBuild $State.Build -PolicyPresent $State.PolicyPresent -PolicyState $State.PolicyState -Interactive $true -Answers $used)
}

$base = @{ Error = 'FLG_DRIVER_INSTALL_FAILED: pnputil 結束碼 5'; Caption = 'Windows 11'; Build = 26100; PolicyPresent = $false; PolicyState = $null }

$refuse = Run-Step $base @('N')
Assert-True ($refuse.Done -and -not $refuse.Retry -and -not $refuse.OpenSettings -and -not $refuse.ChangedSettings) '拒絕：不改設定、不重試'
Assert-True (($refuse.Lines -join ' ') -match '維持原設定') '拒絕文案'

$blank = Get-FlgPrintProtectionStep -ErrorMessage $base.Error -OsCaption $base.Caption -OsBuild 26100 -PolicyPresent $false -PolicyState $null -Interactive $true -Answers @('')
Assert-True ($blank.Done -and -not $blank.Retry) '空白答案視為拒絕'

$declineOpen = Run-Step $base @('Y', 'N')
Assert-True ($declineOpen.Done -and -not $declineOpen.Retry -and -not $declineOpen.OpenSettings) '同意後又拒絕開啟設定：不重試'

$retry = Run-Step $base @('Y', 'Y', 'Y')
Assert-True ($retry.Done -and $retry.Retry -and $retry.OpenSettings -and -not $retry.ChangedSettings) '同意開啟設定並重試一次'
Assert-True (($retry.Lines -join ' ') -match '不會一直重試') '重試是一次'

$noRetry = Run-Step $base @('Y', 'Y', 'N')
Assert-True ($noRetry.Done -and $noRetry.OpenSettings -and -not $noRetry.Retry) '開啟設定後拒絕重試'

$managed = @{ Error = $base.Error; Caption = 'Windows 11'; Build = 26100; PolicyPresent = $true; PolicyState = 1 }
$managedStop = Run-Step $managed @('Y', 'Y')
Assert-True ($managedStop.Managed -and $managedStop.Done -and -not $managedStop.Retry -and $managedStop.OpenSettings -and -not $managedStop.ChangedSettings) '受管理：可開設定頁但不重試、不改設定'
$managedExplain = Get-FlgPrintProtectionStep -ErrorMessage $managed.Error -OsCaption $managed.Caption -OsBuild 26100 -PolicyPresent $true -PolicyState 1 -Interactive $true -Answers @('Y')
Assert-True (($managedExplain.Lines -join ' ') -match '不會繞過') '受管理說明不繞過原則'

$non = Get-FlgPrintProtectionStep -ErrorMessage $base.Error -OsCaption 'Windows 11' -OsBuild 26100 -PolicyPresent $false -PolicyState $null -Interactive $false -Answers @()
Assert-True ($non.Done -and -not $non.Retry -and (($non.Lines -join ' ') -match '可能原因')) '非互動：顯示可能原因且不重試'

Assert-True (-not (Test-FlgPnpInstallFailed -ExitCode 0 -DriverInStore $false)) '結束碼 0 不是失敗'
Assert-True (-not (Test-FlgPnpInstallFailed -ExitCode 3010 -DriverInStore $false)) '3010 重開機不是失敗'
Assert-True (-not (Test-FlgPnpInstallFailed -ExitCode 1641 -DriverInStore $false)) '1641 重開機不是失敗'
Assert-True (Test-FlgPnpInstallFailed -ExitCode 5 -DriverInStore $false) '結束碼 5 且驅動不在存放區是失敗'
Assert-True (-not (Test-FlgPnpInstallFailed -ExitCode 5 -DriverInStore $true)) '結束碼 5 但驅動已在存放區不是失敗'
Assert-True ((Get-FlgPnpRebootNote 3010) -match '不是安裝失敗') '重開機說明'

$notice = Get-FlgPrintProtectionStep -ErrorMessage $base.Error -OsCaption 'Windows 11' -OsBuild 22631 -PolicyPresent $false -PolicyState $null -Interactive $true -Answers @()
$joined = $notice.Lines -join "`n"
Assert-True ($joined -match '不是每次失敗都是這個') '提醒寫明只是可能原因'
Assert-True ($joined -match 'pnputil 結束碼 5') '顯示錯誤訊息'
Assert-True ($joined -match '組建 22631') '較舊組建不假裝有受保護列印開關'
Assert-True ($joined -notmatch 'C:\\Users\\') '文案沒有寫死 C:\Users'

if ($BaseUrl) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('flg-dl-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $known = Get-FlgDownloadsFolder -Override $dir
    Assert-True ($known -eq ([IO.Path]::GetFullPath($dir))) '下載資料夾可指向 Known Folder 覆寫，不寫死 C:\Users'

    $events = New-Object System.Collections.Generic.List[object]
    $out = Join-Path $dir 'ok.bin'
    [void](Save-FlgHttpWithProgress -Url ($BaseUrl + '/len') -OutFile $out -OnProgress { param($s) $events.Add($s) })
    Assert-True ((Test-Path $out) -and ((Get-Item $out).Length -eq 100000)) '有總容量時下載完整檔'
    $withPct = @($events | Where-Object { $null -ne $_.Percent })
    Assert-True ($withPct.Count -gt 0) '有總容量時有百分比'
    Assert-True (-not (Test-Path ($out + '.partial'))) '成功後不留 partial'

    $events2 = New-Object System.Collections.Generic.List[object]
    $out2 = Join-Path $dir 'nolen.bin'
    [void](Save-FlgHttpWithProgress -Url ($BaseUrl + '/nolen') -OutFile $out2 -OnProgress { param($s) $events2.Add($s) })
    $badPct = @($events2 | Where-Object { $null -ne $_.Percent })
    Assert-True ($badPct.Count -eq 0) '沒有總容量時不顯示百分比'
    Assert-True ((Get-Item $out2).Length -eq 50000) '沒有總容量仍存下已下載內容'

    $out3 = Join-Path $dir 'cut.bin'
    $threw = $false
    try { [void](Save-FlgHttpWithProgress -Url ($BaseUrl + '/cut') -OutFile $out3) } catch { $threw = $true }
    Assert-True $threw '中斷時丟出錯誤'
    Assert-True (-not (Test-Path $out3)) '中斷不留下完成檔'
    Assert-True (-not (Test-Path ($out3 + '.partial'))) '中斷不留下 partial'
    Remove-Item -LiteralPath $dir -Recurse -Force
}

if ($script:failed -gt 0) { Write-Host ("FAILED " + $script:failed) -ForegroundColor Red; exit 1 }
Write-Host 'ALL PASS' -ForegroundColor Green
exit 0
