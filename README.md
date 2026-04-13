# Chandra Journey (C++ Qt Desktop App)

A modern, modular desktop application for journaling, file/media management, and user administration, built with C++20 and Qt 6.8.3.

---

## Features
- **Journaling**: Create, edit, and manage journal entries
- **File & Media Management**: Upload, rename, move, and delete files securely
- **User Administration**: Admin user management, password resets, and bulk operations
- **Activity Log**: Tracks user actions and web-search events
- **Settings**: User and system settings with round-trip persistence
- **Security**: Path safety, authentication, and sysop controls
- **Regression & Smoke Tests**: Comprehensive test suite for all major flows
- **Configurable Branding**: Change app name, version, publisher, and installer branding via CMake variables

---

## Build & Run Instructions

### Prerequisites
- **Windows 10/11**
- **CMake 3.24+**
- **Qt 6.8.3** (or compatible 6.5+)
- **MSVC 2022** (or compatible C++20 compiler)
- **Git**

### Clone the Repository
```sh
git clone https://github.com/gabareeclifton211-hue/chandra.git
cd chandra/cpp-app
```

### Configure & Build
```sh
cmake --preset=release
cmake --build --preset=release
```

#### (Optional) Custom Branding
```sh
cmake --preset=release -DAPP_NAME="MyApp" -DAPP_VERSION="2.0.0"
```

### Run the App
```sh
cd build/release/Release
./chandra_journey.exe
```

### Run Tests
```sh
ctest --preset=release
```

### Create Installer
```sh
cd build/release
makensis ../../platform/windows/chandra_journey.nsi
```

---

## Directory Structure
- `src/` — C++ source code
- `ui/qml/` — QML UI files
- `platform/windows/` — Windows installer scripts
- `tests/` — Regression and smoke tests
- `docs/` — Documentation

---

## License
MIT License (see LICENSE file)

---

## Contributing
Pull requests and issues are welcome! Please see the code style in `CMakeLists.txt` and submit changes via GitHub.

---

## Contact
Maintainer: gabareeclifton211-hue
