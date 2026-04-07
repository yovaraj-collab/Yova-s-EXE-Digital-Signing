#Requires -Version 5.1
<#
.SYNOPSIS
    GUI tool for creating self-signed certificates, exporting as PFX, and signing EXE files.

.DESCRIPTION
    A Windows Forms-based graphical interface that wraps New-SelfSignedCertificate,
    Export-PfxCertificate, and signtool.exe (Windows SDK). Supports EXE/DLL code signing
    with auto-detection of Windows SDK. No admin rights required when using CurrentUser store.

.NOTES
    Run directly: .\New-SelfSignedPfx-GUI.ps1
    Or right-click -> Run with PowerShell
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Colour & Font Palette ----------------------------------------------------
$BG       = [System.Drawing.Color]::FromArgb(15, 17, 26)
$PANEL    = [System.Drawing.Color]::FromArgb(24, 28, 42)
$CARD     = [System.Drawing.Color]::FromArgb(30, 36, 54)
$BORDER   = [System.Drawing.Color]::FromArgb(50, 60, 90)
$ACCENT   = [System.Drawing.Color]::FromArgb(82, 130, 255)
$ACCENT2  = [System.Drawing.Color]::FromArgb(56, 220, 180)
$TEXT     = [System.Drawing.Color]::FromArgb(220, 228, 255)
$MUTED    = [System.Drawing.Color]::FromArgb(110, 125, 165)
$SUCCESS  = [System.Drawing.Color]::FromArgb(56, 220, 140)
$ERROR_C  = [System.Drawing.Color]::FromArgb(255, 90, 100)
$WARN     = [System.Drawing.Color]::FromArgb(255, 190, 60)
$INPUT_BG = [System.Drawing.Color]::FromArgb(20, 24, 38)

$FontMono  = New-Object System.Drawing.Font("Consolas", 9)
$FontBody  = New-Object System.Drawing.Font("Segoe UI", 9)
$FontBold  = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$FontTitle = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$FontSm    = New-Object System.Drawing.Font("Segoe UI", 8)
$FontLabel = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

# --- Helper: Styled Label -----------------------------------------------------
function New-Label {
    param($Text, $X, $Y, $W = 160, $H = 18, $Color = $MUTED, $Font = $FontLabel)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $Text.ToUpper()
    $lbl.Location  = New-Object System.Drawing.Point($X, $Y)
    $lbl.Size      = New-Object System.Drawing.Size($W, $H)
    $lbl.ForeColor = $Color
    $lbl.Font      = $Font
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    return $lbl
}

# --- Helper: Styled TextBox ---------------------------------------------------
function New-Input {
    param($X, $Y, $W = 280, $H = 28, $Placeholder = "", $Password = $false)
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location  = New-Object System.Drawing.Point($X, $Y)
    $tb.Size      = New-Object System.Drawing.Size($W, $H)
    $tb.BackColor = $INPUT_BG
    $tb.ForeColor = $TEXT
    $tb.Font      = $FontBody
    $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    if ($Password) { $tb.PasswordChar = [char]0x2022 }
    if ($Placeholder) {
        $tb.Text      = $Placeholder
        $tb.ForeColor = $MUTED
        $tb.Add_GotFocus({
            if ($this.Text -eq $this.Tag) {
                $this.Text      = ""
                $this.ForeColor = $TEXT
            }
        })
        $tb.Add_LostFocus({
            if ($this.Text -eq "") {
                $this.Text      = $this.Tag
                $this.ForeColor = $MUTED
            }
        })
        $tb.Tag = $Placeholder
    }
    return $tb
}

# --- Helper: Styled Button ----------------------------------------------------
function New-Button {
    param($Text, $X, $Y, $W = 130, $H = 34, $Primary = $true)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = $Text
    $btn.Location  = New-Object System.Drawing.Point($X, $Y)
    $btn.Size      = New-Object System.Drawing.Size($W, $H)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.Font      = $FontBold
    $btn.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $btn.FlatAppearance.BorderSize = 1

    if ($Primary) {
        $btn.BackColor = $ACCENT
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatAppearance.BorderColor = $ACCENT
        $btn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(100, 150, 255) })
        $btn.Add_MouseLeave({ $this.BackColor = $ACCENT })
    } else {
        $btn.BackColor = $CARD
        $btn.ForeColor = $TEXT
        $btn.FlatAppearance.BorderColor = $BORDER
        $btn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(40, 48, 72) })
        $btn.Add_MouseLeave({ $this.BackColor = $CARD })
    }
    return $btn
}

# --- Helper: Divider Line -----------------------------------------------------
function New-Divider {
    param($X, $Y, $W = 560)
    $pnl = New-Object System.Windows.Forms.Panel
    $pnl.Location  = New-Object System.Drawing.Point($X, $Y)
    $pnl.Size      = New-Object System.Drawing.Size($W, 1)
    $pnl.BackColor = $BORDER
    return $pnl
}

# --- Helper: Section header ---------------------------------------------------
function New-SectionHeader {
    param($Text, $X, $Y, $W = 560)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = "  $Text"
    $lbl.Location  = New-Object System.Drawing.Point($X, $Y)
    $lbl.Size      = New-Object System.Drawing.Size($W, 22)
    $lbl.ForeColor = $ACCENT2
    $lbl.Font      = $FontLabel
    $lbl.BackColor = [System.Drawing.Color]::FromArgb(20, 56, 220, 180)
    return $lbl
}

