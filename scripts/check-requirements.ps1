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

# Check WSL
try {
    $wslStatus = & wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        $result.WSLInstalled = $true
    }
} catch {}

# Output JSON
$result | ConvertTo-Json -Compress