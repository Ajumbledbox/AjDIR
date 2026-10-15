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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptRoot = Get-Variable -Name PSScriptRoot -ValueOnly -ErrorAction SilentlyContinue
if ($scriptRoot) {
    $script:AjDIRRoot = $scriptRoot
} else {
    $script:AjDIRRoot = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

function Request-AjDIRLiabilityAcceptance {
    $acceptancePath = Join-Path $script:AjDIRRoot 'AjDIR.lic'
    if (Test-Path -LiteralPath $acceptancePath -PathType Leaf) {
        return $true
    }

    $liabilityPath = Join-Path $script:AjDIRRoot 'docs\AjDIR.Liability.md'
    if (-not (Test-Path -LiteralPath $liabilityPath -PathType Leaf)) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Required liability document not found: $liabilityPath", 'AjDIR',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }

    $acceptanceForm = New-Object System.Windows.Forms.Form
    $acceptanceIcon = $null
    try {
        $acceptanceForm.Text = 'AjDIR Liability Acceptance'
        $acceptanceForm.StartPosition = 'CenterScreen'
        $acceptanceForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $acceptanceForm.MaximizeBox = $false
        $acceptanceForm.MinimizeBox = $false
        $acceptanceForm.ClientSize = New-Object System.Drawing.Size(760, 620)
        $acceptanceIconPath = Join-Path $script:AjDIRRoot 'assets\AjDIR.ico'
        if (Test-Path -LiteralPath $acceptanceIconPath -PathType Leaf) {
            $acceptanceIcon = New-Object System.Drawing.Icon($acceptanceIconPath)
            $acceptanceForm.Icon = $acceptanceIcon
        }

        $instruction = New-Object System.Windows.Forms.Label
        $instruction.Location = New-Object System.Drawing.Point(15, 15)
        $instruction.Size = New-Object System.Drawing.Size(730, 40)
        $instruction.Text = 'Read the complete AjDIR liability statement. You must accept it before AjDIR can open.'
        $acceptanceForm.Controls.Add($instruction)

        $liabilityText = New-Object System.Windows.Forms.TextBox
        $liabilityText.Location = New-Object System.Drawing.Point(15, 60)
        $liabilityText.Size = New-Object System.Drawing.Size(730, 500)
        $liabilityText.Multiline = $true
        $liabilityText.ReadOnly = $true
        $liabilityText.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $liabilityText.WordWrap = $true
        $liabilityText.Font = New-Object System.Drawing.Font('Consolas', 10)
        $liabilityText.Text = [System.IO.File]::ReadAllText($liabilityPath, [System.Text.Encoding]::UTF8) -replace "(?<!`r)`n", "`r`n"
        $acceptanceForm.Controls.Add($liabilityText)

        $acceptButton = New-Object System.Windows.Forms.Button
        $acceptButton.Text = 'Accept'
        $acceptButton.Location = New-Object System.Drawing.Point(535, 575)
        $acceptButton.Size = New-Object System.Drawing.Size(100, 30)
        $acceptButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $acceptanceForm.Controls.Add($acceptButton)

        $declineButton = New-Object System.Windows.Forms.Button
        $declineButton.Text = 'Decline'
        $declineButton.Location = New-Object System.Drawing.Point(645, 575)
        $declineButton.Size = New-Object System.Drawing.Size(100, 30)
        $declineButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $acceptanceForm.Controls.Add($declineButton)
        $acceptanceForm.AcceptButton = $acceptButton
        $acceptanceForm.CancelButton = $declineButton

        if ($acceptanceForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return $false
        }

        $acceptanceRecord = @(
            'AjDIR Liability Acceptance'
            "Accepted: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))"
            "Machine: $([Environment]::MachineName)"
        ) -join [Environment]::NewLine
        [System.IO.File]::WriteAllText(
            $acceptancePath, $acceptanceRecord + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))
        return $true
    } finally {
        $acceptanceForm.Dispose()
        if ($acceptanceIcon) {
            $acceptanceIcon.Dispose()
        }
    }
}