# =============================================================================
#  MAIN FORM
# =============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Self-Signed PFX Certificate Creator"
$form.Size            = New-Object System.Drawing.Size(960, 760)
$form.MinimumSize     = New-Object System.Drawing.Size(800, 600)
$form.BackColor       = $BG
$form.ForeColor       = $TEXT
$form.Font            = $FontBody
$form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

# --- Title Bar Area ----------------------------------------------------------
$titlePanel = New-Object System.Windows.Forms.Panel
$titlePanel.Location  = New-Object System.Drawing.Point(0, 0)
$titlePanel.Size      = New-Object System.Drawing.Size(960, 68)
$titlePanel.BackColor = $PANEL
$titlePanel.Anchor    = [System.Windows.Forms.AnchorStyles]"Top,Left,Right"

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text      = "  [CERT]  Certificate Creator & Code Signer"
$titleLabel.Location  = New-Object System.Drawing.Point(14, 12)
$titleLabel.Size      = New-Object System.Drawing.Size(400, 28)
$titleLabel.Font      = $FontTitle
$titleLabel.ForeColor = $TEXT
$titleLabel.BackColor = [System.Drawing.Color]::Transparent

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text      = "  Create self-signed certs, export PFX, and sign EXE/DLL files with signtool"
$subtitleLabel.Location  = New-Object System.Drawing.Point(14, 40)
$subtitleLabel.Size      = New-Object System.Drawing.Size(600, 18)
$subtitleLabel.Font      = $FontSm
$subtitleLabel.ForeColor = $MUTED
$subtitleLabel.BackColor = [System.Drawing.Color]::Transparent

$titlePanel.Controls.AddRange(@($titleLabel, $subtitleLabel))
$form.Controls.Add($titlePanel)

# --- Scrollable Content Panel ------------------------------------------------
$scroll = New-Object System.Windows.Forms.Panel
$scroll.Location        = New-Object System.Drawing.Point(0, 68)
$scroll.Size            = New-Object System.Drawing.Size(960, 636)
$scroll.BackColor       = $BG
$scroll.AutoScroll      = $true
$scroll.VerticalScroll.Visible = $true
$scroll.Anchor          = [System.Windows.Forms.AnchorStyles]"Top,Bottom,Left,Right"

$Y = 16    # running Y offset inside scroll panel
$LX = 28   # left column X
$RX = 500  # right column X
$FW = 420  # field width per column

# -- SECTION: Certificate Identity --------------------------------------------
$scroll.Controls.Add((New-SectionHeader "CERTIFICATE IDENTITY" $LX $Y 900))
$Y += 28

$scroll.Controls.Add((New-Label "Common Name (CN)" $LX $Y))
$scroll.Controls.Add((New-Label "Organization (O)" $RX $Y))
$Y += 20

$txtCN = New-Input $LX $Y $FW 28 "e.g. myapp.local"
$txtOrg = New-Input $RX $Y $FW 28 "e.g. Contoso Ltd (optional)"
$scroll.Controls.AddRange(@($txtCN, $txtOrg))
$Y += 36

$scroll.Controls.Add((New-Label "DNS Subject Alt Names (SANs)" $LX $Y 560))
$Y += 20

$txtSANs = New-Input $LX $Y 900 28 "e.g. myapp.local, localhost, 127.0.0.1  (comma-separated)"
$scroll.Controls.Add($txtSANs)
$Y += 36

$scroll.Controls.Add((New-Divider $LX $Y 900))
$Y += 14

# -- SECTION: Key & Validity ---------------------------------------------------
$scroll.Controls.Add((New-SectionHeader "KEY & VALIDITY" $LX $Y 900))
$Y += 28

$scroll.Controls.Add((New-Label "RSA Key Length" $LX $Y))
$scroll.Controls.Add((New-Label "Valid For (Years)" $RX $Y))
$Y += 20

$cmbKey = New-Object System.Windows.Forms.ComboBox
$cmbKey.Location     = New-Object System.Drawing.Point($LX, $Y)
$cmbKey.Size         = New-Object System.Drawing.Size($FW, 28)
$cmbKey.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbKey.BackColor    = $INPUT_BG
$cmbKey.ForeColor    = $TEXT
$cmbKey.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
$cmbKey.Font         = $FontBody
[void]$cmbKey.Items.AddRange(@("2048 bits (Recommended)", "4096 bits (High Security)"))
$cmbKey.SelectedIndex = 0

$nudYears = New-Object System.Windows.Forms.NumericUpDown
$nudYears.Location  = New-Object System.Drawing.Point($RX, $Y)
$nudYears.Size      = New-Object System.Drawing.Size($FW, 28)
$nudYears.Minimum   = 1
$nudYears.Maximum   = 30
$nudYears.Value     = 1
$nudYears.BackColor = $INPUT_BG
$nudYears.ForeColor = $TEXT
$nudYears.Font      = $FontBody
$nudYears.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$scroll.Controls.AddRange(@($cmbKey, $nudYears))
$Y += 36

$scroll.Controls.Add((New-Label "Hash Algorithm" $LX $Y))
$scroll.Controls.Add((New-Label "Certificate Store" $RX $Y))
$Y += 20

$cmbHash = New-Object System.Windows.Forms.ComboBox
$cmbHash.Location     = New-Object System.Drawing.Point($LX, $Y)
$cmbHash.Size         = New-Object System.Drawing.Size($FW, 28)
$cmbHash.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbHash.BackColor    = $INPUT_BG
$cmbHash.ForeColor    = $TEXT
$cmbHash.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
$cmbHash.Font         = $FontBody
[void]$cmbHash.Items.AddRange(@("SHA256 (Recommended)", "SHA384", "SHA512"))
$cmbHash.SelectedIndex = 0

