# 下載頁設定的讀寫、合併與 GitHub 發布。不含視窗。
# 由 DownloadEditor.ps1 載入。Windows PowerShell 5.1 與 PowerShell 7 都可用。
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$script:LanyenRepo = 'lanyen007/DW_tools'
$script:LanyenConfigApi = 'repos/lanyen007/DW_tools/contents/downloads.json'
$script:LanyenMaxUpload = 2GB
$script:LanyenDefaultCategories = @(
    @{ id = 'toolbox'; titleZh = '工具'; titleEn = 'Tools' },
    @{ id = 'cloud'; titleZh = '雲端通用驅動'; titleEn = 'Cloud universal drivers' },
    @{ id = 'fuji-old'; titleZh = '舊版 FUJI'; titleEn = 'Legacy FUJI' },
    @{ id = 'common-tools'; titleZh = '常用工具'; titleEn = 'Common tools' },
    @{ id = 'github-models'; titleZh = '其他 GitHub 驅動'; titleEn = 'Other GitHub drivers' }
)

function New-LanyenEmptyConfig {
    return @{
        version = 1
        categories = (New-Object System.Collections.ArrayList)
        order = @{}
        hidden = (New-Object System.Collections.ArrayList)
        overrides = @{}
        custom = (New-Object System.Collections.ArrayList)
    }
}

function ConvertTo-LanyenPlain {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -or $Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $map = @{}
        foreach ($key in @($Value.Keys)) {
            $map[[string]$key] = ConvertTo-LanyenPlain $Value[$key]
        }
        return $map
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $Value) {
            [void]$list.Add((ConvertTo-LanyenPlain $item))
        }
        return $list
    }
    $map = @{}
    foreach ($prop in $Value.PSObject.Properties) {
        $map[$prop.Name] = ConvertTo-LanyenPlain $prop.Value
    }
    return $map
}

function ConvertFrom-LanyenConfigText {
    param([string]$Text)
    $config = New-LanyenEmptyConfig
    if ([string]::IsNullOrWhiteSpace($Text)) { return $config }
    $parsed = ConvertTo-LanyenPlain ($Text | ConvertFrom-Json)
    if ($parsed.ContainsKey('version')) { $config.version = $parsed.version }
    if ($parsed.categories) {
        foreach ($row in @($parsed.categories)) { [void]$config.categories.Add($row) }
    }
    if ($parsed.hidden) {
        foreach ($row in @($parsed.hidden)) { [void]$config.hidden.Add([string]$row) }
    }
    if ($parsed.overrides) { $config.overrides = $parsed.overrides }
    if ($parsed.order) { $config.order = $parsed.order }
    if ($parsed.custom) {
        foreach ($row in @($parsed.custom)) { [void]$config.custom.Add($row) }
    }
    return $config
}

function ConvertTo-LanyenJsonLiteral {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) {
        if ($Value) { return 'true' }
        return 'false'
    }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [decimal]) {
        return ([string]$Value)
    }
    if ($Value -is [double]) {
        if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return 'null' }
        return ([string]$Value)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = New-Object System.Collections.ArrayList
        foreach ($key in @($Value.Keys | Sort-Object)) {
            [void]$parts.Add(((ConvertTo-LanyenJsonLiteral ([string]$key)) + ':' + (ConvertTo-LanyenJsonLiteral $Value[$key])))
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $parts = New-Object System.Collections.ArrayList
        foreach ($item in $Value) {
            [void]$parts.Add((ConvertTo-LanyenJsonLiteral $item))
        }
        return '[' + ($parts -join ',') + ']'
    }
    $text = [string]$Value
    $text = $text.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
    return '"' + $text + '"'
}

function ConvertTo-LanyenConfigJson {
    param($Config)
    $root = [ordered]@{
        version = 1
        categories = @($Config.categories)
        order = $Config.order
        hidden = @($Config.hidden)
        overrides = $Config.overrides
        custom = @($Config.custom)
    }
    return (ConvertTo-LanyenJsonLiteral $root)
}

function Test-LanyenGithubFileUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    try { $parsed = [Uri]$Url } catch { return $false }
    if ($parsed.Scheme -ne 'https') { return $false }
    $hostName = $parsed.Host.ToLowerInvariant()
    $path = $parsed.AbsolutePath
    if ($hostName -eq 'raw.githubusercontent.com') {
        return [bool]($path -match '\.[A-Za-z0-9]{1,8}$')
    }
    if ($hostName -ne 'github.com') { return $false }
    if ($path -match '/releases/download/[^/]+/[^/]+\.[A-Za-z0-9]{1,8}$') { return $true }
    if ($path -match '/raw/.+\.[A-Za-z0-9]{1,8}$') { return $true }
    return $false
}

