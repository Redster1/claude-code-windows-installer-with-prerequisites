# install-wsl2.ps1 - Simplified WSL installation using Windows built-in installer

param()

try {
    # Check if WSL features are enabled
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    
    # Check if wsl.exe exists and works
    $wslWorks = $false
    try {
        $null = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            $wslWorks = $true
        }
    } catch {}
    
    # If WSL works, we're done
    if ($wslWorks) {
        Write-Output "WSL_ALREADY_INSTALLED"
        exit 0
    }
    
    # Step 1: Enable features if needed
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
    
    # Step 2: Features are enabled but WSL doesn't work
    # First, install the WSL2 kernel update which is often the missing piece
    Write-Output "Installing WSL2 kernel update..."
    $kernelUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
    $kernelPath = "$env:TEMP\wsl_update_x64.msi"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $kernelUrl -OutFile $kernelPath -UseBasicParsing
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$kernelPath`"", "/quiet", "/norestart" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Output "WSL2 kernel installed successfully"
        } else {
            Write-Output "WSL2 kernel installation returned code: $($process.ExitCode)"
        }
        
        Remove-Item $kernelPath -ErrorAction SilentlyContinue
    } catch {
        Write-Output "Failed to install kernel update: $_"
    }
    
    # Step 3: Use winget to install WSL if available
    Write-Output "Checking for winget..."
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    
    if (Test-Path $wingetPath) {
        Write-Output "Installing WSL using winget..."
        try {
            # Accept source agreements first
            & $wingetPath source update --accept-source-agreements
            
            # Install WSL from Microsoft Store
            $wingetResult = & $wingetPath install --id 9P9TQF7MRM4R --source msstore --accept-package-agreements --accept-source-agreements 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Output "WSL installed via winget successfully"
                
                # Give it time to register
                Start-Sleep -Seconds 5
                
                # Try to verify
                $null = wsl --status 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Output "WSL_INSTALLED"
                    exit 0
                }
            } else {
                Write-Output "Winget installation failed: $wingetResult"
            }
        } catch {
            Write-Output "Winget method failed: $_"
        }
    }
    
    # Step 4: Try using wsl.exe from System32 (it might exist but not be in PATH)
    Write-Output "Checking for WSL in System32..."
    $wslSystem32 = "$env:SystemRoot\System32\wsl.exe"
    
    if (Test-Path $wslSystem32) {
        Write-Output "Found WSL.exe in System32, attempting to use it..."
        
        try {
            # Try to run wsl --install to complete setup
            & $wslSystem32 --update 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Output "WSL setup completed"
                
                # Add to PATH if needed
                $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                if ($currentPath -notlike "*System32*") {
                    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$env:SystemRoot\System32", "Machine")
                }
                
                Write-Output "WSL_INSTALLED"
                exit 0
            }
        } catch {
            Write-Output "WSL setup failed: $_"
        }
    }
    
    # Step 5: Last resort - use DISM to ensure WSL is properly installed
    Write-Output "Attempting DISM installation..."
    try {
        # Use DISM to enable WSL completely
        $dismResult = & dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1
        Write-Output "DISM WSL result: $dismResult"
        
        $dismResult2 = & dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1
        Write-Output "DISM VM result: $dismResult2"
        
        # This might require a reboot
        if ($dismResult -like "*restart*" -or $dismResult2 -like "*restart*") {
            Write-Output "REBOOT_REQUIRED_AFTER_DISM"
            exit 3010
        }
    } catch {
        Write-Output "DISM method failed: $_"
    }
    
    # If we get here, WSL installation is incomplete but features are enabled
    # The system likely needs a restart or manual Store installation
    Write-Output "WSL features enabled but WSL command not available. A system restart may be required."
    Write-Output "RESTART_SUGGESTED"
    exit 3010
    
} catch {
    Write-Output "ERROR: $_"
    exit 1
}