# Create desktop shortcut
param(
    [string]$ProjectsFolder
)

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Claude Code.lnk")
$Shortcut.TargetPath = "wsl.exe"
$Shortcut.Arguments = "-d Alpine --cd `"$ProjectsFolder`" claude"
$Shortcut.WorkingDirectory = $ProjectsFolder
$Shortcut.IconLocation = "$env:LOCALAPPDATA\ClaudeCode\claude-icon.ico"
$Shortcut.Description = "Launch Claude Code in WSL"
$Shortcut.Save()

Write-Output "SHORTCUT_CREATED"