$cmbStore = New-Object System.Windows.Forms.ComboBox
$cmbStore.Location     = New-Object System.Drawing.Point($RX, $Y)
$cmbStore.Size         = New-Object System.Drawing.Size($FW, 28)
$cmbStore.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbStore.BackColor    = $INPUT_BG
$cmbStore.ForeColor    = $TEXT
$cmbStore.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
$cmbStore.Font         = $FontBody
[void]$cmbStore.Items.AddRange(@("CurrentUser\My", "LocalMachine\My"))
$cmbStore.SelectedIndex = 0

$scroll.Controls.AddRange(@($cmbHash, $cmbStore))
$Y += 36

$scroll.Controls.Add((New-Divider $LX $Y 900))
$Y += 14

# -- SECTION: PFX Export -------------------------------------------------------
$scroll.Controls.Add((New-SectionHeader "PFX EXPORT" $LX $Y 900))
$Y += 28

$chkExport = New-Object System.Windows.Forms.CheckBox
$chkExport.Text      = "Export certificate as PFX file"
$chkExport.Location  = New-Object System.Drawing.Point($LX, $Y)
$chkExport.Size      = New-Object System.Drawing.Size(300, 22)
$chkExport.Font      = $FontBold
$chkExport.ForeColor = $TEXT
$chkExport.BackColor = [System.Drawing.Color]::Transparent
$chkExport.Checked   = $true
$scroll.Controls.Add($chkExport)
$Y += 30

$scroll.Controls.Add((New-Label "Export Path" $LX $Y))
$Y += 20

$txtExportPath = New-Input $LX $Y 820 28
$txtExportPath.Text      = [System.IO.Path]::Combine(
    [Environment]::GetFolderPath('Desktop'), "certificate.pfx")
$txtExportPath.ForeColor = $TEXT

$btnBrowse = New-Button "Browse..." ($LX + 828) $Y 80 28 $false
$scroll.Controls.AddRange(@($txtExportPath, $btnBrowse))
$Y += 36

$scroll.Controls.Add((New-Label "PFX Password" $LX $Y))
$scroll.Controls.Add((New-Label "Confirm Password" $RX $Y))
$Y += 20

$txtPass1 = New-Input $LX $Y $FW 28 "" $true
$txtPass2 = New-Input $RX $Y $FW 28 "" $true
$scroll.Controls.AddRange(@($txtPass1, $txtPass2))

# Password strength bar
$Y += 36
$lblPwStrength = New-Object System.Windows.Forms.Label
$lblPwStrength.Location  = New-Object System.Drawing.Point($LX, $Y)
$lblPwStrength.Size      = New-Object System.Drawing.Size(200, 14)
$lblPwStrength.Font      = $FontSm
$lblPwStrength.ForeColor = $MUTED
$lblPwStrength.BackColor = [System.Drawing.Color]::Transparent
$lblPwStrength.Text      = ""

$pwBar = New-Object System.Windows.Forms.Panel
$pwBar.Location  = New-Object System.Drawing.Point($LX, ($Y + 16))
$pwBar.Size      = New-Object System.Drawing.Size(0, 4)
$pwBar.BackColor = $MUTED

$scroll.Controls.AddRange(@($lblPwStrength, $pwBar))

$txtPass1.Add_TextChanged({
    $p = $txtPass1.Text
    $score = 0
    if ($p.Length -ge 8)  { $score++ }
    if ($p.Length -ge 12) { $score++ }
    if ($p -match '[A-Z]') { $score++ }
    if ($p -match '[0-9]') { $score++ }
    if ($p -match '[^a-zA-Z0-9]') { $score++ }
    switch ($score) {
        0 { $pwBar.Width = 0;   $pwBar.BackColor = $MUTED;    $lblPwStrength.Text = "" }
        1 { $pwBar.Width = 70;  $pwBar.BackColor = $ERROR_C;  $lblPwStrength.Text = "Weak" }
        2 { $pwBar.Width = 130; $pwBar.BackColor = $WARN;     $lblPwStrength.Text = "Fair" }
        3 { $pwBar.Width = 200; $pwBar.BackColor = $WARN;     $lblPwStrength.Text = "Good" }
        4 { $pwBar.Width = 258; $pwBar.BackColor = $SUCCESS;  $lblPwStrength.Text = "Strong" }
        5 { $pwBar.Width = 258; $pwBar.BackColor = $ACCENT2;  $lblPwStrength.Text = "Very Strong" }
    }
})

$Y += 28

$scroll.Controls.Add((New-Divider $LX $Y 900))
$Y += 14

# -- Toggle export fields ------------------------------------------------------
$exportFields = @($txtExportPath, $btnBrowse, $txtPass1, $txtPass2, $lblPwStrength, $pwBar)

function Update-ExportFields {
    $enabled = $chkExport.Checked
    foreach ($ctrl in $exportFields) {
        $ctrl.Enabled = $enabled
    }
    if ($enabled) {
        $txtExportPath.BackColor = $INPUT_BG
        $txtPass1.BackColor      = $INPUT_BG
        $txtPass2.BackColor      = $INPUT_BG
    } else {
        $txtExportPath.BackColor = [System.Drawing.Color]::FromArgb(18, 20, 30)
        $txtPass1.BackColor      = [System.Drawing.Color]::FromArgb(18, 20, 30)
        $txtPass2.BackColor      = [System.Drawing.Color]::FromArgb(18, 20, 30)
    }
}
$chkExport.Add_CheckedChanged({ Update-ExportFields })

