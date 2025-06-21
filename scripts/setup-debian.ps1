# Setup Debian Linux - Simple and robust PowerShell

param()

# Find WSL executable function
function Find-WSLExecutable {
    $wslPaths = @(
        "$env:SystemRoot\System32\wsl.exe",
        "$env:LocalAppData\Microsoft\WindowsApps\wsl.exe",
        "$env:ProgramFiles\WSL\wsl.exe"
    )
    
    foreach ($path in $wslPaths) {
        if (Test-Path $path) {
            Write-Host "Found WSL at: $path"
            return $path
        }
    }
    
    try {
        $null = Get-Command wsl.exe -ErrorAction Stop
        Write-Host "Found WSL in PATH"
        return "wsl.exe"
    } catch {
        return $null
    }
}

# Check WSL services function  
function Test-WSLServices {
    try {
        $lxssService = Get-Service -Name "LxssManager" -ErrorAction SilentlyContinue
        if ($lxssService) {
            Write-Output "LxssManager service status: $($lxssService.Status)"
            if ($lxssService.Status -ne "Running") {
                Write-Output "Attempting to start LxssManager service..."
                try {
                    Start-Service -Name "LxssManager" -ErrorAction Stop
                    Start-Sleep -Seconds 3
                    return $true
                } catch {
                    Write-Output "Failed to start LxssManager: $_"
                    return $false
                }
            }
            return $true
        } else {
            Write-Output "LxssManager service not found"
            return $false
        }
    } catch {
        Write-Output "Error checking WSL services: $_"
        return $false
    }
}

# Test WSL functionality
function Test-WSLFunctionality {
    param([string]$wslPath)
    
    Write-Output "Testing WSL status..."
    try {
        $result = & $wslPath --status 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Output "WSL status check passed"
            return $true
        } else {
            Write-Output "WSL status check failed with exit code: $exitCode"
            Write-Output "Output: $result"
        }
    } catch {
        Write-Output "WSL status check threw exception: $_"
    }
    
    return $false
}

try {
    Write-Output "Starting WSL readiness check..."
    
    # Step 1: Find WSL executable
    $wslPath = Find-WSLExecutable
    if (-not $wslPath) {
        Write-Output "ERROR: WSL executable not found"
        exit 1
    }
    
    # Step 2: Check WSL services
    Write-Output "Checking WSL services..."
    $serviceResult = Test-WSLServices
    
    # Step 3: Wait for WSL to be ready
    Write-Output "Waiting for WSL to be ready..."
    $maxAttempts = 30
    $attempts = 0
    $wslReady = $false
    
    while ($attempts -lt $maxAttempts -and -not $wslReady) {
        $attempts = $attempts + 1
        $remainingTime = ($maxAttempts - $attempts) * 2
        Write-Output "Attempt $attempts of $maxAttempts ($remainingTime seconds remaining)"
        
        if (Test-WSLFunctionality -wslPath $wslPath) {
            $wslReady = $true
            Write-Output "WSL is ready!"
            break
        }
        
        if ($attempts -eq 10) {
            Write-Output "WSL still not ready after 20 seconds, trying service restart..."
            $null = Test-WSLServices
        }
        
        Start-Sleep -Seconds 2
    }
    
    if (-not $wslReady) {
        $totalWaitTime = $maxAttempts * 2
        Write-Output "ERROR: WSL is not responding after $totalWaitTime seconds"
        Write-Output "WSL appears to be installed but is not functional."
        Write-Output "This may require:"
        Write-Output "  1. A system restart"
        Write-Output "  2. Manual WSL initialization"
        Write-Output "  3. Checking Windows Update for WSL components"
        Write-Output ""
        Write-Output "You can try running 'wsl --install' manually from an admin PowerShell."
        exit 1
    }
    
    # Step 4: Check if Debian already exists
    Write-Output "Checking for existing Debian installation..."
    try {
        $distros = & $wslPath --list --quiet 2>$null
        if ($distros -match "Debian") {
            Write-Output "Debian Linux already exists"
            Write-Output "DEBIAN_EXISTS"
            exit 0
        }
    } catch {
        Write-Output "Warning: Could not check existing distributions: $_"
    }
    
    # Step 5: Install Debian
    Write-Output "Installing Debian Linux..."
    try {
        & $wslPath --install -d Debian
        $installExitCode = $LASTEXITCODE
        
        if ($installExitCode -ne 0) {
            Write-Output "Debian installation command failed with exit code: $installExitCode"
            
            Write-Output "Trying alternative installation method..."
            & $wslPath --install Debian
            if ($LASTEXITCODE -ne 0) {
                Write-Output "Alternative installation also failed"
                exit 1
            }
        }
    } catch {
        Write-Output "Debian installation failed: $_"
        exit 1
    }
    
    # Step 6: Wait for Debian to appear
    Write-Output "Waiting for Debian to be registered..."
    $attempts = 0
    $debianReady = $false
    $maxWait = 20
    
    while ($attempts -lt $maxWait -and -not $debianReady) {
        $attempts = $attempts + 1
        Write-Output "Checking for Debian... attempt $attempts of $maxWait"
        
        try {
            $distros = & $wslPath --list --quiet 2>$null
            if ($distros -match "Debian") {
                $debianReady = $true
                Write-Output "Debian Linux detected!"
                break
            }
        } catch {
            Write-Output "Error checking distributions: $_"
        }
        
        Start-Sleep -Seconds 2
    }
    
    if ($debianReady) {
        Write-Output "Setting Debian as default distribution..."
        try {
            & $wslPath --set-default Debian
            Write-Output "DEBIAN_INSTALLED"
            exit 0
        } catch {
            Write-Output "Warning: Could not set Debian as default: $_"
            Write-Output "DEBIAN_INSTALLED"
            exit 0
        }
    } else {
        Write-Output "Debian installation timeout - distribution not appearing in WSL list"
        Write-Output "Debian may have been installed but is not yet visible to WSL"
        exit 1
    }
    
} catch {
    Write-Output "ERROR in Debian setup: $_"
    exit 1
}