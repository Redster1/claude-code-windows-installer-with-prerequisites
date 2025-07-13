# create-shortcuts.ps1 - Creates desktop shortcut for native Windows PowerShell

param(
    [string]$ProjectsFolder
)

try {
    Write-Output "Creating native Windows PowerShell shortcut..."
    
    # Find PowerShell executable (prefer PowerShell 7+ if available, fallback to Windows PowerShell)
    $powershellPaths = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "$env:ProgramFiles\PowerShell\6\pwsh.exe", 
        "$env:LocalAppData\Microsoft\WindowsApps\pwsh.exe",
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    )
    
    $powershellPath = $null
    $powershellName = "PowerShell"
    
    foreach ($path in $powershellPaths) {
        if (Test-Path $path) {
            $powershellPath = $path
            if ($path -match "pwsh") {
                $powershellName = "PowerShell 7"
            } else {
                $powershellName = "Windows PowerShell"
            }
            Write-Output "Using PowerShell at: $powershellPath ($powershellName)"
            break
        }
    }
    
    if (-not $powershellPath) {
        Write-Output "ERROR: No PowerShell executable found"
        exit 1
    }
    
    # Ensure projects folder exists
    if (-not (Test-Path $ProjectsFolder)) {
        New-Item -ItemType Directory -Path $ProjectsFolder -Force | Out-Null
        Write-Output "Created projects folder: $ProjectsFolder"
    }
    
    # Create the desktop shortcut
    $WshShell = New-Object -ComObject "WScript.Shell"
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Claude Code.lnk")
    
    # Set target to PowerShell
    $Shortcut.TargetPath = $powershellPath
    
    # Create PowerShell arguments to:
    # 1. Set location to projects folder
    # 2. Show a welcome message
    # 3. Automatically start Claude Code
    $psCommand = @"
Set-Location '$ProjectsFolder'; 
Write-Host 'Claude Code for Windows' -ForegroundColor Green; 
Write-Host 'Starting Claude Code in: $ProjectsFolder' -ForegroundColor Cyan; 
Write-Host ''; 
claude
"@
    
    # Build arguments for PowerShell
    if ($powershellPath -match "pwsh") {
        # PowerShell 7+ arguments
        $Shortcut.Arguments = "-NoExit -Command `"$psCommand`""
    } else {
        # Windows PowerShell arguments  
        $Shortcut.Arguments = "-NoExit -Command `"$psCommand`""
    }
    
    # Set working directory
    $Shortcut.WorkingDirectory = $ProjectsFolder
    
    # Set icon (optional - don't fail if icon missing)
    $iconPath = "$env:LOCALAPPDATA\ClaudeCode\claude-icon.ico"
    if (Test-Path $iconPath) {
        try {
            $Shortcut.IconLocation = $iconPath
            Write-Output "Icon set to: $iconPath"
        } catch {
            Write-Output "WARNING: Could not set icon: $_"
        }
    } else {
        Write-Output "WARNING: Icon file not found at: $iconPath"
    }
    
    # Set description
    $Shortcut.Description = "Launch Claude Code in $powershellName"
    
    # Save the shortcut
    try {
        $Shortcut.Save()
        Write-Output "Shortcut saved successfully to: $env:USERPROFILE\Desktop\Claude Code.lnk"
    } catch {
        Write-Output "ERROR: Failed to save shortcut: $_"
        throw
    }
    
    Write-Output "Desktop shortcut created successfully"
    Write-Output "Target: $powershellPath"
    Write-Output "Working Directory: $ProjectsFolder"
    Write-Output "Uses: $powershellName"
    
    
    Write-Output "SHORTCUT_CREATED"
    exit 0
} catch {
    Write-Output "ERROR creating shortcut: $_"
    exit 1
}