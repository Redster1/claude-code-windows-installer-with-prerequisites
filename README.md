# Claude Code Native Windows Installer

A simple, robust installer that sets up Claude Code CLI to run natively on Windows PowerShell without requiring WSL or Linux.

## What This Installer Does

- ✅ **Native Windows Installation** - No WSL or Linux required
- ✅ **Automatic Prerequisites** - Installs Node.js and Git via winget if needed
- ✅ **Smart Detection** - Tests functionality, not just presence
- ✅ **Zero Manual Steps** - Automatic PATH configuration
- ✅ **Non-Technical Friendly** - Designed for lawyers and other professionals
- ✅ **PowerShell Integration** - Creates desktop shortcuts that open in your projects folder

## Requirements

- Windows 10 version 1809 (build 17763) or later
- Administrator privileges
- Windows Package Manager (winget) - usually pre-installed on modern Windows

## Installation

1. Download `ClaudeCodeInstaller.exe` from the [latest release](https://github.com/Redster1/claude-code-windows-installer-with-prerequisites/releases)
2. Right-click and "Run as administrator"
3. Follow the simple installation wizard
4. Use the "Claude Code" desktop shortcut when installation completes

## What Gets Installed

The installer will check and install as needed:

- **Node.js LTS** (via winget) - JavaScript runtime for Claude Code
- **Git** (via winget) - Version control system  
- **Claude Code CLI** (via npm) - The main Claude Code command-line interface

After installation, the `claude` command will work system-wide in PowerShell.

## Installation Flow

1. **System Check** - Validates Windows version, admin rights, and winget availability
2. **Status Check** - Tests existing tools for functionality (not just presence)
3. **Smart Installation** - Only installs what's actually needed
4. **Tool Setup** - Installs missing components via winget and npm
5. **Shortcut Creation** - Creates PowerShell shortcuts on desktop and Start Menu
6. **Verification** - Ensures everything works before completion

## For Developers

### Building the Installer

```bash
# Enter development environment
nix-shell

# Build the installer
make build

# Test the build environment
make test
```

### Development Environment

This project uses Nix for reproducible builds:

- **NSIS 3.11** - Windows installer compiler
- **PowerShell 7+** - Script validation
- **Make** - Build automation

### Project Structure

```
├── build.nsi                 # NSIS installer script
├── scripts/
│   ├── check-requirements.ps1    # Windows/winget validation
│   ├── check-full-status.ps1     # Tool functionality testing  
│   ├── install-tools.ps1         # Native Windows installation
│   └── create-shortcuts.ps1      # PowerShell shortcut creation
├── templates/
│   └── CLAUDE.md             # Default project configuration
├── assets/                   # Icons and graphics
├── shell.nix                 # Nix development environment
└── Makefile                  # Build automation
```

## Key Features

### Smart Installation Logic

- **Functionality Testing** - Uses timeouts and actual command execution
- **Skip Working Tools** - Won't reinstall what already works
- **Graceful Failures** - Clear error messages for users
- **PATH Management** - Automatic environment variable handling

### Native Windows Integration

- **PowerShell Shortcuts** - Opens directly in projects folder
- **winget Integration** - Uses Windows Package Manager
- **No WSL Required** - Runs entirely on Windows
- **Start Menu Support** - Shortcuts in both desktop and Start Menu

### Non-Technical User Focus

- **Zero Configuration** - Everything works after installation
- **Clear Messages** - Helpful error messages and status updates  
- **Administrator Handling** - Proper elevation and permissions
- **Foolproof Process** - Designed for users who aren't developers

## Troubleshooting

### "winget not found"
- Update Windows to the latest version
- Install "App Installer" from Microsoft Store

### "Administrator rights required"  
- Right-click the installer and select "Run as administrator"

### "Windows version not supported"
- Upgrade to Windows 10 1809 or later
- Windows 11 is fully supported

### Tools not working after installation
- Restart PowerShell/Command Prompt
- Log out and back in to refresh PATH
- Some installations may require a system restart

## License

This installer is provided as-is for setting up Claude Code on Windows systems.

## Support

For issues with:
- **This installer**: Create an issue in this repository
- **Claude Code itself**: See [Anthropic's documentation](https://docs.anthropic.com/en/docs/claude-code)