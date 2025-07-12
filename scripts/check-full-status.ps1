# Native Windows System Status Check - Fast functional validation
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

function Test-NodeJS {
    Write-Output "Testing Node.js functionality..."
    
    # Test 1: Node.js command exists and responds
    $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
        try {
            $output = & node --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "v\d+\.\d+\.\d+") {
                return "NODE_FUNCTIONAL:$output"
            } else {
                return "NODE_ERROR: $output"
            }
        } catch {
            return "NODE_MISSING"
        }
    }
    
    if (-not $result.Success) {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "Node.js command timeout"; Version = $null }
    }
    
    if ($result.Output -match "NODE_MISSING") {
        return @{ Status = "NOT_INSTALLED"; Reason = "Node.js command not found"; Version = $null }
    }
    
    if ($result.Output -match "NODE_FUNCTIONAL:(.+)") {
        $version = $matches[1].Trim()
        return @{ Status = "FUNCTIONAL"; Reason = "Node.js is working correctly"; Version = $version }
    }
    
    return @{ Status = "NOT_FUNCTIONAL"; Reason = "Node.js returned unexpected output"; Version = $null }
}

function Test-NPM {
    Write-Output "Testing npm functionality..."
    
    # Test 1: npm command exists and responds
    $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
        try {
            $output = & npm --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "\d+\.\d+\.\d+") {
                return "NPM_FUNCTIONAL:$output"
            } else {
                return "NPM_ERROR: $output"
            }
        } catch {
            return "NPM_MISSING"
        }
    }
    
    if (-not $result.Success) {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "npm command timeout"; Version = $null }
    }
    
    if ($result.Output -match "NPM_MISSING") {
        return @{ Status = "NOT_INSTALLED"; Reason = "npm command not found"; Version = $null }
    }
    
    if ($result.Output -match "NPM_FUNCTIONAL:(.+)") {
        $version = $matches[1].Trim()
        return @{ Status = "FUNCTIONAL"; Reason = "npm is working correctly"; Version = $version }
    }
    
    return @{ Status = "NOT_FUNCTIONAL"; Reason = "npm returned unexpected output"; Version = $null }
}

function Test-Git {
    Write-Output "Testing Git functionality..."
    
    # Test 1: Git command exists and responds
    $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
        try {
            $output = & git --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "git version \d+") {
                return "GIT_FUNCTIONAL:$output"
            } else {
                return "GIT_ERROR: $output"
            }
        } catch {
            return "GIT_MISSING"
        }
    }
    
    if (-not $result.Success) {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "Git command timeout"; Version = $null }
    }
    
    if ($result.Output -match "GIT_MISSING") {
        return @{ Status = "NOT_INSTALLED"; Reason = "Git command not found"; Version = $null }
    }
    
    if ($result.Output -match "GIT_FUNCTIONAL:(.+)") {
        $version = $matches[1].Trim()
        return @{ Status = "FUNCTIONAL"; Reason = "Git is working correctly"; Version = $version }
    }
    
    return @{ Status = "NOT_FUNCTIONAL"; Reason = "Git returned unexpected output"; Version = $null }
}

function Test-ClaudeCode {
    Write-Output "Testing Claude Code functionality..."
    
    # Test 1: Claude command exists and responds
    $result = Test-WithTimeout -TimeoutSeconds 15 -ScriptBlock {
        try {
            $output = & claude --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match "claude|@anthropic-ai") {
                return "CLAUDE_FUNCTIONAL:$output"
            } else {
                return "CLAUDE_ERROR: $output"
            }
        } catch {
            return "CLAUDE_MISSING"
        }
    }
    
    if (-not $result.Success) {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "Claude Code command timeout"; Version = $null }
    }
    
    if ($result.Output -match "CLAUDE_MISSING") {
        return @{ Status = "NOT_INSTALLED"; Reason = "Claude Code command not found"; Version = $null }
    }
    
    if ($result.Output -match "CLAUDE_FUNCTIONAL:(.+)") {
        $version = $matches[1].Trim()
        return @{ Status = "FUNCTIONAL"; Reason = "Claude Code is working correctly"; Version = $version }
    }
    
    return @{ Status = "NOT_FUNCTIONAL"; Reason = "Claude Code returned unexpected output"; Version = $null }
}

