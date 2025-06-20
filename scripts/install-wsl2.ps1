# Install WSL2 - simple and direct
param()

try {
    # Check if already installed
    $wslCheck = & wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Output "WSL_ALREADY_INSTALLED"
        exit 0
    }
    
    # Install WSL with no distribution
    Write-Output "Installing WSL2..."
    & wsl --install --no-distribution
    
    if ($LASTEXITCODE -eq 3010) {
        Write-Output "REBOOT_REQUIRED"
        exit 3010
    } elseif ($LASTEXITCODE -eq 0) {
        Write-Output "WSL_INSTALLED"
        exit 0
    } else {
        Write-Output "WSL_INSTALL_FAILED"
        exit 1
    }
} catch {
    Write-Output "ERROR: $_"
    exit 1
}