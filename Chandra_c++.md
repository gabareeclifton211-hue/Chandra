## Plan: Ground-Up C++ Rebuild (Qt/QML)

Rebuild the application from scratch in modern C++ using Qt 6 with Qt Quick/QML, SQLite metadata storage, and an embedded browser in v1. Keep this as a clean-room rebuild: no edits to existing project source files, and no dependency on Electron runtime code at build time. Reuse only product behavior as reference.

**Steps**
1. Define product parity contract and acceptance criteria from existing app behavior (auth, wardrobe/media, journal, camera, import browser, admin, settings). Mark each feature with v1 must-have status. This contract gates all downstream steps.
2. Establish repository structure for a new C++ project in a separate root (parallel with step 3): cpp-app/ with modules core/, data/, services/, ui/qml/, platform/windows/, tests/, and top-level CMake presets.
3. Provision and lock toolchain (parallel with step 2): MSVC, CMake, Ninja, Qt 6 modules (Core, Quick, QuickControls2, Multimedia, WebEngine, Sql), NSIS, and signing tooling. Capture exact versions in docs/toolchain.md for reproducibility.
4. Design domain model and persistence schema (depends on 1): define SQLite schema for users, file items, descriptions, journal entries, category mappings, settings, and custom tabs; define migration/bootstrap rules for first run.
5. Implement security/auth foundation (depends on 4): PBKDF2-SHA512 password hashing, salt strategy, user roles, login throttling, secure file-path canonicalization, and audit logging hooks.
6. Implement storage and media services (depends on 4, 5): file import/export, copy/move/rename/delete, media probing, thumbnail cache, category folder mapping per user, and resilient transaction boundaries between filesystem and SQLite.
7. Build shell UI and navigation in QML (depends on 2, 5): login flow, session state, tab host, responsive layouts for desktop/mobile window sizes, and global notifications.
8. Deliver feature modules in phased vertical slices:
   - 8a Wardrobe module (depends on 6, 7): per-category media grid/list, preview viewer, drag/drop, rename/move/delete, descriptions.
   - 8b Journal module (depends on 6, 7): entry CRUD, timestamps, sorting, unsaved-change guards.
   - 8c Camera module (depends on 6, 7): device selection, photo capture with countdown, video record/stop, save pipeline.
   - 8d Import module with embedded browser v1 (depends on 6, 7): search engine selector, intercepted downloads, URL/media validation, save destination picker.
   - 8e Admin module (depends on 6, 7): user CRUD/reset, global file listing, batch operations, role checks.
9. Add settings/profile capabilities (depends on 8): custom tabs, tab labels, avatars, per-user preferences, default app settings, import/browser defaults.
10. Hardening and quality gates (depends on 8, 9): structured error handling, background worker queue, cancellation, race-condition mitigation, large-library performance tests, and security review checklist.
11. Packaging and release pipeline (depends on 10): CMake Release build, dependency deployment (Qt deploy), NSIS installer, optional code signing, and upgrade path tests.
12. UAT and parity sign-off (depends on 11): execute parity matrix against feature contract; close defects and finalize v1 readiness.

**Relevant files (behavior reference only — do NOT modify)**
- c:/Users/gabar/Desktop/chandras-journey/electron/main.cjs — auth, file ops, role-guarded actions
- c:/Users/gabar/Desktop/chandras-journey/electron/preload.cjs — API surface / service boundaries
- c:/Users/gabar/Desktop/chandras-journey/src/App.jsx — session and login flow
- c:/Users/gabar/Desktop/chandras-journey/src/components/MainApp.jsx — tab definitions and navigation
- c:/Users/gabar/Desktop/chandras-journey/src/components/tabs/WardrobeTab.jsx — wardrobe interactions
- c:/Users/gabar/Desktop/chandras-journey/src/components/tabs/JournalTab.jsx — journal lifecycle
- c:/Users/gabar/Desktop/chandras-journey/src/components/tabs/CameraTab.jsx — capture/recording UX
- c:/Users/gabar/Desktop/chandras-journey/src/components/tabs/ImportTab.jsx — import browser behavior
- c:/Users/gabar/Desktop/chandras-journey/src/components/admin/AdminPanel.jsx — admin operations

**Verification**
1. Toolchain: confirm cl, cmake, ninja, qmake, windeployqt, makensis, signtool in Developer PowerShell.
2. Unit tests: auth/hashing, path traversal guards, SQLite repos, filesystem transactions.
3. Integration tests: login, upload, rename, move, journal CRUD, camera capture, import download, admin batch delete.
4. Performance: large media list load; camera/browser session memory profiling.
5. Security: path injection, malformed media, unauthorized admin access, brute-force login.
6. Installer: clean install, upgrade, uninstall, data preservation, signed build.

