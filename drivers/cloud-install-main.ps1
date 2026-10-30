# FLG 雲端安裝驅動（Ricoh / FUJIFILM / Sharp 通用 PCL6）
# 用法（各品牌獨立指令，只問 IP）：
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-install.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-fuji.ps1 | iex
#   irm https://lanyen007.github.io/FLGPQT/drivers/cloud-sharp.ps1 | iex
# 參數：$args[0]=印表機 IP；$args[1]=印表機名稱（可省略）
# 品牌由 bootstrap 透過 $env:FLG_CLOUD_DRIVER_ID 指定。

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$CloudJsonUrl = 'https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/cloud.json'
$PagesBase = 'https://lanyen007.github.io/FLGPQT/drivers/'
$IsWindowsOs = $true
try {
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { $IsWindowsOs = $false }
} catch {}
if ($env:OS -notmatch 'Windows' -and $PSVersionTable.Platform -eq 'Unix') { $IsWindowsOs = $false }

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-ErrMsg([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Test-IsAdmin {
    if (-not $IsWindowsOs) { return $true }
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BootstrapUrl([string]$BootstrapFile) {
    if ([string]::IsNullOrWhiteSpace($BootstrapFile)) { $BootstrapFile = 'cloud-install.ps1' }
    return ($PagesBase + $BootstrapFile)
}

function Request-Elevation([string]$BootstrapUrl) {
    Write-WarnMsg '需要系統管理員權限才能安裝驅動，即將跳出 UAC 提示…'
    $parts = @()
    foreach ($a in $args) {
        $s = [string]$a
        $parts += ("'" + $s.Replace("'", "''") + "'")
    }
    $argStr = $parts -join ' '
    $inner = "& ([scriptblock]::Create((Invoke-RestMethod -Uri '$BootstrapUrl'))) $argStr"
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList | Out-Null
        Write-Info '已啟動提權視窗，請在新視窗完成安裝。'
    } catch {
        Write-ErrMsg ("無法提權：" + $_.Exception.Message)
        Write-Host '請以「系統管理員」開啟 PowerShell 後再執行一次。' -ForegroundColor Yellow
        exit 1
    }
    exit 0
}

function Test-Ipv4Address([string]$Ip) {
    if ([string]::IsNullOrWhiteSpace($Ip)) { return $false }
    $m = [regex]::Match($Ip.Trim(), '^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$')
    return $m.Success
}

function Get-CloudCatalog {
    Write-Info '讀取雲端驅動清單…'
    $wc = New-Object Net.WebClient
    $wc.Encoding = [Text.Encoding]::UTF8
    $raw = $wc.DownloadString("$CloudJsonUrl`?t=$([DateTime]::UtcNow.Ticks)")
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
    return ($raw | ConvertFrom-Json)
}

function Select-CloudDriver($Catalog, [string]$DriverId) {
    $list = @($Catalog.drivers)
    if ($list.Count -eq 0) { throw 'cloud.json 沒有可用驅動。' }
    if ($DriverId) {
        $found = $list | Where-Object { $_.id -eq $DriverId } | Select-Object -First 1
        if (-not $found) {
            throw ("找不到驅動 id：$DriverId`n可用：" + (($list | ForEach-Object { $_.id }) -join ', '))
        }
        Write-Ok ("選用：" + $found.title + "  v" + $found.version)
        return $found
    }
    # 相容舊版：未指定 id 時，優先 Ricoh
    $ricoh = $list | Where-Object { $_.brand -eq 'Ricoh' } | Select-Object -First 1
    if ($ricoh) {
        Write-Ok ("選用：" + $ricoh.title + "  v" + $ricoh.version)
        return $ricoh
    }
    Write-Ok ("選用：" + $list[0].title + "  v" + $list[0].version)
    return $list[0]
}

function Get-PrinterIpFromArgsOrPrompt {
    $ip = ''
    if ($script:ArgIp) { $ip = $script:ArgIp }
    while (-not (Test-Ipv4Address $ip)) {
        if ($ip) { Write-WarnMsg "IP 格式不正確：$ip" }
        $ip = Read-Host '請輸入印表機 IP（例如 192.168.1.50）'
    }
    return $ip.Trim()
}

function Test-PrinterReachable([string]$Ip) {
    Write-Info ("檢查連線 " + $Ip + " …")
    $pingOk = $false
    try {
        if ($IsWindowsOs) {
            $pingOk = Test-Connection -ComputerName $Ip -Count 1 -Quiet -ErrorAction SilentlyContinue
        } else {
            & ping -c 1 -W 2 $Ip 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $pingOk = $true }
        }
    } catch {}
    if ($pingOk) { Write-Ok 'Ping 成功' } else { Write-WarnMsg 'Ping 失敗（部分機台會關閉 ICMP，可略過）' }

    $tcpOk = $false
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($Ip, 9100, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait -and $client.Connected) { $tcpOk = $true }
        try { $client.Close() } catch {}
    } catch {}
    if ($tcpOk) { Write-Ok 'TCP 9100（Raw）可連' } else { Write-WarnMsg 'TCP 9100 無法連線（仍可繼續安裝驅動）' }
    return @{ Ping = $pingOk; Tcp9100 = $tcpOk }
}

