.PHONY: build clean test help

# Default target
all: build

# Build the installer
build:
	@echo "Building Claude Code Windows Installer..."
	@mkdir -p output
	@makensis build.nsi
	@echo "Build complete! Installer created at: output/ClaudeCodeInstaller.exe"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf output/*.exe
	@echo "Clean complete!"

# Test the build environment
test:
	@echo "Testing build environment..."
	@echo "Checking makensis..."
	@which makensis || (echo "ERROR: makensis not found!" && exit 1)
	@makensis /version || true
	@echo "Checking file structure..."
	@test -f build.nsi || (echo "ERROR: build.nsi not found!" && exit 1)
	@test -d scripts || (echo "ERROR: scripts directory not found!" && exit 1)
	@test -d templates || (echo "ERROR: templates directory not found!" && exit 1)
	@echo "Environment test passed!"

# Show help
help:
	@echo "Claude Code Windows Installer Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  build   - Build the Windows installer (default)"
	@echo "  clean   - Remove build artifacts"
	@echo "  test    - Test the build environment"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  nix-shell --run 'make build'"