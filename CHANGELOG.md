# Changelog

All notable changes to the Claude Code Native Windows Installer will be documented in this file.

## [0.0.1] - 2025-01-12

### Added
- Native Windows installation support (no WSL required)
- Windows Package Manager (winget) integration for Node.js and Git
- Smart tool detection that tests functionality, not just presence
- Automatic PATH configuration
- PowerShell shortcuts with welcome messages
- Desktop and Start Menu shortcut creation
- Support for both PowerShell 7+ and Windows PowerShell
- Comprehensive error handling and user-friendly messages
- Skip logic for tools that already work
- Windows 10 1809+ compatibility (build 17763+)

### Removed  
- WSL2 dependency and installation
- Debian Linux setup and configuration
- Linux username requirements
- Complex reboot handling for WSL features

### Changed
- Minimum Windows version from 2004 to 1809
- Installation method from WSL-based to native Windows
- Tool installation from apt packages to winget + npm
- Shortcut target from WSL to native PowerShell
- System requirements checking logic

### Technical Details
- Rebuilt installer flow for native Windows operation
- Enhanced status checking with timeout protection
- Improved winget detection across multiple installation paths
- Added robust npm global installation handling
- Implemented PATH refresh logic for immediate tool availability

This represents a complete architectural shift from WSL-based to native Windows operation, making Claude Code accessible to users who cannot or prefer not to use WSL.