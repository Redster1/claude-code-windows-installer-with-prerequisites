# Native Windows installation of Node.js, Git, and Claude Code
param()

function Test-CommandFunctionality {
    param(
        [string]$Command,
        [string]$TestArgument = "--version",
        [string]$ExpectedPattern = "\d+\.\d+",
        [int]$TimeoutSeconds = 15
    )
    
    try {
        $job = Start-Job -ScriptBlock {
            param($cmd, $arg)
            try {
                $output = & $cmd $arg 2>&1
                return @{ Success = ($LASTEXITCODE -eq 0); Output = $output; ExitCode = $LASTEXITCODE }
            } catch {
                return @{ Success = $false; Output = $_.Exception.Message; ExitCode = -1 }
            }
        } -ArgumentList $Command, $TestArgument
        
        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if ($result) {
            $output = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            if ($output.Success -and $output.Output -match $ExpectedPattern) {
                return @{ Functional = $true; Version = $output.Output; Error = $null }
            } else {
                return @{ Functional = $false; Version = $null; Error = "Command failed or unexpected output: $($output.Output)" }
            }
        } else {
            Remove-Job -Job $job -Force
            return @{ Functional = $false; Version = $null; Error = "Command timed out after $TimeoutSeconds seconds" }
        }
    } catch {
        return @{ Functional = $false; Version = $null; Error = $_.Exception.Message }
    }
}

function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$FriendlyName
    )
    
    Write-Output "Installing $FriendlyName via winget..."
    
    try {
        # Use winget install with accept agreements and silent mode
        $result = & winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output "$FriendlyName installed successfully"
            return $true
        } else {
            Write-Output "WARNING: winget install returned exit code $LASTEXITCODE for $FriendlyName"
            Write-Output "Output: $result"
            # Don't fail immediately - tool might already be installed
            return $false
        }
    } catch {
        Write-Output "ERROR installing $FriendlyName`: $($_.Exception.Message)"
        return $false
    }
}

