# Stops BreakBuddy and removes the login task. Your config.json and the folder stay; delete the folder to remove everything.
# If you added the optional AI prompt hook (see SETUP.md), remove that line from your AI tool's settings too.
Stop-ScheduledTask -TaskName 'BreakBuddy' -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'BreakBuddy' -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*buddy.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Write-Host 'BreakBuddy removed.'
