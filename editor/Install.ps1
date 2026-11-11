# 安裝 lanyen.de 下載管理。
# 正式環境：
# $b=(New-Object Net.WebClient).DownloadData('https://raw.githubusercontent.com/lanyen007/DW_tools/main/editor/Install.ps1');$t=[Text.Encoding]::UTF8.GetString($b);if($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF){$t=$t.Substring(1)};Invoke-Expression $t
# 合併前從分支測試時，先設定 $LanyenEditorRef，網址裡的分支名稱也要相同。
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ref = 'main'
if (Get-Variable -Name LanyenEditorRef -ErrorAction SilentlyContinue) {
    if (-not [string]::IsNullOrWhiteSpace([string]$LanyenEditorRef)) { $ref = [string]$LanyenEditorRef }
}
$root = Join-Path $env:LOCALAPPDATA 'lanyen\DownloadEditor'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $true
$client = New-Object System.Net.WebClient
$client.Encoding = [System.Text.Encoding]::UTF8
$names = @('EditorLib.ps1', 'DownloadEditor.ps1', 'Uninstall.ps1')
foreach ($name in $names) {
    $url = "https://raw.githubusercontent.com/lanyen007/DW_tools/$ref/editor/$name"
    $bytes = $client.DownloadData($url)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    [System.IO.File]::WriteAllText((Join-Path $root $name), $text, $utf8)
}
$client.Dispose()

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) { $exe = $pwsh.Source } else { $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
$target = Join-Path $root 'DownloadEditor.ps1'
$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$start = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
foreach ($folder in @($desktop, $start)) {
    $link = $shell.CreateShortcut((Join-Path $folder 'lanyen.de 下載管理.lnk'))
    $link.TargetPath = $exe
    $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$target`""
    $link.WorkingDirectory = $root
    $link.Description = '編輯 lanyen.de 下載頁'
    $link.Save()
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host '已安裝到' $root
    Write-Host '找不到 gh。請安裝 GitHub CLI（https://cli.github.com/），再執行 gh auth login，並使用 lanyen007 帳號。沒有登入時無法儲存或上傳。'
    return
}
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$login = & gh api user --jq .login 2>&1 | ForEach-Object { $_.ToString() }
$code = $LASTEXITCODE
$ErrorActionPreference = $previous
Write-Host '已安裝到' $root
Write-Host '桌面和開始功能表已建立「lanyen.de 下載管理」。'
Write-Host '移除方式：powershell -NoProfile -ExecutionPolicy Bypass -File "'$target.Replace('DownloadEditor.ps1','Uninstall.ps1')'"'
if ($code -ne 0) {
    Write-Host 'gh 尚未登入。請執行 gh auth login，並使用 lanyen007 帳號。'
} else {
    $name = ($login -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1).Trim()
    if ($name -ne 'lanyen007') {
        Write-Host "目前 gh 登入的是 $name，不是 lanyen007。儲存前請先 gh auth login。"
    } else {
        Write-Host 'gh 已使用 lanyen007 登入。'
    }
}
