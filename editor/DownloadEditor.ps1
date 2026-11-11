# lanyen.de 下載管理。Windows PowerShell 5.1 與 PowerShell 7 都可用。
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'EditorLib.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Config = New-LanyenEmptyConfig
$script:Generated = @()
$script:Rows = @()
$script:LoadedJson = ''
$script:Sha = ''
$script:Busy = $false
$script:SelectedKey = ''

function New-LanyenLabel([string]$Text) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $true
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 2)
    return $label
}

function New-LanyenBox {
    $box = New-Object System.Windows.Forms.TextBox
    $box.Dock = 'Top'
    $box.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)
    return $box
}

function Read-LanyenPrompt {
    param([string]$Title, [string]$Label, [string]$Default)
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(420, 130)
    $dialog.Font = $script:UiFont
    $caption = New-Object System.Windows.Forms.Label
    $caption.Text = $Label
    $caption.Location = New-Object System.Drawing.Point(12, 12)
    $caption.AutoSize = $true
    $input = New-Object System.Windows.Forms.TextBox
    $input.Text = $Default
    $input.Location = New-Object System.Drawing.Point(12, 40)
    $input.Width = 390
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = '確定'
    $ok.DialogResult = 'OK'
    $ok.Location = New-Object System.Drawing.Point(230, 80)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = '取消'
    $cancel.DialogResult = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(320, 80)
    $dialog.Controls.AddRange(@($caption, $input, $ok, $cancel))
    $dialog.AcceptButton = $ok
    $dialog.CancelButton = $cancel
    if ($dialog.ShowDialog() -ne 'OK') { return $null }
    return $input.Text
}

function Set-LanyenStatus([string]$Text) {
    $script:Status.Text = $Text
}

function Get-LanyenCurrentRow {
    return @($script:Rows | Where-Object { $_.Key -eq $script:SelectedKey } | Select-Object -First 1)
}

function Save-LanyenFields {
    if ($script:Busy) { return }
    $row = Get-LanyenCurrentRow
    if (-not $row) {
        $node = $script:Tree.SelectedNode
        if ($node -and $node.Tag -like 'category:*') {
            $id = [string]$node.Tag.Substring(9)
            Set-LanyenCategoryText $script:Config $script:Rows $id $script:CatZh.Text $script:CatEn.Text $script:CatNoteZh.Text $script:CatNoteEn.Text
        }
        return
    }
    try {
        $size = $null
        if (-not [string]::IsNullOrWhiteSpace($script:SizeBox.Text)) { $size = [long]$script:SizeBox.Text }
        Set-LanyenRowFields $script:Config $row @{
            Category = [string]$script:CategoryBox.SelectedItem
            Name = $script:NameBox.Text
            Brand = $script:BrandBox.Text
            Version = $script:VersionBox.Text
            Url = $script:UrlBox.Text.Trim()
            Filename = $script:FileBox.Text.Trim()
            Note = $script:NoteBox.Text
            Size = $size
            Hidden = [bool]$script:HiddenBox.Checked
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '無法套用', 'OK', 'Warning') | Out-Null
    }
}