try {
    Write-Output "Starting native Windows installation check..."
    
    # Test current functionality of required tools
    Write-Output "Testing Node.js functionality..."
    $nodeTest = Test-CommandFunctionality -Command "node" -TestArgument "--version" -ExpectedPattern "v\d+\.\d+"
    
    Write-Output "Testing npm functionality..."
    $npmTest = Test-CommandFunctionality -Command "npm" -TestArgument "--version" -ExpectedPattern "\d+\.\d+"
    
    Write-Output "Testing Git functionality..."
    $gitTest = Test-CommandFunctionality -Command "git" -TestArgument "--version" -ExpectedPattern "git version \d+"
    
    Write-Output "Testing Claude Code functionality..."
    $claudeTest = Test-CommandFunctionality -Command "claude" -TestArgument "--version" -ExpectedPattern "claude|@anthropic-ai" -TimeoutSeconds 20
    
    # Report current status
    Write-Output ""
    Write-Output "=== CURRENT TOOL STATUS ==="
    Write-Output "Node.js: $(if ($nodeTest.Functional) { "FUNCTIONAL - $($nodeTest.Version)" } else { "NOT_FUNCTIONAL - $($nodeTest.Error)" })"
    Write-Output "npm: $(if ($npmTest.Functional) { "FUNCTIONAL - $($npmTest.Version)" } else { "NOT_FUNCTIONAL - $($npmTest.Error)" })"
    Write-Output "Git: $(if ($gitTest.Functional) { "FUNCTIONAL - $($gitTest.Version)" } else { "NOT_FUNCTIONAL - $($gitTest.Error)" })"
    Write-Output "Claude Code: $(if ($claudeTest.Functional) { "FUNCTIONAL - $($claudeTest.Version)" } else { "NOT_FUNCTIONAL - $($claudeTest.Error)" })"
    Write-Output ""
    
    # Check if everything is already working
    if ($nodeTest.Functional -and $npmTest.Functional -and $gitTest.Functional -and $claudeTest.Functional) {
        Write-Output "All tools are already functional! Skipping installation."
        Write-Output "TOOLS_ALREADY_INSTALLED"
        exit 0
    }
    
    # Refresh environment variables to pick up any recently installed tools
    Write-Output "Refreshing environment variables..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Install missing tools
    $needsReboot = $false
    $installationOccurred = $false
    
    # Install Node.js if needed (includes npm)
    if (-not $nodeTest.Functional -or -not $npmTest.Functional) {
        Write-Output "Node.js or npm not functional, installing Node.js LTS..."
        $nodeInstalled = Install-WithWinget -PackageId "OpenJS.NodeJS.LTS" -FriendlyName "Node.js LTS"
        if ($nodeInstalled) {
            $installationOccurred = $true
        }
    } else {
        Write-Output "Node.js and npm are functional, skipping installation"
    }
    
    # Install Git if needed
    if (-not $gitTest.Functional) {
        Write-Output "Git not functional, installing Git..."
        $gitInstalled = Install-WithWinget -PackageId "Git.Git" -FriendlyName "Git"
        if ($gitInstalled) {
            $installationOccurred = $true
        }
    } else {
        Write-Output "Git is functional, skipping installation"
    }
    
    # Refresh PATH again after installations
    if ($installationOccurred) {
        Write-Output "Refreshing PATH after installations..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Give Windows time to update PATH
        Start-Sleep -Seconds 3
        
        # Re-test Node.js and npm after installation
        Write-Output "Re-testing Node.js and npm after installation..."
        $nodeTest = Test-CommandFunctionality -Command "node" -TestArgument "--version" -ExpectedPattern "v\d+\.\d+"
        $npmTest = Test-CommandFunctionality -Command "npm" -TestArgument "--version" -ExpectedPattern "\d+\.\d+"
        
        if (-not $nodeTest.Functional) {
            Write-Output "ERROR: Node.js still not functional after installation. Manual intervention may be required."
            Write-Output "Error: $($nodeTest.Error)"
            exit 1
        }
        
        if (-not $npmTest.Functional) {
            Write-Output "ERROR: npm still not functional after Node.js installation. Manual intervention may be required."
            Write-Output "Error: $($npmTest.Error)"
            exit 1
        }
        
        Write-Output "Node.js and npm are now functional after installation"
    }
    
    # Install Claude Code if needed
    if (-not $claudeTest.Functional) {
        Write-Output "Claude Code not functional, installing via npm..."
        
        try {
            Write-Output "Running: npm install -g @anthropic-ai/claude-code"
            $npmOutput = & npm install -g @anthropic-ai/claude-code 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Output "Claude Code installed successfully via npm"
                
                # Refresh PATH once more
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                
                # Test Claude Code after installation
                Start-Sleep -Seconds 2
                $claudeTest = Test-CommandFunctionality -Command "claude" -TestArgument "--version" -ExpectedPattern "claude|@anthropic-ai" -TimeoutSeconds 20
                
                if ($claudeTest.Functional) {
                    Write-Output "Claude Code verified functional: $($claudeTest.Version)"
                } else {
                    Write-Output "WARNING: Claude Code installed but verification failed: $($claudeTest.Error)"
                    Write-Output "This may be normal - PATH might need a restart to take effect"
                }
            } else {
                Write-Output "ERROR: npm install failed with exit code $LASTEXITCODE"
                Write-Output "Output: $npmOutput"
                exit 1
            }
        } catch {
            Write-Output "ERROR installing Claude Code via npm: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Output "Claude Code is already functional, skipping installation"
    }
    
    # Final verification
    Write-Output ""
    Write-Output "=== FINAL VERIFICATION ==="
    $finalNodeTest = Test-CommandFunctionality -Command "node" -TestArgument "--version" -ExpectedPattern "v\d+\.\d+"
    $finalNpmTest = Test-CommandFunctionality -Command "npm" -TestArgument "--version" -ExpectedPattern "\d+\.\d+"
    $finalGitTest = Test-CommandFunctionality -Command "git" -TestArgument "--version" -ExpectedPattern "git version \d+"
    $finalClaudeTest = Test-CommandFunctionality -Command "claude" -TestArgument "--version" -ExpectedPattern "claude|@anthropic-ai" -TimeoutSeconds 20
    
    Write-Output "Node.js: $(if ($finalNodeTest.Functional) { "✓ FUNCTIONAL" } else { "✗ NOT_FUNCTIONAL" })"
    Write-Output "npm: $(if ($finalNpmTest.Functional) { "✓ FUNCTIONAL" } else { "✗ NOT_FUNCTIONAL" })"
    Write-Output "Git: $(if ($finalGitTest.Functional) { "✓ FUNCTIONAL" } else { "✗ NOT_FUNCTIONAL" })"
    Write-Output "Claude Code: $(if ($finalClaudeTest.Functional) { "✓ FUNCTIONAL" } else { "✗ NOT_FUNCTIONAL" })"
    
    if ($finalNodeTest.Functional -and $finalNpmTest.Functional -and $finalGitTest.Functional -and $finalClaudeTest.Functional) {
        Write-Output ""
        Write-Output "All tools are now functional! Installation completed successfully."
        Write-Output "TOOLS_INSTALLED"
        exit 0
    } else {
        Write-Output ""
        Write-Output "Some tools are still not functional. Installation may require a system restart."
        Write-Output "TOOLS_INSTALLED_RESTART_REQUIRED"
        exit 0
    }
    
} catch {
    Write-Output "ERROR during installation: $_"
    Write-Output "TOOLS_INSTALL_FAILED"
    exit 1
}