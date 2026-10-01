# BricsCAD edition launcher
# Installs per-user shortcuts; no administrator rights or BricsCAD files are changed.
[CmdletBinding()]
param(
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $BricscadExe,
    [switch] $NoDesktop,
    [switch] $NoStartMenu,
    [ValidateSet('Lite', 'Pro', 'BIM', 'Mech', 'Ult', 'All')]
    [string[]] $DesktopEditions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Find-BricscadV26 {
    param([string] $ExplicitPath)

    if ($ExplicitPath) {
        $item = Get-Item -LiteralPath $ExplicitPath
        if ($item.Name -ieq 'bricscad.exe') { return $item.FullName }
        throw "-BricscadExe must point to bricscad.exe, not '$ExplicitPath'."
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)} | Where-Object { $_ })) {
        $bricsys = Join-Path $root 'Bricsys'
        if (Test-Path -LiteralPath $bricsys -PathType Container) {
            Get-ChildItem -LiteralPath $bricsys -Directory -Filter 'BricsCAD V26*' |
                ForEach-Object {
                    $exe = Join-Path $_.FullName 'bricscad.exe'
                    if (Test-Path -LiteralPath $exe -PathType Leaf) { $candidates.Add($exe) }
                }
        }
    }
    if ($candidates.Count -eq 0) {
        throw 'BricsCAD V26 was not found. Re-run with -BricscadExe "C:\Path\To\bricscad.exe".'
    }
    return $candidates[0]
}

function New-EditionIcon {
    param(
        [string] $DestinationPath,
        [System.Drawing.Icon] $BricscadIcon,
        [string] $Label,
        [System.Drawing.Color] $Color
    )

    # Include both a native 64px image (the normal Windows Desktop size) and a
    # 256px image.  This prevents Explorer from shrinking a 256px label into an
    # unreadable thumbnail.
    $iconImages = [System.Collections.Generic.List[object]]::new()
    foreach ($size in @(64, 256)) {
        $scale = $size / 256.0
        $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            # Reserve space for the edition label without overwhelming the logo.
            $graphics.DrawIcon($BricscadIcon, [System.Drawing.Rectangle]::new([int](70 * $scale), 0, [int](116 * $scale), [int](96 * $scale)))

            # Half-size revision: the previous label was visibly clipped at the
            # Windows Desktop icon size.
            $baseFontSize = if ($Label -eq 'Mech') { 68 } else { 84 }
            # Arial Narrow keeps the Mech label inside the square icon.
            $font = [System.Drawing.Font]::new('Arial Narrow', [single]($baseFontSize * $scale), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $format = [System.Drawing.StringFormat]::new()
            try {
                $format.Alignment = [System.Drawing.StringAlignment]::Center
                $format.LineAlignment = [System.Drawing.StringAlignment]::Center
                $brush = [System.Drawing.SolidBrush]::new($Color)
                $outline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(235, 0, 0, 0), [single][Math]::Max(2, 10 * $scale))
                try {
                    $textOutlinePath = [System.Drawing.Drawing2D.GraphicsPath]::new()
                    try {
                        $textOutlinePath.AddString($Label, $font.FontFamily, [int]$font.Style, $font.Size, [System.Drawing.RectangleF]::new(0, [single](88 * $scale), $size, [single](168 * $scale)), $format)
                        $graphics.DrawPath($outline, $textOutlinePath)
                        $graphics.FillPath($brush, $textOutlinePath)
                    } finally { $textOutlinePath.Dispose() }
                } finally { $outline.Dispose(); $brush.Dispose() }
            } finally { $font.Dispose(); $format.Dispose() }

            $pngStream = [System.IO.MemoryStream]::new()
            try {
                $bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
                $iconImages.Add([PSCustomObject]@{ Size = $size; Bytes = $pngStream.ToArray() })
            } finally { $pngStream.Dispose() }
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }

    $stream = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create)
    try {
        $writer = [System.IO.BinaryWriter]::new($stream)
        try {
            $writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$iconImages.Count)
            $offset = 6 + (16 * $iconImages.Count)
            foreach ($image in $iconImages) {
                $writer.Write([byte]$(if ($image.Size -eq 256) { 0 } else { $image.Size }))
                $writer.Write([byte]$(if ($image.Size -eq 256) { 0 } else { $image.Size }))
                $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([UInt16]1); $writer.Write([UInt16]32)
                $writer.Write([UInt32]$image.Bytes.Length); $writer.Write([UInt32]$offset)
                $offset += $image.Bytes.Length
            }
            foreach ($image in $iconImages) { $writer.Write($image.Bytes) }
        } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

