; ============================================================
; Chandra's Journey v1.0.0 – NSIS Installer Script
; Build: makensis chandra_journey.nsi (run from platform\windows\)
; ============================================================

!define APP_NAME        "Chandra's Journey"
!define APP_VERSION     "1.0.0"
!define APP_PUBLISHER   "Chandra"
!define APP_EXE         "chandra_journey.exe"
!define INST_KEY        "Software\Chandra\ChandraJourney"
!define UNINST_KEY      "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChandraJourney"
!define DIST_DIR        "..\..\dist\ChandraJourney-1.0.0"

Unicode True
SetCompressor /SOLID lzma
RequestExecutionLevel admin

Name "${APP_NAME} ${APP_VERSION}"
OutFile "..\..\dist\ChandraJourney-${APP_VERSION}-Setup.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${INST_KEY}" "InstallDir"

; Pages
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

; ---- Main install section --------------------------------
Section "Application" SecApp
    SectionIn RO
    SetOutPath "$INSTDIR"

    ; ---- Root DLLs and exe ----
    File "${DIST_DIR}\chandra_journey.exe"
    File "${DIST_DIR}\Qt6Core.dll"
    File "${DIST_DIR}\Qt6Gui.dll"
    File "${DIST_DIR}\Qt6Network.dll"
    File "${DIST_DIR}\Qt6Qml.dll"
    File "${DIST_DIR}\Qt6QmlCore.dll"
    File "${DIST_DIR}\Qt6QmlMeta.dll"
    File "${DIST_DIR}\Qt6QmlModels.dll"
    File "${DIST_DIR}\Qt6QmlWorkerScript.dll"
    File "${DIST_DIR}\Qt6Quick.dll"
    File "${DIST_DIR}\Qt6QuickControls2.dll"
    File "${DIST_DIR}\Qt6QuickControls2Basic.dll"
    File "${DIST_DIR}\Qt6QuickControls2BasicStyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickControls2FluentWinUI3StyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickControls2Fusion.dll"
    File "${DIST_DIR}\Qt6QuickControls2FusionStyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickControls2Imagine.dll"
    File "${DIST_DIR}\Qt6QuickControls2ImagineStyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickControls2Impl.dll"
    File "${DIST_DIR}\Qt6QuickControls2Material.dll"
    File "${DIST_DIR}\Qt6QuickControls2MaterialStyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickControls2Universal.dll"
    File "${DIST_DIR}\Qt6QuickControls2UniversalStyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickControls2WindowsStyleImpl.dll"
    File "${DIST_DIR}\Qt6QuickDialogs2.dll"
    File "${DIST_DIR}\Qt6QuickDialogs2QuickImpl.dll"
    File "${DIST_DIR}\Qt6QuickDialogs2Utils.dll"
    File "${DIST_DIR}\Qt6QuickEffects.dll"
    File "${DIST_DIR}\Qt6QuickLayouts.dll"
    File "${DIST_DIR}\Qt6QuickShapes.dll"
    File "${DIST_DIR}\Qt6QuickTemplates2.dll"
    File "${DIST_DIR}\Qt6LabsFolderListModel.dll"
    File "${DIST_DIR}\Qt6Sql.dll"
    File "${DIST_DIR}\Qt6Svg.dll"
    File "${DIST_DIR}\Qt6Multimedia.dll"
    File "${DIST_DIR}\Qt6MultimediaQuick.dll"
    File "${DIST_DIR}\Qt6OpenGL.dll"
    File "${DIST_DIR}\Qt6Positioning.dll"
    File "${DIST_DIR}\Qt6WebEngineCore.dll"
    File "${DIST_DIR}\Qt6WebEngineQuick.dll"
    File "${DIST_DIR}\Qt6WebChannel.dll"
    File "${DIST_DIR}\Qt6WebChannelQuick.dll"
    File "${DIST_DIR}\QtWebEngineProcess.exe"
    File "${DIST_DIR}\D3Dcompiler_47.dll"
    File "${DIST_DIR}\opengl32sw.dll"
    File "${DIST_DIR}\avcodec-61.dll"
    File "${DIST_DIR}\avformat-61.dll"
    File "${DIST_DIR}\avutil-59.dll"
    File "${DIST_DIR}\swresample-5.dll"
    File "${DIST_DIR}\swscale-8.dll"
    File "${DIST_DIR}\msvcp140.dll"
    File "${DIST_DIR}\msvcp140_1.dll"
    File "${DIST_DIR}\msvcp140_2.dll"
    File "${DIST_DIR}\msvcp140_atomic_wait.dll"
    File "${DIST_DIR}\msvcp140_codecvt_ids.dll"
    File "${DIST_DIR}\vcruntime140.dll"
    File "${DIST_DIR}\vcruntime140_1.dll"
    File "${DIST_DIR}\vcruntime140_threads.dll"
    File "${DIST_DIR}\concrt140.dll"

    ; ---- Plugin subdirectories ----
    SetOutPath "$INSTDIR\generic"
    File /r "${DIST_DIR}\generic\*"

    SetOutPath "$INSTDIR\iconengines"
    File /r "${DIST_DIR}\iconengines\*"

    SetOutPath "$INSTDIR\imageformats"
    File /r "${DIST_DIR}\imageformats\*"

    SetOutPath "$INSTDIR\multimedia"
    File /r "${DIST_DIR}\multimedia\*"

    SetOutPath "$INSTDIR\networkinformation"
    File /r "${DIST_DIR}\networkinformation\*"

    SetOutPath "$INSTDIR\platforms"
    File /r "${DIST_DIR}\platforms\*"

    SetOutPath "$INSTDIR\position"
    File /r "${DIST_DIR}\position\*"

    SetOutPath "$INSTDIR\sqldrivers"
    File /r "${DIST_DIR}\sqldrivers\*"

    SetOutPath "$INSTDIR\tls"
    File /r "${DIST_DIR}\tls\*"

    SetOutPath "$INSTDIR\qmltooling"
    File /r "${DIST_DIR}\qmltooling\*"

    SetOutPath "$INSTDIR\resources"
    File /r "${DIST_DIR}\resources\*"

    SetOutPath "$INSTDIR\translations"
    File /r "${DIST_DIR}\translations\*"

    SetOutPath "$INSTDIR\qml"
    File /r "${DIST_DIR}\qml\*"

    ; ---- Registry ----
    SetOutPath "$INSTDIR"
    WriteRegStr  HKLM "${INST_KEY}" "InstallDir" "$INSTDIR"
    WriteRegStr  HKLM "${INST_KEY}" "Version"    "${APP_VERSION}"
    WriteRegStr  HKLM "${UNINST_KEY}" "DisplayName"          "${APP_NAME}"
    WriteRegStr  HKLM "${UNINST_KEY}" "DisplayVersion"       "${APP_VERSION}"
    WriteRegStr  HKLM "${UNINST_KEY}" "Publisher"            "${APP_PUBLISHER}"
    WriteRegStr  HKLM "${UNINST_KEY}" "UninstallString"      '"$INSTDIR\Uninstall.exe"'
    WriteRegStr  HKLM "${UNINST_KEY}" "InstallLocation"      "$INSTDIR"
    WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify"            1
    WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair"            1

    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; ---- Shortcuts ----
    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortcut  "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
    CreateShortcut  "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"   "$INSTDIR\Uninstall.exe"
    CreateShortcut  "$DESKTOP\${APP_NAME}.lnk"                "$INSTDIR\${APP_EXE}"
SectionEnd

; ---- Uninstall section ----------------------------------
Section "Uninstall"
    RMDir /r "$INSTDIR"

    Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"
    RMDir  "$SMPROGRAMS\${APP_NAME}"
    Delete "$DESKTOP\${APP_NAME}.lnk"

    DeleteRegKey HKLM "${INST_KEY}"
    DeleteRegKey HKLM "${UNINST_KEY}"
SectionEnd
