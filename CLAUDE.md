# Claude Development Session Memory

This file contains important context and lessons learned for future Claude sessions.

## Project Context
- Claude Code Windows Installer for non-technical users (lawyers)
- Uses NSIS for Windows installer, PowerShell for Windows automation, Bash for Alpine setup
- Cross-platform development on NixOS targeting Windows
- Architecture: NSIS + PowerShell + WSL2 + Alpine Linux + Node.js + Claude Code CLI

## Note
- You are developing on NixOS, so you'll want to create a shell.nix file and update this document/that shell.nix as necessary to run what you need to build this. 

## Development Environment Rules
- **ALL build commands must run inside**: `nix-shell --run "command"`
- NSIS v3.11, PowerShell 7.5.1, Node.js v22.14.0 available in shell
- Asset files need proper path resolution

## Important Commands
- `nix-shell --run "make build"` - Build installer in Nix environment

