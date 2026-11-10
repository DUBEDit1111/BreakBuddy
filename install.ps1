# Registers BreakBuddy to start at login and starts it now. Safe to run again after moving the folder. Undo: uninstall.ps1
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path (Join-Path $Root 'config.json'))) {
    Copy-Item (Join-Path $Root 'config.example.json') (Join-Path $Root 'config.json')
    Write-Host 'No config.json yet: copied config.example.json (hourly water only). Edit it any time; BreakBuddy reloads it.'
}
# Stop a copy that is already running so the new one starts with this folder's code.
Stop-ScheduledTask -TaskName 'BreakBuddy' -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*buddy.ps1*' -and $_.CommandLine -notlike '*-Popup*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $Root 'buddy.ps1'))
$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'BreakBuddy' -Action $a -Trigger $t -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName 'BreakBuddy'
Write-Host "BreakBuddy registered and started from $Root"
