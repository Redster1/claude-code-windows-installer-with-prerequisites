# Install Node.js and Claude Code - Fixed version with enhanced readiness checks
param()

try {
    # Check which distro to use
    $distros = & wsl.exe --list --quiet 2>&1
    $targetDistro = "Debian"
    if ($distros -match "Ubuntu" -and -not ($distros -match "Debian")) {
        $targetDistro = "Ubuntu"
    }

    # Wait for distribution to be fully ready (including user setup)
    Write-Output "Waiting for $targetDistro to be fully ready..."
    $maxWaitTime = 180  # Maximum wait time in seconds (3 minutes for slower systems)
    $waitTime = 0
    $distroReady = $false
    
    while ($waitTime -lt $maxWaitTime -and -not $distroReady) {
        try {
            # Test if we can run a basic command in the distro
            $testResult = & wsl.exe -d $targetDistro --exec whoami 2>$null
            
            if ($LASTEXITCODE -eq 0 -and $testResult -ne "") {
                Write-Output "$targetDistro is ready with user: $testResult"
                $distroReady = $true
                break
            }
        } catch {
            # Ignore errors and continue waiting
        }
        
        Start-Sleep -Seconds 2
        $waitTime += 2
        Write-Output "Waiting for $targetDistro... ($waitTime/$maxWaitTime seconds)"
    }
    
    if (-not $distroReady) {
        Write-Output "ERROR: $targetDistro is not ready after $maxWaitTime seconds"
        exit 1
    }
    
    # Check if tools are already installed and functional
    Write-Output "Checking for existing tools in $targetDistro..."
    
    # Test Node.js functionality first
    $nodeJob = Start-Job -ScriptBlock {
        param($distro)
        try {
            $nodeResult = & wsl.exe -d $distro --exec node --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $nodeResult -match "v\d+\.\d+\.\d+") {
                return "NODE_FUNCTIONAL:$nodeResult"
            } else {
                return "NODE_NOT_FUNCTIONAL:$nodeResult"
            }
        } catch {
            return "NODE_ERROR"
        }
    } -ArgumentList $targetDistro
    
    $nodeResult = Wait-Job -Job $nodeJob -Timeout 8
    $nodeStatus = "NOT_FUNCTIONAL"
    
    if ($nodeResult) {
        $nodeOutput = Receive-Job -Job $nodeJob
        Remove-Job -Job $nodeJob -Force
        
        if ($nodeOutput -match "NODE_FUNCTIONAL") {
            $nodeStatus = "FUNCTIONAL"
            Write-Output "Node.js is functional: $($nodeOutput -replace 'NODE_FUNCTIONAL:', '')"
        } else {
            Write-Output "Node.js test failed: $nodeOutput"
        }
    } else {
        Remove-Job -Job $nodeJob -Force
        Write-Output "Node.js test timed out"
    }
    
    # Test Claude Code functionality
    $claudeJob = Start-Job -ScriptBlock {
        param($distro)
        try {
            $claudeResult = & wsl.exe -d $distro --exec claude --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $claudeResult -match "claude|Claude") {
                return "CLAUDE_FUNCTIONAL:$claudeResult"
            } else {
                return "CLAUDE_NOT_FUNCTIONAL:$claudeResult"
            }
        } catch {
            return "CLAUDE_ERROR"
        }
    } -ArgumentList $targetDistro
    
    $claudeResult = Wait-Job -Job $claudeJob -Timeout 10
    $claudeStatus = "NOT_FUNCTIONAL"
    
    if ($claudeResult) {
        $claudeOutput = Receive-Job -Job $claudeJob
        Remove-Job -Job $claudeJob -Force
        
        if ($claudeOutput -match "CLAUDE_FUNCTIONAL") {
            $claudeStatus = "FUNCTIONAL"
            Write-Output "Claude Code is functional: $($claudeOutput -replace 'CLAUDE_FUNCTIONAL:', '')"
        } else {
            Write-Output "Claude Code test failed: $claudeOutput"
        }
    } else {
        Remove-Job -Job $claudeJob -Force
        Write-Output "Claude Code test timed out"
    }
    
    # If both tools are functional, we're done
    if ($nodeStatus -eq "FUNCTIONAL" -and $claudeStatus -eq "FUNCTIONAL") {
        Write-Output "All tools are functional, skipping installation"
        Write-Output "TOOLS_ALREADY_INSTALLED"
        exit 0
    } else {
        Write-Output "Tools need installation/repair - Node.js: $nodeStatus, Claude: $claudeStatus"
    }

    Write-Output "Installing tools in WSL..."
    Write-Output "Using distribution: $targetDistro"
    
    # Install commands with better error handling
    $commands = @"
#!/bin/bash
set -e  # Exit on any error

# Set non-interactive mode to prevent prompts
export DEBIAN_FRONTEND=noninteractive

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install required packages
echo "Installing Node.js, npm, curl, and git..."
sudo apt install -y nodejs npm curl git

# Verify Node.js installation
echo "Verifying Node.js installation..."
node --version
npm --version

# Install Claude Code globally
echo "Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# Verify Claude Code installation
echo "Verifying Claude Code installation..."
claude --version

echo "All tools installed successfully!"
"@

    # Save commands to a temporary script file
    $tempScript = "$env:TEMP\install-tools.sh"
    $commands | Out-File -FilePath $tempScript -Encoding UTF8 -NoNewline
    
    # Copy script to WSL and execute with proper error handling
    Write-Output "Copying installation script to WSL..."
    & wsl.exe -d $targetDistro -- bash -c "cat > /tmp/install-tools.sh" < $tempScript
    if ($LASTEXITCODE -ne 0) {
        Write-Output "ERROR: Failed to copy installation script to WSL"
        exit 1
    }
    
    Write-Output "Making installation script executable..."
    & wsl.exe -d $targetDistro -- chmod +x /tmp/install-tools.sh
    if ($LASTEXITCODE -ne 0) {
        Write-Output "ERROR: Failed to make installation script executable"
        exit 1
    }
    
    Write-Output "Executing installation script..."
    & wsl.exe -d $targetDistro -- /tmp/install-tools.sh
    
    # Clean up
    & wsl.exe -d $targetDistro -- rm -f /tmp/install-tools.sh
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -eq 0) {
        # Verify the installation was successful
        Write-Output "Verifying installation..."
        $claudeVersion = & wsl.exe -d $targetDistro -- claude --version 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $claudeVersion -ne "") {
            Write-Output "Claude Code installed successfully: $claudeVersion"
            Write-Output "TOOLS_INSTALLED"
            exit 0
        } else {
            Write-Output "ERROR: Claude Code installation verification failed"
            Write-Output "TOOLS_INSTALL_FAILED"
            exit 1
        }
    } else {
        Write-Output "ERROR: Installation script failed with exit code $LASTEXITCODE"
        Write-Output "TOOLS_INSTALL_FAILED"
        exit 1
    }
} catch {
    Write-Output "ERROR: $_"
    exit 1
}