function Test-Winget {
    Write-Output "Testing winget functionality..."
    
    # Test winget availability
    $result = Test-WithTimeout -TimeoutSeconds 8 -ScriptBlock {
        try {
            $output = & winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                return "WINGET_FUNCTIONAL:$output"
            } else {
                return "WINGET_ERROR: $output"
            }
        } catch {
            return "WINGET_MISSING"
        }
    }
    
    if (-not $result.Success) {
        return @{ Status = "NOT_FUNCTIONAL"; Reason = "winget command timeout"; Version = $null }
    }
    
    if ($result.Output -match "WINGET_MISSING") {
        return @{ Status = "NOT_INSTALLED"; Reason = "winget command not found"; Version = $null }
    }
    
    if ($result.Output -match "WINGET_FUNCTIONAL:(.+)") {
        $version = $matches[1].Trim()
        return @{ Status = "FUNCTIONAL"; Reason = "winget is working correctly"; Version = $version }
    }
    
    return @{ Status = "NOT_FUNCTIONAL"; Reason = "winget returned unexpected output"; Version = $null }
}

try {
    Write-Output "Starting native Windows system status check..."
    Write-Output "This will test actual functionality with timeouts to avoid hanging."
    Write-Output ""
    
    # Refresh PATH to pick up recently installed tools
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Run all checks
    $wingetStatus = Test-Winget
    $nodeStatus = Test-NodeJS
    $npmStatus = Test-NPM
    $gitStatus = Test-Git
    $claudeStatus = Test-ClaudeCode
    
    # Create status summary
    $statusSummary = @{
        Winget = $wingetStatus
        NodeJS = $nodeStatus
        NPM = $npmStatus
        Git = $gitStatus
        ClaudeCode = $claudeStatus
    }
    
    Write-Output ""
    Write-Output "=== NATIVE WINDOWS SYSTEM STATUS SUMMARY ==="
    Write-Output "winget: $($wingetStatus.Status) - $($wingetStatus.Reason)$(if ($wingetStatus.Version) { " ($($wingetStatus.Version))" })"
    Write-Output "Node.js: $($nodeStatus.Status) - $($nodeStatus.Reason)$(if ($nodeStatus.Version) { " ($($nodeStatus.Version))" })"
    Write-Output "npm: $($npmStatus.Status) - $($npmStatus.Reason)$(if ($npmStatus.Version) { " ($($npmStatus.Version))" })"
    Write-Output "Git: $($gitStatus.Status) - $($gitStatus.Reason)$(if ($gitStatus.Version) { " ($($gitStatus.Version))" })"
    Write-Output "Claude Code: $($claudeStatus.Status) - $($claudeStatus.Reason)$(if ($claudeStatus.Version) { " ($($claudeStatus.Version))" })"
    Write-Output ""
    
    # Determine overall status
    $allFunctional = ($nodeStatus.Status -eq "FUNCTIONAL" -and 
                     $npmStatus.Status -eq "FUNCTIONAL" -and 
                     $gitStatus.Status -eq "FUNCTIONAL" -and 
                     $claudeStatus.Status -eq "FUNCTIONAL")
    
    $hasNotInstalled = ($nodeStatus.Status -eq "NOT_INSTALLED" -or 
                       $npmStatus.Status -eq "NOT_INSTALLED" -or 
                       $gitStatus.Status -eq "NOT_INSTALLED" -or 
                       $claudeStatus.Status -eq "NOT_INSTALLED")
    
    $wingetNotFunctional = ($wingetStatus.Status -ne "FUNCTIONAL")
    
    if ($allFunctional) {
        Write-Output "OVERALL_STATUS:FULLY_FUNCTIONAL"
        exit 0
    } elseif ($wingetNotFunctional -and $hasNotInstalled) {
        Write-Output "OVERALL_STATUS:WINGET_REQUIRED"
        exit 3
    } elseif ($hasNotInstalled) {
        Write-Output "OVERALL_STATUS:PARTIAL_INSTALLATION_NEEDED"
        exit 1
    } else {
        Write-Output "OVERALL_STATUS:REPAIR_NEEDED"
        exit 2
    }
    
} catch {
    Write-Output "ERROR: Status check failed: $_"
    Write-Output "OVERALL_STATUS:CHECK_FAILED"
    exit 4
}