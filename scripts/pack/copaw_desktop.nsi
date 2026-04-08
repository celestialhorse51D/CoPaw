; CoPaw Desktop NSIS installer. Run makensis from repo root after
; building dist/win-unpacked (see scripts/pack/build_win.ps1).
; Usage: makensis /DCOPAW_VERSION=1.2.3 /DOUTPUT_EXE=dist\CoPaw-Setup-1.2.3.exe scripts\pack\copaw_desktop.nsi

!include "MUI2.nsh"
!include "LogicLib.nsh"
!define MUI_ABORTWARNING
; Use custom icon from unpacked env (copied by build_win.ps1)
!define MUI_ICON "${UNPACKED}\icon.ico"
!define MUI_UNICON "${UNPACKED}\icon.ico"

; WebView2 Runtime detection — same GUID used by desktop_cmd.py
!define WEBVIEW2_GUID "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
!define WEBVIEW2_BOOTSTRAPPER_URL "https://go.microsoft.com/fwlink/p/?LinkId=2124703"

!ifndef COPAW_VERSION
  !define COPAW_VERSION "0.0.0"
!endif
!ifndef OUTPUT_EXE
  !define OUTPUT_EXE "dist\CoPaw-Setup-${COPAW_VERSION}.exe"
!endif

Name "CoPaw Desktop"
OutFile "${OUTPUT_EXE}"
InstallDir "$LOCALAPPDATA\CoPaw"
InstallDirRegKey HKCU "Software\CoPaw" "InstallPath"
RequestExecutionLevel user

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

; Pass /DUNPACKED=full_path from build_win.ps1 so path works when cwd != repo root
!ifndef UNPACKED
  !define UNPACKED "dist\win-unpacked"
!endif

; ---------------------------------------------------------------------------
; WebView2 Runtime: detect via registry, download + install if missing.
; The bootstrapper (~1.8 MB) supports per-user install — no admin needed.
; ---------------------------------------------------------------------------
Function _DetectWebView2
  ; Check HKLM 64-bit registry view
  SetRegView 64
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\EdgeUpdate\Clients\${WEBVIEW2_GUID}" "pv"
  ${If} $0 != ""
  ${AndIf} $0 != "0.0.0.0"
    SetRegView lastused
    StrCpy $1 "1"
    Return
  ${EndIf}

  ; Check HKLM 32-bit registry view
  SetRegView 32
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\EdgeUpdate\Clients\${WEBVIEW2_GUID}" "pv"
  ${If} $0 != ""
  ${AndIf} $0 != "0.0.0.0"
    SetRegView lastused
    StrCpy $1 "1"
    Return
  ${EndIf}
  SetRegView lastused

  ; Check HKCU (not affected by registry redirection)
  ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\${WEBVIEW2_GUID}" "pv"
  ${If} $0 != ""
  ${AndIf} $0 != "0.0.0.0"
    StrCpy $1 "1"
    Return
  ${EndIf}

  StrCpy $1 "0"
FunctionEnd

; Hidden section (runs automatically, not shown in component list)
Section "-WebView2"
  Call _DetectWebView2
  ${If} $1 == "1"
    DetailPrint "WebView2 Runtime already installed ($0), skipping."
    Goto webview2_done
  ${EndIf}

  DetailPrint "WebView2 Runtime not found, downloading bootstrapper..."
  NSISdl::download "${WEBVIEW2_BOOTSTRAPPER_URL}" "$TEMP\MicrosoftEdgeWebview2Setup.exe"
  Pop $0
  ${If} $0 == "success"
    DetailPrint "Installing WebView2 Runtime (this may take a moment)..."
    ExecWait '"$TEMP\MicrosoftEdgeWebview2Setup.exe" /silent /install' $0
    Delete "$TEMP\MicrosoftEdgeWebview2Setup.exe"
    ${If} $0 != 0
      DetailPrint "WebView2 installer exited with code $0"
      MessageBox MB_OK|MB_ICONEXCLAMATION \
        "WebView2 Runtime installation may have failed (exit code: $0).$\n$\n\
CoPaw Desktop requires WebView2 to display properly.$\n\
If it does not work, please install manually:$\n\
https://developer.microsoft.com/en-us/microsoft-edge/webview2/"
    ${Else}
      DetailPrint "WebView2 Runtime installed successfully."
    ${EndIf}
  ${Else}
    Delete "$TEMP\MicrosoftEdgeWebview2Setup.exe"
    MessageBox MB_OK|MB_ICONEXCLAMATION \
      "Could not download WebView2 Runtime ($0).$\n$\n\
CoPaw Desktop requires WebView2 to display properly.$\n\
Please install it manually after setup:$\n\
https://developer.microsoft.com/en-us/microsoft-edge/webview2/"
  ${EndIf}

  webview2_done:
SectionEnd

Section "CoPaw Desktop" SEC01
  SetOutPath "$INSTDIR"
  File /r "${UNPACKED}\*.*"
  WriteRegStr HKCU "Software\CoPaw" "InstallPath" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Main shortcut - uses VBS to hide console window
  CreateShortcut "$SMPROGRAMS\CoPaw Desktop.lnk" "$INSTDIR\CoPaw Desktop.vbs" "" "$INSTDIR\icon.ico" 0
  CreateShortcut "$DESKTOP\CoPaw Desktop.lnk" "$INSTDIR\CoPaw Desktop.vbs" "" "$INSTDIR\icon.ico" 0
  
  ; Debug shortcut - shows console window for troubleshooting
  CreateShortcut "$SMPROGRAMS\CoPaw Desktop (Debug).lnk" "$INSTDIR\CoPaw Desktop (Debug).bat" "" "$INSTDIR\icon.ico" 0
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\CoPaw Desktop.lnk"
  Delete "$SMPROGRAMS\CoPaw Desktop (Debug).lnk"
  Delete "$DESKTOP\CoPaw Desktop.lnk"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\CoPaw"
SectionEnd
