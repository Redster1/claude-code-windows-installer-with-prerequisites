# Comprehensive System Status Check - Fast functional validation
# Tests actual functionality with timeouts to avoid hanging on broken components

param()

function Test-WithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 10,
        [string]$Description = "Test"
    )
    
    try {
        $job = Start-Job -ScriptBlock $ScriptBlock
        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if ($result) {
            $output = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            return @{ Success = $true; Output = $output; Error = $null }
        } else {
            Remove-Job -Job $job -Force
            return @{ Success = $false; Output = $null; Error = "Timeout after $TimeoutSeconds seconds" }
        }
    } catch {
        return @{ Success = $false; Output = $null; Error = $_.Exception.Message }
    }
}

function Test-WSL {
    Write-Output "Testing WSL functionality..."
    
    # Test 1: WSL command exists and responds
    $result = Test-WithTimeout -TimeoutSeconds 5 -ScriptBlock {
        try {
            $output = & wsl.exe --status 2>&1
            if ($LASTEXITCODE -eq 0) {
                return "WSL_RESPONDS"
            } else {
                return "WSL_ERROR: $output"
            }
        } catch {
            return "WSL_MISSING"
        }
    }
    
    if (-not $result.Success) {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "WSL command timeout or missing" }
    }
    
    if ($result.Output -match "WSL_MISSING") {
        return @{ Status = "NOT_INSTALLED"; Reason = "WSL command not found" }
    }
    
    # Test 2: Can execute basic command in WSL
    $result = Test-WithTimeout -TimeoutSeconds 8 -ScriptBlock {
        try {
            $output = & wsl.exe --exec echo "functional_test" 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "functional_test") {
                return "WSL_FUNCTIONAL"
            } else {
                return "WSL_NOT_FUNCTIONAL: $output"
            }
        } catch {
            return "WSL_EXEC_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -notmatch "WSL_FUNCTIONAL") {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "WSL cannot execute commands" }
    }
    
    return @{ Status = "FUNCTIONAL"; Reason = "WSL is working correctly" }
}

function Test-Debian {
    Write-Output "Testing Debian functionality..."
    
    # Test 1: Debian appears in distro list
    $result = Test-WithTimeout -TimeoutSeconds 5 -ScriptBlock {
        try {
            $output = & wsl.exe --list --quiet 2>&1
            if ($output -match "Debian") {
                return "DEBIAN_LISTED"
            } else {
                return "DEBIAN_NOT_LISTED"
            }
        } catch {
            return "LIST_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -notmatch "DEBIAN_LISTED") {
        return @{ Status = "NOT_INSTALLED"; Reason = "Debian not found in WSL distributions" }
    }
    
    # Test 2: Can execute commands in Debian
    $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
        try {
            $output = & wsl.exe -d Debian --exec whoami 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -ne "") {
                return "DEBIAN_USER:$output"
            } else {
                return "DEBIAN_NO_USER: $output"
            }
        } catch {
            return "DEBIAN_EXEC_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -match "DEBIAN_NO_USER|DEBIAN_EXEC_FAILED") {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "Debian cannot execute commands or no user configured" }
    }
    
    # Test 3: User has basic system tools
    $result = Test-WithTimeout -TimeoutSeconds 8 -ScriptBlock {
        try {
            $output = & wsl.exe -d Debian --exec bash -c "which apt && which bash" 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "/usr/bin/apt" -and $output -match "/bin/bash") {
                return "DEBIAN_TOOLS_OK"
            } else {
                return "DEBIAN_TOOLS_MISSING: $output"
            }
        } catch {
            return "DEBIAN_TOOLS_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -notmatch "DEBIAN_TOOLS_OK") {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "Debian missing essential tools" }
    }
    
    return @{ Status = "FUNCTIONAL"; Reason = "Debian is working correctly" }
}

function Test-Tools {
    Write-Output "Testing Node.js and Claude Code functionality..."
    
    # Test 1: Node.js available and working
    $result = Test-WithTimeout -TimeoutSeconds 8 -ScriptBlock {
        try {
            $output = & wsl.exe -d Debian --exec node --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "v\d+\.\d+\.\d+") {
                return "NODE_FUNCTIONAL:$output"
            } else {
                return "NODE_NOT_FUNCTIONAL: $output"
            }
        } catch {
            return "NODE_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -notmatch "NODE_FUNCTIONAL") {
        return @{ Status = "NOT_INSTALLED"; Reason = "Node.js not available or not working" }
    }
    
    # Test 2: npm available and working
    $result = Test-WithTimeout -TimeoutSeconds 8 -ScriptBlock {
        try {
            $output = & wsl.exe -d Debian --exec npm --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "\d+\.\d+\.\d+") {
                return "NPM_FUNCTIONAL:$output"
            } else {
                return "NPM_NOT_FUNCTIONAL: $output"
            }
        } catch {
            return "NPM_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -notmatch "NPM_FUNCTIONAL") {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "npm not available or not working" }
    }
    
    # Test 3: Claude Code available and working
    $result = Test-WithTimeout -TimeoutSeconds 12 -ScriptBlock {
        try {
            $output = & wsl.exe -d Debian --exec claude --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "claude|Claude") {
                return "CLAUDE_FUNCTIONAL:$output"
            } else {
                return "CLAUDE_NOT_FUNCTIONAL: $output"
            }
        } catch {
            return "CLAUDE_FAILED"
        }
    }
    
    if (-not $result.Success -or $result.Output -notmatch "CLAUDE_FUNCTIONAL") {
        return @{ Status = "NOT_INSTALLED"; Reason = "Claude Code not available or not working" }
    }
    
    return @{ Status = "FUNCTIONAL"; Reason = "All tools are working correctly" }
}

try {
    Write-Output "Starting comprehensive system status check..."
    Write-Output "This will test actual functionality with timeouts to avoid hanging."
    Write-Output ""
    
    # Run all checks
    $wslStatus = Test-WSL
    $debianStatus = Test-Debian
    $toolsStatus = Test-Tools
    
    # Create status summary
    $statusSummary = @{
        WSL = $wslStatus
        Debian = $debianStatus
        Tools = $toolsStatus
    }
    
    Write-Output ""
    Write-Output "=== SYSTEM STATUS SUMMARY ==="
    Write-Output "WSL: $($wslStatus.Status) - $($wslStatus.Reason)"
    Write-Output "Debian: $($debianStatus.Status) - $($debianStatus.Reason)"
    Write-Output "Tools: $($toolsStatus.Status) - $($toolsStatus.Reason)"
    Write-Output ""
    
    # Determine overall status
    if ($wslStatus.Status -eq "FUNCTIONAL" -and $debianStatus.Status -eq "FUNCTIONAL" -and $toolsStatus.Status -eq "FUNCTIONAL") {
        Write-Output "OVERALL_STATUS:FULLY_FUNCTIONAL"
        exit 0
    } elseif ($wslStatus.Status -eq "NOT_INSTALLED" -or $debianStatus.Status -eq "NOT_INSTALLED" -or $toolsStatus.Status -eq "NOT_INSTALLED") {
        Write-Output "OVERALL_STATUS:PARTIAL_INSTALLATION_NEEDED"
        exit 1
    } else {
        Write-Output "OVERALL_STATUS:REPAIR_NEEDED"
        exit 2
    }
    
} catch {
    Write-Output "ERROR: Status check failed: $_"
    Write-Output "OVERALL_STATUS:CHECK_FAILED"
    exit 3
}