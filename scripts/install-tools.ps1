# Install Node.js and Claude Code in Alpine
param()

$commands = @'
#!/bin/sh
# Update packages
apk update
apk add nodejs npm curl git

# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
'@

try {
    # Save script to temp file
    $tempScript = "$env:TEMP\alpine-setup.sh"
    $commands | Out-File -FilePath $tempScript -Encoding ASCII -NoNewline
    
    # Execute in Alpine
    & wsl -d Alpine --exec sh < $tempScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output "TOOLS_INSTALLED"
        exit 0
    } else {
        Write-Output "TOOLS_INSTALL_FAILED"
        exit 1
    }
} catch {
    Write-Output "ERROR: $_"
    exit 1
} finally {
    Remove-Item $tempScript -ErrorAction SilentlyContinue
}