# Browse dialog
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title      = "Export PFX to..."
    $dlg.Filter     = "PFX Certificate (*.pfx)|*.pfx|P12 Certificate (*.p12)|*.p12"
    $dlg.FileName   = "certificate.pfx"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtExportPath.Text      = $dlg.FileName
        $txtExportPath.ForeColor = $TEXT
    }
})

# --- Log / Output Area -------------------------------------------------------
$scroll.Controls.Add((New-SectionHeader "OUTPUT LOG" $LX $Y 900))
$Y += 28

$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Location   = New-Object System.Drawing.Point($LX, $Y)
$rtbLog.Size       = New-Object System.Drawing.Size(900, 110)
$rtbLog.BackColor  = [System.Drawing.Color]::FromArgb(10, 12, 20)
$rtbLog.ForeColor  = $TEXT
$rtbLog.Font       = $FontMono
$rtbLog.ReadOnly   = $true
$rtbLog.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$rtbLog.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$scroll.Controls.Add($rtbLog)
$Y += 118

$scroll.Controls.Add((New-Divider $LX ($Y + 4) 900))
$Y += 18

# =============================================================================
#  EXE / DLL CODE SIGNING SECTION
# =============================================================================

# --- SDK Detection Logic -----------------------------------------------------
function Find-SignTool {
    # Search common Windows SDK install paths for signtool.exe (newest first)
    $sdkRoots = @(
        "$env:ProgramFiles\Windows Kits\10\bin",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "$env:ProgramFiles\Windows Kits\8.1\bin",
        "${env:ProgramFiles(x86)}\Windows Kits\8.1\bin"
    )
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $found = @()
    foreach ($root in $sdkRoots) {
        if (Test-Path $root) {
            $hits = Get-ChildItem -Path $root -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match "\\$arch\\" } |
                    Sort-Object FullName -Descending
            $found += $hits
        }
    }
    # Also check PATH
    $inPath = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($inPath) { $found += [PSCustomObject]@{ FullName = $inPath.Source } }
    if ($found.Count -gt 0) { return $found[0].FullName }
    return $null
}

$script:SignToolPath = Find-SignTool

# --- EXE Signing UI ----------------------------------------------------------
$scroll.Controls.Add((New-SectionHeader "CODE SIGNING (EXE / DLL)" $LX $Y 900))
$Y += 28

# SDK status banner
$sdkStatusPanel = New-Object System.Windows.Forms.Panel
$sdkStatusPanel.Location  = New-Object System.Drawing.Point($LX, $Y)
$sdkStatusPanel.Size      = New-Object System.Drawing.Size(900, 30)

if ($script:SignToolPath) {
    $sdkStatusPanel.BackColor = [System.Drawing.Color]::FromArgb(20, 56, 220, 140)
    $sdkStatusLbl = New-Object System.Windows.Forms.Label
    $sdkStatusLbl.Text      = "  SDK OK   signtool found: $($script:SignToolPath)"
    $sdkStatusLbl.ForeColor = $SUCCESS
} else {
    $sdkStatusPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 255, 90, 100)
    $sdkStatusLbl = New-Object System.Windows.Forms.Label
    $sdkStatusLbl.Text      = "  SDK NOT FOUND   signtool.exe could not be located on this machine."
    $sdkStatusLbl.ForeColor = $ERROR_C
}
$sdkStatusLbl.Location  = New-Object System.Drawing.Point(0, 6)
$sdkStatusLbl.Size      = New-Object System.Drawing.Size(900, 18)
$sdkStatusLbl.Font      = $FontSm
$sdkStatusLbl.BackColor = [System.Drawing.Color]::Transparent
$sdkStatusPanel.Controls.Add($sdkStatusLbl)
$scroll.Controls.Add($sdkStatusPanel)
$Y += 36

# Download SDK link (shown only when SDK missing)
$lblSdkLink = New-Object System.Windows.Forms.LinkLabel
$lblSdkLink.Text      = "  >> Click here to download Windows SDK (includes signtool.exe)"
$lblSdkLink.Location  = New-Object System.Drawing.Point($LX, $Y)
$lblSdkLink.Size      = New-Object System.Drawing.Size(900, 18)
$lblSdkLink.Font      = $FontSm
$lblSdkLink.LinkColor = $ACCENT
$lblSdkLink.ActiveLinkColor = $ACCENT2
$lblSdkLink.BackColor = [System.Drawing.Color]::Transparent
$lblSdkLink.Visible   = (-not $script:SignToolPath)
$lblSdkLink.Add_LinkClicked({
    Start-Process "https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/"
})
$scroll.Controls.Add($lblSdkLink)

# Manual signtool path override (always shown so user can point to custom location)
$lblSignToolPath = New-Label "signtool.exe Path (auto-detected or override)" $LX ($Y + 4) 900
$scroll.Controls.Add($lblSignToolPath)
$Y += 24

$txtSignTool = New-Input $LX $Y 820 28
$txtSignTool.Text      = if ($script:SignToolPath) { $script:SignToolPath } else { "" }
$txtSignTool.ForeColor = $TEXT
if (-not $script:SignToolPath) {
    $txtSignTool.Text      = "Path to signtool.exe"
    $txtSignTool.ForeColor = $MUTED
    $txtSignTool.Tag       = "Path to signtool.exe"
}

$btnBrowseSdk = New-Button "Browse..." ($LX + 828) $Y 80 28 $false
$scroll.Controls.AddRange(@($txtSignTool, $btnBrowseSdk))
$Y += 36

