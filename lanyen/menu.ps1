
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try {
    $__flgHit = [Net.HttpWebRequest]::Create('https://abacus.jasoncameron.dev/hit/lanyen-de/menu')
    $__flgHit.Method = 'GET'$__flgHit.Timeout = 2000
    $__flgHit.ReadWriteTimeout = 2000$__flgHit.KeepAlive = $false$__flgHitResp = $__flgHit.GetResponse()$__flgHitResp.Close()
} catch {}
function Get-FlgUiIsZh {
    try {
        $n = [string](Get-UICulture).Name
        if ([string]::IsNullOrWhiteSpace($n)) {$n = [string](Get-Culture).Name }
        if ([string]::IsNullOrWhiteSpace($n)) {$n = [string][CultureInfo]::CurrentUICulture.Name }
        return ($n -match '^(?i)zh')
    } catch {
        try { return ([string](Get-Culture).Name -match '^(?i)zh') } catch { return $true }
    }
}
$script:FlgIsZh = Get-FlgUiIsZh
function Get-FlgT([string]$Zh, [string]$En) {
    if ($script:FlgIsZh) { return $Zh } else { return$En }
}
$flgB = 'https://lanyen007.github.io/FLGPQT/'$flgCloud = @(
    @{ Name = (Get-FlgT '雲端安裝 Ricoh 驅動（輸入 IP 自動建立）' 'Cloud install Ricoh driver (enter IP)'); Url = 'https://lanyen.de/ricoh' },
    @{ Name = (Get-FlgT '雲端安裝 FUJIFILM／全錄 驅動' 'Cloud install FUJIFILM / Xerox driver'); Url = $flgB + 'drivers/cloud-fuji.ps1' },
    @{ Name = (Get-FlgT '雲端安裝 Sharp 驅動' 'Cloud install Sharp driver'); Url = $flgB + 'drivers/cloud-sharp.ps1' },
    @{ Name = (Get-FlgT '雲端安裝 Canon 驅動' 'Cloud install Canon driver'); Url = $flgB + 'drivers/cloud-canon.ps1' },
    @{ Name = (Get-FlgT '雲端安裝 美樂達／KONICA MINOLTA 驅動' 'Cloud install Konica Minolta driver'); Url = $flgB + 'drivers/cloud-konica.ps1' }
)
$flgDl = @(
    @{ Name = (Get-FlgT 'Ricoh 驅動程式下載' 'Ricoh driver download'); Url = $flgB + 'drivers/ricoh.ps1' },
    @{ Name = (Get-FlgT 'FUJIFILM／全錄 驅動程式下載' 'FUJIFILM / Xerox driver download'); Url = $flgB + 'drivers/fuji.ps1' },
    @{ Name = (Get-FlgT 'Sharp 驅動程式下載' 'Sharp driver download'); Url = $flgB + 'drivers/sharp.ps1' },
    @{ Name = (Get-FlgT '舊版 FUJI 驅動（IV／V／DocuCentre／DocuPrint）' 'Legacy FUJI drivers (IV / V / DocuCentre / DocuPrint)'); Url = $flgB + 'drivers/fuji-old.ps1' }
)
$flgScan = @(
    @{ Name = (Get-FlgT '掃描到資料夾（視窗／三廠牌）' 'Scan to folder (GUI / 3 brands)'); Url = $flgB + 'drivers/scan2folder.ps1' },
    @{ Name = (Get-FlgT '簡易 FTP 伺服器' 'Simple FTP server'); Url = $flgB + 'drivers/ftp.ps1' },
    @{ Name = (Get-FlgT '快速建立 SMB 共用資料夾' 'Quick SMB shared folder'); Url = $flgB + 'drivers/smb.ps1' }
)
$flgItems = @(
    @{ Name = (Get-FlgT '自動驅動安裝（區網掃描／SNMP）' 'Auto driver install (LAN scan / SNMP)'); Url = 'https://lanyen.de/scan' },
    @{ Name = (Get-FlgT '雲端影印機安裝' 'Cloud copier install'); Sub = $flgCloud },
    @{ Name = (Get-FlgT '驅動程式下載' 'Driver download'); Sub = $flgDl },
    @{ Name = (Get-FlgT '掃描到電腦（FTP／SMB）' 'Scan to PC (FTP / SMB)'); Sub = $flgScan },
    @{ Name = (Get-FlgT '檔案箱小工具（PQT、可自動更新的使用者計數下載）' 'File box tools (PQT, auto-updating user counter)'); Url = $flgB + 'install.ps1' },
    @{ Name = (Get-FlgT '常用工具下載（QServer／Sharpdesk／NST）' 'Common tools (QServer / Sharpdesk / NST)'); Url = $flgB + 'drivers/tools.ps1' },
    @{ Name = (Get-FlgT '重灌後常用軟體（可勾選安裝）' 'Post-reinstall apps (pick and install)'); Url = $flgB + 'drivers/pc.ps1' }
)
# Hidden menu: only reachable by typing 007 at the main menu prompt (never listed)
$script:FlgHiddenTitle = (Get-FlgT 'RICOH 通訊錄' 'RICOH address book')
$script:FlgHidden = @(
    @{ Name = (Get-FlgT '新增使用者代碼' 'Add user code'); Url = $flgB + 'drivers/ricoh-usercode.ps1' },
    @{ Name = (Get-FlgT '新增使用者 EMAIL' 'Add user email'); Url = $flgB + 'drivers/ricoh-email.ps1' },
    @{ Name = (Get-FlgT '使用者計數下載' 'Download user counters'); Url = $flgB + 'drivers/ricoh-usercounter.ps1' }
)
function Invoke-FlgPick($items,$title, $exitText) {$isMain = [object]::ReferenceEquals($items,$flgItems)
    while ($true) {
        Write-Host ''
        Write-Host ('========== ' + $title + ' ==========') -ForegroundColor Cyan
        for ($i = 0; $i -lt$items.Count; $i++) { Write-Host ('  [{0}] {1}' -f ($i + 1), $items[$i].Name) }
        Write-Host ('  [0] ' + $exitText)
        Write-Host ''
        $c = (Read-Host (Get-FlgT '請輸入編號' 'Enter number')).Trim()
        if ($c -eq '0' -or $c -eq '') { return$null }
        if ($c -eq '007' -and$isMain) { return @{ Name = $script:FlgHiddenTitle; Sub =$script:FlgHidden } }   # hidden entry, not listed
        $n = 0
        if (-not [int]::TryParse($c, [ref]$n) -or$n -lt 1 -or $n -gt$items.Count) { Write-Host (Get-FlgT '無效的編號。' 'Invalid number.') -ForegroundColor Yellow; continue }
        return $items[$n - 1]
    }
}
function Invoke-FlgRunUrl([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return }
    try {
        $flgWc = New-Object Net.WebClient
        $flgCode = [Text.Encoding]::UTF8.GetString($flgWc.DownloadData($Url + '?t=' + [DateTime]::Now.Ticks))$flgCode = $flgCode.TrimStart([char]0xFEFF) & ([scriptblock]::Create($flgCode))
    } catch {
        Write-Host ((Get-FlgT '執行失敗：' 'Failed: ') + $_.Exception.Message) -ForegroundColor Red
    }
}
$env:FLG_FROM_MENU = '1'
try {
    while ($true) {
        $flgSel = Invoke-FlgPick$flgItems (Get-FlgT 'lanyen.de 工具箱' 'lanyen.de Toolkit') (Get-FlgT '離開' 'Exit')
        if ($null -eq$flgSel) { Write-Host (Get-FlgT '已離開。' 'Exited.') ; break }
        if ($flgSel.Open) {
            try {
                Start-Process ([string]$flgSel.Open)
            } catch {
                Write-Host ((Get-FlgT '執行失敗：' 'Failed: ') + $_.Exception.Message) -ForegroundColor Red
            }
            continue
        }
        if ($flgSel.Sub) {
            while ($true) {$flgSub = Invoke-FlgPick $flgSel.Sub ([string]$flgSel.Name) (Get-FlgT '回到上一頁' 'Back')
                if ($null -eq$flgSub) { break }
                Invoke-FlgRunUrl ([string]$flgSub.Url)
            }
            continue
        }
        Invoke-FlgRunUrl ([string]$flgSel.Url)
    }
} finally {
    Remove-Item Env:\FLG_FROM_MENU -ErrorAction SilentlyContinue
}
return
