import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "views"

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    visible: true
    // ============================================================
    // Change appTitle to customize the window title
    // This should match APP_DISPLAY_NAME in CMakeLists.txt
    // ============================================================
    readonly property string appTitle: "Chandra Journey (C++ Rebuild)"
    title: root.appTitle

    StackLayout {
        anchors.fill: parent
        currentIndex: appController.authenticated ? 1 : 0

        LoginView {
            id: loginView
        }

        ShellView {
            id: shellView
        }
    }
}
