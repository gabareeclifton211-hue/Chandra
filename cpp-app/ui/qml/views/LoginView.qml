import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f6eee6" }
            GradientStop { position: 1.0; color: "#e6edf5" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 420)
        spacing: 14

        Label {
            text: "Chandra Journey"
            font.pixelSize: 34
            font.bold: true
            color: "#2f2a24"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Sign in to continue"
            font.pixelSize: 16
            color: "#4f4a44"
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: usernameField
            placeholderText: "Username"
            selectByMouse: true
            Layout.fillWidth: true
        }

        TextField {
            id: passwordField
            placeholderText: "Password"
            echoMode: TextInput.Password
            selectByMouse: true
            Layout.fillWidth: true
            onAccepted: loginButton.clicked()
        }

        Label {
            id: errorLabel
            visible: text.length > 0
            color: "#9a1f1f"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Button {
            id: loginButton
            text: "Login"
            Layout.fillWidth: true
            onClicked: {
                errorLabel.text = ""
                const ok = appController.login(usernameField.text, passwordField.text)
                if (!ok && errorLabel.text.length === 0) {
                    errorLabel.text = "Login failed."
                }
            }
        }

        Label {
            text: "Default sysop login: chandra / chandra123"
            color: "#5f5a54"
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
        }
    }

    Connections {
        target: appController
        function onLoginFailed(reason) {
            errorLabel.text = reason
        }
    }
}
