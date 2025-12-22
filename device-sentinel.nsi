!define PRODUCT_NAME "Device Sentinel"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "Device Sentinel"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\device-sentinel.exe"

SetCompressor /SOLID lzma

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "dist\device-sentinel-installer.exe"
InstallDir "$PROGRAMFILES\\Device Sentinel"
ShowInstDetails show

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "dist\\device-sentinel.exe"
  File /r "README.md"
  CreateShortCut "$DESKTOP\\Device Sentinel.lnk" "$INSTDIR\\device-sentinel.exe"
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\\device-sentinel.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\\device-sentinel.exe"
  Delete "$DESKTOP\\Device Sentinel.lnk"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
SectionEnd
