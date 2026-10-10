Unicode true
!include "MUI2.nsh"
!include "WinMessages.nsh"
!include "x64.nsh"
!cd ".."

Name "暗淡蓝点 (Native)"
OutFile "dist/native-win/DimBlueDot-1.1.0-Win10-x64-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\DimBlueDotNative"
InstallDirRegKey HKCU "Software\Xuwu\DimBlueDotNative" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 8
ShowInstDetails nevershow
ShowUninstDetails nevershow
BrandingText "戌無营造"
VIProductVersion "1.1.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "暗淡蓝点"
VIAddVersionKey /LANG=1033 "CompanyName" "戌無营造"
VIAddVersionKey /LANG=1033 "FileDescription" "暗淡蓝点 Native Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "1.1.0"
VIAddVersionKey /LANG=1033 "LegalCopyright" "戌無营造"
!define MUI_ICON "dist/native-win/icon-small.ico"
!define MUI_UNICON "dist/native-win/icon-small.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\DimBlueDot.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Open 暗淡蓝点"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "This app needs 64-bit Windows 10 or later."
    Abort
  ${EndIf}
  SetShellVarContext current
FunctionEnd

!macro CloseNativeApp
  FindWindow $0 "DimBlueDotNative"
  ${If} $0 != 0
    SendMessage $0 ${WM_COMMAND} 303 0 /TIMEOUT=3000
    Sleep 200
  ${EndIf}
!macroend

Section "Install"
  !insertmacro CloseNativeApp
  SetOutPath "$INSTDIR"
  File "dist/native-win/DimBlueDot.exe"
  File /oname=使用说明.txt "native-win/使用说明.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\暗淡蓝点 (Native)"
  CreateShortcut "$SMPROGRAMS\暗淡蓝点 (Native)\暗淡蓝点.lnk" "$INSTDIR\DimBlueDot.exe"
  CreateShortcut "$SMPROGRAMS\暗淡蓝点 (Native)\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\暗淡蓝点 (Native).lnk" "$INSTDIR\DimBlueDot.exe"
  WriteRegStr HKCU "Software\Xuwu\DimBlueDotNative" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "DisplayName" "暗淡蓝点 (Native)"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "DisplayVersion" "1.1.0"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "Publisher" "戌無营造"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "DisplayIcon" "$INSTDIR\DimBlueDot.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "NoRepair" 1
  FileOpen $0 "$INSTDIR\DimBlueDot.exe" r
  FileSeek $0 0 END $1
  FileClose $0
  FileOpen $0 "$INSTDIR\Uninstall.exe" r
  FileSeek $0 0 END $2
  FileClose $0
  IntOp $1 $1 + $2
  IntOp $1 $1 / 1024
  IntOp $1 $1 + 8
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative" "EstimatedSize" $1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  !insertmacro CloseNativeApp
  Delete "$DESKTOP\暗淡蓝点 (Native).lnk"
  Delete "$SMPROGRAMS\暗淡蓝点 (Native)\暗淡蓝点.lnk"
  Delete "$SMPROGRAMS\暗淡蓝点 (Native)\Uninstall.lnk"
  RMDir "$SMPROGRAMS\暗淡蓝点 (Native)"
  Delete "$INSTDIR\DimBlueDot.exe"
  Delete "$INSTDIR\使用说明.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DimBlueDotNative"
  DeleteRegKey HKCU "Software\Xuwu\DimBlueDotNative"
SectionEnd
