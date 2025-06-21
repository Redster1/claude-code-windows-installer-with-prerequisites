# Install Node.js and Claude Code - Fixed version
param()

try {
    # Check which distro to use
    $distros = & wsl.exe --list --quiet 2>&1
    $targetDistro = "Debian"
    if ($distros -match "Ubuntu" -and -not ($distros -match "Debian")) {
        $targetDistro = "Ubuntu"
    }

    # Check if claude command already exists
    Write-Output "Checking for existing Claude Code tools in $targetDistro..."
    & wsl.exe -d $targetDistro -- bash -c "command -v claude >/dev/null 2>&1"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output "TOOLS_ALREADY_INSTALLED"
        exit 0
    }

    Write-Output "Installing tools in WSL..."
    Write-Output "Using distribution: $targetDistro"
    
    # Install commands
    $commands = @"
sudo apt update
sudo apt install -y nodejs npm curl git
npm install -g @anthropic-ai/claude-code
claude --version
"@

    # Execute in WSL
    $commands | & wsl.exe -d $targetDistro -- bash
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output "TOOLS_INSTALLED"
        exit 0
    } else {
        Write-Output "TOOLS_INSTALL_FAILED"
        exit 1
    }
} catch {
    Write-Output "ERROR: $_"
    exit 1
}