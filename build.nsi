; Claude Code Native Windows Installer
; Simple, robust installer for native Windows PowerShell using winget and npm

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

Name "Claude Code Native Windows"
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

; Pages
!insertmacro MUI_PAGE_WELCOME
Page custom CheckSystemPage
Page custom SelectProjectsFolderPage SelectProjectsFolderPageLeave
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
    
    ; Run native Windows installation steps
    Call CheckRequirements
    Call CheckSystemStatus
    Call InstallTools
    Call CreateProjectsFolder
    Call CreateShortcuts
    
    ; Cleanup
    Delete "$INSTDIR\*.ps1"
SectionEnd

Function CheckRequirements
    DetailPrint "Checking native Windows requirements..."
    
    ; Run check script
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\check-requirements.ps1"'
    Pop $0 ; Exit code
    Pop $1 ; JSON output
    
    ; Parse results (simplified - you'd parse JSON properly)
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "System requirements not met:$\n$1$\n$\nRequirements: Windows 10 1809+, Administrator rights, and Windows Package Manager (winget)"
        Abort
    ${EndIf}
FunctionEnd

Function CheckSystemStatus
    DetailPrint "Checking native Windows system status with functional testing..."
    
    ; Run comprehensive status check
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\check-full-status.ps1"'
    Pop $0 ; Exit code
    Pop $1 ; Output
    
    ; Show user what we found
    DetailPrint "Native Windows System Status Check Results:"
    DetailPrint "$1"
    
    ; Parse the overall status
    ${If} $0 == 0
        DetailPrint "All native Windows components are functional - optimized installation will proceed"
    ${ElseIf} $0 == 1
        DetailPrint "Some components need installation - will install missing parts via winget/npm"
    ${ElseIf} $0 == 2
        DetailPrint "Some components need repair - will fix broken installations"
    ${ElseIf} $0 == 3
        DetailPrint "winget is required but not available - installation cannot proceed"
        MessageBox MB_OK|MB_ICONSTOP "Windows Package Manager (winget) is required but not available.$\n$\nPlease install from Microsoft Store or update Windows before continuing."
        Abort
    ${Else}
        DetailPrint "Status check had issues - will proceed with full installation"
    ${EndIf}
    
    ; Brief pause so user can see the status
    Sleep 2000
FunctionEnd


; Variables for dialog controls
Var ProjectsFolderControl
Var BrowseButton

Function SelectProjectsFolderPage
    nsDialogs::Create 1018
    Pop $0
    
    ${NSD_CreateLabel} 0 0 100% 20u "Select location for Claude Code Projects folder:"
    ${NSD_CreateDirRequest} 0 25u 80% 14u "$DOCUMENTS\Claude Code Projects"
    Pop $ProjectsFolderControl
    ${NSD_CreateBrowseButton} 82% 25u 18% 14u "Browse..."
    Pop $BrowseButton
    
    ; Set up browse button callback
    ${NSD_OnClick} $BrowseButton BrowseForFolder
    
    nsDialogs::Show
FunctionEnd

Function SelectProjectsFolderPageLeave
    ; Capture the user's selection
    ${NSD_GetText} $ProjectsFolderControl $ProjectsFolder
    
    ; Validate the selection
    ${If} $ProjectsFolder == ""
        MessageBox MB_OK|MB_ICONSTOP "Please select a valid folder location."
        Abort
    ${EndIf}
    
    ; Ensure the path ends properly
    ${GetParent} "$ProjectsFolder\." $0
    StrCpy $ProjectsFolder $0
FunctionEnd

Function BrowseForFolder
    nsDialogs::SelectFolderDialog "Select Projects Folder" $ProjectsFolder
    Pop $0
    ${If} $0 != ""
        ${NSD_SetText} $ProjectsFolderControl $0
    ${EndIf}
FunctionEnd







Function CheckSystemPage
    ; Placeholder for system check page
    nsDialogs::Create 1018
    Pop $0
    
    ${NSD_CreateLabel} 0 0 100% 20u "Checking system requirements..."
    
    nsDialogs::Show
FunctionEnd


Function InstallTools
    DetailPrint "Installing native Windows tools: Node.js, Git, and Claude Code..."
    
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\install-tools.ps1"'
    Pop $0
    Pop $1
    
    ; Check if tools were already installed.
    StrCmp $1 "TOOLS_ALREADY_INSTALLED" 0 +3
        DetailPrint "All tools are already functional. Skipping installation."
        Return
        
    ; Handle the installation result.
    ${If} $0 != 0
        MessageBox MB_OK|MB_ICONSTOP "Native Windows tools installation failed: $1"
        Abort
    ${Else}
        DetailPrint "Native Windows tools have been successfully installed."
    ${EndIf}
FunctionEnd

Function CreateProjectsFolder
    DetailPrint "Creating projects folder: $ProjectsFolder"
    
    ; Validate ProjectsFolder is set
    ${If} $ProjectsFolder == ""
        DetailPrint "ERROR: No projects folder specified"
        MessageBox MB_OK|MB_ICONSTOP "Internal error: No projects folder specified."
        Abort
    ${EndIf}
    
    ; Create the projects folder with error checking
    CreateDirectory "$ProjectsFolder"
    ${IfNot} ${FileExists} "$ProjectsFolder"
        DetailPrint "ERROR: Failed to create directory: $ProjectsFolder"
        MessageBox MB_OK|MB_ICONSTOP "Failed to create projects folder:$\n$ProjectsFolder$\n$\nPlease check permissions and disk space."
        Abort
    ${EndIf}
    DetailPrint "Projects folder created successfully: $ProjectsFolder"
    
    ; Verify source CLAUDE.md exists
    ${IfNot} ${FileExists} "$INSTDIR\CLAUDE.md"
        DetailPrint "WARNING: CLAUDE.md template not found at: $INSTDIR\CLAUDE.md"
        MessageBox MB_OK|MB_ICONEXCLAMATION "Warning: CLAUDE.md template file missing.$\n$\nInstallation will continue but projects folder will not have the template file."
        Return
    ${EndIf}
    
    ; Copy CLAUDE.md template with error checking
    ClearErrors
    CopyFiles "$INSTDIR\CLAUDE.md" "$ProjectsFolder\CLAUDE.md"
    ${If} ${Errors}
        DetailPrint "WARNING: Failed to copy CLAUDE.md template"
        MessageBox MB_OK|MB_ICONEXCLAMATION "Warning: Could not copy CLAUDE.md template to projects folder.$\n$\nYou may need to create this file manually."
    ${Else}
        DetailPrint "CLAUDE.md template copied successfully"
    ${EndIf}
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
    ; Initialize native Windows installer
    ; No special handling needed for native Windows installation
FunctionEnd

