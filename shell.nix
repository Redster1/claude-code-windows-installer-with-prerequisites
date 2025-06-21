{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # NSIS compiler for creating Windows installers
    nsis
    
    # Wine for running Windows applications if needed
    wine
    
    # Basic build tools
    gnumake
    
    # PowerShell for testing scripts (if available)
    powershell
    
    # PowerShell linting and formatting tools
    nodePackages.prettier
    
    # Utilities
    file
    unzip
    wget
    curl
    jq
  ];

  shellHook = ''
    echo "Claude Code Windows Installer Development Environment"
    echo "Available tools:"
    echo "  - makensis (NSIS compiler)"
    echo "  - wine (Windows compatibility layer)"
    echo "  - make (build automation)"
    echo "  - powershell (PowerShell Core for script validation)"
    echo ""
    echo "To build the installer, run: make build"
    echo "To validate PowerShell syntax: pwsh -NoProfile -Command \"& './scripts/scriptname.ps1' -WhatIf\""
    echo ""
  '';
}