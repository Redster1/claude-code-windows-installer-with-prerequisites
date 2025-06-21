# Setup Debian Linux - Fixed version
param()

try {
    Write-Output "Starting Debian setup..."
    
    # Simple WSL check
    $wslStatus = & wsl.exe --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Output "ERROR: WSL not functional"
        exit 1
    }
    
    # Check existing distros
    $distros = & wsl.exe --list --quiet 2>&1
    if ($distros -match "Debian") {
        Write-Output "DEBIAN_EXISTS"
        exit 0
    }
    
    # Install Debian (no --no-launch flag)
    Write-Output "Installing Debian..."
    & wsl.exe --install -d Debian
    
    if ($LASTEXITCODE -eq 0) {
        # Wait for installation
        Start-Sleep -Seconds 10
        
        # Verify installation
        $distros = & wsl.exe --list --quiet 2>&1
        if ($distros -match "Debian") {
            # Set as default
            & wsl.exe --set-default Debian
            Write-Output "DEBIAN_INSTALLED"
            exit 0
        }
    }
    
    Write-Output "ERROR: Debian installation failed"
    exit 1
    
} catch {
    Write-Output "ERROR: $_"
    exit 1
}