function Get-LanyenText {
    param([string]$Url)
    $client = New-Object System.Net.WebClient
    $client.Encoding = [System.Text.Encoding]::UTF8
    $client.Headers['User-Agent'] = 'lanyen-de-editor'
    try { return $client.DownloadString($Url) }
    finally { $client.Dispose() }
}

function Get-LanyenMapValue {
    param($Map, [string]$Key)
    if ($null -eq $Map) { return $null }
    if ($Map -is [System.Collections.IDictionary]) {
        if ($Map.ContainsKey($Key)) { return $Map[$Key] }
        return $null
    }
    $prop = $Map.PSObject.Properties[$Key]
    if ($prop) { return $prop.Value }
    return $null
}

function Add-LanyenGenerated {
    param($List, [string]$Category, [string]$Name, [string]$Brand, [string]$Version, [string]$Url, [string]$Filename, $Size)
    if (-not (Test-LanyenGithubFileUrl $Url)) { return }
    [void]$List.Add([pscustomobject]@{
        Category = $Category
        Name = $Name
        Brand = $Brand
        Version = $Version
        Url = $Url
        Filename = $Filename
        Size = $Size
    })
}

function Get-LanyenVersionText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $match = [regex]::Match($Text, '\d+\.\d+\.\d+(?:\.\d+)?')
    if ($match.Success) { return $match.Value }
    return ''
}

function Convert-LanyenSourcesToItems {
    param($PqtVersion, $CounterVersion, $Cloud, $FujiOld, $Ricoh, $Fuji, $Sharp, [string]$ToolsText)
    $items = New-Object System.Collections.ArrayList
    if ($PqtVersion) {
        $url = [string](Get-LanyenMapValue $PqtVersion 'url')
        if (-not (Test-LanyenGithubFileUrl $url)) { $url = 'https://raw.githubusercontent.com/lanyen007/DW_tools/main/PQT.exe' }
        Add-LanyenGenerated $items 'toolbox' 'PQT.exe' 'PQT' ([string](Get-LanyenMapValue $PqtVersion 'version')) $url 'PQT.exe' $null
    }
    if ($CounterVersion) {
        $url = [string](Get-LanyenMapValue $CounterVersion 'url')
        if (-not (Test-LanyenGithubFileUrl $url)) { $url = 'https://raw.githubusercontent.com/lanyen007/DW_tools/main/UserCounterDownload.exe' }
        Add-LanyenGenerated $items 'toolbox' 'RICOH 使用者計數下載' 'RICOH' ([string](Get-LanyenMapValue $CounterVersion 'version')) $url 'UserCounterDownload.exe' $null
    }
    $drivers = Get-LanyenMapValue $Cloud 'drivers'
    foreach ($driver in @($drivers)) {
        if (-not $driver) { continue }
        $url = [string](Get-LanyenMapValue $driver 'url')
        Add-LanyenGenerated $items 'cloud' ([string](Get-LanyenMapValue $driver 'title')) ([string](Get-LanyenMapValue $driver 'brand')) ([string](Get-LanyenMapValue $driver 'version')) $url ([string](Get-LanyenMapValue $driver 'zip_name')) (Get-LanyenMapValue $driver 'size')
    }
    $old = Get-LanyenMapValue $FujiOld 'drivers'
    foreach ($driver in @($old)) {
        if (-not $driver) { continue }
        $url = [string](Get-LanyenMapValue $driver 'url')
        $title = [string](Get-LanyenMapValue $driver 'title')
        Add-LanyenGenerated $items 'fuji-old' $title 'FUJIFILM' (Get-LanyenVersionText $title) $url ([string](Get-LanyenMapValue $driver 'filename')) $null
    }
    if ($ToolsText) {
        $tagMatch = [regex]::Match($ToolsText, "\`$ReleaseTag\s*=\s*'([^']+)'")
        $tag = ''
        if ($tagMatch.Success) { $tag = $tagMatch.Groups[1].Value }
        $pattern = "Key\s*=\s*'([^']+)'[\s\S]*?File\s*=\s*'([^']+)'[\s\S]*?Title\s*=\s*'([^']+)'[\s\S]*?Size\s*=\s*(\d+)L[\s\S]*?Note\s*=\s*'([^']*)'"
        $matches = [regex]::Matches($ToolsText, $pattern)
        foreach ($tool in $matches) {
            $file = $tool.Groups[2].Value
            $title = $tool.Groups[3].Value
            $brand = '工具'
            $lower = ($title + ' ' + $file).ToLowerInvariant()
            if ($lower.Contains('sharp') -or $lower.Contains('nst')) { $brand = 'Sharp' }
            elseif ($lower.Contains('qserver')) { $brand = 'QServer' }
            $version = Get-LanyenVersionText ($title + ' ' + $tool.Groups[5].Value)
            if (-not $version) {
                $loose = [regex]::Match($title, '\d+\.\d+')
                if ($loose.Success) { $version = $loose.Value }
            }
            $url = ''
            if ($tag) { $url = "https://github.com/lanyen007/FLGPQT/releases/download/$tag/$file" }
            Add-LanyenGenerated $items 'common-tools' $title $brand $version $url $file ([int]$tool.Groups[4].Value)
        }
    }
    $grouped = @{}
    foreach ($pair in @(
        @{ Data = $Ricoh; Brand = 'Ricoh' },
        @{ Data = $Sharp; Brand = 'Sharp' },
        @{ Data = $Fuji; Brand = 'FUJIFILM' }
    )) {
        $brand = [string](Get-LanyenMapValue $pair.Data 'brand')
        if ([string]::IsNullOrWhiteSpace($brand)) { $brand = $pair.Brand }
        foreach ($driver in @(Get-LanyenMapValue $pair.Data 'drivers')) {
            if (-not $driver) { continue }
            $url = [string](Get-LanyenMapValue $driver 'url')
            if (-not (Test-LanyenGithubFileUrl $url)) { continue }
            if (-not $grouped.ContainsKey($url)) {
                $file = [string](Get-LanyenMapValue $driver 'filename')
                if ([string]::IsNullOrWhiteSpace($file)) { $file = [IO.Path]::GetFileName($url) }
                $grouped[$url] = @{
                    Url = $url
                    Brand = $brand
                    Filename = $file
                    Title = [string](Get-LanyenMapValue $driver 'title')
                    Version = Get-LanyenVersionText (([string](Get-LanyenMapValue $driver 'title')) + ' ' + ([string](Get-LanyenMapValue $driver 'notes')))
                    Models = New-Object System.Collections.ArrayList
                }
            }
            $model = [string](Get-LanyenMapValue $driver 'model')
            if ($model -and -not $grouped[$url].Models.Contains($model)) {
                [void]$grouped[$url].Models.Add($model)
            }
        }
    }
    foreach ($url in @($grouped.Keys)) {
        $group = $grouped[$url]
        $name = $group.Filename
        if ($group.Models.Count -eq 1 -and $group.Title) { $name = $group.Title }
        Add-LanyenGenerated $items 'github-models' $name $group.Brand $group.Version $group.Url $group.Filename $null
    }
    return @($items.ToArray())
}

