; Claude Code Installer
; Simple, robust installer using temporary PowerShell scripts

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

Name "Claude Code for Windows"
OutFile "output\ClaudeCodeInstaller.exe"
InstallDir "$LOCALAPPDATA\ClaudeCode"
RequestExecutionLevel admin

; Interface Settings
!define MUI_ABORTWARNING
!define MUI_ICON "assets\claude-icon.ico"
!define MUI_UNICON "assets\claude-icon.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "assets\banner.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\wizard.bmp"

; Variables
Var ProjectsFolder
Var WSLDistro
Var RebootRequired

; Pages
!insertmacro MUI_PAGE_WELCOME
Page custom CheckSystemPage
Page custom SelectProjectsFolderPage
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Language
!insertmacro MUI_LANGUAGE "English"

Section "Main"
    SetOutPath "$INSTDIR"
    
    ; Extract scripts and assets
    File "scripts\*.ps1"
    File "templates\CLAUDE.md"
    File "assets\claude-icon.ico"
    
    ; Fix PowerShell script encoding
    nsExec::ExecToLog 'powershell.exe -Command "Get-ChildItem \"$INSTDIR\*.ps1\" | ForEach-Object { $content = Get-Content $_ -Raw; $content = $content -replace [char]0xFEFF, \"\"; Set-Content $_ -Value $content -Encoding ASCII -NoNewline }"'
    
    ; Run installation steps
    Call CheckRequirements
    Call InstallWSL2
    Call SetupDebian
    Call InstallTools
    Call CreateProjectsFolder
    Call CreateShortcuts
    
    ; Cleanup
    Delete "$INSTDIR\*.ps1"
SectionEnd

Function CheckRequirements
    DetailPrint "Checking system requirements..."
    
    ; Run check script
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\check-requirements.ps1"'
    Pop $0 ; Exit code
    Pop $1 ; JSON output
    
    ; Parse results (simplified - you'd parse JSON properly)
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "System requirements not met:$\n$1"
        Abort
    ${EndIf}
FunctionEnd

Function InstallWSL2
    DetailPrint "Checking/Installing WSL2..."
    
    ; Before running the script, check if we're post-reboot
    ReadRegStr $0 HKCU "Software\ClaudeCode" "PostRebootStage"
    ${If} $0 == ""
        ; First run - no special handling needed
    ${EndIf}
    
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\install-wsl2.ps1"'
    Pop $0 ; Exit Code
    Pop $1 ; Output String
    
    ; First, check if it was already installed and we can just skip.
    StrCmp $1 "WSL_ALREADY_INSTALLED" 0 +3
        DetailPrint "WSL is already installed. Skipping."
        Return
    
    ; If not skipped, handle the result of the installation attempt.
    ${If} $0 == 3010
        ; Set flag for post-reboot
        WriteRegStr HKCU "Software\ClaudeCode" "PostRebootStage" "WSLFeaturesEnabled"
        
        StrCpy $RebootRequired "true"
        MessageBox MB_YESNO "WSL2 installation requires a reboot. Reboot now?" IDYES RebootNow
        Return
        
        RebootNow:
        ; Set run-once registry key to continue after reboot
        WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\RunOnce" \
                    "ClaudeCodeInstaller" "$EXEPATH"
        Reboot
    ${ElseIf} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "WSL2 installation failed: $1"
        Abort
    ${Else}
        DetailPrint "WSL has been successfully installed."
    ${EndIf}
FunctionEnd

Function SelectProjectsFolderPage
    nsDialogs::Create 1018
    Pop $0
    
    ${NSD_CreateLabel} 0 0 100% 20u "Select location for Claude Code Projects folder:"
    ${NSD_CreateDirRequest} 0 25u 80% 14u "$DOCUMENTS\Claude Code Projects"
    Pop $ProjectsFolder
    ${NSD_CreateBrowseButton} 82% 25u 18% 14u "Browse..."
    
    nsDialogs::Show
FunctionEnd

Function CheckSystemPage
    ; Placeholder for system check page
    nsDialogs::Create 1018
    Pop $0
    
    ${NSD_CreateLabel} 0 0 100% 20u "Checking system requirements..."
    
    nsDialogs::Show
FunctionEnd

Function SetupDebian
    DetailPrint "Checking/Setting up Debian Linux..."
    
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\setup-debian.ps1"'
    Pop $0
    Pop $1
    
    ; Check if Debian was already installed.
    StrCmp $1 "DEBIAN_EXISTS" 0 +3
        DetailPrint "Debian is already installed. Skipping."
        Return
        
    ; Handle the installation result.
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "Debian setup failed: $1"
        Abort
    ${Else}
        DetailPrint "Debian has been successfully installed."
    ${EndIf}
FunctionEnd

Function InstallTools
    DetailPrint "Checking/Installing Node.js and Claude Code..."
    
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\install-tools.ps1"'
    Pop $0
    Pop $1
    
    ; Check if tools were already installed.
    StrCmp $1 "TOOLS_ALREADY_INSTALLED" 0 +3
        DetailPrint "Claude Code tools are already installed. Skipping."
        Return
        
    ; Handle the installation result.
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "Tools installation failed: $1"
        Abort
    ${Else}
        DetailPrint "Claude Code tools have been successfully installed."
    ${EndIf}
FunctionEnd

Function CreateProjectsFolder
    DetailPrint "Creating projects folder..."
    
    ; Create the projects folder
    CreateDirectory "$ProjectsFolder"
    
    ; Copy CLAUDE.md template
    CopyFiles "$INSTDIR\CLAUDE.md" "$ProjectsFolder\CLAUDE.md"
FunctionEnd

Function CreateShortcuts
    DetailPrint "Creating shortcuts..."
    
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\create-shortcuts.ps1" -ProjectsFolder "$ProjectsFolder"'
    Pop $0
    Pop $1
    
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "Shortcut creation failed: $1"
        Abort
    ${EndIf}
FunctionEnd

Function .onInit
    ; Check if we're continuing after reboot
    ReadRegStr $0 HKCU "Software\ClaudeCode" "PostRebootStage"
    ${If} $0 == "WSLFeaturesEnabled"
        ; Jump to WSL kernel installation - clear the flag
        StrCpy $0 ""
        WriteRegStr HKCU "Software\ClaudeCode" "PostRebootStage" ""
        ; The installer will naturally continue from CheckRequirements
    ${EndIf}
FunctionEnd

Function UpdateProgress
    ; Simple progress updates
    DetailPrint "Installing component..."
    Sleep 100 ; Give user time to see progress
FunctionEnd

Function HandleError
    Pop $0 ; Error message
    
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
        "Installation error: $0$\n$\nWould you like to retry?" \
        IDRETRY Retry IDCANCEL Cancel
        
    Retry:
        Return
    Cancel:
        Abort
FunctionEnd