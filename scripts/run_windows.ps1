# Downloads Godot 4.6.3 (once) into tools\godot, imports the project, and runs it.
# Usage (from the repo root, in PowerShell):
#   powershell -ExecutionPolicy Bypass -File scripts\run_windows.ps1            # play
#   powershell -ExecutionPolicy Bypass -File scripts\run_windows.ps1 -Editor    # open editor
#   powershell -ExecutionPolicy Bypass -File scripts\run_windows.ps1 -HostGame  # auto-host w/ bots
#   powershell -ExecutionPolicy Bypass -File scripts\run_windows.ps1 -Join 192.168.1.20
param(
    [switch]$Editor,
    [switch]$HostGame,
    [string]$Join = "",
    [int]$Bots = 3
)
$ErrorActionPreference = "Stop"
$Version = "4.6.3-stable"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$ToolDir = Join-Path $Root "tools\godot"
$Exe = Join-Path $ToolDir "Godot_v$($Version)_win64.exe"
$ConsoleExe = Join-Path $ToolDir "Godot_v$($Version)_win64_console.exe"

if (-not (Test-Path $Exe)) {
    New-Item -ItemType Directory -Force -Path $ToolDir | Out-Null
    $Zip = Join-Path $ToolDir "godot.zip"
    $Url = "https://github.com/godotengine/godot/releases/download/$Version/Godot_v$($Version)_win64.exe.zip"
    Write-Host "Downloading Godot $Version ..."
    Invoke-WebRequest -Uri $Url -OutFile $Zip
    Expand-Archive -Path $Zip -DestinationPath $ToolDir -Force
    Remove-Item $Zip
}

# First run: import assets + build the global class cache (class_name scripts).
if (-not (Test-Path (Join-Path $Root ".godot\global_script_class_cache.cfg"))) {
    Write-Host "Importing project (first run only) ..."
    & $ConsoleExe --headless --path $Root --import | Out-Host
}

if ($Editor) {
    & $Exe --path $Root -e
    exit
}
$UserArgs = @()
if ($HostGame) { $UserArgs += "--host"; $UserArgs += "--bots=$Bots" }
if ($Join -ne "") { $UserArgs += "--join=$Join" }
if ($UserArgs.Count -gt 0) {
    & $Exe --path $Root -- @UserArgs
} else {
    & $Exe --path $Root
}