**Toolchain Status — Fully Verified (Apr 9, 2026)**
- MSVC compiler (cl)       : Ready — VS Build Tools Dev shell
- CMake                    : Ready — VS Build Tools
- Ninja                    : Ready — VS Build Tools
- Qt 6.11.0 msvc2022_64   : Ready — C:\Qt\6.11.0\msvc2022_64
- qmake                    : Ready — C:\Qt\6.11.0\msvc2022_64\bin
- windeployqt              : Ready — C:\Qt\6.11.0\msvc2022_64\bin
- Qt Creator 19.0.0        : Ready — installed via winget
- vcpkg                    : Ready — C:\vcpkg
- NSIS                     : Ready — system
- signtool                 : Ready — Windows SDK x64
- Git                      : Ready — system PATH

**Decisions**
- UI stack: Qt Quick/QML
- Compiler/kit: MSVC msvc2022_64 — do NOT use mingw_64 for this project
- Qt version: 6.11.0
- Metadata storage: SQLite
- Import browser: QWebEngineView embedded in v1
- Scope: new C++ project tree only; existing JS/Electron files are read-only references
- Excluded from v1: cloud sync, remote multi-device sharing, plugin ecosystem

**Developer PowerShell Setup (run before each build session)**
Open Developer PowerShell for VS 2022, then run:
  $env:Path = "C:\Qt\6.11.0\msvc2022_64\bin;$env:Path"
  qmake -v
  cl
  cmake --version

**Further Considerations**
1. Codec strategy: include ffmpeg-backed decoding early to match Chromium media breadth.
2. Concurrency: central worker queue with prioritized tasks to prevent UI stutter.
3. Data compatibility: one-time JSON-to-SQLite import utility if needed later — out of v1 scope.

## Project Log: Apr 10, 2026

### Session Summary
- Continued stabilization and feature completion work in `cpp-app` for the Qt/QML rebuild.
- Main themes this session: admin file operations, Windows path-safety edge cases, and a full rework of wardrobe drag-to-category behavior.
- End state at close of session: admin cross-user move works, thumbnails work, duplicate upload handling is enforced, bulk delete exists across key tabs, and wardrobe category drag/move is now handled by a manual drag controller rather than Qt internal `DropArea` routing.

### Features/Fixes Completed During Session
- Added admin media move workflow so sysop can move selected files from one user to another and choose a destination category.
- Added backend support for admin file moves:
  - `AppController::moveAdminFiles(...)`
  - `FileMediaService::moveFileAdmin(...)`
  - `UserRepository::findUserById(...)`
- Added admin UI controls for destination user + destination category and a `Move Selected` action.
- Fixed Windows managed-storage guard for admin file moves/deletes by normalizing separators and comparing paths consistently/case-insensitively.
- Preserved strict safety rule: admin file operations must stay inside managed storage under the app users root.

### Errors Encountered And Fixes

#### 1. Admin Move Error
- Symptom:
  - Moving a file from `chandra/panties` to `Tonia/panties` failed with:
    - `Refusing to move file outside managed storage.`
- Root cause:
  - Windows path comparison used mixed separator forms and fragile prefix logic.
  - A valid managed file path could fail the containment check even though it was under the users root.
- Fix:
  - Added normalized path comparison helper in `FileMediaService.cpp`.
  - Converted candidate/root paths with native-separator normalization before containment checks.
  - Reused same helper for both admin move and admin delete safety checks.
- Result:
  - Cross-user admin move succeeded after patch.

#### 2. Repeated Linker Lock During Build
- Symptom:
  - Release builds intermittently failed with `LNK1104: cannot open file 'chandra_journey.exe'`.
- Root cause:
  - Running app instance kept the target binary locked during relink.
- Fix/workaround used this session:
  - Explicitly stopped `chandra_journey` process before rebuild.
- Result:
  - Builds linked successfully after process termination.

#### 3. Wardrobe Drag/Drop Did Not Work
- Original symptom:
  - Drag and drop had not worked since first launch.
  - Initial user reports: dragging caused list scroll instead of drag.
  - Later states: drag handle moved, prohibited cursor appeared, handle could not leave grid, handle moved without carrying file/drop behavior.

### Drag/Drop Investigation Timeline

#### A. Initial Metadata Mismatch
- Problem:
  - `drop.source` did not always expose the outer delegate fields expected by the drop logic.
  - Drag payload was being read from the wrong object in some cases.
- Fix attempted:
  - Added parent-chain metadata resolution in `ShellView.qml` via `resolveDragValue(...)`.
  - Mirrored `dragFilename` and `dragCategory` on the handle itself.

