# Runs every headless test, one at a time, and reports pass/fail.
#   powershell -ExecutionPolicy Bypass -File scripts\test_all.ps1
# The console exe launches the real game as a child, so killing only the wrapper
# orphans a process that keeps the game port. Every test here runs under a deadline
# and its whole process family is cleaned up afterwards. Only headless processes
# started from this repo are touched, so a game you have open is safe.
$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Godot = Join-Path $Root "tools\godot\Godot_v4.6.3-stable_win64_console.exe"
$TestPort = 24690  # not the game port, so tests can run while the game is open

function Clear-Strays {
    Get-CimInstance Win32_Process -Filter "Name like 'Godot_v4.6.3%'" |
        Where-Object { $_.CommandLine -like "*--headless*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 800
}

function Run-Test([string]$Name, [string]$Script, [string[]]$GameArgs, [int]$Secs, [string]$OkText) {
    $log = Join-Path $env:TEMP ("slopped_test_" + ($Name -replace '\W', '_') + ".log")
    $a = @("--headless", "--path", "`"$Root`"", "-s", $Script, "--", "--port=$TestPort") + $GameArgs
    $p = Start-Process -FilePath $Godot -ArgumentList $a -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $null = $p.WaitForExit($Secs * 1000)
    Clear-Strays
    $text = Get-Content $log -Raw
    $ok = $text -match [regex]::Escape($OkText)
    $errors = ([regex]::Matches($text, "SCRIPT ERROR")).Count
    $fails = ($text -split "`n" | Where-Object { $_ -match "^FAIL" }) -join " | "
    "{0,-22} {1,-5} script errors: {2}  {3}" -f $Name, $(if ($ok) { "OK" } else { "FAIL" }), $errors, $fails
}

Clear-Strays
Start-Sleep -Seconds 2  # let the OS release the game port
Run-Test "smoke lobby" "tests/smoke_test.gd" @("--host", "--bots=3") 60 "SMOKE OK"
Run-Test "smoke giant" "tests/smoke_test.gd" @("--host", "--bots=4", "--giant") 60 "SMOKE OK"
Run-Test "physics" "tests/physics_test.gd" @("--host", "--bots=2") 70 "PHYSICS OK"
Run-Test "settings" "tests/settings_test.gd" @() 30 "SETTINGS OK"
Run-Test "gamepad + display" "tests/ui_test.gd" @() 30 "UI OK"
Run-Test "town walk" "tests/town_test.gd" @("--host", "--bots=1") 280 "TOWN OK"
Run-Test "rides" "tests/rides_test.gd" @("--host", "--bots=1") 175 "RIDES OK"
foreach ($g in "pocket", "soup", "cursed") {
    Run-Test "$g (bot boss)" "tests/games_test.gd" @("--host", "--bots=4", "--game=$g", "--bot-boss") 75 "GAME $g OK"
    Run-Test "$g (you boss)" "tests/games_test.gd" @("--host", "--bots=3", "--game=$g") 75 "GAME $g OK"
}
$hostLog = Join-Path $env:TEMP "slopped_test_host.log"
$h = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$Root`"", "--", "--port=$TestPort", "--host", "--bots=1") -PassThru -NoNewWindow -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err"
Start-Sleep -Seconds 3
$log = Join-Path $env:TEMP "slopped_test_client.log"
$c = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$Root`"", "-s", "tests/net_test.gd", "--", "--port=$TestPort", "--join=127.0.0.1") -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"
$null = $c.WaitForExit(60000)
Clear-Strays
$text = Get-Content $log -Raw
"{0,-22} {1,-5} script errors (host): {2}" -f "two-process net", $(if ($text -match "NET OK") { "OK" } else { "FAIL" }), ([regex]::Matches((Get-Content $hostLog -Raw), "SCRIPT ERROR")).Count
