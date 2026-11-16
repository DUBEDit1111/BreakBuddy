' Starts BreakBuddy with no window at all. The login task, the Startup shortcut and the Desktop shortcut all run this.
' Why not powershell.exe directly: on Windows 11 with Windows Terminal as the default terminal, "-WindowStyle Hidden"
' still opens a terminal window, and closing that window ends BreakBuddy. Window style 0 here never creates one.
' Running it twice is safe: buddy.ps1 exits if a copy is already running.
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & dir & "\buddy.ps1""", 0, False