function Get-LanyenGeneratedItems {
    $base = 'https://raw.githubusercontent.com/lanyen007'
    $pqt = ConvertTo-LanyenPlain (Get-LanyenText "$base/DW_tools/main/version.json" | ConvertFrom-Json)
    $counter = ConvertTo-LanyenPlain (Get-LanyenText "$base/DW_tools/main/UserCounterDownload_version.json" | ConvertFrom-Json)
    $cloud = ConvertTo-LanyenPlain (Get-LanyenText "$base/FLGPQT/main/drivers/cloud.json" | ConvertFrom-Json)
    $fujiOld = ConvertTo-LanyenPlain (Get-LanyenText "$base/FLGPQT/main/drivers/fuji-old.json" | ConvertFrom-Json)
    $ricoh = ConvertTo-LanyenPlain (Get-LanyenText "$base/FLGPQT/main/drivers/ricoh.json" | ConvertFrom-Json)
    $fuji = ConvertTo-LanyenPlain (Get-LanyenText "$base/FLGPQT/main/drivers/fuji.json" | ConvertFrom-Json)
    $sharp = ConvertTo-LanyenPlain (Get-LanyenText "$base/FLGPQT/main/drivers/sharp.json" | ConvertFrom-Json)
    $tools = Get-LanyenText "$base/FLGPQT/main/drivers/tools-main.ps1"
    return Convert-LanyenSourcesToItems -PqtVersion $pqt -CounterVersion $counter -Cloud $cloud -FujiOld $fujiOld -Ricoh $ricoh -Fuji $fuji -Sharp $sharp -ToolsText $tools
}