$btnBrowseSdk.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title  = "Locate signtool.exe"
    $dlg.Filter = "signtool.exe|signtool.exe|All Executables (*.exe)|*.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtSignTool.Text      = $dlg.FileName
        $txtSignTool.ForeColor = $TEXT
        $script:SignToolPath   = $dlg.FileName
    }
})

# Files to sign
$scroll.Controls.Add((New-Label "File(s) to Sign  (EXE, DLL, MSI - one per line)" $LX $Y 584))
$Y += 20

$txtFilesToSign = New-Object System.Windows.Forms.TextBox
$txtFilesToSign.Location   = New-Object System.Drawing.Point($LX, $Y)
$txtFilesToSign.Size       = New-Object System.Drawing.Size(820, 60)
$txtFilesToSign.BackColor  = $INPUT_BG
$txtFilesToSign.ForeColor  = $TEXT
$txtFilesToSign.Font       = $FontBody
$txtFilesToSign.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtFilesToSign.Multiline  = $true
$txtFilesToSign.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical

$btnAddFiles = New-Button "Add..." ($LX + 828) $Y 80 28 $false
$btnAddFiles.Location = New-Object System.Drawing.Point(($LX + 828), $Y)
$scroll.Controls.AddRange(@($txtFilesToSign, $btnAddFiles))
$Y += 68

$btnAddFiles.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title       = "Select file(s) to sign"
    $dlg.Filter      = "Signable Files (*.exe;*.dll;*.msi;*.msix;*.appx)|*.exe;*.dll;*.msi;*.msix;*.appx|All Files (*.*)|*.*"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $existing = $txtFilesToSign.Text.Trim()
        $newLines = $dlg.FileNames -join "`r`n"
        if ($existing -and $existing -ne "") {
            $txtFilesToSign.Text = $existing + "`r`n" + $newLines
        } else {
            $txtFilesToSign.Text = $newLines
        }
        $txtFilesToSign.ForeColor = $TEXT
    }
})

# PFX source for signing
$scroll.Controls.Add((New-Label "PFX Certificate for Signing" $LX $Y))
$scroll.Controls.Add((New-Label "PFX Password" $RX $Y))
$Y += 20

$txtSignPfx = New-Input $LX $Y $FW 28 "Path to .pfx file (or use above export path)"
$txtSignPfx.Tag = "Path to .pfx file (or use above export path)"

$btnBrowseSignPfx = New-Button "Browse..." ($LX + $FW + 6) $Y 60 28 $false
$btnBrowseSignPfx.Size = New-Object System.Drawing.Size(60, 28)

$txtSignPass = New-Input $RX $Y $FW 28 "" $true
$scroll.Controls.AddRange(@($txtSignPfx, $btnBrowseSignPfx, $txtSignPass))
$Y += 36

$btnBrowseSignPfx.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title  = "Select PFX for signing"
    $dlg.Filter = "PFX Certificate (*.pfx;*.p12)|*.pfx;*.p12"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtSignPfx.Text      = $dlg.FileName
        $txtSignPfx.ForeColor = $TEXT
    }
})

# Timestamp server + digest algo row
$scroll.Controls.Add((New-Label "Timestamp Server" $LX $Y))
$scroll.Controls.Add((New-Label "File Digest Algorithm" $RX $Y))
$Y += 20

$cmbTimestamp = New-Object System.Windows.Forms.ComboBox
$cmbTimestamp.Location      = New-Object System.Drawing.Point($LX, $Y)
$cmbTimestamp.Size          = New-Object System.Drawing.Size($FW, 28)
$cmbTimestamp.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbTimestamp.BackColor     = $INPUT_BG
$cmbTimestamp.ForeColor     = $TEXT
$cmbTimestamp.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
$cmbTimestamp.Font          = $FontBody
[void]$cmbTimestamp.Items.AddRange(@(
    "http://timestamp.digicert.com",
    "http://timestamp.sectigo.com",
    "http://timestamp.globalsign.com/tsa/r6advanced1",
    "http://tsa.starfieldtech.com",
    "None (no timestamp)"
))
$cmbTimestamp.SelectedIndex = 0

$cmbDigest = New-Object System.Windows.Forms.ComboBox
$cmbDigest.Location      = New-Object System.Drawing.Point($RX, $Y)
$cmbDigest.Size          = New-Object System.Drawing.Size($FW, 28)
$cmbDigest.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbDigest.BackColor     = $INPUT_BG
$cmbDigest.ForeColor     = $TEXT
$cmbDigest.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
$cmbDigest.Font          = $FontBody
[void]$cmbDigest.Items.AddRange(@("SHA256 (Recommended)", "SHA384", "SHA512", "SHA1 (Legacy)"))
$cmbDigest.SelectedIndex = 0

$scroll.Controls.AddRange(@($cmbTimestamp, $cmbDigest))
$Y += 36

# Use-exported-PFX shortcut checkbox
$chkUseSamePfx = New-Object System.Windows.Forms.CheckBox
$chkUseSamePfx.Text      = "Use the PFX exported above (auto-fill path + password)"
$chkUseSamePfx.Location  = New-Object System.Drawing.Point($LX, $Y)
$chkUseSamePfx.Size      = New-Object System.Drawing.Size(800, 22)
$chkUseSamePfx.Font      = $FontBody
$chkUseSamePfx.ForeColor = $ACCENT2
$chkUseSamePfx.BackColor = [System.Drawing.Color]::Transparent
$chkUseSamePfx.Checked   = $false
$scroll.Controls.Add($chkUseSamePfx)
$Y += 30

