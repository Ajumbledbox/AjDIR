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
$script:Reader = Join-Path $script:AjDIRRoot 'application\python\viewer_data.py'
$script:ViewerData = $null
$script:ScopePath = 'core\'
$script:Closing = $false

function Read-AjDIRViewData {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $script:PythonExe
    $startInfo.Arguments = '-B "' + $script:Reader + '"'
    $startInfo.WorkingDirectory = $script:AjDIRRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['PYTHONUTF8'] = '1'
    $startInfo.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $process = New-Object System.Diagnostics.Process
    try {
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ([string]::IsNullOrWhiteSpace($output)) {
            throw "The read-only viewer returned no data. $errorOutput"
        }
        $result = $output.Trim() | ConvertFrom-Json
        if ($process.ExitCode -ne 0 -or -not $result.success) {
            throw [string]$result.error
        }
        return $result
    }
    finally {
        if (-not $process.HasExited) { $process.Kill() }
        $process.Dispose()
        $output = $null
        $errorOutput = $null
        $result = $null
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'AjDIR Read-Only Viewer'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(1240, 760)
$form.MinimumSize = New-Object System.Drawing.Size(1050, 680)

$heading = New-Object System.Windows.Forms.Label
$heading.AutoSize = $true
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$heading.Location = New-Object System.Drawing.Point(16, 12)
$heading.Text = 'AjDIR Read-Only Warehouse Viewer'
$form.Controls.Add($heading)

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Location = New-Object System.Drawing.Point(460, 18)
$searchLabel.Size = New-Object System.Drawing.Size(50, 22)
$searchLabel.Text = 'Search:'
$form.Controls.Add($searchLabel)

$search = New-Object System.Windows.Forms.TextBox
$search.Location = New-Object System.Drawing.Point(515, 15)
$search.Size = New-Object System.Drawing.Size(430, 25)
$search.Anchor = 'Top,Left,Right'
$form.Controls.Add($search)

$refresh = New-Object System.Windows.Forms.Button
$refresh.Location = New-Object System.Drawing.Point(960, 12)
$refresh.Size = New-Object System.Drawing.Size(120, 30)
$refresh.Anchor = 'Top,Right'
$refresh.Text = 'Refresh Read-Only'
$form.Controls.Add($refresh)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Location = New-Object System.Drawing.Point(1090, 12)
$closeButton.Size = New-Object System.Drawing.Size(130, 30)
$closeButton.Anchor = 'Top,Right'
$closeButton.Text = 'Close and Clear'
$form.Controls.Add($closeButton)

$scopeLabel = New-Object System.Windows.Forms.Label
$scopeLabel.Location = New-Object System.Drawing.Point(16, 50)
$scopeLabel.Size = New-Object System.Drawing.Size(1204, 24)
$scopeLabel.Anchor = 'Top,Left,Right'
$scopeLabel.Text = 'Scope: core\'
$form.Controls.Add($scopeLabel)

$tree = New-Object System.Windows.Forms.TreeView
$tree.Location = New-Object System.Drawing.Point(16, 78)
$tree.Size = New-Object System.Drawing.Size(320, 650)
$tree.Anchor = 'Top,Bottom,Left'
$tree.HideSelection = $false
$form.Controls.Add($tree)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(350, 78)
$tabs.Size = New-Object System.Drawing.Size(870, 480)
$tabs.Anchor = 'Top,Bottom,Left,Right'
$form.Controls.Add($tabs)

function New-ViewerGrid {
    param([string[]]$Columns)
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = 'Fill'
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.MultiSelect = $false
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::DisplayedCells
    foreach ($column in $Columns) { [void]$grid.Columns.Add($column.Replace(' ', ''), $column) }
    return $grid
}

$inventoryTab = New-Object System.Windows.Forms.TabPage
$inventoryTab.Text = 'Complete Inventory'
$inventoryGrid = New-ViewerGrid @('Type', 'ID', 'Name', 'Lineage', 'Path', 'Added', 'State')
$inventoryTab.Controls.Add($inventoryGrid)
$tabs.TabPages.Add($inventoryTab)

$directoryTab = New-Object System.Windows.Forms.TabPage
$directoryTab.Text = 'Directories'
$directoryGrid = New-ViewerGrid @('ID', 'Lineage', 'Path', 'State')
$directoryTab.Controls.Add($directoryGrid)
$tabs.TabPages.Add($directoryTab)

$assetTab = New-Object System.Windows.Forms.TabPage
$assetTab.Text = 'Assets'
$assetGrid = New-ViewerGrid @('ID', 'Filename', 'Directory Lineage', 'Path', 'Date Added', 'Integrity')
$assetTab.Controls.Add($assetGrid)
$tabs.TabPages.Add($assetTab)

$detailsLabel = New-Object System.Windows.Forms.Label
$detailsLabel.Location = New-Object System.Drawing.Point(350, 568)
$detailsLabel.Size = New-Object System.Drawing.Size(200, 22)
$detailsLabel.Anchor = 'Bottom,Left'
$detailsLabel.Text = 'Selected record details:'
$form.Controls.Add($detailsLabel)

$details = New-Object System.Windows.Forms.TextBox
$details.Location = New-Object System.Drawing.Point(350, 590)
$details.Size = New-Object System.Drawing.Size(870, 138)
$details.Anchor = 'Bottom,Left,Right'
$details.Multiline = $true
$details.ReadOnly = $true
$details.ScrollBars = 'Both'
$details.WordWrap = $false
$details.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($details)

function Test-VisibleRecord {
    param($Record)
    $path = [string]$Record.path
    if (-not $path.StartsWith($script:ScopePath, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    $term = $search.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($term)) { return $true }
    $haystack = (($Record.PSObject.Properties | ForEach-Object { [string]$_.Value }) -join ' ')
    return $haystack.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Set-RowStateColor {
    param($Row, [string]$State)
    if ($State -notin @('Present', 'Verified')) {
        $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::MistyRose
    }
}

function Refresh-Grids {
    if ($script:Closing -or $null -eq $script:ViewerData) { return }
    $inventoryGrid.Rows.Clear()
    $directoryGrid.Rows.Clear()
    $assetGrid.Rows.Clear()
    foreach ($item in @($script:ViewerData.inventory)) {
        if (-not (Test-VisibleRecord $item)) { continue }
        $rowIndex = $inventoryGrid.Rows.Add($item.type, $item.id, $item.name, $item.lineage, $item.path, $item.added, $item.state)
        $row = $inventoryGrid.Rows[$rowIndex]
        $row.Tag = $item
        Set-RowStateColor $row $item.state
    }
    foreach ($item in @($script:ViewerData.directories)) {
        if (-not (Test-VisibleRecord $item)) { continue }
        $rowIndex = $directoryGrid.Rows.Add($item.id, $item.lineage, $item.path, $item.state)
        $row = $directoryGrid.Rows[$rowIndex]
        $row.Tag = $item
        Set-RowStateColor $row $item.state
    }
    foreach ($item in @($script:ViewerData.assets)) {
        if (-not (Test-VisibleRecord $item)) { continue }
        $rowIndex = $assetGrid.Rows.Add($item.id, $item.filename, $item.directory_lineage, $item.path, $item.date_added, $item.state)
        $row = $assetGrid.Rows[$rowIndex]
        $row.Tag = $item
        Set-RowStateColor $row $item.state
    }
}

function Refresh-Tree {
    $tree.BeginUpdate()
    try {
        $tree.Nodes.Clear()
        $nodes = @{}
        foreach ($item in @($script:ViewerData.directories | Sort-Object depth, path)) {
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = [string]$item.name
            $node.Tag = [string]$item.path
            $nodes[[string]$item.path] = $node
            if ([string]$item.path -eq 'core\') {
                [void]$tree.Nodes.Add($node)
            }
            else {
                $trimmed = ([string]$item.path).TrimEnd('\')
                $cut = $trimmed.LastIndexOf('\')
                $parentPath = $trimmed.Substring(0, $cut + 1)
                if ($nodes.ContainsKey($parentPath)) { [void]$nodes[$parentPath].Nodes.Add($node) }
            }
        }
        if ($tree.Nodes.Count -gt 0) {
            $tree.Nodes[0].Expand()
            $tree.SelectedNode = $tree.Nodes[0]
        }
    }
    finally { $tree.EndUpdate() }
}

function Load-ViewerData {
    $script:ViewerData = Read-AjDIRViewData
    $script:ScopePath = 'core\'
    $scopeLabel.Text = 'Scope: core\'
    Refresh-Tree
    Refresh-Grids
}

function Show-SelectedDetails {
    param($Grid)
    if ($Grid.SelectedRows.Count -eq 0 -or $null -eq $Grid.SelectedRows[0].Tag) { return }
    $item = $Grid.SelectedRows[0].Tag
    $details.Text = ($item.PSObject.Properties | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Value }) -join "`r`n"
}

$tree.Add_AfterSelect({
    if ($script:Closing) { return }
    $script:ScopePath = [string]$tree.SelectedNode.Tag
    $scopeLabel.Text = "Scope: $script:ScopePath"
    Refresh-Grids
})
$search.Add_TextChanged({ Refresh-Grids })
$inventoryGrid.Add_SelectionChanged({ Show-SelectedDetails $inventoryGrid })
$directoryGrid.Add_SelectionChanged({ Show-SelectedDetails $directoryGrid })
$assetGrid.Add_SelectionChanged({ Show-SelectedDetails $assetGrid })
$refresh.Add_Click({
    try { Load-ViewerData } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR Viewer') | Out-Null }
})
$closeButton.Add_Click({ $form.Close() })

function Clear-ViewerMemory {
    $script:Closing = $true
    foreach ($grid in @($inventoryGrid, $directoryGrid, $assetGrid)) {
        $grid.DataSource = $null
        $grid.Rows.Clear()
        $grid.Columns.Clear()
    }
    $tree.Nodes.Clear()
    $details.Clear()
    $search.Clear()
    $scopeLabel.Text = ''
    $script:ViewerData = $null
    $script:ScopePath = $null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
}

$form.Add_FormClosing({ Clear-ViewerMemory })
$form.Add_FormClosed({
    $form.Dispose()
    [Environment]::Exit(0)
})

try {
    Load-ViewerData
    [void]$form.ShowDialog()
}
catch {
    Clear-ViewerMemory
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AjDIR Viewer startup failure') | Out-Null
    $form.Dispose()
}