#### B. Scroll Gesture Won Over Drag Gesture
- Problem:
  - `ListView` flick behavior captured pointer movement before drag activation.
- Fixes attempted:
  - Disabled list interaction while drag active.
  - Increased handle usability and pointer grab priority.
  - Tried `MouseArea` press capture and then removed it when it interfered with drag initiation.
  - Set `DragHandler.dragThreshold = 0` and adjusted grab behavior.

#### C. Prohibited Cursor Over Category Chips
- Problem:
  - Drag started, but target did not accept the drop action.
- Fixes attempted:
  - Added explicit drag acceptance in `DropArea.onEntered`, `onPositionChanged`, and `onDropped`.
  - Added explicit drag hotspot.
  - Switched source from whole delegate to handle item.

#### D. Handle Could Move But Could Not Leave Grid
- Problem:
  - Handle was visually constrained by the clipped `ListView` / delegate hierarchy.
- Fix attempted:
  - Reparented drag handle to a top-level overlay layer in `ShellView` during drag.
- Result:
  - Handle could move above the grid, but Qt internal drag/drop still did not provide reliable end-to-end behavior.

#### E. Final Fix: Replaced Qt Internal Drop Path With Manual Drag Controller
- Final root decision:
  - Stop relying on Qt internal `Drag` + `DropArea` routing for this wardrobe-to-category interaction.
  - Use direct pointer-position tracking and explicit category hit-testing in `ShellView`.
- Final implementation:
  - `ShellView.qml` now owns the drag session state:
    - `manualDragActive`
    - `manualDragFilename`
    - `manualDragFromCategory`
    - `manualDragHoverCategory`
    - `manualDragPosition`
  - Added helper functions:
    - `beginWardrobeDrag(...)`
    - `updateWardrobeDrag(...)`
    - `endWardrobeDrag(...)`
    - `categoryAt(...)`
  - Category chips now highlight based on pointer hit-test instead of `DropArea.containsDrag`.
  - Drag overlay now shows a floating filename preview while dragging.
  - On release over a valid category, `ShellView` calls `appController.moveFile(fromCategory, targetCategory, filename)` directly.
  - `WardrobeView.qml` reports drag lifecycle to `ShellView` and still uses overlay reparenting so the handle can move outside the grid.
- Result:
  - Final user confirmation: `now we got it`.

### Other Working Changes Confirmed In This Session Window
- File upload robustness improvements remained in place.
- File-open access-denied behavior had already been corrected earlier via managed-path logic tuning.
- File picker for upload remained in place.
- Camera audio fix remained in place.
- Thumbnails remained working after switching to status-based image loading.
- Bulk delete remained available across Journal, Camera, and Admin views.
- Duplicate upload handling remained active with skip-duplicates behavior.

### Files Touched During This Session
- `cpp-app/src/data/UserRepository.h`
- `cpp-app/src/data/UserRepository.cpp`
- `cpp-app/src/services/FileMediaService.h`
- `cpp-app/src/services/FileMediaService.cpp`
- `cpp-app/src/app/AppController.h`
- `cpp-app/src/app/AppController.cpp`
- `cpp-app/ui/qml/views/AdminView.qml`
- `cpp-app/ui/qml/views/WardrobeView.qml`
- `cpp-app/ui/qml/views/ShellView.qml`

### Final Working State At End Of Day
- Admin can move selected media between users and into a chosen destination category.
- Windows managed-storage path checks are working correctly for admin move/delete.
- Wardrobe drag-to-category now works through explicit manual drag tracking rather than Qt internal `DropArea` handling.
- Release build linked successfully at end of session.

### Recommended Next Start Point
1. Smoke test the final manual wardrobe drag flow across all wardrobe categories.
2. Add a success toast/message for admin move and wardrobe drag move so successful actions are clearer.
3. If desired later, refactor manual drag code into a reusable QML helper component to reduce `ShellView` / `WardrobeView` coupling.

## Project Log: Apr 11, 2026

### Session Summary
- Continued feature expansion and stabilization in `cpp-app`, with emphasis on camera UX, user profile data, Admin usability, and automated regression coverage.
- Main outcomes this session:
  - Camera tab redesigned into a split layout with persistent pane sizing.
  - Camera save/import reliability hardened and category routing added.
  - Manual path upload UI removed in favor of picker-based import flows.
  - Admin media review improved with thumbnails and direct open actions.
  - Optional user profile fields added end-to-end, including a new `My Profile` tab.
  - Backend regression harness created and extended to cover admin operations, startup/resource loading, and camera output path behavior.
  - Admin file pane changed from global listing toward selected-user-only behavior, including multiple follow-up fixes.