function Update-LanyenTree {
    param([string]$Reselect)
    $script:Busy = $true
    try {
        $script:Rows = @(Get-LanyenEditorRows -Generated $script:Generated -Config $script:Config)
        $query = $script:Search.Text.Trim().ToLowerInvariant()
        $script:Tree.BeginUpdate()
        $script:Tree.Nodes.Clear()
        $script:CategoryBox.Items.Clear()
        foreach ($id in @(Get-LanyenCategoryOrder $script:Config $script:Rows)) {
            [void]$script:CategoryBox.Items.Add($id)
            $title = $id
            foreach ($cat in @($script:Config.categories)) {
                if ([string](Get-LanyenMapValue $cat 'id') -eq $id -and (Get-LanyenMapValue $cat 'titleZh')) {
                    $title = [string](Get-LanyenMapValue $cat 'titleZh')
                }
            }
            if ($title -eq $id) {
                foreach ($known in $script:LanyenDefaultCategories) {
                    if ($known.id -eq $id) { $title = $known.titleZh }
                }
            }
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = $title
            $node.Tag = "category:$id"
            foreach ($row in @($script:Rows | Where-Object { $_.Category -eq $id })) {
                $hay = (($row.Name, $row.Brand, $row.Version, $row.Filename, $row.Url, $row.Note) -join ' ').ToLowerInvariant()
                if ($query -and $hay.IndexOf($query) -lt 0 -and $title.ToLowerInvariant().IndexOf($query) -lt 0) { continue }
                $child = New-Object System.Windows.Forms.TreeNode
                $prefix = ''
                if ($row.Hidden) { $prefix = '（隱藏）' }
                $child.Text = $prefix + $row.Name
                $child.Tag = [string]$row.Key
                [void]$node.Nodes.Add($child)
            }
            if ($query -and $node.Nodes.Count -eq 0) { continue }
            [void]$script:Tree.Nodes.Add($node)
            $node.Expand()
        }
        $script:Tree.EndUpdate()
        if ($Reselect) {
            foreach ($node in $script:Tree.Nodes) {
                if ($node.Tag -eq $Reselect) { $script:Tree.SelectedNode = $node; break }
                foreach ($child in $node.Nodes) {
                    if ([string]$child.Tag -eq $Reselect) { $script:Tree.SelectedNode = $child; break }
                }
            }
        }
    } finally {
        $script:Busy = $false
    }
}

function Show-LanyenSelection {
    $script:Busy = $true
    try {
        $node = $script:Tree.SelectedNode
        $script:ItemPanel.Visible = $false
        $script:CategoryPanel.Visible = $false
        if (-not $node) { return }
        if ($node.Tag -like 'category:*') {
            $id = [string]$node.Tag.Substring(9)
            $script:HideButton.Text = '隱藏'
            $script:CategoryPanel.Visible = $true
            $script:CatId.Text = $id
            $zh = ''
            $en = ''
            $noteZh = ''
            $noteEn = ''
            foreach ($cat in @($script:Config.categories)) {
                if ([string](Get-LanyenMapValue $cat 'id') -eq $id) {
                    $zh = [string](Get-LanyenMapValue $cat 'titleZh')
                    $en = [string](Get-LanyenMapValue $cat 'titleEn')
                    $noteZh = [string](Get-LanyenMapValue $cat 'noteZh')
                    $noteEn = [string](Get-LanyenMapValue $cat 'noteEn')
                }
            }
            if (-not $zh) {
                foreach ($known in $script:LanyenDefaultCategories) {
                    if ($known.id -eq $id) { $zh = $known.titleZh; $en = $known.titleEn }
                }
            }
            $script:CatZh.Text = $zh
            $script:CatEn.Text = $en
            $script:CatNoteZh.Text = $noteZh
            $script:CatNoteEn.Text = $noteEn
            return
        }
        $script:SelectedKey = [string]$node.Tag
        $row = Get-LanyenCurrentRow
        if (-not $row) { return }
        $script:ItemPanel.Visible = $true
        $script:CategoryBox.SelectedItem = $row.Category
        $script:NameBox.Text = $row.Name
        $script:BrandBox.Text = $row.Brand
        $script:VersionBox.Text = $row.Version
        $script:UrlBox.Text = $row.Url
        $script:FileBox.Text = $row.Filename
        if ($null -eq $row.Size) { $script:SizeBox.Text = '' } else { $script:SizeBox.Text = [string]$row.Size }
        $script:NoteBox.Text = $row.Note
        $script:HiddenBox.Checked = [bool]$row.Hidden
        $script:HiddenBox.Enabled = $row.Source -eq 'generated'
        if ($row.Source -eq 'custom') { $script:HideButton.Text = '刪除' } else { $script:HideButton.Text = '隱藏' }
    } finally {
        $script:Busy = $false
    }
}

