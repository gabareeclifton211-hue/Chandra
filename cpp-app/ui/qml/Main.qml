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
    // Change APP_TITLE to customize the window title
    // This should match APP_DISPLAY_NAME in CMakeLists.txt
    // ============================================================
    readonly property string APP_TITLE: "Chandra Journey (C++ Rebuild)"
    title: root.APP_TITLE

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
