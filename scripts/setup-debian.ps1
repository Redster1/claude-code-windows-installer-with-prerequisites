# Setup Debian Linux - Fixed version with automated user setup
param(
    [string]$Username = "user"
)

try {
    Write-Output "Starting Debian setup..."
    
    # Simple WSL check
    $wslStatus = & wsl.exe --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Output "ERROR: WSL not functional"
        exit 1
    }
    
    # Check existing distros and verify functionality
    Write-Output "Checking for existing Debian installation..."
    
    $distros = & wsl.exe --list --quiet 2>&1
    if ($distros -match "Debian") {
        Write-Output "Debian found in WSL list, testing functionality..."
        
        # Test if Debian is actually functional (with timeout)
        $job = Start-Job -ScriptBlock {
            try {
                # Try to execute a basic command in Debian
                $result = & wsl.exe -d Debian --exec whoami 2>&1
                if ($LASTEXITCODE -eq 0 -and $result -ne "") {
                    return "DEBIAN_FUNCTIONAL:$result"
                } else {
                    return "DEBIAN_NOT_FUNCTIONAL:$result"
                }
            } catch {
                return "DEBIAN_ERROR"
            }
        }
        
        $result = Wait-Job -Job $job -Timeout 10
        if ($result) {
            $output = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            if ($output -match "DEBIAN_FUNCTIONAL") {
                Write-Output "Debian is functional with user: $($output -replace 'DEBIAN_FUNCTIONAL:', '')"
                Write-Output "DEBIAN_EXISTS"
                exit 0
            } else {
                Write-Output "Debian exists but is not functional: $output"
                Write-Output "Will reinstall Debian to fix issues"
            }
        } else {
            Remove-Job -Job $job -Force
            Write-Output "Debian test timed out (probably broken), will reinstall"
        }
    } else {
        Write-Output "Debian not found in WSL distributions"
    }
    
    # Install Debian using --no-launch to prevent interactive setup
    Write-Output "Installing Debian..."
    & wsl.exe --install -d Debian --no-launch
    
    if ($LASTEXITCODE -eq 0) {
        # Wait for installation to complete with dynamic polling
        Write-Output "Waiting for Debian installation to complete..."
        $maxWaitTime = 120  # Maximum wait time in seconds
        $waitTime = 0
        $debianInstalled = $false
        
        while ($waitTime -lt $maxWaitTime -and -not $debianInstalled) {
            Start-Sleep -Seconds 5
            $waitTime += 5
            
            $distros = & wsl.exe --list --quiet 2>&1
            if ($distros -match "Debian") {
                $debianInstalled = $true
                Write-Output "Debian installation detected after $waitTime seconds"
                break
            }
            
            Write-Output "Still waiting for Debian installation... ($waitTime/$maxWaitTime seconds)"
        }
        
        if ($debianInstalled) {
            # Set as default
            & wsl.exe --set-default Debian
            
            # Now set up the user account automatically
            Write-Output "Setting up user account: $Username"
            SetupDebianUser
            
            if ($LASTEXITCODE -eq 0) {
                Write-Output "DEBIAN_INSTALLED"
                exit 0
            } else {
                Write-Output "ERROR: User setup failed"
                exit 1
            }
        } else {
            Write-Output "ERROR: Debian installation timeout after $maxWaitTime seconds"
            exit 1
        }
    }
    
    Write-Output "ERROR: Debian installation failed"
    exit 1
    
} catch {
    Write-Output "ERROR: $_"
    exit 1
}

function SetupDebianUser {
    try {
        # Generate a secure random password
        $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})
        
        # Create the user account
        Write-Output "Creating user account..."
        & wsl.exe -d Debian --user root --exec useradd -m -s /bin/bash $Username
        
        if ($LASTEXITCODE -ne 0) {
            Write-Output "ERROR: Failed to create user account"
            return 1
        }
        
        # Set the password securely using stdin
        Write-Output "Setting user password..."
        $passwordInput = "$Username:$password"
        $passwordInput | & wsl.exe -d Debian --user root --exec chpasswd
        
        if ($LASTEXITCODE -ne 0) {
            Write-Output "ERROR: Failed to set user password"
            return 1
        }
        
        # Add user to sudo group
        Write-Output "Adding user to sudo group..."
        & wsl.exe -d Debian --user root --exec usermod -aG sudo $Username
        
        if ($LASTEXITCODE -ne 0) {
            Write-Output "ERROR: Failed to add user to sudo group"
            return 1
        }
        
        # Configure WSL to use this user as default (run as root to avoid sudo prompts)
        Write-Output "Configuring default user..."
        $wslConfig = "[user]`ndefault=$Username"
        & wsl.exe -d Debian --user root --exec bash -c "echo '$wslConfig' | tee /etc/wsl.conf > /dev/null"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Output "ERROR: Failed to configure default user"
            return 1
        }
        
        # Verify user was created successfully
        Write-Output "Verifying user account..."
        $userCheck = & wsl.exe -d Debian --exec id $Username 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output "User account created successfully: $userCheck"
            
            # Test user authentication
            $authTest = & wsl.exe -d Debian --exec su -c "whoami" $Username 2>$null
            
            if ($authTest -eq $Username) {
                Write-Output "User authentication verified"
                return 0
            } else {
                Write-Output "ERROR: User authentication failed"
                return 1
            }
        } else {
            Write-Output "ERROR: User verification failed"
            return 1
        }
        
    } catch {
        Write-Output "ERROR in SetupDebianUser: $_"
        return 1
    }
}