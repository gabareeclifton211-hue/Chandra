# Changing the Application Name

This guide explains how to customize the application name, version, publisher, and executable name across your entire build.

## Quick Start

### To Change the App Name, Version, or Publisher:

Use the CMake configuration command with these options:

```powershell
# Change app name and display title
cmake --preset=release `
  -DAPP_NAME="My New App" `
  -DAPP_DISPLAY_NAME="My New App v2.0" `
  -DAPP_PUBLISHER="My Company" `
  -DAPP_VERSION="2.0.0"
```

### To Change the Executable Name:

```powershell
# Change executable name (also changes EXE filename)
cmake --preset=release `
  -DAPP_EXECUTABLE="my_custom_app" `
  -DAPP_INST_KEY="MyCustomApp" `
  -DAPP_DIST_DIR="MyCustomApp"
```

## Configuration Variables

All of these values are optional. If not specified, they use default values.

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | "Chandra Journey" | Display name in Windows installer and registry |
| `APP_DISPLAY_NAME` | "Chandra Journey (C++ Rebuild)" | Window title shown in the application |
| `APP_VERSION` | "1.0.0" | Application version |
| `APP_PUBLISHER` | "Chandra" | Publisher name in installer and registry |
| `APP_EXECUTABLE` | "chandra_journey" | Name of the .exe file and CMake target |
| `APP_INST_KEY` | "ChandraJourney" | Registry installation key (no spaces!) |
| `APP_UNINST_KEY` | "ChandraJourney" | Registry uninstall key (no spaces!) |
| `APP_DIST_DIR` | "ChandraJourney" | Distribution folder name (no spaces!) |

## Example: Complete Rebrand

To completely rebrand the app as "Elite Journal":

```powershell
cd C:\Users\gabar\Desktop\Chandra_C++\cpp-app

cmake --preset=release `
  -DAPP_NAME="Elite Journal" `
  -DAPP_DISPLAY_NAME="Elite Journal v1.0" `
  -DAPP_PUBLISHER="Elite Software" `
  -DAPP_VERSION="1.0.0" `
  -DAPP_EXECUTABLE="elite_journal" `
  -DAPP_INST_KEY="EliteJournal" `
  -DAPP_UNINST_KEY="EliteJournal" `
  -DAPP_DIST_DIR="EliteJournal"

cmake --build --preset=release
```

Then build the installer:

```powershell
cd build\release
mkdir -p ..\dist\EliteJournal-1.0.0  # Create dist folder
# Deploy dependencies and copy executable
cd ..\..\platform\windows
makensis chandra_journey.nsi
```

## What Gets Updated Automatically

When you configure with these variables, the following are automatically updated:

1. ✅ **CMake Executable Target Name** - The main executable
2. ✅ **Application Window Title** - Title bar of the app
3. ✅ **Generated AppConfig.h** - C++ header with build-time constants
4. ✅ **NSIS Installer Script** - Generated from template with all metadata
5. ✅ **Windows Registry Keys** - Install directory and program info
6. ✅ **Start Menu Shortcuts** - Created with correct app name
7. ✅ **Installer Filename** - `{APP_DIST_DIR}-{APP_VERSION}-Setup.exe`

## Manual Updates

If you want to make some changes that aren't covered by CMake variables, edit these files directly:

- **Window Title in QML**: Edit [ui/qml/Main.qml](../ui/qml/Main.qml#L12) - change `APP_TITLE`
- **CMake Project Name**: Edit [CMakeLists.txt](../CMakeLists.txt#L2) - change `project()` name
- **Add Custom Constants**: Edit [src/AppConfig.h.in](../src/AppConfig.h.in) to add more `#define` statements

## Using App Metadata in C++ Code

The generated `AppConfig.h` header provides these constants:

```cpp
#include "AppConfig.h"

QString appName = APP_NAME;           // "Chandra Journey"
QString appVersion = APP_VERSION;     // "1.0.0"
QString publisher = APP_PUBLISHER;    // "Chandra"
QString exePath = APP_EXECUTABLE;     // "chandra_journey"
QString displayName = APP_DISPLAY_NAME; // "Chandra Journey (C++ Rebuild)"
```

## Build Configuration Flow

```
CMakeLists.txt
  ├─ Defines APP_* variables
  ├─ Generates AppConfig.h.in → Generated/AppConfig.h
  ├─ Generates platform/windows/chandra_journey.nsi.in → build/chandra_journey.nsi
  │
  └─ Builds executable (${APP_EXECUTABLE})
      └─ Links generated AppConfig.h
```

## After Changing the Executable Name

If you change `APP_EXECUTABLE`, remember to:

1. Update the deployment scripts (like `deploy.ps1`) to reference the new executable name
2. Update any shortcuts or batch files that launch the app
3. Update the installer to copy the new executable name
4. Regenerate the installer with `makensis`

## Tips & Tricks

### Generate Multiple Variants

You can create separate build configurations for different app variants:

```powershell
# Debug version
cmake --preset=debug -DAPP_DISPLAY_NAME="Chandra Journey (Debug)"

# Release version  
cmake --preset=release -DAPP_DISPLAY_NAME="Chandra Journey"

# Beta version
cmake --preset=release `
  -DAPP_DISPLAY_NAME="Chandra Journey (Beta)" `
  -DAPP_VERSION="2.0.0-beta"
```

### Check Generated Files

After configuring CMake, check these generated files:

1. `build/generated/AppConfig.h` - C++ configuration header
2. `build/platform/windows/chandra_journey.nsi` - Installer script

These are created anew each CMake reconfigure.

### Rollback to Defaults

To restore all defaults, just don't pass the `-DAPP_*` variables:

```powershell
cmake --preset=release  # Uses all default values
```

## Troubleshooting

**Q: The app name changed in CMake but the window title didn't update**
- A: Edit the `APP_TITLE` property in [ui/qml/Main.qml](../ui/qml/Main.qml#L12) manually, or set `-DAPP_DISPLAY_NAME` when you configure CMake.

**Q: The installer still shows the old name**
- A: Delete the `build/release` folder and reconfigure:
  ```powershell
  Remove-Item build\release -Recurse
  cmake --preset=release -DAPP_NAME="New Name"
  ```

**Q: Registry keys have the old app name**
- A: The NSIS installer uses the generated script. Make sure you regenerated it after changing `APP_INST_KEY`. Uninstall the old version first, or manually delete the old registry keys:
  ```powershell
  reg delete "HKEY_LOCAL_MACHINE\Software\Chandra\ChandraJourney" /f
  ```

## See Also

- [CMakeLists.txt](../CMakeLists.txt) - Configuration variables are defined here
- [src/AppConfig.h.in](../src/AppConfig.h.in) - C++ header template
- [platform/windows/chandra_journey.nsi.in](../platform/windows/chandra_journey.nsi.in) - Installer template
- [ui/qml/Main.qml](../ui/qml/Main.qml#L12) - Window title constant
