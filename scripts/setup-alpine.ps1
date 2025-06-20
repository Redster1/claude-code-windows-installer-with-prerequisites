# Setup Alpine Linux
param()

try {
    # Check if Alpine already exists
    $distros = & wsl --list --quiet 2>$null
    if ($distros -match "Alpine") {
        Write-Output "ALPINE_EXISTS"
        exit 0
    }
    
    # Install Alpine
    Write-Output "Installing Alpine Linux..."
    & wsl --install -d Alpine
    
    # Wait for installation
    Start-Sleep -Seconds 5
    
    # Set as default
    & wsl --set-default Alpine
    
    Write-Output "ALPINE_INSTALLED"
    exit 0
} catch {
    Write-Output "ERROR: $_"
    exit 1
}