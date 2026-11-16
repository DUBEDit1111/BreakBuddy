# Registers BreakBuddy to start at login and starts it now. Safe to run again after moving the folder. Undo: uninstall.ps1
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path (Join-Path $Root 'config.json'))) {
    Copy-Item (Join-Path $Root 'config.example.json') (Join-Path $Root 'config.json')
    Write-Host 'No config.json yet: copied config.example.json (hourly water only). Edit it any time; BreakBuddy reloads it.'
}
# Stop a copy that is already running so the new one starts with this folder's code.
Stop-ScheduledTask -TaskName 'BreakBuddy' -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*buddy.ps1*' -and $_.CommandLine -notlike '*-Popup*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
# start.vbs launches buddy.ps1 with no window (a hidden powershell.exe still opens a Windows Terminal window on Windows 11).
$a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f (Join-Path $Root 'start.vbs'))
$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'BreakBuddy' -Action $a -Trigger $t -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName 'BreakBuddy'
# Startup-folder and Desktop shortcuts that start BreakBuddy. The Startup one shows under Task Manager > Startup apps
# and backs up the login task; a second start exits at once.
try {
    foreach ($folder in 'Startup', 'Desktop') {
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath($folder)) 'BreakBuddy.lnk'))
        $lnk.TargetPath = 'wscript.exe'; $lnk.Arguments = '"{0}"' -f (Join-Path $Root 'start.vbs')
        $lnk.WorkingDirectory = $Root; $lnk.Description = 'Start BreakBuddy reminders'
        $lnk.Save()
    }
} catch { Write-Host "Could not add the Startup and Desktop shortcuts ($($_.Exception.Message))." }
# Start menu shortcut to the settings window.
try {
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'BreakBuddy Settings.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $Root 'settings.ps1')
    $lnk.WorkingDirectory = $Root; $lnk.Description = 'Change BreakBuddy reminders and the session timer'
    $lnk.Save()
    Write-Host 'Settings: open "BreakBuddy Settings" from the Start menu.'
} catch { Write-Host "Could not add the Start menu shortcut ($($_.Exception.Message)). Open settings with: powershell -STA -ExecutionPolicy Bypass -File settings.ps1" }
Write-Host "BreakBuddy registered and started from $Root"