$chkUseSamePfx.Add_CheckedChanged({
    if ($chkUseSamePfx.Checked) {
        $txtSignPfx.Text      = $txtExportPath.Text
        $txtSignPfx.ForeColor = $TEXT
        $txtSignPass.Text     = $txtPass1.Text
    }
})

# Sign button
$btnSign = New-Button ">  Sign File(s)" $LX $Y 160 34 $true
$btnSign.BackColor = [System.Drawing.Color]::FromArgb(40, 160, 80)
$btnSign.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(40, 160, 80)
$btnSign.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(56, 200, 100) })
$btnSign.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(40, 160, 80) })

# Re-detect button
$btnRedetect = New-Button "Re-detect SDK" ($LX + 170) $Y 140 34 $false
$scroll.Controls.AddRange(@($btnSign, $btnRedetect))
$Y += 44

$btnRedetect.Add_Click({
    $script:SignToolPath = Find-SignTool
    if ($script:SignToolPath) {
        $sdkStatusLbl.Text      = "  SDK OK   signtool found: $($script:SignToolPath)"
        $sdkStatusLbl.ForeColor = $SUCCESS
        $sdkStatusPanel.BackColor = [System.Drawing.Color]::FromArgb(20, 56, 220, 140)
        $txtSignTool.Text         = $script:SignToolPath
        $txtSignTool.ForeColor    = $TEXT
        $lblSdkLink.Visible       = $false
        Write-Log "SDK re-detected: $($script:SignToolPath)" "OK"
    } else {
        $sdkStatusLbl.Text      = "  SDK NOT FOUND   signtool.exe could not be located on this machine."
        $sdkStatusLbl.ForeColor = $ERROR_C
        $sdkStatusPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 255, 90, 100)
        $lblSdkLink.Visible       = $true
        Write-Log "signtool.exe not found. Install Windows SDK and click Re-detect." "WARN"
    }
})

# Sign button logic
$btnSign.Add_Click({
    $rtbLog.Clear()

    # -- Resolve signtool path
    $stPath = $txtSignTool.Text.Trim()
    if ($stPath -eq "Path to signtool.exe" -or [string]::IsNullOrWhiteSpace($stPath)) {
        $stPath = $script:SignToolPath
    }
    if ([string]::IsNullOrWhiteSpace($stPath) -or -not (Test-Path $stPath)) {
        Write-Log "signtool.exe not found. Install Windows SDK or browse to it manually." "ERROR"
        Write-Log "Download: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" "WARN"
        return
    }

    # -- Resolve PFX
    $pfxPath = Get-InputValue $txtSignPfx
    if ([string]::IsNullOrWhiteSpace($pfxPath)) {
        Write-Log "PFX path is required for signing." "ERROR"
        $txtSignPfx.Focus()
        return
    }
    if (-not (Test-Path $pfxPath)) {
        Write-Log "PFX file not found: $pfxPath" "ERROR"
        return
    }

    # -- Resolve password
    $signPwd = $txtSignPass.Text
    if ([string]::IsNullOrEmpty($signPwd)) {
        Write-Log "PFX password is required." "ERROR"
        $txtSignPass.Focus()
        return
    }

    # -- Resolve files to sign
    $rawFiles = $txtFilesToSign.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($rawFiles)) {
        Write-Log "No files specified to sign." "ERROR"
        $txtFilesToSign.Focus()
        return
    }
    $filesToSign = $rawFiles -split '\r?\n' |
                   ForEach-Object { $_.Trim() } |
                   Where-Object { $_ -ne '' }

    $missing = $filesToSign | Where-Object { -not (Test-Path $_) }
    if ($missing) {
        foreach ($m in $missing) { Write-Log "File not found: $m" "ERROR" }
        return
    }

    # -- Digest algorithm
    $digestAlgo = switch ($cmbDigest.SelectedIndex) {
        1 { "sha384" }
        2 { "sha512" }
        3 { "sha1"   }
        default { "sha256" }
    }

    # -- Timestamp
    $tsUrl = $cmbTimestamp.SelectedItem.ToString()
    $useTimestamp = ($tsUrl -notmatch "^None")

    Write-Log "---  Code Signing  ---" "HEAD"
    Write-Log "signtool : $stPath"
    Write-Log "PFX      : $pfxPath"
    Write-Log "Digest   : $digestAlgo"
    if ($useTimestamp) { Write-Log "Timestamp: $tsUrl" }
    Write-Log "Files    : $($filesToSign.Count) file(s)"

    $btnSign.Enabled = $false
    $btnSign.Text    = "Signing..."
    [System.Windows.Forms.Application]::DoEvents()

    $successCount = 0
    $failCount    = 0

    try {
        foreach ($file in $filesToSign) {
            Write-Log "Signing  : $([System.IO.Path]::GetFileName($file))"

            # Build signtool argument string
            # NOTE: $args is a PS automatic variable — use $signArgs instead
            # Wrap only paths/values that may contain spaces in quotes; flags don't need them
            $signArgs  = "sign"
            $signArgs += " /fd $digestAlgo"
            $signArgs += " /f `"$pfxPath`""
            $signArgs += " /p `"$signPwd`""
            if ($useTimestamp) {
                $signArgs += " /tr `"$tsUrl`""
                $signArgs += " /td $digestAlgo"
            }
            $signArgs += " `"$file`""

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName               = $stPath
            $psi.Arguments              = $signArgs
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true

            $proc = [System.Diagnostics.Process]::Start($psi)
            $stdout = $proc.StandardOutput.ReadToEnd()
            $stderr = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()

            if ($proc.ExitCode -eq 0) {
                Write-Log "  Signed OK: $([System.IO.Path]::GetFileName($file))" "OK"
                $successCount++
            } else {
                $errMsg = if ($stderr) { $stderr.Trim() } else { $stdout.Trim() }
                Write-Log "  FAILED: $([System.IO.Path]::GetFileName($file)) - $errMsg" "ERROR"
                $failCount++
            }
        }

        Write-Log "---  Signing complete: $successCount OK, $failCount failed  ---" "HEAD"

        if ($failCount -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "All $successCount file(s) signed successfully.",
                "Signing Complete",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "$successCount file(s) signed OK.`n$failCount file(s) FAILED - see the output log for details.",
                "Signing Finished with Errors",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }

    } catch {
        Write-Log "ERROR: $_" "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred during signing:`n`n$_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        $btnSign.Enabled = $true
        $btnSign.Text    = ">  Sign File(s)"
    }
})

