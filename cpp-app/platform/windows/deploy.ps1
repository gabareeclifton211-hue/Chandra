#Requires -Version 5.1
<#
.SYNOPSIS
    Chandra's Journey — Windows release deploy script.
.DESCRIPTION
    1. Rebuilds the Release exe via CMake/MSBuild.
    2. Copies the exe to dist\ChandraJourney-<VERSION>\.
    3. Runs windeployqt to gather all Qt runtime dependencies.
    4. Copies MSVC CRT DLLs.
    5. Optionally builds the NSIS installer.
.PARAMETER QtDir
    Path to the Qt msvc2022_64 directory. Default: C:\Qt\6.8.3\msvc2022_64
.PARAMETER BuildInstaller
    Switch. Pass -BuildInstaller to also call makensis and produce the setup exe.
.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -BuildInstaller
    .\deploy.ps1 -QtDir "C:\Qt\6.11.0\msvc2022_64" -BuildInstaller
#>
param(
    [string]$QtDir = "C:\Qt\6.8.3\msvc2022_64",
    [switch]$BuildInstaller
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------- paths -----------------------------------------------------------
$AppVersion  = "1.0.0"
$ScriptDir   = $PSScriptRoot
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$BuildDir    = "$ProjectRoot\build\release"
$ReleaseExe  = "$BuildDir\Release\chandra_journey.exe"
$DistRoot    = "$ProjectRoot\dist"
$DistDir     = "$DistRoot\ChandraJourney-$AppVersion"
$NsiScript   = "$ScriptDir\chandra_journey.nsi"
$QmlSourceDir = "$ProjectRoot\ui\qml"

$WinDeployQt = "$QtDir\bin\windeployqt.exe"
$MakeNsis    = "${env:ProgramFiles(x86)}\NSIS\makensis.exe"

# ---------- helpers ---------------------------------------------------------
function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Die([string]$msg)  { Write-Host "FATAL: $msg" -ForegroundColor Red; exit 1 }

# ---------- validate pre-conditions -----------------------------------------
if (-not (Test-Path $WinDeployQt))  { Die "windeployqt not found at $WinDeployQt" }
if ($BuildInstaller -and -not (Test-Path $MakeNsis)) { Die "makensis not found at $MakeNsis" }

# ---------- stop running instance -------------------------------------------
Step "Stopping running application instance (if any)"
Stop-Process -Name "chandra_journey" -Force -ErrorAction SilentlyContinue

# ---------- cmake build -----------------------------------------------------
Step "Building Release target"
$env:Path = "$QtDir\bin;$env:Path"
Push-Location $BuildDir
try {
    cmake --build . --config Release --target chandra_journey
    if ($LASTEXITCODE -ne 0) { Die "CMake build failed (exit $LASTEXITCODE)" }
} finally { Pop-Location }

if (-not (Test-Path $ReleaseExe)) { Die "Release exe not found after build: $ReleaseExe" }

# ---------- ctest -----------------------------------------------------------
Step "Running regression tests"
Push-Location $BuildDir
try {
    ctest --output-on-failure -C Release
    if ($LASTEXITCODE -ne 0) { Die "Regression tests failed (exit $LASTEXITCODE)" }
} finally { Pop-Location }

# ---------- prepare dist folder ---------------------------------------------
Step "Preparing dist directory: $DistDir"
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Copy-Item $ReleaseExe $DistDir

# ---------- windeployqt -----------------------------------------------------
Step "Running windeployqt"
& $WinDeployQt --release --qmldir $QmlSourceDir "$DistDir\chandra_journey.exe"
# Exit code 1 is expected when optional plugins (SerialPort, dxcompiler) are absent
if ($LASTEXITCODE -gt 1) { Die "windeployqt failed (exit $LASTEXITCODE)" }
Write-Host "windeployqt completed (warnings about optional components are expected)"

# ---------- MSVC CRT DLLs ---------------------------------------------------
Step "Copying MSVC CRT DLLs"
$CrtDlls = @(
    "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
    "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll",
    "vcruntime140.dll", "vcruntime140_1.dll", "vcruntime140_threads.dll",
    "concrt140.dll"
)

# Try VS Build Tools redist first, fall back to System32
$VsRedistBase = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC"
$RedistCrtDir = ""
if (Test-Path $VsRedistBase) {
    $latestRedist = Get-ChildItem $VsRedistBase -Directory | Sort-Object Name | Select-Object -Last 1
    if ($latestRedist) {
        $RedistCrtDir = "$($latestRedist.FullName)\x64\Microsoft.VC143.CRT"
    }
}

foreach ($dll in $CrtDlls) {
    $src = if ($RedistCrtDir -and (Test-Path "$RedistCrtDir\$dll")) {
        "$RedistCrtDir\$dll"
    } else {
        "C:\Windows\System32\$dll"
    }

    if (Test-Path $src) {
        Copy-Item $src $DistDir
        Write-Host "  $dll"
    } else {
        Write-Warning "CRT DLL not found: $dll"
    }
}

# ---------- optional: NSIS installer ----------------------------------------
if ($BuildInstaller) {
    Step "Building NSIS installer"
    New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
    Push-Location $ScriptDir
    try {
        & $MakeNsis $NsiScript
        if ($LASTEXITCODE -ne 0) { Die "makensis failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
    Write-Host "Installer: $DistRoot\ChandraJourney-$AppVersion-Setup.exe" -ForegroundColor Green
}

# ---------- done ------------------------------------------------------------
Write-Host "`n✓ Deploy complete → $DistDir" -ForegroundColor Green
