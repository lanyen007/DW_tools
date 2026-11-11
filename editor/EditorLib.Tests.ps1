$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'EditorLib.ps1')

function Assert-Lanyen([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-Lanyen (Test-LanyenGithubFileUrl 'https://github.com/lanyen007/DW_tools/raw/main/PQT.exe') 'github raw'
Assert-Lanyen (Test-LanyenGithubFileUrl 'https://github.com/lanyen007/DW_tools/releases/download/downloads-uploads/PQT.exe') 'release'
Assert-Lanyen (-not (Test-LanyenGithubFileUrl 'https://www.mediafire.com/file/abc/x.exe/file')) 'mediafire'

$generated = @(
    [pscustomobject]@{ Category = 'toolbox'; Name = 'PQT.exe'; Brand = 'PQT'; Version = '4.1.22'; Url = 'https://github.com/lanyen007/DW_tools/raw/main/PQT.exe'; Filename = 'PQT.exe'; Size = 100 },
    [pscustomobject]@{ Category = 'toolbox'; Name = '計數'; Brand = 'RICOH'; Version = '1.0.1'; Url = 'https://github.com/lanyen007/DW_tools/raw/main/UserCounterDownload.exe'; Filename = 'UserCounterDownload.exe'; Size = 50 }
)
$config = New-LanyenEmptyConfig
[void]$config.hidden.Add('https://github.com/lanyen007/DW_tools/raw/main/UserCounterDownload.exe')
$config.overrides['https://github.com/lanyen007/DW_tools/raw/main/PQT.exe'] = @{ name = 'PQT 工具'; brand = 'lanyen' }
[void]$config.custom.Add(@{
    id = 'scan-tool'; category = 'extra'; name = '掃描小工具'; brand = 'Sharp'; version = '1.2'
    url = 'https://github.com/lanyen007/DW_tools/releases/download/downloads-uploads/scan.exe'
    note = '測試用'; filename = 'scan.exe'; size = 4096
})
$rows = @(Get-LanyenEditorRows -Generated $generated -Config $config)
$hidden = @($rows | Where-Object { $_.OriginUrl -like '*UserCounterDownload.exe' })
Assert-Lanyen ($hidden.Count -eq 1 -and $hidden[0].Hidden) 'hidden stays visible in the editor'
$pqt = @($rows | Where-Object { $_.BaseName -eq 'PQT.exe' })[0]
Assert-Lanyen ($pqt.Name -eq 'PQT 工具' -and $pqt.Brand -eq 'lanyen') 'override text'
$custom = @($rows | Where-Object { $_.CustomId -eq 'scan-tool' })[0]
Assert-Lanyen ($custom.Category -eq 'extra' -and $custom.Note -eq '測試用') 'custom row'

$moved = Move-LanyenRow $config $rows $pqt.Key 1
Assert-Lanyen $moved 'move within the category'
Assert-Lanyen ([string]$config.order['toolbox'][0] -like '*UserCounterDownload.exe') 'moved item order'

$round = ConvertFrom-LanyenConfigText (ConvertTo-LanyenConfigJson $config)
Assert-Lanyen ([string](Get-LanyenMapValue $round.custom[0] 'name') -eq '掃描小工具') 'json keeps chinese'
Assert-Lanyen (@($round.hidden) -contains 'https://github.com/lanyen007/DW_tools/raw/main/UserCounterDownload.exe') 'json keeps hidden'

$empty = New-LanyenEmptyConfig
$message = New-LanyenCommitMessage $empty $config
Assert-Lanyen ($message.Contains('新增') -and $message.Contains('隱藏') -and $message.Contains('修改')) $message

$big = $script:LanyenMaxUpload
Assert-Lanyen ($big -eq 2147483648) '2GB limit'
Write-Output 'editor-lib-ok'