$scroll.Controls.Add((New-Divider $LX $Y 900))
$Y += 18

$form.Controls.Add($scroll)

# --- Bottom Action Bar -------------------------------------------------------
$actionBar = New-Object System.Windows.Forms.Panel
$actionBar.Location  = New-Object System.Drawing.Point(0, 704)
$actionBar.Size      = New-Object System.Drawing.Size(960, 56)
$actionBar.BackColor = $PANEL
$actionBar.Anchor    = [System.Windows.Forms.AnchorStyles]"Bottom,Left,Right"

$btnCreate = New-Button ">  Create Certificate" 28 11 200 34 $true
$btnClear  = New-Button "R  Reset Form" 240 11 130 34 $false
$btnClose  = New-Button "X  Close" 382 11 100 34 $false
$btnClose.ForeColor = $ERROR_C
$btnClose.FlatAppearance.BorderColor = $ERROR_C

# Thumbprint display
$lblThumb = New-Object System.Windows.Forms.Label
$lblThumb.Location  = New-Object System.Drawing.Point(500, 20)
$lblThumb.Size      = New-Object System.Drawing.Size(130, 16)
$lblThumb.Font      = $FontSm
$lblThumb.ForeColor = $MUTED
$lblThumb.Text      = ""
$lblThumb.BackColor = [System.Drawing.Color]::Transparent

$actionBar.Controls.AddRange(@($btnCreate, $btnClear, $btnClose, $lblThumb))
$form.Controls.Add($actionBar)

# --- Log Writer --------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts    = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "OK"    { $SUCCESS }
        "ERROR" { $ERROR_C }
        "WARN"  { $WARN }
        "HEAD"  { $ACCENT2 }
        default { $TEXT }
    }
    $rtbLog.SelectionStart  = $rtbLog.TextLength
    $rtbLog.SelectionLength = 0
    $rtbLog.SelectionColor  = $MUTED
    $rtbLog.AppendText("[$ts] ")
    $rtbLog.SelectionColor  = $color
    $rtbLog.AppendText("$Message`n")
    $rtbLog.ScrollToCaret()
}

# --- Validation Helper -------------------------------------------------------
function Get-InputValue {
    param($ctrl)
    $v = $ctrl.Text.Trim()
    if ($v -eq $ctrl.Tag) { return "" }
    return $v
}

