cmake_minimum_required(VERSION 3.24)
project(ChandraJourneyCpp VERSION 1.0.0 LANGUAGES CXX)

include(CTest)

# ============================================================
# Configurable Application Metadata
# Override these when configuring to change app name/version
# ============================================================
if(NOT APP_NAME)
    set(APP_NAME "Chandra Journey")
endif()

if(NOT APP_DISPLAY_NAME)
    set(APP_DISPLAY_NAME "Chandra Journey (C++ Rebuild)")
endif()

if(NOT APP_VERSION)
    set(APP_VERSION "1.0.0")
endif()

if(NOT APP_PUBLISHER)
    set(APP_PUBLISHER "Chandra")
endif()

if(NOT APP_EXECUTABLE)
    set(APP_EXECUTABLE "chandra_journey")
endif()

if(NOT APP_INST_KEY)
    set(APP_INST_KEY "ChandraJourney")
endif()

if(NOT APP_UNINST_KEY)
    set(APP_UNINST_KEY "ChandraJourney")
endif()

if(NOT APP_DIST_DIR)
    set(APP_DIST_DIR "ChandraJourney")
endif()

# Generate AppConfig.h from template
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/AppConfig.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/generated/AppConfig.h"
)

# Generate NSIS installer script from template
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/platform/windows/chandra_journey.nsi.in"
    "${CMAKE_CURRENT_BINARY_DIR}/../platform/windows/chandra_journey.nsi"
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Sql Network Multimedia WebEngineQuick Test)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(${APP_EXECUTABLE}
    src/app/main.cpp
    src/app/AppController.cpp
    src/core/DataPaths.cpp
    src/core/Security.cpp
    src/data/DatabaseManager.cpp
    src/data/UserRepository.cpp
    src/services/FileMediaService.cpp
    src/services/JournalService.cpp
    src/services/SettingsService.cpp
    resources.qrc
)

target_include_directories(${APP_EXECUTABLE} PRIVATE src "${CMAKE_CURRENT_BINARY_DIR}/generated")

target_link_libraries(${APP_EXECUTABLE} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Network
    Qt6::Multimedia
    Qt6::WebEngineQuick
)

if(WIN32)
    set_target_properties(${APP_EXECUTABLE} PROPERTIES WIN32_EXECUTABLE ON)
endif()

install(TARGETS ${APP_EXECUTABLE}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)

if(BUILD_TESTING)
    add_executable(regression_tests
        tests/RegressionTests.cpp
        src/app/AppController.cpp
        src/core/DataPaths.cpp
        src/core/Security.cpp
        src/data/DatabaseManager.cpp
        src/data/UserRepository.cpp
        src/services/FileMediaService.cpp
        src/services/JournalService.cpp
        src/services/SettingsService.cpp
        resources.qrc
    )

    target_include_directories(regression_tests PRIVATE src "${CMAKE_CURRENT_BINARY_DIR}/generated")

    target_link_libraries(regression_tests PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Qml
        Qt6::Sql
        Qt6::Network
        Qt6::Multimedia
        Qt6::WebEngineQuick
        Qt6::Test
    )

    add_test(NAME regression_tests COMMAND regression_tests)

    if(WIN32)
        set_tests_properties(regression_tests PROPERTIES
            ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt6::Core>")
    endif()
endif()