function Get-LanyenCategoryOrder {
    param($Config, $Rows)
    $ids = New-Object System.Collections.ArrayList
    if (@($Config.categories).Count -gt 0) {
        foreach ($row in @($Config.categories)) {
            $id = [string](Get-LanyenMapValue $row 'id')
            if ($id -and -not $ids.Contains($id)) { [void]$ids.Add($id) }
        }
    } else {
        foreach ($row in $script:LanyenDefaultCategories) { [void]$ids.Add($row.id) }
    }
    foreach ($row in @($Rows)) {
        if ($row.Category -and -not $ids.Contains([string]$row.Category)) { [void]$ids.Add([string]$row.Category) }
    }
    return @($ids.ToArray())
}

function Get-LanyenEditorRows {
    param($Generated, $Config)
    $rows = New-Object System.Collections.ArrayList
    $seq = 0
    foreach ($item in @($Generated)) {
        $override = Get-LanyenMapValue $Config.overrides ([string]$item.Url)
        $category = [string]$item.Category
        $name = [string]$item.Name
        $brand = [string]$item.Brand
        $version = [string]$item.Version
        $url = [string]$item.Url
        $filename = [string]$item.Filename
        $note = ''
        $size = $item.Size
        if ($override) {
            $ovCategory = Get-LanyenMapValue $override 'category'
            $ovName = Get-LanyenMapValue $override 'name'
            $ovBrand = Get-LanyenMapValue $override 'brand'
            $ovVersion = Get-LanyenMapValue $override 'version'
            $ovUrl = Get-LanyenMapValue $override 'url'
            $ovFile = Get-LanyenMapValue $override 'filename'
            $ovNote = Get-LanyenMapValue $override 'note'
            if ($ovCategory) { $category = [string]$ovCategory }
            if ($ovName) { $name = [string]$ovName }
            if ($ovBrand) { $brand = [string]$ovBrand }
            if ($ovVersion) { $version = [string]$ovVersion }
            if ($ovUrl -and (Test-LanyenGithubFileUrl ([string]$ovUrl))) { $url = [string]$ovUrl }
            if ($ovFile) { $filename = [string]$ovFile }
            if ($null -ne $ovNote) { $note = [string]$ovNote }
            if ($override -is [System.Collections.IDictionary] -and $override.ContainsKey('size') -and $null -ne $override['size']) {
                $size = $override['size']
            } elseif ($url -ne [string]$item.Url) {
                $size = $null
            }
        }
        $hidden = @($Config.hidden) -contains [string]$item.Url
        [void]$rows.Add([pscustomobject]@{
            Key = [string]$item.Url
            OriginUrl = [string]$item.Url
            Source = 'generated'
            CustomId = ''
            Category = $category
            Name = $name
            Brand = $brand
            Version = $version
            Url = $url
            Note = $note
            Filename = $filename
            Size = $size
            Hidden = [bool]$hidden
            BaseCategory = [string]$item.Category
            BaseName = [string]$item.Name
            BaseBrand = [string]$item.Brand
            BaseVersion = [string]$item.Version
            BaseUrl = [string]$item.Url
            BaseFilename = [string]$item.Filename
            Seq = $seq
        })
        $seq += 1
    }
    foreach ($custom in @($Config.custom)) {
        $id = [string](Get-LanyenMapValue $custom 'id')
        if (-not $id) { continue }
        [void]$rows.Add([pscustomobject]@{
            Key = "custom:$id"
            OriginUrl = ''
            Source = 'custom'
            CustomId = $id
            Category = [string](Get-LanyenMapValue $custom 'category')
            Name = [string](Get-LanyenMapValue $custom 'name')
            Brand = [string](Get-LanyenMapValue $custom 'brand')
            Version = [string](Get-LanyenMapValue $custom 'version')
            Url = [string](Get-LanyenMapValue $custom 'url')
            Note = [string](Get-LanyenMapValue $custom 'note')
            Filename = [string](Get-LanyenMapValue $custom 'filename')
            Size = Get-LanyenMapValue $custom 'size'
            Hidden = $false
            BaseCategory = ''
            BaseName = ''
            BaseBrand = ''
            BaseVersion = ''
            BaseUrl = ''
            BaseFilename = ''
            Seq = $seq
        })
        $seq += 1
    }
    $ordered = New-Object System.Collections.ArrayList
    foreach ($category in @(Get-LanyenCategoryOrder $Config @($rows.ToArray()))) {
        $group = @($rows | Where-Object { $_.Category -eq $category })
        $listed = Get-LanyenMapValue $Config.order $category
        if ($listed) {
            $rank = @{}
            $index = 0
            foreach ($key in @($listed)) {
                $rank[[string]$key] = $index
                $index += 1
            }
            $group = @($group | Sort-Object @{ Expression = {
                if ($rank.ContainsKey([string]$_.Key)) { return $rank[[string]$_.Key] }
                return 100000 + $_.Seq
            } })
        }
        foreach ($row in $group) { [void]$ordered.Add($row) }
    }
    return @($ordered.ToArray())
}

