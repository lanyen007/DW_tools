# 移除 lanyen.de 下載管理、桌面捷徑和開始功能表捷徑。
$root = Join-Path $env:LOCALAPPDATA 'lanyen\DownloadEditor'
if (Test-Path -LiteralPath $root) {
    Remove-Item -LiteralPath $root -Recurse -Force
}
$desktop = [Environment]::GetFolderPath('Desktop')
$start = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
foreach ($folder in @($desktop, $start)) {
    $link = Join-Path $folder 'lanyen.de 下載管理.lnk'
    if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
}
$parent = Join-Path $env:LOCALAPPDATA 'lanyen'
if ((Test-Path -LiteralPath $parent) -and -not (Get-ChildItem -LiteralPath $parent -Force | Select-Object -First 1)) {
    Remove-Item -LiteralPath $parent -Force
}
Write-Host '已移除 lanyen.de 下載管理。'
