# Removes only the per-user shortcuts and support files created by the installer.
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
# Remove both the current short names and shortcuts produced by earlier releases.
$names = @('Lite', 'Pro', 'BIM', 'Mech', 'Ult' | ForEach-Object { "$_.lnk" }) +
         @('Lite', 'Pro', 'BIM', 'Mech', 'Ult' | ForEach-Object { "BricsCAD $_.lnk" }) +
         @('Lite', 'Pro', 'BIM', 'Mech', 'Ult' | ForEach-Object { "BricsCAD V26 $_.lnk" })
$folders = @(
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\BricsCAD Launcher')
)
foreach ($folder in $folders) {
    foreach ($name in $names) {
        $path = Join-Path $folder $name
        if ((Test-Path -LiteralPath $path) -and $PSCmdlet.ShouldProcess($path, 'Remove shortcut')) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}
$startFolder = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\BricsCAD Launcher'
if ((Test-Path -LiteralPath $startFolder) -and -not (Get-ChildItem -LiteralPath $startFolder -Force | Select-Object -First 1)) {
    Remove-Item -LiteralPath $startFolder -Force
}
$installRoot = Join-Path $env:LOCALAPPDATA 'BricsCAD Launcher'
if ((Test-Path -LiteralPath $installRoot) -and $PSCmdlet.ShouldProcess($installRoot, 'Remove generated startup scripts and icons')) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}
Write-Host 'BricsCAD edition shortcuts have been removed.' -ForegroundColor Green