### Major Features And Fixes Completed

#### 1. Camera Tab Layout Rework
- Replaced the old vertical camera layout with a side-by-side split:
  - live camera and capture controls on the left
  - camera file list on the right
- Added draggable splitter with persisted split ratio.
- Reduced right-side row density so more files fit in view.

Files touched:
- `cpp-app/ui/qml/views/CameraView.qml`

#### 2. Camera Capture / Recording Reliability
- Fixed stopped-state capture failure:
  - photo capture now waits for camera activation before shooting.
- Fixed output path write failures:
  - output path normalization
  - fallback to writable safe folder
  - proper `file:///` recorder output URLs
  - one-shot fallback retry for recording
- Added C++ helper to guarantee a writable capture directory:
  - `AppController::ensureCaptureOutputDir(...)`
- Final outcome:
  - photo capture and video recording passed after multiple iterations.

Files touched:
- `cpp-app/src/app/AppController.h`
- `cpp-app/src/app/AppController.cpp`
- `cpp-app/ui/qml/views/CameraView.qml`

#### 3. Camera Category Routing And Drag/Drop
- Added camera target-category selection so captured/imported media can be placed into any supported category instead of always landing in `camera`.
- Added camera-tab drag handles using the same manual host drag strategy used for wardrobe items.
- Extended top category drop chips in `ShellView` to include `camera`.

Files touched:
- `cpp-app/ui/qml/views/CameraView.qml`
- `cpp-app/ui/qml/views/ShellView.qml`

#### 4. Removal Of Manual File Path Upload UI
- Removed manual text-area file path entry blocks from tabs that had them.
- Retained Explorer / portable-drive picker workflow only.

Files touched:
- `cpp-app/ui/qml/views/WardrobeView.qml`
- `cpp-app/ui/qml/views/CameraView.qml`

#### 5. Admin Media Review Improvements
- Added thumbnail preview tiles for Admin media rows.
- Added explicit `Open` button for admin media rows.
- Added one-click thumbnail opening in Wardrobe, Camera, and Admin by making preview tiles clickable.

Files touched:
- `cpp-app/ui/qml/views/AdminView.qml`
- `cpp-app/ui/qml/views/WardrobeView.qml`
- `cpp-app/ui/qml/views/CameraView.qml`

#### 6. Optional User Profile Fields
- Added optional user fields end-to-end:
  - email
  - phone
  - profile picture
  - pronouns
- Extended schema with migration logic for existing databases.
- Extended repository and controller APIs to create/update/read these fields.
- Added Admin-side profile editing UI and profile picture picker.

Files touched:
- `cpp-app/src/data/DatabaseManager.cpp`
- `cpp-app/src/data/UserRepository.h`
- `cpp-app/src/data/UserRepository.cpp`
- `cpp-app/src/app/AppController.h`
- `cpp-app/src/app/AppController.cpp`
- `cpp-app/ui/qml/views/AdminView.qml`

#### 7. Header Profile Display And My Profile Tab
- Exposed current-user profile fields on `AppController` session properties.
- Updated app header to show:
  - profile picture or fallback initial
  - username and pronouns
  - role, email, phone
- Added `My Profile` tab for signed-in users.
- Added self-service profile editing via `updateMyProfile(...)`.

Files touched:
- `cpp-app/src/app/AppController.h`
- `cpp-app/src/app/AppController.cpp`
- `cpp-app/ui/qml/views/ShellView.qml`
- `cpp-app/ui/qml/views/MyProfileView.qml`

### Errors Encountered And Final Fixes

#### 1. Camera Layout Appeared Unchanged After Edit
- Symptom:
  - user relaunched app and camera tab still appeared vertical.
- Root cause:
  - source was updated, but release binary had not been rebuilt with the new QML resources due to linker/process state.
- Fix:
  - verified `CameraView.qml` content
  - stopped running process
  - rebuilt release target successfully
- Result:
  - split layout appeared correctly.

#### 2. `LNK1104` During Rebuilds
- Symptom:
  - repeated `cannot open file 'chandra_journey.exe'`
  - later also `cannot open file 'regression_tests.exe'`
- Root cause:
  - running app or test executable held linker lock.
- Fix:
  - stop process before relink and rerun build.
- Result:
  - rebuilds succeeded after unlock.

#### 3. Photo Capture Failed In Stopped State
- Symptom:
  - `photo capture failed ... could not capture in stopped state`
- Root cause:
  - capture call could fire before camera became active.
- Fix:
  - added queued capture flow and activation wait path.