function Reload-LanyenData {
    Set-LanyenStatus '正在讀取 GitHub 目錄與 downloads.json…'
    $script:Generated = @(Get-LanyenGeneratedItems)
    $remote = Get-LanyenRemoteConfig
    $script:Config = $remote.Config
    $script:Sha = $remote.Sha
    $script:LoadedJson = ConvertTo-LanyenConfigJson $script:Config
    Update-LanyenTree
    $gh = Test-LanyenGh
    if ($gh.Ok) { Set-LanyenStatus $gh.Message } else { Set-LanyenStatus $gh.Message }
}

function Show-LanyenEditor {
    $script:UiFont = New-Object System.Drawing.Font('Microsoft JhengHei UI', 10)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'lanyen.de 下載管理'
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(1100, 720)
    $form.MinimumSize = New-Object System.Drawing.Size(900, 600)
    $form.Font = $script:UiFont

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = 'Fill'
    # Min sizes are set in Add_Shown: the container is only 150px wide until the form lays out.

    $script:Search = New-Object System.Windows.Forms.TextBox
    $script:Search.Dock = 'Top'
    $script:Tree = New-Object System.Windows.Forms.TreeView
    $script:Tree.Dock = 'Fill'
    $script:Tree.HideSelection = $false

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Bottom'
    $buttons.Height = 84
    $buttons.WrapContents = $true
    $names = @('新增項目', '新增分類', '隱藏', '上移', '下移', '檢查連結', '上傳到 Release', '預覽線上', '重新載入', '儲存並發布')
    $script:Buttons = @{}
    foreach ($name in $names) {
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $name
        $button.AutoSize = $true
        $button.Margin = New-Object System.Windows.Forms.Padding(4)
        $button.Tag = $name
        [void]$buttons.Controls.Add($button)
        $script:Buttons[$name] = $button
    }
    $script:HideButton = $script:Buttons['隱藏']

    $left = New-Object System.Windows.Forms.Panel
    $left.Dock = 'Fill'
    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = '搜尋名稱、廠牌、版本或網址'
    $searchLabel.Dock = 'Top'
    $searchLabel.Height = 24
    $left.Controls.Add($script:Tree)
    $left.Controls.Add($buttons)
    $left.Controls.Add($script:Search)
    $left.Controls.Add($searchLabel)
    $split.Panel1.Controls.Add($left)

    $script:ItemPanel = New-Object System.Windows.Forms.Panel
    $script:ItemPanel.Dock = 'Fill'
    $script:ItemPanel.Padding = New-Object System.Windows.Forms.Padding(12)
    $script:ItemPanel.AutoScroll = $true
    $script:CategoryBox = New-Object System.Windows.Forms.ComboBox
    $script:CategoryBox.Dock = 'Top'
    $script:CategoryBox.DropDownStyle = 'DropDownList'
    $script:NameBox = New-LanyenBox
    $script:BrandBox = New-LanyenBox
    $script:VersionBox = New-LanyenBox
    $script:UrlBox = New-LanyenBox
    $script:FileBox = New-LanyenBox
    $script:SizeBox = New-LanyenBox
    $script:NoteBox = New-Object System.Windows.Forms.TextBox
    $script:NoteBox.Dock = 'Top'
    $script:NoteBox.Multiline = $true
    $script:NoteBox.Height = 80
    $script:HiddenBox = New-Object System.Windows.Forms.CheckBox
    $script:HiddenBox.Text = '在下載頁隱藏這個自動產生的項目'
    $script:HiddenBox.Dock = 'Top'
    $script:HiddenBox.Height = 32
    $stack = @(
        (New-LanyenLabel '分類'), $script:CategoryBox,
        (New-LanyenLabel '名稱'), $script:NameBox,
        (New-LanyenLabel '廠牌'), $script:BrandBox,
        (New-LanyenLabel '版本'), $script:VersionBox,
        (New-LanyenLabel '網址'), $script:UrlBox,
        (New-LanyenLabel '檔名'), $script:FileBox,
        (New-LanyenLabel '大小（位元組，空白表示由網站重新取得）'), $script:SizeBox,
        (New-LanyenLabel '說明'), $script:NoteBox,
        $script:HiddenBox
    )
    # Dock=Top lays out the last added control at the top.
    for ($i = $stack.Count - 1; $i -ge 0; $i--) { $script:ItemPanel.Controls.Add($stack[$i]) }

    $script:CategoryPanel = New-Object System.Windows.Forms.Panel
    $script:CategoryPanel.Dock = 'Fill'
    $script:CategoryPanel.Padding = New-Object System.Windows.Forms.Padding(12)
    $script:CategoryPanel.Visible = $false
    $script:CatId = New-LanyenBox
    $script:CatId.ReadOnly = $true
    $script:CatZh = New-LanyenBox
    $script:CatEn = New-LanyenBox
    $script:CatNoteZh = New-LanyenBox
    $script:CatNoteEn = New-LanyenBox
    $catStack = @(
        (New-LanyenLabel '分類代號'), $script:CatId,
        (New-LanyenLabel '中文名稱'), $script:CatZh,
        (New-LanyenLabel '英文名稱'), $script:CatEn,
        (New-LanyenLabel '中文說明'), $script:CatNoteZh,
        (New-LanyenLabel '英文說明'), $script:CatNoteEn
    )
    for ($i = $catStack.Count - 1; $i -ge 0; $i--) { $script:CategoryPanel.Controls.Add($catStack[$i]) }

    $right = New-Object System.Windows.Forms.Panel
    $right.Dock = 'Fill'
    $right.Controls.Add($script:ItemPanel)
    $right.Controls.Add($script:CategoryPanel)
    $split.Panel2.Controls.Add($right)
    $form.Controls.Add($split)

    $script:Status = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = 'MiddleLeft'
    [void]$script:Status.Items.Add($statusLabel)
    $script:Status = $statusLabel
    $bar = $statusLabel.GetCurrentParent()
    $form.Controls.Add($bar)

    $script:Search.Add_TextChanged({ Update-LanyenTree $script:SelectedKey })
    $script:Tree.Add_BeforeSelect({
        if (-not $script:Busy) { Save-LanyenFields }
    })
    $script:Tree.Add_AfterSelect({ Show-LanyenSelection })

    $script:Buttons['新增項目'].Add_Click({
        Save-LanyenFields
        $category = 'toolbox'
        $node = $script:Tree.SelectedNode
        if ($node -and $node.Tag -like 'category:*') { $category = [string]$node.Tag.Substring(9) }
        elseif ($node) {
            $row = Get-LanyenCurrentRow
            if ($row) { $category = $row.Category }
        }
        $name = Read-LanyenPrompt '新增項目' '項目名稱' '新項目'
        if (-not $name) { return }
        $id = Add-LanyenCustomItem $script:Config $category $name
        Update-LanyenTree "custom:$id"
        Show-LanyenSelection
    })
    $script:Buttons['新增分類'].Add_Click({
        Save-LanyenFields
        $name = Read-LanyenPrompt '新增分類' '分類的中文名稱' ''
        if (-not $name) { return }
        $id = Add-LanyenCategory $script:Config $script:Rows $name $name
        Update-LanyenTree "category:$id"
        Show-LanyenSelection
    })
    $script:Buttons['隱藏'].Add_Click({
        $row = Get-LanyenCurrentRow
        if (-not $row) {
            [System.Windows.Forms.MessageBox]::Show('請先選擇一個項目。', '下載管理') | Out-Null
            return
        }
        if ($row.Source -eq 'custom') {
            Remove-LanyenCustomItem $script:Config $row.CustomId
        } else {
            $script:HiddenBox.Checked = -not $script:HiddenBox.Checked
            Save-LanyenFields
        }
        Update-LanyenTree $row.Key
        Show-LanyenSelection
    })
    $script:Buttons['上移'].Add_Click({
        Save-LanyenFields
        $node = $script:Tree.SelectedNode
        if ($node -and $node.Tag -like 'category:*') {
            Move-LanyenCategory $script:Config $script:Rows ([string]$node.Tag.Substring(9)) -1 | Out-Null
            Update-LanyenTree $node.Tag
        } elseif ($script:SelectedKey) {
            Move-LanyenRow $script:Config $script:Rows $script:SelectedKey -1 | Out-Null
            Update-LanyenTree $script:SelectedKey
        }
    })
    $script:Buttons['下移'].Add_Click({
        Save-LanyenFields
        $node = $script:Tree.SelectedNode
        if ($node -and $node.Tag -like 'category:*') {
            Move-LanyenCategory $script:Config $script:Rows ([string]$node.Tag.Substring(9)) 1 | Out-Null
            Update-LanyenTree $node.Tag
        } elseif ($script:SelectedKey) {
            Move-LanyenRow $script:Config $script:Rows $script:SelectedKey 1 | Out-Null
            Update-LanyenTree $script:SelectedKey
        }
    })
    $script:Buttons['檢查連結'].Add_Click({
        Save-LanyenFields
        $row = Get-LanyenCurrentRow
        if (-not $row) {
            [System.Windows.Forms.MessageBox]::Show('請先選擇一個項目。', '下載管理') | Out-Null
            return
        }
        Set-LanyenStatus '正在檢查連結…'
        $result = Test-LanyenDownloadLink $row.Url
        if ($result.Ok) {
            if ($null -ne $result.Size -and $result.Size -ge 0) {
                $script:SizeBox.Text = [string]$result.Size
                Save-LanyenFields
            }
            Set-LanyenStatus ("連結正常，HTTP {0}，大小 {1}。" -f $result.Status, $script:SizeBox.Text)
        } else {
            Set-LanyenStatus ("連結檢查失敗：{0}" -f $result.Error)
            [System.Windows.Forms.MessageBox]::Show($result.Error, '檢查連結', 'OK', 'Warning') | Out-Null
        }
    })
    $script:Buttons['上傳到 Release'].Add_Click({
        $gh = Test-LanyenGh
        if (-not $gh.Ok) {
            [System.Windows.Forms.MessageBox]::Show($gh.Message, '需要 gh', 'OK', 'Warning') | Out-Null
            return
        }
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = '選擇要上傳的檔案'
        if ($dialog.ShowDialog() -ne 'OK') { return }
        $tag = Read-LanyenPrompt '上傳到 GitHub Release' 'Release 標籤（新標籤會自動建立）' 'downloads-uploads'
        if (-not $tag) { return }
        Set-LanyenStatus '正在上傳…'
        $uploaded = Send-LanyenReleaseFile -Path $dialog.FileName -Tag $tag.Trim()
        if (-not $uploaded.Ok) {
            [System.Windows.Forms.MessageBox]::Show($uploaded.Error, '上傳失敗', 'OK', 'Warning') | Out-Null
            Set-LanyenStatus '上傳失敗。'
            return
        }
        $row = Get-LanyenCurrentRow
        if (-not $row) {
            $id = Add-LanyenCustomItem $script:Config 'toolbox' $uploaded.Filename
            Update-LanyenTree "custom:$id"
            Show-LanyenSelection
            $row = Get-LanyenCurrentRow
        }
        $script:UrlBox.Text = $uploaded.Url
        $script:FileBox.Text = $uploaded.Filename
        $script:SizeBox.Text = [string]$uploaded.Size
        if (-not $script:NameBox.Text) { $script:NameBox.Text = $uploaded.Filename }
        Save-LanyenFields
        Update-LanyenTree $row.Key
        Set-LanyenStatus ("已上傳，網址已填入：{0}" -f $uploaded.Url)
    })
    $script:Buttons['預覽線上'].Add_Click({
        try {
            $text = Get-LanyenLiveCatalogText
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '無法讀取線上清單', 'OK', 'Warning') | Out-Null
            return
        }
        $preview = New-Object System.Windows.Forms.Form
        $preview.Text = 'https://lanyen.de/downloads.json'
        $preview.StartPosition = 'CenterParent'
        $preview.ClientSize = New-Object System.Drawing.Size(800, 600)
        $preview.Font = $script:UiFont
        $box = New-Object System.Windows.Forms.TextBox
        $box.Multiline = $true
        $box.ReadOnly = $true
        $box.ScrollBars = 'Both'
        $box.Dock = 'Fill'
        $box.Font = New-Object System.Drawing.Font('Consolas', 9)
        $box.Text = $text
        $preview.Controls.Add($box)
        [void]$preview.ShowDialog($form)
    })
    $script:Buttons['重新載入'].Add_Click({
        try { Reload-LanyenData } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '重新載入失敗', 'OK', 'Warning') | Out-Null
        }
    })
    $script:Buttons['儲存並發布'].Add_Click({
        Save-LanyenFields
        foreach ($item in @($script:Config.custom)) {
            $url = [string](Get-LanyenMapValue $item 'url')
            if (-not (Test-LanyenGithubFileUrl $url)) {
                $name = [string](Get-LanyenMapValue $item 'name')
                [System.Windows.Forms.MessageBox]::Show("「$name」的網址還不是 GitHub 檔案連結，請先填寫或上傳。", '無法儲存', 'OK', 'Warning') | Out-Null
                return
            }
        }
        $gh = Test-LanyenGh
        if (-not $gh.Ok) {
            [System.Windows.Forms.MessageBox]::Show($gh.Message, '需要 gh', 'OK', 'Warning') | Out-Null
            return
        }
        $before = ConvertFrom-LanyenConfigText $script:LoadedJson
        $message = New-LanyenCommitMessage $before $script:Config
        Set-LanyenStatus '正在提交到 DW_tools main…'
        $saved = Save-LanyenRemoteConfig -Config $script:Config -Sha $script:Sha -Message $message
        if ($saved.Conflict) {
            [System.Windows.Forms.MessageBox]::Show('downloads.json 已被其他人更新（sha 衝突）。請按「重新載入」後再修改、儲存。', '請重新載入', 'OK', 'Warning') | Out-Null
            Set-LanyenStatus '儲存衝突，請重新載入。'
            return
        }
        if (-not $saved.Ok) {
            [System.Windows.Forms.MessageBox]::Show($saved.Error, '儲存失敗', 'OK', 'Warning') | Out-Null
            Set-LanyenStatus '儲存失敗。'
            return
        }
        $script:Sha = $saved.Sha
        $script:LoadedJson = ConvertTo-LanyenConfigJson $script:Config
        Set-LanyenStatus ("已提交：{0}" -f $message)
        [System.Windows.Forms.MessageBox]::Show("已寫入 DW_tools 的 main。`r`n$message`r`n網站下載頁稍後會自動更新。", '已發布') | Out-Null
    })

    $form.Add_Shown({
        try {
            $split.Panel1MinSize = 280
            $split.Panel2MinSize = 320
            $split.SplitterDistance = 440
        } catch {}
        try { Reload-LanyenData } catch {
            Set-LanyenStatus $_.Exception.Message
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '載入失敗', 'OK', 'Warning') | Out-Null
        }
    })
    [void]$form.ShowDialog()
}

if ($MyInvocation.InvocationName -ne '.') {
    Show-LanyenEditor
}
