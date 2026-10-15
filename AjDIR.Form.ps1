# (c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
# Project: Ajumbledbox Data Integrity Retention (AjDIR)
# Ownership: AjDIR and the project files created for this project are owned by
# Ajumbledbox / David Groeling unless otherwise stated in a specific file.
# Liability: AjDIR project files, plans, instructions, and future outputs
# are provided "AS IS" without warranty of any kind unless a later project document
# states otherwise.
# Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
# retain their own ownership, copyright, and licensing. AjDIR does not claim
# ownership over third-party tooling.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AjDIRRoot = $PSScriptRoot
$script:PythonExe = Join-Path $script:AjDIRRoot 'runtime\python\python.exe'
$script:PythonScripts = Join-Path $script:AjDIRRoot 'application\python'
$script:EntryFormMutex = $null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$startupReady = $false
try {
    $createdNew = $false
    $script:EntryFormMutex = [System.Threading.Mutex]::new($true, 'Local\AjDIR.EntryForm.Singleton', [ref]$createdNew)
    if (-not $createdNew) {
        [System.Windows.Forms.MessageBox]::Show(
            'The AjDIR entry form is already open.',
            'AjDIR',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        $script:EntryFormMutex.Dispose()
        $script:EntryFormMutex = $null
        return
    }

    $operationLock = Join-Path $script:AjDIRRoot 'core\.ajdir-audit.lock'
    if (Test-Path -LiteralPath $operationLock -PathType Leaf) {
        [System.IO.File]::Delete($operationLock)
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        'AjDIR startup failure',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    if ($null -ne $script:EntryFormMutex) {
        try { $script:EntryFormMutex.ReleaseMutex() } catch { }
        $script:EntryFormMutex.Dispose()
        $script:EntryFormMutex = $null
    }
    return
}

function ConvertTo-CommandLineArgument {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Invoke-AjDIRPython {
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [string[]]$Arguments = @(),
        [AllowNull()][string]$InputText = $null
    )

    if (-not (Test-Path -LiteralPath $script:PythonExe -PathType Leaf)) {
        throw "The private AjDIR Python runtime is missing: $script:PythonExe"
    }

    $scriptPath = Join-Path $script:PythonScripts $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "The AjDIR Python operation is missing: $scriptPath"
    }

    $parts = @((ConvertTo-CommandLineArgument $scriptPath))
    foreach ($argument in $Arguments) {
        $parts += ConvertTo-CommandLineArgument ([string]$argument)
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $script:PythonExe
    $startInfo.Arguments = $parts -join ' '
    $startInfo.WorkingDirectory = $script:AjDIRRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $null -ne $InputText
    $startInfo.EnvironmentVariables['PYTHONUTF8'] = '1'
    $startInfo.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    if ($null -ne $InputText) {
        $process.StandardInput.Write($InputText)
        $process.StandardInput.Close()
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ([string]::IsNullOrWhiteSpace($stdout)) {
        if ([string]::IsNullOrWhiteSpace($stderr)) {
            throw "The Python operation returned no result (exit code $($process.ExitCode))."
        }
        throw $stderr.Trim()
    }

    try {
        $result = $stdout.Trim() | ConvertFrom-Json
    }
    catch {
        throw "The Python operation returned an unreadable result: $($stdout.Trim())"
    }

    if ($process.ExitCode -ne 0 -or -not $result.success) {
        if ($null -ne $result.error) {
            throw [string]$result.error
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            throw $stderr.Trim()
        }
        throw "The Python operation failed with exit code $($process.ExitCode)."
    }

    return $result
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'AjDIR Warehouse'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(980, 700)
$form.MinimumSize = New-Object System.Drawing.Size(996, 739)

$heading = New-Object System.Windows.Forms.Label
$heading.AutoSize = $true
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$heading.Location = New-Object System.Drawing.Point(18, 15)
$heading.Text = 'AjDIR Warehouse'
$form.Controls.Add($heading)

$warehouseLabel = New-Object System.Windows.Forms.Label
$warehouseLabel.AutoSize = $false
$warehouseLabel.Location = New-Object System.Drawing.Point(20, 50)
$warehouseLabel.Size = New-Object System.Drawing.Size(855, 35)
$warehouseLabel.Text = "Select the warehouse or a category. Python performs category, registry, copy and integrity operations.`r`nAjDIR root: $script:AjDIRRoot"
$form.Controls.Add($warehouseLabel)

$tree = New-Object System.Windows.Forms.TreeView
$tree.Location = New-Object System.Drawing.Point(20, 95)
$tree.Size = New-Object System.Drawing.Size(400, 520)
$tree.HideSelection = $false
$form.Controls.Add($tree)

$selectedLabel = New-Object System.Windows.Forms.Label
$selectedLabel.AutoSize = $false
$selectedLabel.Location = New-Object System.Drawing.Point(445, 95)
$selectedLabel.Size = New-Object System.Drawing.Size(425, 42)
$selectedLabel.Text = 'Selected location:'
$form.Controls.Add($selectedLabel)

$categoryGroup = New-Object System.Windows.Forms.GroupBox
$categoryGroup.Location = New-Object System.Drawing.Point(445, 145)
$categoryGroup.Size = New-Object System.Drawing.Size(505, 205)
$categoryGroup.Text = 'Create Category'
$form.Controls.Add($categoryGroup)

$categoryName = New-Object System.Windows.Forms.TextBox
$categoryName.Location = New-Object System.Drawing.Point(18, 33)
$categoryName.Size = New-Object System.Drawing.Size(465, 25)
$categoryGroup.Controls.Add($categoryName)

$createCategory = New-Object System.Windows.Forms.Button
$nestedCategory = New-Object System.Windows.Forms.CheckBox
$nestedCategory.Location = New-Object System.Drawing.Point(18, 68)
$nestedCategory.Size = New-Object System.Drawing.Size(245, 24)
$nestedCategory.Text = 'Nest beneath an existing category'
$categoryGroup.Controls.Add($nestedCategory)

$parentCategory = New-Object System.Windows.Forms.ComboBox
$parentCategory.Location = New-Object System.Drawing.Point(18, 98)
$parentCategory.Size = New-Object System.Drawing.Size(465, 25)
$parentCategory.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$parentCategory.DisplayMember = 'Display'
$parentCategory.Enabled = $false
$categoryGroup.Controls.Add($parentCategory)

$createCategory.Location = New-Object System.Drawing.Point(18, 145)
$createCategory.Size = New-Object System.Drawing.Size(185, 36)
$createCategory.Text = 'Create Category'
$categoryGroup.Controls.Add($createCategory)

$assetGroup = New-Object System.Windows.Forms.GroupBox
$assetGroup.Location = New-Object System.Drawing.Point(445, 365)
$assetGroup.Size = New-Object System.Drawing.Size(505, 230)
$assetGroup.Text = 'Add Asset to Selected Category'
$form.Controls.Add($assetGroup)

$selectAsset = New-Object System.Windows.Forms.Button
$typedNameCaption = New-Object System.Windows.Forms.Label
$typedNameCaption.Location = New-Object System.Drawing.Point(18, 30)
$typedNameCaption.Size = New-Object System.Drawing.Size(180, 22)
$typedNameCaption.Text = 'Typed text asset name:'
$assetGroup.Controls.Add($typedNameCaption)

$typedAssetName = New-Object System.Windows.Forms.TextBox
$typedAssetName.Location = New-Object System.Drawing.Point(18, 53)
$typedAssetName.Size = New-Object System.Drawing.Size(465, 25)
$assetGroup.Controls.Add($typedAssetName)

$selectAsset.Location = New-Object System.Drawing.Point(18, 92)
$selectAsset.Size = New-Object System.Drawing.Size(185, 36)
$selectAsset.Text = 'Select and Add Asset'
$assetGroup.Controls.Add($selectAsset)

$typedAsset = New-Object System.Windows.Forms.Button
$typedAsset.Location = New-Object System.Drawing.Point(218, 92)
$typedAsset.Size = New-Object System.Drawing.Size(185, 36)
$typedAsset.Text = 'Create Typed Text Asset'
$assetGroup.Controls.Add($typedAsset)

$assetNote = New-Object System.Windows.Forms.Label
$assetNote.AutoSize = $false
$assetNote.Location = New-Object System.Drawing.Point(18, 140)
$assetNote.Size = New-Object System.Drawing.Size(465, 70)
$assetNote.Text = 'Imported files retain their existing filenames. A typed text asset uses the entered name and is stored as that name plus .txt.'
$assetGroup.Controls.Add($assetNote)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(20, 625)
$refreshButton.Size = New-Object System.Drawing.Size(120, 32)
$refreshButton.Text = 'Refresh'
$form.Controls.Add($refreshButton)

$manageInvalidButton = New-Object System.Windows.Forms.Button
$manageInvalidButton.Location = New-Object System.Drawing.Point(545, 15)
$manageInvalidButton.Size = New-Object System.Drawing.Size(195, 32)
$manageInvalidButton.Text = 'Manage Invalid Items'
$form.Controls.Add($manageInvalidButton)

$openInvalidButton = New-Object System.Windows.Forms.Button
$openInvalidButton.Location = New-Object System.Drawing.Point(755, 15)
$openInvalidButton.Size = New-Object System.Drawing.Size(195, 32)
$openInvalidButton.Text = 'Open Invalid Directory'
$form.Controls.Add($openInvalidButton)

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $false
$status.Location = New-Object System.Drawing.Point(160, 620)
$status.Size = New-Object System.Drawing.Size(790, 58)
$status.Text = 'Loading warehouse through private Python runtime...'
$form.Controls.Add($status)

function Set-Status {
    param([string]$Message, [bool]$IsError = $false)
    $status.ForeColor = if ($IsError) { [System.Drawing.Color]::DarkRed } else { [System.Drawing.Color]::DarkGreen }
    $status.Text = $Message
}

function Add-CategoryNodes {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.TreeNode]$ParentNode,
        [Parameter(Mandatory)]$Categories
    )

    foreach ($category in @($Categories)) {
        $node = New-Object System.Windows.Forms.TreeNode
        $node.Text = [string]$category.name
        $node.Tag = [PSCustomObject]@{
            RelativePath = [string]$category.relative_path
            CategoryId = [string]$category.category_id
            Lineage = [string]$category.lineage
        }
        [void]$ParentNode.Nodes.Add($node)
        Add-CategoryNodes -ParentNode $node -Categories $category.children
    }
}

function Add-CategoryChoices {
    param([Parameter(Mandatory)]$Categories)
    foreach ($category in @($Categories)) {
        $choice = [PSCustomObject]@{
            Display = ('core\' + ([string]$category.relative_path -replace '/', '\'))
            RelativePath = [string]$category.relative_path
        }
        [void]$parentCategory.Items.Add($choice)
        Add-CategoryChoices -Categories $category.children
    }
}

function Refresh-CategoryTree {
    $result = Invoke-AjDIRPython -ScriptName 'category_manager.py' -Arguments @('list')
    $tree.BeginUpdate()
    try {
        $tree.Nodes.Clear()
        $rootNode = New-Object System.Windows.Forms.TreeNode
        $rootNode.Text = 'core (warehouse)'
        $rootNode.Tag = [PSCustomObject]@{ RelativePath = ''; CategoryId = 'core'; Lineage = '' }
        [void]$tree.Nodes.Add($rootNode)
        Add-CategoryNodes -ParentNode $rootNode -Categories $result.categories
        $parentCategory.Items.Clear()
        Add-CategoryChoices -Categories $result.categories
        $rootNode.Expand()
        $tree.SelectedNode = $rootNode
    }
    finally {
        $tree.EndUpdate()
    }
}

function Get-TypedAssetName {
    $name = $typedAssetName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'Enter the typed text asset name.'
    }
    return $name
}

function Show-PlainTextEditor {
    $editor = New-Object System.Windows.Forms.Form
    $editor.Text = 'Create Typed Text Asset'
    $editor.StartPosition = 'CenterParent'
    $editor.ClientSize = New-Object System.Drawing.Size(780, 560)
    $text = New-Object System.Windows.Forms.TextBox
    $text.Multiline = $true
    $text.AcceptsReturn = $true
    $text.AcceptsTab = $true
    $text.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $text.WordWrap = $true
    $text.Font = New-Object System.Drawing.Font('Consolas', 10)
    $text.Location = New-Object System.Drawing.Point(12, 12)
    $text.Size = New-Object System.Drawing.Size(756, 490)
    $text.Anchor = 'Top,Bottom,Left,Right'
    $editor.Controls.Add($text)
    $save = New-Object System.Windows.Forms.Button
    $save.Text = 'Store Text Asset'
    $save.Location = New-Object System.Drawing.Point(603, 515)
    $save.Size = New-Object System.Drawing.Size(165, 32)
    $save.Anchor = 'Bottom,Right'
    $save.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $editor.Controls.Add($save)
    $editor.AcceptButton = $save
    if ($editor.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $text.Text
    }
    return $null
}

function Show-InvalidItemManager {
    $invalidDirectory = Join-Path $script:AjDIRRoot 'invalid'
    if (-not (Test-Path -LiteralPath $invalidDirectory -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show(
            'The AjDIR invalid directory does not currently exist.',
            'AjDIR invalid directory',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $manager = New-Object System.Windows.Forms.Form
    $manager.Text = 'Manage AjDIR Invalid Items'
    $manager.StartPosition = 'CenterParent'
    $manager.ClientSize = New-Object System.Drawing.Size(760, 455)
    $manager.MinimumSize = New-Object System.Drawing.Size(776, 494)

    $explanation = New-Object System.Windows.Forms.Label
    $explanation.Location = New-Object System.Drawing.Point(15, 15)
    $explanation.Size = New-Object System.Drawing.Size(730, 45)
    $explanation.Text = 'Select one item to securely delete it with the supplied SDelete tool, or securely delete every item currently in the invalid directory. SDelete uses one overwrite pass (-p 1).'
    $manager.Controls.Add($explanation)

    $invalidItems = New-Object System.Windows.Forms.ListBox
    $invalidItems.Location = New-Object System.Drawing.Point(15, 68)
    $invalidItems.Size = New-Object System.Drawing.Size(730, 315)
    $invalidItems.Anchor = 'Top,Bottom,Left,Right'
    $manager.Controls.Add($invalidItems)

    $refreshInvalidItems = {
        $invalidItems.Items.Clear()
        foreach ($item in @(Get-ChildItem -LiteralPath $invalidDirectory -Force | Sort-Object Name)) {
            $entry = [PSCustomObject]@{
                Display = if ($item.PSIsContainer) { "[Directory] $($item.Name)" } else { "[File] $($item.Name)" }
                FullPath = $item.FullName
            }
            [void]$invalidItems.Items.Add($entry)
        }
        $invalidItems.DisplayMember = 'Display'
    }

    $deleteSelected = New-Object System.Windows.Forms.Button
    $deleteSelected.Location = New-Object System.Drawing.Point(15, 399)
    $deleteSelected.Size = New-Object System.Drawing.Size(185, 34)
    $deleteSelected.Text = 'SDelete Selected Item'
    $deleteSelected.Anchor = 'Bottom,Left'
    $manager.Controls.Add($deleteSelected)

    $deleteAll = New-Object System.Windows.Forms.Button
    $deleteAll.Location = New-Object System.Drawing.Point(215, 399)
    $deleteAll.Size = New-Object System.Drawing.Size(185, 34)
    $deleteAll.Text = 'SDelete All Items'
    $deleteAll.Anchor = 'Bottom,Left'
    $manager.Controls.Add($deleteAll)

    $closeManager = New-Object System.Windows.Forms.Button
    $closeManager.Location = New-Object System.Drawing.Point(610, 399)
    $closeManager.Size = New-Object System.Drawing.Size(135, 34)
    $closeManager.Text = 'Close'
    $closeManager.Anchor = 'Bottom,Right'
    $manager.Controls.Add($closeManager)

    $deleteSelected.Add_Click({
        if ($invalidItems.SelectedIndex -lt 0) {
            [System.Windows.Forms.MessageBox]::Show('Select an invalid item first.', 'AjDIR', 'OK', 'Information') | Out-Null
            return
        }
        $selectedItem = $invalidItems.SelectedItem
        $confirmation = [System.Windows.Forms.MessageBox]::Show(
            "Permanently delete this item with SDelete -p 1?`r`n`r`n$($selectedItem.FullPath)",
            'Confirm secure deletion',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        try {
            [void](Invoke-AjDIRPython -ScriptName 'invalid_content.py' -Arguments @('delete', '--path', [string]$selectedItem.FullPath))
            Set-Status -Message "SDelete permanently deleted invalid item: $($selectedItem.Display)"
            & $refreshInvalidItems
        }
        catch {
            Set-Status -Message $_.Exception.Message -IsError $true
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR SDelete failure', 'OK', 'Error') | Out-Null
        }
    })

    $deleteAll.Add_Click({
        $itemsToDelete = @($invalidItems.Items)
        if ($itemsToDelete.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('The invalid directory contains no items.', 'AjDIR', 'OK', 'Information') | Out-Null
            return
        }
        $confirmation = [System.Windows.Forms.MessageBox]::Show(
            "Permanently delete all $($itemsToDelete.Count) item(s) in the invalid directory with SDelete -p 1?",
            'Confirm secure deletion of all invalid items',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        try {
            foreach ($item in $itemsToDelete) {
                [void](Invoke-AjDIRPython -ScriptName 'invalid_content.py' -Arguments @('delete', '--path', [string]$item.FullPath))
            }
            Set-Status -Message "SDelete permanently deleted all $($itemsToDelete.Count) item(s) from the invalid directory."
            & $refreshInvalidItems
        }
        catch {
            Set-Status -Message $_.Exception.Message -IsError $true
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR SDelete failure', 'OK', 'Error') | Out-Null
            & $refreshInvalidItems
        }
    })

    $closeManager.Add_Click({ $manager.Close() })
    & $refreshInvalidItems
    [void]$manager.ShowDialog($form)
}

$nestedCategory.Add_CheckedChanged({
    $parentCategory.Enabled = $nestedCategory.Checked
    if ($nestedCategory.Checked -and $parentCategory.Items.Count -gt 0 -and $parentCategory.SelectedIndex -lt 0) {
        $parentCategory.SelectedIndex = 0
    }
})

function Get-SelectedRelativePath {
    if ($null -eq $tree.SelectedNode) {
        throw 'Select the warehouse or a category first.'
    }
    return [string]$tree.SelectedNode.Tag.RelativePath
}

$tree.Add_AfterSelect({
    $selected = [string]$tree.SelectedNode.Tag.RelativePath
    $selectedLabel.Text = if ([string]::IsNullOrWhiteSpace($selected)) {
        "Selected location:`r`ncore (warehouse)"
    }
    else {
        "Selected location:`r`ncore\$($selected -replace '/', '\')"
    }

    if ([string]::IsNullOrWhiteSpace($selected)) {
        $nestedCategory.Checked = $false
        $parentCategory.SelectedIndex = -1
    }
    else {
        $nestedCategory.Checked = $true
        for ($index = 0; $index -lt $parentCategory.Items.Count; $index++) {
            $itemPath = [string]($parentCategory.Items[$index].RelativePath)
            if ($itemPath -eq $selected) {
                $parentCategory.SelectedIndex = $index
                break
            }
        }
    }
    [void]$categoryName.Focus()
})

$createCategory.Add_Click({
    try {
        $parent = ''
        if ($nestedCategory.Checked) {
            if ($parentCategory.SelectedIndex -lt 0) {
                throw 'Select the existing category beneath which the new category will be nested.'
            }
            $parent = [string]$parentCategory.SelectedItem.RelativePath
        }
        $result = Invoke-AjDIRPython -ScriptName 'category_manager.py' -Arguments @(
            'create', '--parent', $parent, '--name', $categoryName.Text
        )
        $categoryName.Clear()
        Refresh-CategoryTree
        Set-Status -Message "Category created: $($result.category)"
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$selectAsset.Add_Click({
    try {
        $category = Get-SelectedRelativePath
        if ([string]::IsNullOrWhiteSpace($category)) {
            throw 'Select a category before adding an asset.'
        }

        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select an asset to copy into the selected AjDIR category'
        $dialog.Multiselect = $false
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return
        }

        $result = Invoke-AjDIRPython -ScriptName 'asset_copy.py' -Arguments @(
            '--category', $category, '--source', $dialog.FileName
        )
        Set-Status -Message "Asset stored as '$($result.filename)'."
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$typedAsset.Add_Click({
    try {
        $category = Get-SelectedRelativePath
        if ([string]::IsNullOrWhiteSpace($category)) {
            throw 'Select a category before creating a typed text asset.'
        }
        $name = Get-TypedAssetName
        $content = Show-PlainTextEditor
        if ($null -eq $content) {
            return
        }
        $result = Invoke-AjDIRPython -ScriptName 'typed_asset.py' -Arguments @(
            '--category', $category, '--name', $name
        ) -InputText $content
        $typedAssetName.Clear()
        Set-Status -Message "Typed text stored as '$($result.filename)'."
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$refreshButton.Add_Click({
    try {
        Refresh-CategoryTree
        Set-Status -Message 'Warehouse categories refreshed by Python.'
    }
    catch {
        Set-Status -Message $_.Exception.Message -IsError $true
    }
})

$manageInvalidButton.Add_Click({
    Show-InvalidItemManager
})

$openInvalidButton.Add_Click({
    $invalidDirectory = Join-Path $script:AjDIRRoot 'invalid'
    if (-not (Test-Path -LiteralPath $invalidDirectory -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show(
            'The AjDIR invalid directory does not currently exist.',
            'AjDIR invalid directory',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    [void][System.Diagnostics.Process]::Start('explorer.exe', "`"$invalidDirectory`"")
})

try {
    $recovery = Invoke-AjDIRPython -ScriptName 'integrity_checkpoint.py' -Arguments @('recover')
    if ($recovery.restored) {
        [System.Windows.Forms.MessageBox]::Show(
            'AjDIR restored registry.xmlf and assets.xmlf from the verified pre-operation copies left by an interrupted operation.',
            'AjDIR registry recovery',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    $inspection = Invoke-AjDIRPython -ScriptName 'integrity_checkpoint.py' -Arguments @('inspect')
    $retainedFailures = @()
    foreach ($issue in @($inspection.issues)) {
        $failureMessage = "Incomplete asset: $($issue.filename)`r`nIntended location: $($issue.path)"
        [System.Windows.Forms.MessageBox]::Show(
            "$failureMessage`r`n`r`nAjDIR is reverting to the previous working state. You can try adding this asset again after the entry form opens.",
            'AjDIR incomplete asset',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        [void](Invoke-AjDIRPython -ScriptName 'integrity_checkpoint.py' -Arguments @(
            'revert', '--asset-id', [string]$issue.id
        ))
        $retainedFailures += "$failureMessage`r`nAjDIR reverted to the previous working state. You can try adding this asset again."
    }
    $quarantine = Invoke-AjDIRPython -ScriptName 'invalid_content.py' -Arguments @('scan')
    foreach ($movedItem in @($quarantine.moved)) {
        $movedItemMessage = "Unregistered item moved to the invalid directory: $($movedItem.name)`r`nOriginal location: $($movedItem.original_path)"
        [System.Windows.Forms.MessageBox]::Show(
            $movedItemMessage,
            'AjDIR invalid warehouse item',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        $retainedFailures += $movedItemMessage
    }
    Refresh-CategoryTree
    if ($retainedFailures.Count -gt 0) {
        Set-Status -Message ($retainedFailures -join "`r`n") -IsError $true
    }
    else {
        Set-Status -Message 'Ready. Warehouse loaded by the private AjDIR Python runtime.'
    }
    $startupReady = $true
}
catch {
    Set-Status -Message $_.Exception.Message -IsError $true
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR startup failure', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

if (-not $startupReady) {
    if ($null -ne $script:EntryFormMutex) {
        try { $script:EntryFormMutex.ReleaseMutex() } catch { }
        $script:EntryFormMutex.Dispose()
        $script:EntryFormMutex = $null
    }
    return
}

try {
    [void]$form.ShowDialog()
}
finally {
    if ($null -ne $script:EntryFormMutex) {
        try { $script:EntryFormMutex.ReleaseMutex() } catch { }
        $script:EntryFormMutex.Dispose()
        $script:EntryFormMutex = $null
    }
}
