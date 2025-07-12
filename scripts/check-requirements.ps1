# Native Windows requirements check - returns JSON for NSIS to parse
param()

$result = @{
    Success = $true
    WindowsValid = $false
    IsAdmin = $false
    WingetAvailable = $false
    Messages = @()
}

# Check Windows version (1809 / build 17763 or later for native claude-code)
$build = [System.Environment]::OSVersion.Version.Build
if ($build -ge 17763) {
    $result.WindowsValid = $true
} else {
    $result.Success = $false
    $result.Messages += "Windows 10 version 1809 (build 17763) or later required"
}

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$result.IsAdmin = $isAdmin
if (-not $isAdmin) {
    $result.Success = $false
    $result.Messages += "Administrator rights required"
}

# Check winget availability - critical for native Windows installation
try {
    # Try to find winget in common locations
    $wingetPaths = @(
        "$env:LocalAppData\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe",
        "winget.exe"  # In PATH
    )
    
    $wingetFound = $false
    $wingetPath = $null
    
    foreach ($path in $wingetPaths) {
        if ($path -like "*WindowsApps*") {
            # Handle wildcard path for DesktopAppInstaller
            $resolvedPaths = Get-ChildItem -Path ($path -replace "\*", "*") -ErrorAction SilentlyContinue
            if ($resolvedPaths) {
                $wingetPath = $resolvedPaths[0].FullName
                $wingetFound = $true
                break
            }
        } elseif (Get-Command $path -ErrorAction SilentlyContinue) {
            $wingetPath = $path
            $wingetFound = $true
            break
        }
    }
    
    # Test if winget actually works
    if ($wingetFound) {
        try {
            $null = & $wingetPath --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $result.WingetAvailable = $true
            }
        } catch {}
    }
    
    if (-not $result.WingetAvailable) {
        $result.Success = $false
        $result.Messages += "Windows Package Manager (winget) is required but not available. Please install from Microsoft Store or update Windows."
    }
} catch {
    $result.Success = $false
    $result.Messages += "Failed to check winget availability: $($_.Exception.Message)"
}

# Output JSON
$result | ConvertTo-Json -Compress