function Ensure-LanyenOverride {
    param($Config, [string]$OriginUrl)
    if (-not $Config.overrides.ContainsKey($OriginUrl)) {
        $Config.overrides[$OriginUrl] = @{}
    }
    return $Config.overrides[$OriginUrl]
}

function Set-LanyenRowFields {
    param($Config, $Row, [hashtable]$Fields)
    if ($Row.Source -eq 'custom') {
        $target = $null
        foreach ($item in @($Config.custom)) {
            if ([string](Get-LanyenMapValue $item 'id') -eq $Row.CustomId) { $target = $item; break }
        }
        if (-not $target) { return }
        foreach ($key in @($Fields.Keys)) {
            $jsonKey = $key.Substring(0, 1).ToLowerInvariant() + $key.Substring(1)
            if ($key -eq 'Category') { $jsonKey = 'category' }
            if ($key -eq 'Name') { $jsonKey = 'name' }
            if ($key -eq 'Brand') { $jsonKey = 'brand' }
            if ($key -eq 'Version') { $jsonKey = 'version' }
            if ($key -eq 'Url') { $jsonKey = 'url' }
            if ($key -eq 'Note') { $jsonKey = 'note' }
            if ($key -eq 'Filename') { $jsonKey = 'filename' }
            if ($key -eq 'Size') { $jsonKey = 'size' }
            $target[$jsonKey] = $Fields[$key]
        }
        return
    }
    $override = Ensure-LanyenOverride $Config $Row.OriginUrl
    $pairs = @{
        Category = 'category'; Name = 'name'; Brand = 'brand'; Version = 'version'
        Url = 'url'; Note = 'note'; Filename = 'filename'; Size = 'size'
    }
    $bases = @{
        Category = $Row.BaseCategory; Name = $Row.BaseName; Brand = $Row.BaseBrand
        Version = $Row.BaseVersion; Url = $Row.BaseUrl; Filename = $Row.BaseFilename
        Note = ''; Size = $null
    }
    foreach ($key in @($Fields.Keys)) {
        if (-not $pairs.ContainsKey($key)) { continue }
        $value = $Fields[$key]
        if ($key -eq 'Url' -and $value -and -not (Test-LanyenGithubFileUrl ([string]$value))) {
            throw '網址必須是 GitHub 上的檔案（raw 或 Release 下載連結）。'
        }
        if ($key -eq 'Size') {
            if ($null -eq $value -or [string]$value -eq '') {
                if ($override.ContainsKey('size')) { $override.Remove('size') }
            } else {
                $override['size'] = [long]$value
            }
            continue
        }
        $same = ([string]$value) -eq ([string]$bases[$key])
        if ($same) {
            if ($override.ContainsKey($pairs[$key])) { $override.Remove($pairs[$key]) }
        } else {
            $override[$pairs[$key]] = $value
        }
    }
    if ($override.Count -eq 0) { $Config.overrides.Remove($Row.OriginUrl) }
    if ($Fields.ContainsKey('Hidden')) {
        $url = [string]$Row.OriginUrl
        $has = @($Config.hidden) -contains $url
        if ($Fields.Hidden -and -not $has) { [void]$Config.hidden.Add($url) }
        if (-not $Fields.Hidden -and $has) {
            $left = New-Object System.Collections.ArrayList
            foreach ($item in @($Config.hidden)) {
                if ([string]$item -ne $url) { [void]$left.Add($item) }
            }
            $Config.hidden = $left
        }
    }
}

function Move-LanyenRow {
    param($Config, $Rows, [string]$Key, [int]$Delta)
    $row = $Rows | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
    if (-not $row) { return $false }
    $siblings = @($Rows | Where-Object { $_.Category -eq $row.Category })
    $index = 0
    $found = -1
    foreach ($item in $siblings) {
        if ($item.Key -eq $Key) { $found = $index }
        $index += 1
    }
    $target = $found + $Delta
    if ($found -lt 0 -or $target -lt 0 -or $target -ge $siblings.Count) { return $false }
    $keys = New-Object System.Collections.ArrayList
    foreach ($item in $siblings) { [void]$keys.Add([string]$item.Key) }
    $swap = $keys[$target]
    $keys[$target] = $keys[$found]
    $keys[$found] = $swap
    $Config.order[$row.Category] = @($keys.ToArray())
    return $true
}

