# Ricoh user-code prompt, loaded as UTF-8 by the ASCII bootstraps and prepended
# to the FLGPQT install script. Windows has no documented Set-PrintConfiguration
# field for the driver User Code, so this only opens Printing Preferences.

function Test-RicohWindowsHost {
    try {
        if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { return $false }
    } catch {}
    try {
        if ($env:OS -notmatch 'Windows' -and $PSVersionTable.Platform -eq 'Unix') { return $false }
    } catch {}
    return $true
}

function Invoke-RicohUserCodePrompt {
    param([Parameter(Mandatory = $true)][string]$PrinterName)
    if ([string]::IsNullOrWhiteSpace($PrinterName)) { return }
    $code = ''
    try {
        Write-Host ''
        $entered = Read-Host '使用者代碼（可留白跳過）'
        if ($null -ne $entered) { $code = $entered.Trim() }
    } catch {
        return
    }
    if ([string]::IsNullOrWhiteSpace($code)) { return }
    Write-Host ''
    Write-Host '請把使用者代碼貼上或輸入到：' -ForegroundColor Yellow
    Write-Host '  列印喜好設定 → 工作設定 → 使用者代碼' -ForegroundColor Yellow
    Write-Host ('使用者代碼：' + $code) -ForegroundColor Green
    if (-not (Test-RicohWindowsHost)) { return }
    Write-Host ('正在開啟「' + $PrinterName + '」的列印喜好設定…') -ForegroundColor Cyan
    try {
        $quoted = $PrinterName.Replace('"', '')
        Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /e /n "' + $quoted + '"') -Wait
    } catch {
        $msg = '無法開啟列印喜好設定：' + $_.Exception.Message
        if (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue) { Write-WarnMsg $msg }
        else { Write-Host $msg -ForegroundColor Yellow }
        Write-Host '請自行開啟這台印表機的列印喜好設定，到「工作設定」貼上使用者代碼。' -ForegroundColor Yellow
    }
}

function Invoke-RicohUserCodeAfterInstall {
    param(
        $Driver,
        [string]$PrinterName,
        [switch]$Force
    )
    $ricoh = [bool]$Force
    if (-not $ricoh -and $null -ne $Driver) {
        $ricoh = [string]$Driver.brand -match '^(?i)Ricoh$'
    }
    if (-not $ricoh) { return }
    try {
        Invoke-RicohUserCodePrompt -PrinterName $PrinterName
    } catch {
        $msg = '使用者代碼提示失敗：' + $_.Exception.Message
        if (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue) { Write-WarnMsg $msg }
        else { Write-Host $msg -ForegroundColor Yellow }
    }
}

function Write-FlgUserCodeHookMiss([string]$What) {
    Write-Host ('使用者代碼提示沒有掛上（' + $What + '）。安裝仍會繼續。') -ForegroundColor Yellow
}

function Add-FlgRicohUserCodeHooks {
    param(
        [Parameter(Mandatory = $true)][string]$Script,
        [Parameter(Mandatory = $true)][string]$PromptScript,
        [Parameter(Mandatory = $true)][ValidateSet('ricoh', 'scan', 'auto')][string]$Kind
    )
    $text = $Script
    $elevUrl = 'https://lanyen.de/ricoh'
    if ($Kind -eq 'scan') { $elevUrl = 'https://lanyen.de/scan' }
    elseif ($Kind -eq 'auto') { $elevUrl = 'https://lanyen.de/auto' }
    $newElev = "    `$null = Request-Elevation '$elevUrl' @args"
    if ($Kind -eq 'ricoh') {
        $oldInstall = '        Install-CloudDriverWindows -Driver $driver -Ip $ip -PrinterName $printerName'
        $addInstall = '        if (Get-Command Invoke-RicohUserCodeAfterInstall -ErrorAction SilentlyContinue) { Invoke-RicohUserCodeAfterInstall -Driver $driver -PrinterName $printerName }'
        $jobs = @(
            @{ Name = 'cloud-elevation'; Old = '    $null = Request-Elevation $BootstrapUrl @args'; New = $newElev },
            @{ Name = 'cloud-install'; Old = $oldInstall; New = ($oldInstall + "`n" + $addInstall) }
        )
    } else {
        $oldModel = '            Install-RicohModelDriverPackage -DriverName ([string]$resolved.RicohDriverName) -PackageId ([string]$resolved.RicohPackageId) -Ip $Ip -PrinterName $printerName'
        $addModel = '            if (Get-Command Invoke-RicohUserCodeAfterInstall -ErrorAction SilentlyContinue) { Invoke-RicohUserCodeAfterInstall -PrinterName $printerName -Force }'
        $oldEnd = '    if (-not $SkipAfterMenu -and -not ($Install -and ($resolved.FujiOld -or $resolved.RicohModel))) { Show-AfterMenu $downloaded }'
        $addEnd = '    if ($Install -and -not $resolved.RicohModel -and $resolved.Brand -match ''^(?i)Ricoh$'' -and (Get-Command Invoke-RicohUserCodeAfterInstall -ErrorAction SilentlyContinue)) { Invoke-RicohUserCodeAfterInstall -PrinterName $printerName -Force }'
        $jobs = @(
            @{ Name = 'auto-elevation'; Old = '    $null = Request-Elevation ($PagesBase + $boot) @args'; New = $newElev },
            @{ Name = 'ricoh-model'; Old = $oldModel; New = ($oldModel + "`n" + $addModel) },
            @{ Name = 'ricoh-universal'; Old = $oldEnd; New = ($oldEnd + "`n" + $addEnd) }
        )
    }
    foreach ($job in $jobs) {
        $old = [string]$job.Old
        $count = 0
        $start = 0
        while ($true) {
            $i = $text.IndexOf($old, $start)
            if ($i -lt 0) { break }
            $count++
            $start = $i + $old.Length
        }
        if ($count -eq 1) {
            $text = $text.Replace($old, [string]$job.New)
        } else {
            Write-FlgUserCodeHookMiss ([string]$job.Name + ' x' + $count)
        }
    }
    $prompt = $PromptScript
    if ($prompt.Length -gt 0 -and [int][char]$prompt[0] -eq 0xFEFF) { $prompt = $prompt.Substring(1) }
    return ($prompt + "`n" + $text)
}
