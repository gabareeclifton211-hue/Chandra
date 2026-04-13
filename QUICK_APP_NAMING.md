# Quick Reference: Change App Name

## One-Line Command (Copy & Paste)

Replace "NEW APP NAME", "NEW PUBLISHER", etc., then run:

```powershell
cd C:\Users\gabar\Desktop\Chandra_C++\cpp-app
cmake --preset=release `
  -DAPP_NAME="NEW APP NAME" `
  -DAPP_DISPLAY_NAME="NEW APP NAME v1.0" `
  -DAPP_PUBLISHER="NEW PUBLISHER" `
  -DAPP_VERSION="1.0.0"
cmake --build --preset=release
```

## Most Common Changes

### Just Change the Window Title
Edit [ui/qml/Main.qml](ui/qml/Main.qml#L12), line 12:
```qml
readonly property string APP_TITLE: "Your New Title Here"
```

### Change Everything (Name, Executable, Installer)
```powershell
cd C:\Users\gabar\Desktop\Chandra_C++\cpp-app
cmake --preset=release `
  -DAPP_NAME="Elite Journal" `
  -DAPP_DISPLAY_NAME="Elite Journal v1.0" `
  -DAPP_PUBLISHER="MyCompany" `
  -DAPP_EXECUTABLE="elite_journal" `
  -DAPP_DIST_DIR="EliteJournal"
cmake --build --preset=release
```

## What Changed After Your Commits

✅ **You can now change:**
- Window title (APP_DISPLAY_NAME)
- App name in installer/registry (APP_NAME)
- Publisher name (APP_PUBLISHER)
- Version (APP_VERSION)
- Executable filename (APP_EXECUTABLE)
- Installer folder name (APP_DIST_DIR)
- Registry keys (APP_INST_KEY, APP_UNINST_KEY)

✅ **Automatically updates:**
- `build/generated/AppConfig.h` - C++ constants
- `build/platform/windows/chandra_journey.nsi` - Installer script
- Window title
- All registry entries
- Installer filename and locations

## Files Modified

1. ✅ [CMakeLists.txt](CMakeLists.txt) - Added configurable variables
2. ✅ [src/AppConfig.h.in](src/AppConfig.h.in) - New template for C++ header
3. ✅ [platform/windows/chandra_journey.nsi.in](platform/windows/chandra_journey.nsi.in) - New template for installer
4. ✅ [ui/qml/Main.qml](ui/qml/Main.qml) - Made APP_TITLE constant
5. ✅ [docs/APP_NAMING.md](docs/APP_NAMING.md) - Complete documentation

## Next Steps for Commit

Before you push:

```powershell
cd C:\Users\gabar\Desktop\Chandra_C++
git add.
git commit -m "feat: add configurable app naming system

- Add CMake variables for app name, version, publisher, executable
- Generate AppConfig.h with build-time constants
- Generate NSIS installer from template with correct metadata  
- Make QML window title configurable
- Add comprehensive documentation for changing app name"
git push
```
