# Enhanced install-tools.ps1 - Installs Node.js and Claude Code with robust WSL handling

param()

$commands = @'
#!/bin/sh
# Update packages
sudo apt update
sudo apt install -y nodejs npm curl git

# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
'@

try {
    # Function to find WSL executable (same as other scripts)
    function Find-WSLExecutable {
        $wslPaths = @(
            "$env:SystemRoot\System32\wsl.exe",
            "$env:LocalAppData\Microsoft\WindowsApps\wsl.exe",
            "$env:ProgramFiles\WSL\wsl.exe"
        )
        
        foreach ($path in $wslPaths) {
            if (Test-Path $path) {
                Write-Host "Using WSL at: $path"
                return $path
            }
        }
        
        # Try finding wsl.exe in PATH as fallback
        try {
            $null = Get-Command wsl.exe -ErrorAction Stop
            Write-Host "Using WSL from PATH"
            return "wsl.exe"
        } catch {
            return $null
        }
    }
    
    # Find WSL executable
    $wslPath = Find-WSLExecutable
    if (-not $wslPath) {
        Write-Output "ERROR: WSL executable not found"
        exit 1
    }
    
    # Test WSL functionality briefly
    Write-Output "Testing WSL functionality..."
    $attempts = 0
    $wslReady = $false
    
    while ($attempts -lt 10 -and -not $wslReady) {
        try {
            $null = & $wslPath --status 2>$null
            if ($LASTEXITCODE -eq 0) {
                $wslReady = $true
                break
            }
        } catch {}
        Start-Sleep -Seconds 2
        $attempts++
    }
    
    if (-not $wslReady) {
        Write-Output "ERROR: WSL is not responding"
        exit 1
    }
    
    # Check if Linux distribution is available
    Write-Output "Checking Linux distribution availability..."
    try {
        $distros = & $wslPath --list --quiet 2>$null
        if (-not ($distros -match "Debian" -or $distros -match "Ubuntu")) {
            Write-Output "ERROR: No supported Linux distribution found in WSL"
            Write-Output "Available distributions: $distros"
            exit 1
        }
        
        # Determine which distribution to use
        $targetDistro = "Debian"
        if ($distros -match "Ubuntu" -and -not ($distros -match "Debian")) {
            $targetDistro = "Ubuntu"
        }
    } catch {
        Write-Output "ERROR: Could not list WSL distributions: $_"
        exit 1
    }
    
    # Save script to temp file
    $tempScript = "$env:TEMP\linux-setup.sh"
    $commands | Out-File -FilePath $tempScript -Encoding ASCII -NoNewline
    
    # Execute in Linux distribution
    Write-Output "Installing Node.js and Claude Code in $targetDistro..."
    $scriptContent = Get-Content $tempScript -Raw
    & $wslPath -d $targetDistro --exec sh -c $scriptContent
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output "TOOLS_INSTALLED"
        exit 0
    } else {
        Write-Output "TOOLS_INSTALL_FAILED"
        Write-Output "Exit code: $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Output "ERROR: $_"
    exit 1
} finally {
    Remove-Item $tempScript -ErrorAction SilentlyContinue
}