function Get-FileSha256([string]$Path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $hash = $sha.ComputeHash($fs)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } finally {
        $fs.Close()
        $sha.Dispose()
    }
}

function Install-CloudDriverWindows($Driver, [string]$Ip, [string]$PrinterName) {
    $work = Join-Path $env:TEMP ('FLG-CloudDriver-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $zipPath = Join-Path $work $Driver.zip_name
    $extractDir = Join-Path $work 'extract'

    try {
        Write-Info ("下載驅動包（約 {0:N1} MB）…" -f ($Driver.size / 1MB))
        Write-Host ("  " + $Driver.url)
        Invoke-WebRequest -Uri $Driver.url -OutFile $zipPath -UseBasicParsing
        if (-not (Test-Path -LiteralPath $zipPath)) { throw '下載失敗：找不到檔案。' }

        Write-Info '驗證 SHA256…'
        $actual = Get-FileSha256 $zipPath
        $expect = ([string]$Driver.sha256).ToLowerInvariant()
        if ($actual -ne $expect) {
            throw ("SHA256 不符`n  期望：$expect`n  實際：$actual")
        }
        Write-Ok 'SHA256 正確'

        Write-Info '解壓縮…'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        $infPath = Join-Path $extractDir $Driver.inf
        if (-not (Test-Path -LiteralPath $infPath)) {
            $infLeaf = [IO.Path]::GetFileName([string]$Driver.inf)
            $found = Get-ChildItem -Path $extractDir -Filter $infLeaf -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $found) {
                $found = Get-ChildItem -Path $extractDir -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            }
            if ($found) { $infPath = $found.FullName } else { throw "找不到 INF：$($Driver.inf)" }
        }
        Write-Ok ("INF：" + $infPath)

        Write-Info '安裝驅動套件（pnputil）…'
        $pnp = & pnputil.exe /add-driver $infPath /install 2>&1
        $pnp | ForEach-Object { Write-Host ("  " + $_) }
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            Write-WarnMsg ("pnputil 結束碼：" + $LASTEXITCODE + "（若驅動已存在可忽略）")
        }

        $drvName = [string]$Driver.driver_name
        Write-Info ("登錄印表機驅動：$drvName")
        $existing = Get-PrinterDriver -Name $drvName -ErrorAction SilentlyContinue
        if (-not $existing) {
            try {
                Add-PrinterDriver -Name $drvName -ErrorAction Stop
            } catch {
                $alt = [string]$Driver.driver_name_alt
                if ($alt) {
                    Write-WarnMsg ("改用備用名稱：$alt")
                    $drvName = $alt
                    if (-not (Get-PrinterDriver -Name $drvName -ErrorAction SilentlyContinue)) {
                        Add-PrinterDriver -Name $drvName -ErrorAction Stop
                    }
                } else { throw }
            }
        } else {
            Write-Ok '驅動已存在，略過 Add-PrinterDriver'
        }

        $portName = 'IP_' + $Ip
        Write-Info ("建立 TCP/IP 連接埠：$portName")
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $portName -PrinterHostAddress $Ip -ErrorAction Stop
            Write-Ok '連接埠已建立'
        } else {
            Write-Ok '連接埠已存在，略過'
        }

        Write-Info ("新增印表機：$PrinterName")
        $prev = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($prev) {
            Write-WarnMsg '同名印表機已存在，將移除後重建…'
            Remove-Printer -Name $PrinterName -ErrorAction Stop
        }
        Add-Printer -Name $PrinterName -DriverName $drvName -PortName $portName -ErrorAction Stop
        Write-Ok '印表機已新增'

        try {
            Set-PrintConfiguration -PrinterName $PrinterName -Color $false -DuplexingMode OneSided -ErrorAction Stop
            Write-Ok '已設定預設：黑白、單面'
        } catch { Write-WarnMsg ("設定黑白單面失敗：" + $_.Exception.Message) }
        $esc = $PrinterName.Replace("'", "''")
        try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name 'LegacyDefaultPrinterMode' -Value 1 -Type DWord -ErrorAction Stop } catch {}
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter | Out-Null
            Write-Ok '已設為預設印表機'
        } catch {
            try { (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName) | Out-Null; Write-Ok '已設為預設印表機' }
            catch { Write-WarnMsg ("設預設失敗：" + $_.Exception.Message) }
        }
        Start-Sleep -Seconds 2
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            $null = Invoke-CimMethod -InputObject $printer -MethodName PrintTestPage
            Write-Ok '已送出測試頁'
        } catch {
            try { Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /k /n "' + $PrinterName + '"') -Wait; Write-Ok '已送出測試頁' }
            catch { Write-WarnMsg ("測試頁失敗：" + $_.Exception.Message) }
        }

        Write-Host ''
        Write-Ok '雲端安裝完成。'
        Write-Host ("  驅動：$drvName  v$($Driver.version)") -ForegroundColor Green
        Write-Host ("  印表機：$PrinterName") -ForegroundColor Green
        Write-Host ("  連接埠：$portName → $Ip") -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $work) {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-CloudDriverMock($Driver, [string]$Ip, [string]$PrinterName) {
    Write-WarnMsg '目前不是 Windows，改走模擬流程（驗證下載與 SHA256）。'
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('FLG-CloudDriver-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $zipPath = Join-Path $work $Driver.zip_name
    try {
        Write-Info ("下載 " + $Driver.url)
        Invoke-WebRequest -Uri $Driver.url -OutFile $zipPath -UseBasicParsing
        $actual = Get-FileSha256 $zipPath
        $expect = ([string]$Driver.sha256).ToLowerInvariant()
        if ($actual -ne $expect) { throw "SHA256 不符：期望 $expect 實際 $actual" }
        Write-Ok ("SHA256 OK  size=" + (Get-Item $zipPath).Length)
        Write-Info '解壓縮（驗證 INF）…'
        Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $work 'extract') -Force
        $inf = Join-Path $work ('extract/' + $Driver.inf)
        if (-not (Test-Path $inf)) {
            $infLeaf = [IO.Path]::GetFileName([string]$Driver.inf)
            $found = Get-ChildItem -Path (Join-Path $work 'extract') -Filter $infLeaf -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $inf = $found.FullName } else { throw "找不到 INF：$inf" }
        }
        Write-Ok ("INF OK：" + $inf)
        Write-Host '[MOCK] pnputil /add-driver … /install' -ForegroundColor DarkGray
        Write-Host ("[MOCK] Add-PrinterDriver -Name '" + $Driver.driver_name + "'") -ForegroundColor DarkGray
        Write-Host ("[MOCK] Add-PrinterPort -Name 'IP_" + $Ip + "' -PrinterHostAddress " + $Ip) -ForegroundColor DarkGray
        Write-Host ("[MOCK] Add-Printer -Name '" + $PrinterName + "'") -ForegroundColor DarkGray
        Write-Host '[MOCK] Set-PrintConfiguration -Color $false -DuplexingMode OneSided' -ForegroundColor DarkGray
        Write-Ok 'Linux 模擬流程通過（Windows 安裝步驟未實測）。'
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- args ---
$script:ArgIp = ''
$script:ArgName = ''
$script:NonInteractive = $false
$script:ArgDriverId = ''
if ($env:FLG_CLOUD_DRIVER_ID) { $script:ArgDriverId = [string]$env:FLG_CLOUD_DRIVER_ID }

if ($args -and $args.Count -ge 1) {
    if (Test-Ipv4Address ([string]$args[0])) {
        $script:ArgIp = [string]$args[0]
        $script:NonInteractive = $true
        if ($args.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace([string]$args[1])) {
            $script:ArgName = [string]$args[1]
        }
    } else {
        # 允許直接傳 driver id（進階用法）
        $script:ArgDriverId = [string]$args[0]
        if ($args.Count -ge 2 -and (Test-Ipv4Address ([string]$args[1]))) {
            $script:ArgIp = [string]$args[1]
            $script:NonInteractive = $true
            if ($args.Count -ge 3 -and -not [string]::IsNullOrWhiteSpace([string]$args[2])) {
                $script:ArgName = [string]$args[2]
            }
        }
    }
}

Write-Host ''
Write-Host '======== FLG 雲端安裝驅動 ========' -ForegroundColor White
Write-Host '通用 PCL6（Win64）｜只輸入 IP｜自動黑白單面＋預設＋測試頁' -ForegroundColor Gray
Write-Host ''

# 先讀清單以決定 bootstrap（提權用）
$catalog = $null
$driverPreview = $null
try {
    $catalog = Get-CloudCatalog
    $driverPreview = Select-CloudDriver $catalog $script:ArgDriverId
} catch {
    Write-ErrMsg ('讀取清單失敗：' + $_.Exception.Message)
    exit 1
}

$bootstrapFile = 'cloud-install.ps1'
if ($driverPreview.bootstrap) { $bootstrapFile = [string]$driverPreview.bootstrap }
$BootstrapUrl = Get-BootstrapUrl $bootstrapFile

if ($IsWindowsOs -and -not (Test-IsAdmin)) {
    Request-Elevation $BootstrapUrl @args
}

try {
    $driver = $driverPreview
    $ip = Get-PrinterIpFromArgsOrPrompt
    $prefix = 'RICOH'
    if ($driver.name_prefix) { $prefix = [string]$driver.name_prefix }
    $defaultName = $prefix + ' ' + $ip
    if ($script:ArgName) {
        $printerName = $script:ArgName
    } else {
        $printerName = $defaultName
    }

    if (-not $script:NonInteractive) {
        $null = Test-PrinterReachable $ip
    } else {
        Write-Info ("非互動模式：IP=$ip  Name=$printerName")
    }

    if ($IsWindowsOs) {
        Install-CloudDriverWindows -Driver $driver -Ip $ip -PrinterName $printerName
    } else {
        Install-CloudDriverMock -Driver $driver -Ip $ip -PrinterName $printerName
    }
} catch {
    Write-ErrMsg ('安裝失敗：' + $_.Exception.Message)
    if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    exit 1
}
