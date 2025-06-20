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
    
    # Utilities
    file
    unzip
    wget
    curl
  ];

  shellHook = ''
    echo "Claude Code Windows Installer Development Environment"
    echo "Available tools:"
    echo "  - makensis (NSIS compiler)"
    echo "  - wine (Windows compatibility layer)"
    echo "  - make (build automation)"
    echo ""
    echo "To build the installer, run: make build"
    echo ""
  '';
}