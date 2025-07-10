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
Var Username
Var UsernameField

; Pages
!insertmacro MUI_PAGE_WELCOME
Page custom CheckSystemPage
Page custom SelectProjectsFolderPage
Page custom SelectUsernamePage SelectUsernamePageLeave
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
    Call CheckSystemStatus
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

Function CheckSystemStatus
    DetailPrint "Checking system status with functional testing..."
    
    ; Run comprehensive status check
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\check-full-status.ps1"'
    Pop $0 ; Exit code
    Pop $1 ; Output
    
    ; Show user what we found
    DetailPrint "System Status Check Results:"
    DetailPrint "$1"
    
    ; Parse the overall status
    ${If} $0 == 0
        DetailPrint "All components are functional - optimized installation will proceed"
    ${ElseIf} $0 == 1
        DetailPrint "Some components need installation - will install missing parts"
    ${ElseIf} $0 == 2
        DetailPrint "Some components need repair - will fix broken installations"
    ${Else}
        DetailPrint "Status check had issues - will proceed with full installation"
    ${EndIf}
    
    ; Brief pause so user can see the status
    Sleep 2000
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

Function SelectUsernamePage
    nsDialogs::Create 1018
    Pop $0
    
    ${NSD_CreateLabel} 0 0 100% 20u "Enter username for Linux environment:"
    ${NSD_CreateText} 0 25u 70% 14u "user"
    Pop $UsernameField
    
    ${NSD_CreateLabel} 0 50u 100% 30u "Note: Username must be lowercase letters only, start with a letter, and be 32 characters or less. No spaces or special characters (except underscore)."
    
    nsDialogs::Show
FunctionEnd

Function SelectUsernamePageLeave
    ${NSD_GetText} $UsernameField $Username
    
    ; Validate username
    Call ValidateUsername
    Pop $0
    
    ${If} $0 != "valid"
        MessageBox MB_OK|MB_ICONEXCLAMATION "Invalid username: $0$\n$\nPlease enter a valid Linux username."
        Abort
    ${EndIf}
FunctionEnd

Function ValidateUsername
    Push $0
    Push $1
    Push $2
    
    ; Check if empty
    ${If} $Username == ""
        StrCpy $0 "Username cannot be empty"
        Goto done
    ${EndIf}
    
    ; Check length
    StrLen $1 $Username
    ${If} $1 > 32
        StrCpy $0 "Username too long (max 32 characters)"
        Goto done
    ${EndIf}
    
    ; Check if starts with letter
    StrCpy $2 $Username 1
    ${If} $2 < "a"
    ${OrIf} $2 > "z"
        StrCpy $0 "Username must start with a lowercase letter"
        Goto done
    ${EndIf}
    
    ; Comprehensive validation for Linux username requirements
    ${If} $Username != ""
        ; Check for uppercase letters
        Push $Username
        Call ContainsUppercase
        Pop $1
        ${If} $1 == "true"
            StrCpy $0 "Username must be lowercase only"
            Goto done
        ${EndIf}
        
        ; Check for spaces
        Push $Username
        Call ContainsSpaces
        Pop $1
        ${If} $1 == "true"
            StrCpy $0 "Username cannot contain spaces"
            Goto done
        ${EndIf}
        
        ; Check for invalid characters (comprehensive)
        Push $Username
        Call ContainsInvalidChars
        Pop $1
        ${If} $1 == "true"
            StrCpy $0 "Username contains invalid characters. Use only lowercase letters, numbers, and underscores."
            Goto done
        ${EndIf}
        
        ; Check for reserved names
        Push $Username
        Call IsReservedUsername
        Pop $1
        ${If} $1 == "true"
            StrCpy $0 "Username is reserved. Please choose a different name."
            Goto done
        ${EndIf}
    ${EndIf}
    
    StrCpy $0 "valid"
    
    done:
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

Function ContainsUppercase
    Exch $0
    Push $1
    Push $2
    
    StrLen $1 $0
    IntOp $1 $1 - 1
    StrCpy $2 "false"
    
    loop:
    ${If} $1 < 0
        Goto done
    ${EndIf}
    
    StrCpy $0 $0 1 $1
    ${If} $0 >= "A"
    ${AndIf} $0 <= "Z"
        StrCpy $2 "true"
        Goto done
    ${EndIf}
    
    IntOp $1 $1 - 1
    Goto loop
    
    done:
    StrCpy $0 $2
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

Function ContainsSpaces
    Exch $0
    Push $1
    Push $2
    
    StrLen $1 $0
    IntOp $1 $1 - 1
    StrCpy $2 "false"
    
    loop:
    ${If} $1 < 0
        Goto done
    ${EndIf}
    
    StrCpy $0 $0 1 $1
    ${If} $0 == " "
        StrCpy $2 "true"
        Goto done
    ${EndIf}
    
    IntOp $1 $1 - 1
    Goto loop
    
    done:
    StrCpy $0 $2
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

Function ContainsInvalidChars
    Exch $0
    Push $1
    Push $2
    Push $3
    
    StrLen $1 $0
    IntOp $1 $1 - 1
    StrCpy $2 "false"
    
    loop:
    ${If} $1 < 0
        Goto done
    ${EndIf}
    
    StrCpy $3 $0 1 $1
    
    ; Check if character is valid (a-z, 0-9, underscore)
    ${If} $3 >= "a"
    ${AndIf} $3 <= "z"
        ; Valid lowercase letter
        Goto next
    ${EndIf}
    
    ${If} $3 >= "0"
    ${AndIf} $3 <= "9"
        ; Valid number
        Goto next
    ${EndIf}
    
    ${If} $3 == "_"
        ; Valid underscore
        Goto next
    ${EndIf}
    
    ; If we reach here, character is invalid
    StrCpy $2 "true"
    Goto done
    
    next:
    IntOp $1 $1 - 1
    Goto loop
    
    done:
    StrCpy $0 $2
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd

Function IsReservedUsername
    Exch $0
    Push $1
    
    ; Check against common reserved usernames
    StrCpy $1 "false"
    
    ${If} $0 == "root"
    ${OrIf} $0 == "bin"
    ${OrIf} $0 == "daemon"
    ${OrIf} $0 == "adm"
    ${OrIf} $0 == "lp"
    ${OrIf} $0 == "sync"
    ${OrIf} $0 == "shutdown"
    ${OrIf} $0 == "halt"
    ${OrIf} $0 == "mail"
    ${OrIf} $0 == "news"
    ${OrIf} $0 == "uucp"
    ${OrIf} $0 == "operator"
    ${OrIf} $0 == "games"
    ${OrIf} $0 == "gopher"
    ${OrIf} $0 == "ftp"
    ${OrIf} $0 == "nobody"
    ${OrIf} $0 == "systemd"
    ${OrIf} $0 == "dbus"
    ${OrIf} $0 == "polkitd"
    ${OrIf} $0 == "apache"
    ${OrIf} $0 == "www"
    ${OrIf} $0 == "mysql"
    ${OrIf} $0 == "postgres"
    ${OrIf} $0 == "admin"
    ${OrIf} $0 == "administrator"
    ${OrIf} $0 == "test"
    ${OrIf} $0 == "guest"
    ${OrIf} $0 == "wheel"
    ${OrIf} $0 == "sudo"
        StrCpy $1 "true"
    ${EndIf}
    
    StrCpy $0 $1
    Pop $1
    Exch $0
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
    
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\setup-debian.ps1" -Username "$Username"'
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