function New-Shortcut {
    param([string] $Path, [string] $Target, [string] $Arguments, [string] $IconPath, [string] $Description)
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = Split-Path -Parent $Target
    $shortcut.IconLocation = "$IconPath,0"
    $shortcut.Description = $Description
    $shortcut.Save()
}

function Select-DesktopEditions {
    param([hashtable[]] $AvailableEditions)

    Write-Host ''
    Write-Host 'Choose the Desktop shortcuts to create:' -ForegroundColor Cyan
    for ($index = 0; $index -lt $AvailableEditions.Count; $index++) {
        Write-Host ("  {0}. {1}" -f ($index + 1), $AvailableEditions[$index].Label)
    }
    Write-Host '  A. All five shortcuts'
    Write-Host '  N. No Desktop shortcuts (Start Menu only)'

    while ($true) {
        $answer = (Read-Host 'Enter numbers separated by commas, A, or N').Trim()
        if ($answer -match '^(?i:a|all)$') { return @($AvailableEditions.Label) }
        if ($answer -match '^(?i:n|none)$') { return @() }
        if ($answer -match '^[1-5](\s*,\s*[1-5])*$') {
            return @($answer -split ',' | ForEach-Object { $AvailableEditions[[int]$_.Trim() - 1].Label } | Select-Object -Unique)
        }
        Write-Host 'Invalid choice. Enter, for example: 1,3,5 — or A for all.' -ForegroundColor Yellow
    }
}

function Get-BricscadV26ProfilesRoot {
    $bricscadRoot = 'HKCU:\Software\Bricsys\Bricscad'
    $versionKey = Get-ChildItem -LiteralPath $bricscadRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^V26(?:x64)?$' } |
        Select-Object -First 1
    if (-not $versionKey) {
        throw 'BricsCAD V26 has not created its user profile yet. Launch BricsCAD once normally, close it, then run this installer again.'
    }
    $languageKey = Get-ChildItem -LiteralPath $versionKey.PSPath -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^[a-z]{2}_[A-Z]{2}$' } |
        Select-Object -First 1
    if (-not $languageKey) { throw 'The BricsCAD V26 user-profile language folder could not be found.' }
    $profilesRoot = Join-Path $languageKey.PSPath 'Profiles'
    if (-not (Test-Path -LiteralPath $profilesRoot -PathType Container)) {
        throw 'The BricsCAD V26 Profiles registry key could not be found. Launch and close BricsCAD once, then run this installer again.'
    }
    return $profilesRoot
}

function Initialize-EditionProfile {
    param([string] $ProfilesRoot, [string] $ProfileName, [string] $Workspace)

    $profilePath = Join-Path $ProfilesRoot $ProfileName
    if (-not (Test-Path -LiteralPath $profilePath -PathType Container)) {
        $template = Join-Path $ProfilesRoot 'Default'
        if (-not (Test-Path -LiteralPath $template -PathType Container)) {
            $template = (Get-ChildItem -LiteralPath $ProfilesRoot | Select-Object -First 1).PSPath
        }
        if (-not $template) { throw 'No usable BricsCAD user profile was found to use as a template.' }

        # Copy-Item cannot reliably traverse some BricsCAD registry values.
        # reg.exe copies the entire profile key without enumerating those values.
        $templateName = (Get-Item -LiteralPath $template).PSChildName
        $registryRoot = $ProfilesRoot -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''
        $registryRoot = $registryRoot -replace '^HKCU:', 'HKEY_CURRENT_USER'
        $sourceRegistryKey = "$registryRoot\$templateName"
        $destinationRegistryKey = "$registryRoot\$ProfileName"
        & reg.exe copy $sourceRegistryKey $destinationRegistryKey /s /f | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not create the BricsCAD profile '$ProfileName' from '$templateName'."
        }
    }

    # WSCURRENT is saved in Profiles/{CurrentProfile}/General (V26 settings.xml).
    # Keeping STARTUP=3 and GETSTARTED=0 opens the Start page directly.
    $generalPath = Join-Path $profilePath 'General'
    New-Item -Force -Path $generalPath | Out-Null
    New-ItemProperty -LiteralPath $generalPath -Name 'WSCURRENT' -PropertyType String -Value $Workspace -Force | Out-Null
    New-ItemProperty -LiteralPath $generalPath -Name 'STARTUP' -PropertyType DWord -Value 3 -Force | Out-Null
    New-ItemProperty -LiteralPath $generalPath -Name 'GETSTARTED' -PropertyType DWord -Value 0 -Force | Out-Null
    return $ProfileName
}

