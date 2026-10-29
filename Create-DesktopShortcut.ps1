# Run via Create-DesktopShortcut.cmd, or pass a folder to create the shortcut there.
param([string]$DestinationDirectory = [Environment]::GetFolderPath('DesktopDirectory'))
$ErrorActionPreference = 'Stop'

try {
    $launcher = Join-Path $PSScriptRoot 'bib2items.cmd'
    if (!(Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Launcher not found: $launcher" }
    if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) { throw 'Windows did not provide a desktop folder.' }
    $destination = Get-Item -LiteralPath $DestinationDirectory
    if (!$destination.PSIsContainer) { throw 'The shortcut destination must be a folder.' }
    $shortcutPath = Join-Path $destination.FullName 'SIBIR.lnk'
    if (Test-Path -LiteralPath $shortcutPath) { Write-Warning "Replacing shortcut: $shortcutPath" }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $launcher
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = 'Drop one JACoW .tex paper or paper folder here to run SIBIR.'
    $iconPath = Join-Path $PSScriptRoot 'assets\sibir-jacow.ico'
    if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
        $shortcut.IconLocation = "$iconPath,0"
    } else {
        $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,1"
        Write-Warning 'Custom icon not found. Keep the assets folder beside the SIBIR scripts to use it.'
    }
    $shortcut.Save()
    Write-Host "Created: $shortcutPath"
    Write-Host 'Drop one .tex paper or paper folder onto the SIBIR shortcut to start.'
    Write-Host 'Keep the SIBIR installation folder in place; recreate the shortcut if you move it.'
}
catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
