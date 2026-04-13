cmake_minimum_required(VERSION 3.24)
project(ChandraJourneyCpp VERSION 1.0.0 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Sql Network Multimedia WebEngineQuick Test)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(chandra_journey
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

target_include_directories(chandra_journey PRIVATE src)

target_link_libraries(chandra_journey PRIVATE
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
    set_target_properties(chandra_journey PROPERTIES WIN32_EXECUTABLE ON)
endif()

install(TARGETS chandra_journey
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

    target_include_directories(regression_tests PRIVATE src)

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