if (-not (Request-AjDIRLiabilityAcceptance)) {
    exit
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'AjDIR Dashboard'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(560, 455)
$dashboardIcon = $null
$dashboardIconPath = Join-Path $script:AjDIRRoot 'assets\AjDIR.ico'
if (Test-Path -LiteralPath $dashboardIconPath -PathType Leaf) {
    $dashboardIcon = New-Object System.Drawing.Icon($dashboardIconPath)
    $form.Icon = $dashboardIcon
}

$menuStrip = New-Object System.Windows.Forms.MenuStrip
$documentsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$documentsMenu.Text = 'Documents'
$readmeMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$readmeMenuItem.Text = 'Readme'
$liabilityMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$liabilityMenuItem.Text = 'Liability'
$ownershipMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$ownershipMenuItem.Text = 'Ownership'
$usageMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$usageMenuItem.Text = 'Usage Instructions'
$userGuideMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$userGuideMenuItem.Text = 'User Guide'
[void]$documentsMenu.DropDownItems.AddRange(@(
    $readmeMenuItem,
    $liabilityMenuItem,
    $ownershipMenuItem,
    $usageMenuItem,
    $userGuideMenuItem
))
[void]$menuStrip.Items.Add($documentsMenu)
$form.MainMenuStrip = $menuStrip
$form.Controls.Add($menuStrip)

$heading = New-Object System.Windows.Forms.Label
$heading.AutoSize = $true
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$heading.Location = New-Object System.Drawing.Point(20, 40)
$heading.Text = 'AjDIR Dashboard'
$form.Controls.Add($heading)

function New-DashboardGroup {
    param([string]$Text, [int]$Top, [int]$Height)
    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $Text
    $group.Location = New-Object System.Drawing.Point(20, $Top)
    $group.Size = New-Object System.Drawing.Size(520, $Height)
    $form.Controls.Add($group)
    return $group
}

function New-DashboardButton {
    param($Group, [string]$Text, [int]$Left, [int]$Top)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($Left, $Top)
    $button.Size = New-Object System.Drawing.Size(235, 34)
    $Group.Controls.Add($button)
    return $button
}

$warehouseGroup = New-DashboardGroup -Text 'Warehouse' -Top 85 -Height 70
$addContent = New-DashboardButton -Group $warehouseGroup -Text 'Add Content' -Left 15 -Top 25
$viewContent = New-DashboardButton -Group $warehouseGroup -Text 'View Content' -Left 265 -Top 25

$toolsGroup = New-DashboardGroup -Text 'Supplied Tools' -Top 165 -Height 190
$ajfi = New-DashboardButton -Group $toolsGroup -Text 'AjFI' -Left 15 -Top 25
$ajfi2 = New-DashboardButton -Group $toolsGroup -Text 'AjFI.2 File Compare' -Left 265 -Top 25
$ajfi2Information = New-DashboardButton -Group $toolsGroup -Text 'AjFI.2.File Information' -Left 265 -Top 65
$ajust = New-DashboardButton -Group $toolsGroup -Text 'AjUST' -Left 15 -Top 65
$notepad = New-DashboardButton -Group $toolsGroup -Text 'Notepad++' -Left 265 -Top 105
$sumatra = New-DashboardButton -Group $toolsGroup -Text 'SumatraPDF' -Left 15 -Top 105
$sdeleteFiles = New-DashboardButton -Group $toolsGroup -Text 'SDelete Files' -Left 265 -Top 145
$sdeleteInformation = New-DashboardButton -Group $toolsGroup -Text 'SDelete Information' -Left 15 -Top 145

$otherGroup = New-DashboardGroup -Text 'Information' -Top 365 -Height 70
$veracryptInformation = New-DashboardButton -Group $otherGroup -Text 'VeraCrypt Information' -Left 15 -Top 25
$readme = New-DashboardButton -Group $otherGroup -Text 'Readme' -Left 265 -Top 25

function Start-DashboardForm {
    param([string]$FileName)
    try {
        $scriptPath = Join-Path $script:AjDIRRoot $FileName
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = 'powershell.exe'
        $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $startInfo.WorkingDirectory = $script:AjDIRRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        [void][System.Diagnostics.Process]::Start($startInfo)
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'AjDIR Dashboard',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Start-DashboardApplication {
    param([string]$RelativePath, [string]$RelativeFile)
    try {
        $applicationPath = Join-Path $script:AjDIRRoot $RelativePath
        $workingDirectory = Split-Path -Parent $applicationPath
        if ($RelativeFile) {
            $filePath = Join-Path $script:AjDIRRoot $RelativeFile
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                throw "File not found: $filePath"
            }
            Start-Process -FilePath $applicationPath -ArgumentList "`"$filePath`"" -WorkingDirectory $workingDirectory
        } else {
            Start-Process -FilePath $applicationPath -WorkingDirectory $workingDirectory
        }
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'AjDIR Dashboard',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Open-AjDIRDocument {
    param([string]$RelativePath)
    $notepadPath = Join-Path $script:AjDIRRoot 'components\notepad.plus.plus\notepad++.exe'
    $documentPath = Join-Path $script:AjDIRRoot $RelativePath
    Start-Process -FilePath $notepadPath -ArgumentList "`"$documentPath`"" -WorkingDirectory (Split-Path -Parent $notepadPath)
}

$readmeMenuItem.Add_Click({ Open-AjDIRDocument -RelativePath 'AjDIR.Readme.txt' })
$liabilityMenuItem.Add_Click({ Open-AjDIRDocument -RelativePath 'docs\AjDIR.Liability.md' })
$ownershipMenuItem.Add_Click({ Open-AjDIRDocument -RelativePath 'docs\AjDIR.Ownership.md' })
$usageMenuItem.Add_Click({ Open-AjDIRDocument -RelativePath 'docs\AjDIR.Usage.Instructions.md' })
$userGuideMenuItem.Add_Click({ Open-AjDIRDocument -RelativePath 'docs\AjDIR.User.Guide.md' })

$addContent.Add_Click({ Start-DashboardForm -FileName 'AjDIR.Form.ps1' })
$viewContent.Add_Click({ Start-DashboardForm -FileName 'AjDIR.Viewer.Form.ps1' })
$ajfi.Add_Click({ Start-DashboardApplication -RelativePath 'components\AjFI\AJFI.exe' })
$ajust.Add_Click({ Start-DashboardApplication -RelativePath 'components\AjUST\AjUST.exe' })
$notepad.Add_Click({ Start-DashboardApplication -RelativePath 'components\notepad.plus.plus\notepad++.exe' })
$sumatra.Add_Click({ Start-DashboardApplication -RelativePath 'components\SumatraPDF.portable\SumatraPDF-3.6.1-64.exe' -RelativeFile 'components\book\Personal_Information_Control_Final_Book.pdf' })

function Select-DashboardFile {
    param([string]$Title)
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = $Title
        $dialog.Filter = 'All files (*.*)|*.*'
        $dialog.Multiselect = $false
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
            return $null
        }
        return $dialog.FileName
    } finally {
        $dialog.Dispose()
    }
}

$ajfi2.Add_Click({
    try {
        $firstFile = Select-DashboardFile -Title 'AjFI.2 File Compare - Select the first file'
        if (-not $firstFile) { return }
        $secondFile = Select-DashboardFile -Title 'AjFI.2 File Compare - Select the second file'
        if (-not $secondFile) { return }
        $pythonPath = Join-Path $script:AjDIRRoot 'runtime\python\python.exe'
        $scriptPath = Join-Path $script:AjDIRRoot 'components\AjFI.2.file\AjFI.2F.py'
        Start-Process -FilePath $pythonPath -ArgumentList @(
            '-B', "`"$scriptPath`"", "`"$firstFile`"", "`"$secondFile`""
        ) -WorkingDirectory (Split-Path -Parent $scriptPath)
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'AjDIR Dashboard',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

function Confirm-DashboardSecureDelete {
    param([string[]]$FilePaths)
    $confirm = New-Object System.Windows.Forms.Form
    try {
        $confirm.Text = 'SDelete Files - Permanent Deletion'
        $confirm.StartPosition = 'CenterParent'
        $confirm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $confirm.MaximizeBox = $false
        $confirm.MinimizeBox = $false
        $confirm.ClientSize = New-Object System.Drawing.Size(600, 400)

        $warning = New-Object System.Windows.Forms.Label
        $warning.Location = New-Object System.Drawing.Point(15, 15)
        $warning.Size = New-Object System.Drawing.Size(570, 75)
        $warning.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $warning.ForeColor = [System.Drawing.Color]::DarkRed
        $warning.Text = "WARNING: The $($FilePaths.Count) file(s) listed below will be permanently deleted with SDelete. They cannot be recovered. Use extreme care and confirm that every file listed is one you intend to permanently delete."
        $confirm.Controls.Add($warning)

        $list = New-Object System.Windows.Forms.ListBox
        $list.Location = New-Object System.Drawing.Point(15, 95)
        $list.Size = New-Object System.Drawing.Size(570, 245)
        $list.HorizontalScrollbar = $true
        [void]$list.Items.AddRange($FilePaths)
        $confirm.Controls.Add($list)

        $continueButton = New-Object System.Windows.Forms.Button
        $continueButton.Text = 'Continue'
        $continueButton.Location = New-Object System.Drawing.Point(375, 355)
        $continueButton.Size = New-Object System.Drawing.Size(100, 30)
        $continueButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $confirm.Controls.Add($continueButton)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = 'Cancel'
        $cancelButton.Location = New-Object System.Drawing.Point(485, 355)
        $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $confirm.Controls.Add($cancelButton)
        $confirm.CancelButton = $cancelButton
        $confirm.ActiveControl = $cancelButton

        return ($confirm.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK)
    } finally {
        $confirm.Dispose()
    }
}

$sdeleteFiles.Add_Click({
    try {
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        try {
            $dialog.Title = 'SDelete Files - Select the files to permanently delete'
            $dialog.Filter = 'All files (*.*)|*.*'
            $dialog.Multiselect = $true
            if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) { return }
            $selectedFiles = @($dialog.FileNames)
        } finally {
            $dialog.Dispose()
        }
        if ($selectedFiles.Count -eq 0) { return }
        if (-not (Confirm-DashboardSecureDelete -FilePaths $selectedFiles)) { return }

        $sdeletePath = Join-Path $script:AjDIRRoot 'components\SDelete\sdelete64.exe'
        if (-not (Test-Path -LiteralPath $sdeletePath -PathType Leaf)) {
            throw "The supplied SDelete executable is missing: $sdeletePath"
        }

        $deleted = New-Object System.Collections.Generic.List[string]
        $failed = New-Object System.Collections.Generic.List[string]
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            foreach ($filePath in $selectedFiles) {
                $startInfo = New-Object System.Diagnostics.ProcessStartInfo
                $startInfo.FileName = $sdeletePath
                $startInfo.Arguments = "-accepteula -nobanner -q -r -p 1 `"$filePath`""
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $true
                $process = [System.Diagnostics.Process]::Start($startInfo)
                $process.WaitForExit()
                if ($process.ExitCode -eq 0 -and -not (Test-Path -LiteralPath $filePath)) {
                    $deleted.Add($filePath)
                } else {
                    $failed.Add("$filePath (exit code $($process.ExitCode))")
                }
                $process.Dispose()
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        $summary = @("Permanently deleted: $($deleted.Count) file(s).")
        if ($failed.Count -gt 0) {
            $summary += ''
            $summary += "Not deleted: $($failed.Count) file(s):"
            $summary += $failed
        }
        $icon = if ($failed.Count -gt 0) { [System.Windows.Forms.MessageBoxIcon]::Warning } else { [System.Windows.Forms.MessageBoxIcon]::Information }
        [void][System.Windows.Forms.MessageBox]::Show(
            ($summary -join [Environment]::NewLine), 'SDelete Files',
            [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'AjDIR Dashboard',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

function Show-DashboardInformation {
    param([string]$Title, [string]$Message)
    [void][System.Windows.Forms.MessageBox]::Show(
        $Message, $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information)
}

$sdeleteInformation.Add_Click({
    Show-DashboardInformation -Title 'SDelete Information' -Message (@(
        'SDelete is a Microsoft Sysinternals tool that permanently deletes files by overwriting their contents so they cannot be recovered.',
        '',
        'Sysinternals SDelete:',
        'https://learn.microsoft.com/en-us/sysinternals/downloads/sdelete',
        '',
        'The AjDIR book contains a brief explanation of basic SDelete usage.',
        '',
        'You are strongly urged to read the Sysinternals SDelete page before using SDelete.'
    ) -join [Environment]::NewLine)
})

$ajfi2Information.Add_Click({
    Show-DashboardInformation -Title 'AjFI.2.File Information' -Message (@(
        'AjFI.2 File Compare compares two files by comparing their SHA-256 hash values.',
        '',
        'This is a form of determining the validity of a file, in an attempt to determine whether the two files are identical. In some understandings it is used to show that there is no file corruption.',
        '',
        'When you press the AjFI.2 File Compare button:',
        '1. Select the first file.',
        '2. Select the second file.',
        '',
        'This is only a comparison tool for files that are supposed to be the same. The result should be a match.'
    ) -join [Environment]::NewLine)
})

$readme.Add_Click({
    try {
        $readmePath = Join-Path $script:AjDIRRoot 'AjDIR.Readme.txt'
        if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
            throw "File not found: $readmePath"
        }
        $readmeWindow = New-Object System.Windows.Forms.Form
        try {
            $readmeWindow.Text = 'AjDIR Readme'
            $readmeWindow.StartPosition = 'CenterParent'
            $readmeWindow.ClientSize = New-Object System.Drawing.Size(760, 600)
            $readmeText = New-Object System.Windows.Forms.TextBox
            $readmeText.Multiline = $true
            $readmeText.ReadOnly = $true
            $readmeText.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
            $readmeText.WordWrap = $false
            $readmeText.Dock = [System.Windows.Forms.DockStyle]::Fill
            $readmeText.Font = New-Object System.Drawing.Font('Consolas', 10)
            $readmeText.BackColor = [System.Drawing.SystemColors]::Window
            $readmeText.Text = [System.IO.File]::ReadAllText($readmePath, [System.Text.Encoding]::UTF8) -replace "(?<!`r)`n", "`r`n"
            $readmeText.SelectionStart = 0
            $readmeWindow.Controls.Add($readmeText)
            [void]$readmeWindow.ShowDialog($form)
        } finally {
            $readmeWindow.Dispose()
        }
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'AjDIR Dashboard',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$veracryptInformation.Add_Click({
    Show-DashboardInformation -Title 'VeraCrypt Information' -Message (@(
        'A copy of VeraCrypt is included with AjDIR.',
        '',
        'Location:',
        'components\VeraCrypt'
    ) -join [Environment]::NewLine)
})

[void]$form.ShowDialog()
$form.Dispose()
if ($dashboardIcon) {
    $dashboardIcon.Dispose()
}