- Result:
  - stopped-state capture issue resolved.

#### 4. `Cannot Open The Output Location For Writing`
- Symptom:
  - photo save failed
  - video recording failed with output-location write error.
- Root cause:
  - fragile output folder handling and backend acceptance of non-writable / malformed paths.
- Fix sequence:
  - normalized output path handling in QML
  - added fallback output directory logic
  - routed video output as proper `file:///` URL
  - added `AppController::ensureCaptureOutputDir(...)`
  - verified writable directory with on-disk probe file before use
- Result:
  - user reported capture finally passed.

#### 5. Startup Crash Before Loading
- Symptom:
  - application crashed during startup after adding `My Profile` tab.
- Root cause:
  - `MyProfileView.qml` was referenced from `ShellView.qml` but missing from `resources.qrc`, so QML load failed at startup.
- Fix:
  - added `ui/qml/views/MyProfileView.qml` to `cpp-app/resources.qrc`
  - rebuilt release.
- Result:
  - startup crash resolved.

#### 6. `Qt6Test.dll Was Not Found`
- Symptom:
  - regression tests would not run under `ctest` because the Qt test runtime DLL was not on `PATH`.
- Root cause:
  - CTest execution environment did not inherit the Qt runtime path automatically.
- Fix:
  - updated `CMakeLists.txt` to prepend Qt runtime directory to `PATH` for the `regression_tests` test on Windows.
- Result:
  - `ctest --output-on-failure` ran successfully.

#### 7. Admin Selected User Showed No Files
- Symptom:
  - selecting a user in Admin showed an empty file pane even when files existed.
- First attempted fix:
  - filtered the global `listAllFiles()` result in QML using `selectedUserId`.
- Why that was insufficient:
  - the admin user row had two different selection concepts (`selectedUserIds` vs `selectedUserId`), leading to UI ambiguity.
- Final fix sequence:
  - made row tap and checkbox update the active `selectedUserId`
  - replaced QML-side filtering with a dedicated backend query:
    - `FileMediaService::listFilesForUser(...)`
    - `AppController::listAdminFilesForUser(...)`
  - updated `AdminView.qml` to load the selected user’s file list directly from backend.
- Result:
  - final user confirmation: `okay now it. working...`

### Regression Testing Added This Session

#### Test Harness
- Added CTest-based regression target:
  - `regression_tests`
- Wired into `cpp-app/CMakeLists.txt`
- Test runtime fixed for Windows Qt deployment path.

#### Coverage Added
- Schema migration includes optional user columns.
- User profile create/update round-trip.
- Settings round-trip.
- File upload/move round-trip.
- Admin cross-user move round-trip.
- Admin delete rejects outside-managed-storage path.
- Camera output directory resolution returns writable directory.
- Startup QML smoke load of bundled main UI/resources.

Files touched:
- `cpp-app/CMakeLists.txt`
- `cpp-app/tests/RegressionTests.cpp`

#### Test Result
- Final `ctest --output-on-failure` passed.

### Files Touched During This Session
- `cpp-app/CMakeLists.txt`
- `cpp-app/resources.qrc`
- `cpp-app/tests/RegressionTests.cpp`
- `cpp-app/src/app/AppController.h`
- `cpp-app/src/app/AppController.cpp`
- `cpp-app/src/data/DatabaseManager.cpp`
- `cpp-app/src/data/UserRepository.h`
- `cpp-app/src/data/UserRepository.cpp`
- `cpp-app/src/services/FileMediaService.h`
- `cpp-app/src/services/FileMediaService.cpp`
- `cpp-app/ui/qml/views/AdminView.qml`
- `cpp-app/ui/qml/views/CameraView.qml`
- `cpp-app/ui/qml/views/MyProfileView.qml`
- `cpp-app/ui/qml/views/ShellView.qml`
- `cpp-app/ui/qml/views/WardrobeView.qml`

### Final Working State At End Of Session
- Camera tab is split left/right, resizable, and persists pane ratio.
- Camera capture and video recording save correctly to validated writable output folders.
- Camera media can target selected categories and participate in drag/drop moves.
- Manual file-path upload boxes are removed from camera/wardrobe flows.
- Admin supports thumbnail review and direct open actions.
- Optional user profile data is stored, editable, and visible in both header and `My Profile` tab.
- Regression suite exists and passes.
- Admin file pane now shows files for the currently selected user rather than all files globally.

### Recommended Next Start Point
1. Add a dedicated change-password section to `My Profile` for normal users.
2. Add lightweight success/error toast notifications for capture, move, delete, and profile-save actions.
3. Expand regression coverage for session/login flow and `My Profile` persistence from controller level.
