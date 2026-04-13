# Toolchain Lock (Windows)

- Compiler: MSVC (Visual Studio 2022 Build Tools)
- CMake: 3.24+
- Generator: Ninja
- Qt: 6.11.0 msvc2022_64
- Modules: Core, Gui, Quick, QuickControls2, Sql
- Database: SQLite (Qt SQL driver)

## Session Setup

Run in Developer PowerShell for VS 2022:

```powershell
$env:Path = "C:\Qt\6.11.0\msvc2022_64\bin;$env:Path"
qmake -v
cl
cmake --version
```

## Configure + Build

```powershell
cmake --preset debug
cmake --build --preset debug
```

## Run

```powershell
.\build\debug\chandra_journey.exe
```
