# Install WSL2 - robust approach for systems without WSL
param()

try {
    # First check if WSL Windows feature is enabled
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    
    # Check if wsl command exists and works
    $wslWorks = $false
    try {
        $null = & wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            $wslWorks = $true
        }
    } catch {}
    
    if ($wslWorks) {
        Write-Output "WSL_ALREADY_INSTALLED"
        exit 0
    }
    
    # If WSL features are not enabled, enable them
    $rebootNeeded = $false
    
    if ($wslFeature.State -ne "Enabled") {
        Write-Output "Enabling WSL feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
        $rebootNeeded = $true
    }
    
    if ($vmFeature.State -ne "Enabled") {
        Write-Output "Enabling Virtual Machine Platform..."
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
        $rebootNeeded = $true
    }
    
    if ($rebootNeeded) {
        Write-Output "REBOOT_REQUIRED"
        exit 3010
    }
    
    # If features are enabled but wsl command doesn't work, try the modern install
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