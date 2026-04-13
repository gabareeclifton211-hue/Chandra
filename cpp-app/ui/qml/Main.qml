import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "views"

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    visible: true
    title: "Chandra Journey (C++ Rebuild)"

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