function Add-LanyenCustomItem {
    param($Config, [string]$Category, [string]$Name)
    $id = 'c' + ([guid]::NewGuid().ToString('n').Substring(0, 8))
    $item = @{
        id = $id
        category = $Category
        name = $Name
        brand = ''
        version = ''
        url = ''
        note = ''
        filename = ''
        size = $null
    }
    [void]$Config.custom.Add($item)
    return $id
}

function Remove-LanyenCustomItem {
    param($Config, [string]$Id)
    $left = New-Object System.Collections.ArrayList
    foreach ($item in @($Config.custom)) {
        if ([string](Get-LanyenMapValue $item 'id') -ne $Id) { [void]$left.Add($item) }
    }
    $Config.custom = $left
}

function Add-LanyenCategory {
    param($Config, $Rows, [string]$TitleZh, [string]$TitleEn)
    if (@($Config.categories).Count -eq 0) {
        $seen = @{}
        foreach ($row in $script:LanyenDefaultCategories) {
            [void]$Config.categories.Add(@{ id = $row.id; titleZh = ''; titleEn = ''; noteZh = $null; noteEn = $null })
            $seen[$row.id] = $true
        }
        foreach ($row in @($Rows)) {
            if ($row.Category -and -not $seen.ContainsKey([string]$row.Category)) {
                [void]$Config.categories.Add(@{ id = [string]$row.Category; titleZh = ''; titleEn = ''; noteZh = $null; noteEn = $null })
                $seen[[string]$row.Category] = $true
            }
        }
    }
    $id = 'cat-' + ([guid]::NewGuid().ToString('n').Substring(0, 8))
    [void]$Config.categories.Add(@{
        id = $id
        titleZh = $TitleZh
        titleEn = $TitleEn
        noteZh = ''
        noteEn = ''
    })
    return $id
}

function Set-LanyenCategoryText {
    param($Config, $Rows, [string]$Id, [string]$TitleZh, [string]$TitleEn, [string]$NoteZh, [string]$NoteEn)
    if (@($Config.categories).Count -eq 0) {
        Add-LanyenCategory $Config $Rows '暫存' 'Temp' | Out-Null
        $Config.categories.RemoveAt($Config.categories.Count - 1)
    }
    $found = $null
    foreach ($row in @($Config.categories)) {
        if ([string](Get-LanyenMapValue $row 'id') -eq $Id) { $found = $row; break }
    }
    if (-not $found) {
        $found = @{ id = $Id; titleZh = ''; titleEn = ''; noteZh = $null; noteEn = $null }
        [void]$Config.categories.Add($found)
    }
    $found.titleZh = $TitleZh
    $found.titleEn = $TitleEn
    $found.noteZh = $NoteZh
    $found.noteEn = $NoteEn
}

function Move-LanyenCategory {
    param($Config, $Rows, [string]$Id, [int]$Delta)
    if (@($Config.categories).Count -eq 0) {
        foreach ($row in $script:LanyenDefaultCategories) {
            [void]$Config.categories.Add(@{ id = $row.id; titleZh = ''; titleEn = ''; noteZh = $null; noteEn = $null })
        }
    }
    $index = -1
    $at = 0
    foreach ($row in @($Config.categories)) {
        if ([string](Get-LanyenMapValue $row 'id') -eq $Id) { $index = $at }
        $at += 1
    }
    $target = $index + $Delta
    if ($index -lt 0 -or $target -lt 0 -or $target -ge @($Config.categories).Count) { return $false }
    $item = $Config.categories[$index]
    $Config.categories.RemoveAt($index)
    $Config.categories.Insert($target, $item)
    return $true
}