$bricscad = Find-BricscadV26 $BricscadExe
$installRoot = Join-Path $env:LOCALAPPDATA 'BricsCAD Launcher'
# New directory version forces Explorer to read the refreshed colours instead
# of retaining cached artwork from the earlier Icons folder.
$iconsDir = Join-Path $installRoot 'Icons-v4'
New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null
$profilesRoot = Get-BricscadV26ProfilesRoot

# The workspace names below are the stock V26 workspaces.  The script runs after
# BricsCAD is started at the requested RunAsLevel by the /pr argument.
$editions = @(
    @{ Level = 'lite';       Label = 'Lite'; Color = '#00FFFF'; Workspace = '2D Drafting' },
    @{ Level = 'pro';        Label = 'Pro';  Color = '#A100FF'; Workspace = '2D Drafting' },
    @{ Level = 'bim';        Label = 'BIM';  Color = '#36CFFF'; Workspace = 'BIM' },
    @{ Level = 'mechanical'; Label = 'Mech'; Color = '#FF7400'; Workspace = 'Mechanical' },
    @{ Level = 'ultimate';   Label = 'Ult';  Color = '#00FF57'; Workspace = 'Ultimate' }
)

if ($NoDesktop) {
    $selectedDesktopEditions = @()
} elseif ($DesktopEditions) {
    if ($DesktopEditions -contains 'All') { $selectedDesktopEditions = @($editions.Label) }
    else { $selectedDesktopEditions = $DesktopEditions }
} else {
    $selectedDesktopEditions = Select-DesktopEditions -AvailableEditions $editions
}

# Re-running the installer updates both locations to match the new selection.
# Only the five launcher-owned, short-named shortcuts are touched.
$desktopFolder = [Environment]::GetFolderPath('Desktop')
$startFolder = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\BricsCAD Launcher'
foreach ($edition in $editions) {
    $legacyName = "$($edition.Label).lnk"
    $shortcutName = "BricsCAD $($edition.Label).lnk"
    # Always remove the legacy, unprefixed caption. Remove the current caption
    # too when that edition is not selected.
    $namesToRemove = @($legacyName)
    if ($selectedDesktopEditions -notcontains $edition.Label) { $namesToRemove += $shortcutName }
    foreach ($nameToRemove in $namesToRemove) {
        $desktopShortcut = Join-Path $desktopFolder $nameToRemove
        if (Test-Path -LiteralPath $desktopShortcut -PathType Leaf) { Remove-Item -LiteralPath $desktopShortcut -Force }
        if (-not $NoStartMenu) {
            $startShortcut = Join-Path $startFolder $nameToRemove
            if (Test-Path -LiteralPath $startShortcut -PathType Leaf) { Remove-Item -LiteralPath $startShortcut -Force }
        }
    }
}

$sourceIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($bricscad)
if (-not $sourceIcon) { throw "Could not extract the BricsCAD icon from '$bricscad'." }
try {
    foreach ($edition in $editions) {
        $profileName = Initialize-EditionProfile -ProfilesRoot $profilesRoot -ProfileName "BricsCAD Launcher - $($edition.Label)" -Workspace $edition.Workspace
        $iconPath = Join-Path $iconsDir "$($edition.Level).ico"
        New-EditionIcon -DestinationPath $iconPath -BricscadIcon $sourceIcon -Label $edition.Label -Color ([System.Drawing.ColorTranslator]::FromHtml($edition.Color))

        # No /B script is passed: BricsCAD can now open directly on Start.
        $arguments = "/pr $($edition.Level) /P `"$profileName`""
        $name = "BricsCAD $($edition.Label)"
        if ($selectedDesktopEditions -contains $edition.Label) {
            New-Shortcut -Path (Join-Path $desktopFolder "$name.lnk") -Target $bricscad -Arguments $arguments -IconPath $iconPath -Description "Launch BricsCAD as $($edition.Level) with the $($edition.Workspace) workspace."
        }
        if ((-not $NoStartMenu) -and ($selectedDesktopEditions -contains $edition.Label)) {
            New-Item -ItemType Directory -Force -Path $startFolder | Out-Null
            New-Shortcut -Path (Join-Path $startFolder "$name.lnk") -Target $bricscad -Arguments $arguments -IconPath $iconPath -Description "Launch BricsCAD as $($edition.Level) with the $($edition.Workspace) workspace."
        }
    }
} finally { $sourceIcon.Dispose() }

Write-Host "Installed BricsCAD edition shortcuts for: $bricscad" -ForegroundColor Green
