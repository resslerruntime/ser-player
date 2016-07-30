; Script generated by the HM NIS Edit Script Wizard.


; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "SER Player"
!define PRODUCT_VERSION "1.5.4"
!define PRODUCT_PUBLISHER "Chris Garry"
!define PRODUCT_WEB_SITE "https://sites.google.com/site/astropipp/ser-player"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\ser-player.exe"
!define PRODUCT_UNINST_KEY_X86 "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_KEY_X64 "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME} x64"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; MUI 1.67 compatible ------
!include "MUI.nsh"
!include WinVer.nsh
!include x64.nsh

; File association
!include "FileAssociation.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; License page
!insertmacro MUI_PAGE_LICENSE "license\ser_player_licence.txt"
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"


; MUI end ------

Name "${PRODUCT_NAME} v${PRODUCT_VERSION} (64-bit)"
OutFile "ser_player_install_x64.exe"
RequestExecutionLevel admin
InstallDir "$PROGRAMFILES\SER Player"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show

Section "MainSection" SEC01
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  SetOverwrite on
  CreateDirectory "$SMPROGRAMS\SER Player"
  CreateShortCut "$SMPROGRAMS\SER Player\SER Player.lnk" "$INSTDIR\ser-player.exe"
  Delete "$INSTDIR\*.exe"
  Delete "$INSTDIR\*.dll"
  
; Specify files that are to be installed
  File /r "..\bin64\*"
  File /r "..\platform-specific\windows\win*"
SectionEnd

Section -Prerequisites
; Install VC++ 2013 Redistributable
  ExecWait '"$INSTDIR\vcredist_x64.exe /install /quiet /norestart /log %TEMP%\vcredist_2013_x64.log"'
SectionEnd


Section -AdditionalIcons
  SetShellVarContext all
  WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
  CreateShortCut "$SMPROGRAMS\SER Player\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
  CreateShortCut "$SMPROGRAMS\SER Player\Uninstall.lnk" "$INSTDIR\uninst.exe"
SectionEnd

Section -Post
  SetShellVarContext all
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\ser-player.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}" "DisplayIcon" "$INSTDIR\ser-player.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd

Function .onInit
  ; Ensure this is a 64-bit machine
  ${If} ${RunningX64}
    ; Check for current 32-bit installation
    IfFileExists "$PROGRAMFILES\SER Player\uninst.exe" Uninstall32Exists PastUninstall32Check
    Uninstall32Exists:
    ${If} ${Cmd} 'MessageBox MB_YESNO "A 32-bit version of SER Player is already installed.  This version must be uninstalled before the 64-bit version of SER Player can be installed.$\nUninstall now?" IDYES' 
        ExecWait '"$PROGRAMFILES\SER Player\uninst.exe" /S _?=$INSTDIR'
        RMDir /r "$INSTDIR"
	${Else}
	    Quit
    ${EndIf}

    PastUninstall32Check:
    SetRegView 64
    StrCpy $InstDir "$PROGRAMFILES64\SER Player"
  ${Else}
    ; This is a 32-bit machine
    MessageBox MB_OK "Cannot install the 64-bit version of SER Player on 32-bit Windows"
    Quit
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  Call CreateSerFileAssication
FunctionEnd

Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "SER Player was successfully removed from your computer."
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove SER Player and all of its components?" IDYES +2
  Abort
FunctionEnd

!macro IfKeyExists ROOT MAIN_KEY KEY
push $R0
push $R1
 
!define Index 'Line${__LINE__}'
 
StrCpy $R1 "0"
 
"${Index}-Loop:"
; Check for Key
EnumRegKey $R0 ${ROOT} "${MAIN_KEY}" "$R1"
StrCmp $R0 "" "${Index}-False"
  IntOp $R1 $R1 + 1
  StrCmp $R0 "${KEY}" "${Index}-True" "${Index}-Loop"
 
"${Index}-True:"
;Return 1 if found
push "1"
goto "${Index}-End"
 
"${Index}-False:"
;Return 0 if not found
push "0"
goto "${Index}-End"
 
"${Index}-End:"
!undef Index
exch 2
pop $R0
pop $R1
!macroend


Function CreateSerFileAssication
    ${If} ${Cmd} 'MessageBox MB_YESNO "Associate .ser files and install .ser thumbnail preview DLL?$\nThis allows .ser files to be opened with SER Player by double-clicking on them and allows .ser files to be previewed as thumbnails in Windows Explorer." IDYES' 
        ${registerExtension} "$INSTDIR\ser-player.exe" ".ser" "SER File"
      
        ${If} ${AtLeastWinVista}
            ${If} ${RunningX64}
                # 64 bit code
                ;Unregister previous version of SerThumbnailHandler.dll
                ExecWait 'regsvr32.exe /s /u "$INSTDIR\win64\SerThumbnailHandler.dll"'
                ;Register SerThumbnailHandler.dll
                ExecWait 'regsvr32.exe /s "$INSTDIR\win64\SerThumbnailHandler.dll"'
            ${Else}
                # 32 bit code
                ;Unregister previous version of SerThumbnailHandler.dll
                ExecWait 'regsvr32.exe /s /u "$INSTDIR\win32\SerThumbnailHandler.dll"'
                ;Register SerThumbnailHandler.dll
                ExecWait 'regsvr32.exe  /s "$INSTDIR\win32\SerThumbnailHandler.dll"'
            ${EndIf}  
        ${EndIf}
    ${EndIf}
FunctionEnd
 
!macro _OpenURL URL
Push "${URL}"
Call openLinkNewWindow
!macroend
 
!define OpenURL '!insertmacro "_OpenURL"'


Section Uninstall
  SetShellVarContext all
  
;Unregister SerThumbnailHandler.dll
  ${If} ${RunningX64}
    ; 64 bit code
    ExecWait 'regsvr32.exe /s /u "$INSTDIR\win64\SerThumbnailHandler.dll"'
  ${Else}
    ; 32 bit code
    ExecWait 'regsvr32.exe /s /u "$INSTDIR\win32\SerThumbnailHandler.dll"'
  ${EndIf}  
  
;Remove the installation directory
  RMDir /r "$INSTDIR"
  
;Remove Start Menu Shortcuts directory
  Delete "$SMPROGRAMS\SER Player\Uninstall.lnk"
  Delete "$SMPROGRAMS\SER Player\Website.lnk"
  Delete "$SMPROGRAMS\SER Player\SER Player.lnk"
  RMDir /r "$SMPROGRAMS\SER Player"
  
  
  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY_X64}"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
  ${unregisterExtension} ".ser" "SER File"
  SetAutoClose true 
SectionEnd