function New-LanyenCommitMessage {
    param($Before, $After)
    $beforeCustom = @{}
    foreach ($item in @($Before.custom)) { $beforeCustom[[string](Get-LanyenMapValue $item 'id')] = $true }
    $afterCustom = @{}
    foreach ($item in @($After.custom)) { $afterCustom[[string](Get-LanyenMapValue $item 'id')] = $true }
    $added = 0
    $removed = 0
    foreach ($id in @($afterCustom.Keys)) { if (-not $beforeCustom.ContainsKey($id)) { $added += 1 } }
    foreach ($id in @($beforeCustom.Keys)) { if (-not $afterCustom.ContainsKey($id)) { $removed += 1 } }
    $beforeHidden = @{}
    foreach ($url in @($Before.hidden)) { $beforeHidden[[string]$url] = $true }
    $hiddenAdded = 0
    foreach ($url in @($After.hidden)) { if (-not $beforeHidden.ContainsKey([string]$url)) { $hiddenAdded += 1 } }
    $beforeKeys = @{}
    if ($Before.overrides) { foreach ($key in @($Before.overrides.Keys)) { $beforeKeys[[string]$key] = (ConvertTo-LanyenJsonLiteral $Before.overrides[$key]) } }
    $changed = 0
    if ($After.overrides) {
        foreach ($key in @($After.overrides.Keys)) {
            $now = ConvertTo-LanyenJsonLiteral $After.overrides[$key]
            if (-not $beforeKeys.ContainsKey([string]$key) -or $beforeKeys[[string]$key] -ne $now) { $changed += 1 }
        }
    }
    $parts = New-Object System.Collections.ArrayList
    if ($added -gt 0) { [void]$parts.Add("新增 $added 項") }
    if ($removed -gt 0) { [void]$parts.Add("刪除 $removed 項") }
    if ($hiddenAdded -gt 0) { [void]$parts.Add("隱藏 $hiddenAdded 項") }
    if ($changed -gt 0) { [void]$parts.Add("修改 $changed 項") }
    $beforeOrder = ConvertTo-LanyenJsonLiteral @($Before.categories)
    $afterOrder = ConvertTo-LanyenJsonLiteral @($After.categories)
    $beforeItemOrder = ConvertTo-LanyenJsonLiteral $Before.order
    $afterItemOrder = ConvertTo-LanyenJsonLiteral $After.order
    if ($beforeOrder -ne $afterOrder -or $beforeItemOrder -ne $afterItemOrder) { [void]$parts.Add('調整分類或順序') }
    if ($parts.Count -eq 0) { return '更新下載頁設定' }
    return '更新下載頁設定：' + ($parts -join '、')
}