# --- CREATE Button Logic -----------------------------------------------------
$btnCreate.Add_Click({
    $rtbLog.Clear()
    $lblThumb.Text = ""

    # -- Validate CN
    $cn = Get-InputValue $txtCN
    if ([string]::IsNullOrWhiteSpace($cn)) {
        Write-Log "Common Name (CN) is required." "ERROR"
        $txtCN.Focus()
        return
    }

    # -- Gather SANs
    $sanRaw = Get-InputValue $txtSANs
    $dnsNames = @($cn)
    if ($sanRaw) {
        $dnsNames += $sanRaw -split '\s*,\s*' | Where-Object { $_ -ne '' }
    }
    $dnsNames = $dnsNames | Sort-Object -Unique

    # -- Key length
    $keyLen = if ($cmbKey.SelectedIndex -eq 1) { 4096 } else { 2048 }

    # -- Hash
    $hash = switch ($cmbHash.SelectedIndex) {
        1 { "SHA384" }
        2 { "SHA512" }
        default { "SHA256" }
    }

    # -- Store
    $store = "Cert:\$($cmbStore.SelectedItem)"

    # -- Validity
    $years    = [int]$nudYears.Value
    $notAfter = (Get-Date).AddYears($years)

    # -- Export validation
    $doExport = $chkExport.Checked
    $exportPath = ""
    $securePwd  = $null

    if ($doExport) {
        $exportPath = $txtExportPath.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($exportPath)) {
            Write-Log "Export path cannot be empty." "ERROR"
            return
        }
        $exportDir = Split-Path $exportPath -Parent
        if (-not (Test-Path $exportDir)) {
            Write-Log "Export directory does not exist: $exportDir" "ERROR"
            return
        }
        $p1 = $txtPass1.Text
        $p2 = $txtPass2.Text
        if ([string]::IsNullOrEmpty($p1)) {
            Write-Log "PFX password cannot be empty." "ERROR"
            $txtPass1.Focus()
            return
        }
        if ($p1 -ne $p2) {
            Write-Log "Passwords do not match." "ERROR"
            $txtPass2.Focus()
            return
        }
        $securePwd = ConvertTo-SecureString $p1 -AsPlainText -Force
    }

    # -- Build subject
    $subject = "CN=$cn"
    $org = Get-InputValue $txtOrg
    if ($org) { $subject += ", O=$org" }

    Write-Log "---  Creating Certificate  ---" "HEAD"
    Write-Log "Subject    : $subject"
    Write-Log "SANs       : $($dnsNames -join ', ')"
    Write-Log "Key        : RSA $keyLen  |  Hash: $hash  |  Type: CodeSigningCert"
    Write-Log "Valid for  : $years year(s)  ->  expires $($notAfter.ToString('yyyy-MM-dd'))"
    Write-Log "Store      : $store"

    $btnCreate.Enabled = $false
    $btnCreate.Text    = "Working..."
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $cert = New-SelfSignedCertificate `
            -Subject           $subject `
            -DnsName           $dnsNames `
            -KeyAlgorithm      'RSA' `
            -KeyLength         $keyLen `
            -HashAlgorithm     $hash `
            -KeyUsage          @('DigitalSignature') `
            -KeyUsageProperty  'Sign' `
            -Type              'CodeSigningCert' `
            -KeyExportPolicy   'Exportable' `
            -NotAfter          $notAfter `
            -CertStoreLocation $store `
            -FriendlyName      $cn

        Write-Log "Certificate created  OK" "OK"
        Write-Log "Thumbprint : $($cert.Thumbprint)" "OK"
        $lblThumb.Text = $cert.Thumbprint.Substring(0,16) + "..."

        if ($doExport) {
            Write-Log "---  Exporting PFX  ---" "HEAD"
            Write-Log "Path       : $exportPath"

            $result = $cert | Export-PfxCertificate `
                -FilePath      $exportPath `
                -Password      $securePwd `
                -ChainOption   EndEntityCertOnly `
                -Force

            $sizeKB = [Math]::Round((Get-Item $exportPath).Length / 1KB, 2)
            Write-Log "PFX exported  OK  ($sizeKB KB)" "OK"
            Write-Log "---  All done!  ---" "HEAD"

            [System.Windows.Forms.MessageBox]::Show(
                "Certificate created and exported successfully!`n`nPFX: $exportPath`nThumbprint: $($cert.Thumbprint)",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        } else {
            Write-Log "---  All done! (no PFX export)  ---" "HEAD"
            [System.Windows.Forms.MessageBox]::Show(
                "Certificate created in store:`n$store`n`nThumbprint: $($cert.Thumbprint)",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }

    } catch {
        Write-Log "ERROR: $_" "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred:`n`n$_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        $btnCreate.Enabled = $true
        $btnCreate.Text    = ">  Create Certificate"
    }
})

# --- Reset Button ------------------------------------------------------------
$btnClear.Add_Click({
    $txtCN.Text              = "e.g. myapp.local";   $txtCN.ForeColor = $MUTED
    $txtOrg.Text             = "e.g. Contoso Ltd (optional)"; $txtOrg.ForeColor = $MUTED
    $txtSANs.Text            = "e.g. myapp.local, localhost, 127.0.0.1  (comma-separated)"; $txtSANs.ForeColor = $MUTED
    $txtCN.Tag  = "e.g. myapp.local"
    $txtOrg.Tag = "e.g. Contoso Ltd (optional)"
    $txtSANs.Tag = "e.g. myapp.local, localhost, 127.0.0.1  (comma-separated)"
    $cmbKey.SelectedIndex    = 0
    $cmbHash.SelectedIndex   = 0
    $cmbStore.SelectedIndex  = 0
    $nudYears.Value          = 1
    $chkExport.Checked       = $true
    $txtExportPath.Text      = [System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'), "certificate.pfx")
    $txtExportPath.ForeColor = $TEXT
    $txtPass1.Text           = ""
    $txtPass2.Text           = ""
    $pwBar.Width             = 0
    $lblPwStrength.Text      = ""
    $lblThumb.Text           = ""
    # -- Clear signing fields
    $txtFilesToSign.Text     = ""
    $txtSignPfx.Text         = "Path to .pfx file (or use above export path)"
    $txtSignPfx.ForeColor    = $MUTED
    $txtSignPfx.Tag          = "Path to .pfx file (or use above export path)"
    $txtSignPass.Text        = ""
    $chkUseSamePfx.Checked   = $false
    $cmbTimestamp.SelectedIndex = 0
    $cmbDigest.SelectedIndex    = 0
    $rtbLog.Clear()
    Update-ExportFields
})

# --- Close Button ------------------------------------------------------------
$btnClose.Add_Click({ $form.Close() })

# --- Init ---------------------------------------------------------------------
Update-ExportFields
Write-Log "Ready. Create a certificate, export PFX, then sign EXE/DLL files below." "HEAD"
if ($script:SignToolPath) {
    Write-Log "signtool.exe detected: $($script:SignToolPath)" "OK"
} else {
    Write-Log "signtool.exe NOT found. Install Windows SDK to enable code signing." "WARN"
    Write-Log "Download: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" "WARN"
}


# --- Resize Handler ----------------------------------------------------------
$form.Add_Resize({
    $newW = $form.ClientSize.Width
    $newH = $form.ClientSize.Height
    $titlePanel.Width  = $newW
    $actionBar.Top     = $newH - 56
    $actionBar.Width   = $newW
    $scroll.Width      = $newW
    $scroll.Height     = $newH - 68 - 56
})
# --- Show ---------------------------------------------------------------------
[void]$form.ShowDialog()
