# Simple requirements check - returns JSON for NSIS to parse
param()

$result = @{
    Success = $true
    WindowsValid = $false
    IsAdmin = $false
    WSLInstalled = $false
    Messages = @()
}

# Check Windows version
$build = [System.Environment]::OSVersion.Version.Build
if ($build -ge 19041) {
    $result.WindowsValid = $true
} else {
    $result.Success = $false
    $result.Messages += "Windows 10 version 2004 or later required"
}

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$result.IsAdmin = $isAdmin
if (-not $isAdmin) {
    $result.Success = $false
    $result.Messages += "Administrator rights required"
}

# Check WSL - check both features and command availability
try {
    # Check if WSL features are enabled
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    
    # Check if wsl command works
    $wslWorks = $false
    try {
        $null = & wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            $wslWorks = $true
        }
    } catch {}
    
    # WSL is considered installed if features are enabled AND command works
    if ($wslFeature.State -eq "Enabled" -and $vmFeature.State -eq "Enabled" -and $wslWorks) {
        $result.WSLInstalled = $true
    }
} catch {}

# Output JSON
$result | ConvertTo-Json -Compress