function Invoke-LanyenGh {
    param([string[]]$GhArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & gh @GhArgs 2>&1 | ForEach-Object { $_.ToString() }
        return @{ Code = $LASTEXITCODE; Text = ($output -join "`n") }
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Test-LanyenGh {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return @{ Ok = $false; Message = "找不到 gh。請先安裝 GitHub CLI：https://cli.github.com/ ，安裝後執行 gh auth login，並使用 lanyen007 帳號。" }
    }
    $result = Invoke-LanyenGh -GhArgs @('api', 'user', '--jq', '.login')
    if ($result.Code -ne 0) {
        return @{ Ok = $false; Message = "gh 尚未登入，或登入已失效。請在 PowerShell 執行 gh auth login，並選擇 lanyen007 帳號（認證會存在 keyring）。`r`n$($result.Text)" }
    }
    $login = ($result.Text -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1).Trim()
    if ($login -ne 'lanyen007') {
        return @{ Ok = $false; Message = "目前 gh 登入的帳號是 $login，不是 lanyen007。請執行 gh auth login 切換帳號後再儲存。" }
    }
    return @{ Ok = $true; Message = '已使用 lanyen007 登入 gh。' }
}

function Get-LanyenRemoteConfig {
    $result = Invoke-LanyenGh -GhArgs @('api', '-H', 'Accept: application/vnd.github+json', ($script:LanyenConfigApi + '?ref=main'))
    if ($result.Code -ne 0) {
        if ($result.Text -match '404') {
            return @{ Config = (New-LanyenEmptyConfig); Sha = ''; Missing = $true }
        }
        throw "讀取 downloads.json 失敗。`r`n$($result.Text)"
    }
    $payload = $result.Text | ConvertFrom-Json
    $bytes = [Convert]::FromBase64String(([string]$payload.content) -replace '\s', '')
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    return @{ Config = (ConvertFrom-LanyenConfigText $text); Sha = [string]$payload.sha; Missing = $false }
}

function Save-LanyenRemoteConfig {
    param($Config, [string]$Sha, [string]$Message)
    $json = ConvertTo-LanyenConfigJson $Config
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $bytes = $utf8.GetBytes($json)
    $body = @{
        message = $Message
        content = [Convert]::ToBase64String($bytes)
        branch = 'main'
    }
    if (-not [string]::IsNullOrWhiteSpace($Sha)) { $body.sha = $Sha }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('lanyen-put-' + [guid]::NewGuid().ToString('n') + '.json')
    [System.IO.File]::WriteAllText($temp, (ConvertTo-LanyenJsonLiteral $body), $utf8)
    try {
        $result = Invoke-LanyenGh -GhArgs @(
            'api', '--method', 'PUT',
            '-H', 'Accept: application/vnd.github+json',
            '-H', 'Content-Type: application/json',
            $script:LanyenConfigApi,
            '--input', $temp
        )
    } finally {
        Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
    }
    $conflict = $result.Code -ne 0 -and $result.Text -match '409'
    $newSha = ''
    if ($result.Code -eq 0) {
        try { $newSha = [string](($result.Text | ConvertFrom-Json).content.sha) } catch {}
    }
    return @{ Ok = ($result.Code -eq 0); Conflict = [bool]$conflict; Sha = $newSha; Error = $result.Text }
}

function Test-LanyenDownloadLink {
    param([string]$Url)
    if (-not (Test-LanyenGithubFileUrl $Url)) {
        return @{ Ok = $false; Status = 0; Size = $null; Error = '網址不是 GitHub 檔案連結。' }
    }
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = 'HEAD'
    $request.UserAgent = 'lanyen-de-editor'
    $request.AllowAutoRedirect = $true
    $request.Timeout = 30000
    try {
        $response = $request.GetResponse()
        try {
            $status = [int]$response.StatusCode
            $size = $response.ContentLength
            if ($size -lt 0) { $size = $null }
            return @{ Ok = ($status -eq 200); Status = $status; Size = $size; Error = '' }
        } finally { $response.Close() }
    } catch [System.Net.WebException] {
        $http = $_.Exception.Response
        if ($http) {
            $status = [int]$http.StatusCode
            $http.Close()
            return @{ Ok = $false; Status = $status; Size = $null; Error = "HTTP $status" }
        }
        return @{ Ok = $false; Status = 0; Size = $null; Error = $_.Exception.Message }
    }
}

function Send-LanyenReleaseFile {
    param([string]$Path, [string]$Tag)
    if ($Tag -notmatch '^[A-Za-z0-9._-]{1,80}$') {
        return @{ Ok = $false; Url = ''; Error = 'Release 標籤只接受英數、點、底線和減號。' }
    }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt $script:LanyenMaxUpload) {
        return @{ Ok = $false; Url = ''; Error = '這個檔案大於 2GB，GitHub Release 無法上傳。' }
    }
    $lookup = Invoke-LanyenGh -GhArgs @('api', "repos/$script:LanyenRepo/releases/tags/$Tag")
    $release = $null
    if ($lookup.Code -eq 0) {
        $release = $lookup.Text | ConvertFrom-Json
    } else {
        $createBody = Join-Path ([IO.Path]::GetTempPath()) ('lanyen-rel-' + [guid]::NewGuid().ToString('n') + '.json')
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $payload = ConvertTo-LanyenJsonLiteral @{
            tag_name = $Tag
            name = $Tag
            body = 'lanyen.de 下載頁上傳的檔案'
        }
        [System.IO.File]::WriteAllText($createBody, $payload, $utf8)
        try {
            $created = Invoke-LanyenGh -GhArgs @(
                'api', '--method', 'POST',
                '-H', 'Accept: application/vnd.github+json',
                '-H', 'Content-Type: application/json',
                "repos/$script:LanyenRepo/releases",
                '--input', $createBody
            )
        } finally {
            Remove-Item -LiteralPath $createBody -ErrorAction SilentlyContinue
        }
        if ($created.Code -ne 0) {
            return @{ Ok = $false; Url = ''; Error = "建立 Release 失敗。`r`n$($created.Text)" }
        }
        $release = $created.Text | ConvertFrom-Json
    }
    $name = $file.Name
    foreach ($asset in @($release.assets)) {
        if ([string]$asset.name -eq $name) {
            Invoke-LanyenGh -GhArgs @('api', '--method', 'DELETE', "repos/$script:LanyenRepo/releases/assets/$($asset.id)") | Out-Null
        }
    }
    $encoded = [Uri]::EscapeDataString($name)
    $uploaded = Invoke-LanyenGh -GhArgs @(
        'api', '--method', 'POST',
        '-H', 'Accept: application/vnd.github+json',
        '-H', 'Content-Type: application/octet-stream',
        "repos/$script:LanyenRepo/releases/$($release.id)/assets?name=$encoded",
        '--input', $file.FullName
    )
    if ($uploaded.Code -ne 0) {
        return @{ Ok = $false; Url = ''; Error = "上傳失敗。`r`n$($uploaded.Text)" }
    }
    $url = "https://github.com/$script:LanyenRepo/releases/download/$Tag/$name"
    return @{ Ok = $true; Url = $url; Error = ''; Size = $file.Length; Filename = $name }
}

function Get-LanyenLiveCatalogText {
    return Get-LanyenText 'https://lanyen.de/downloads.json'
}
