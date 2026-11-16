# Stops BreakBuddy and removes the login task. Your config.json and the folder stay; delete the folder to remove everything.
# If you added the optional AI prompt hook (see SETUP.md), remove that line from your AI tool's settings too.
Stop-ScheduledTask -TaskName 'BreakBuddy' -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'BreakBuddy' -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*buddy.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'BreakBuddy Settings.lnk') -ErrorAction SilentlyContinue
foreach ($folder in 'Startup', 'Desktop') { Remove-Item (Join-Path ([Environment]::GetFolderPath($folder)) 'BreakBuddy.lnk') -ErrorAction SilentlyContinue }
Write-Host 'BreakBuddy removed.'
