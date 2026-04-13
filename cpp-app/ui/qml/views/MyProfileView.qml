import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    function localFileUrl(path) {
        if (!path)
            return ""

        let p = String(path).trim()
        if (p.length === 0)
            return ""
        if (p.indexOf("file:") === 0)
            return p

        p = p.replace(/\\/g, "/")
        if (/^[a-zA-Z]:\//.test(p))
            return "file:///" + p
        if (p.indexOf("/") === 0)
            return "file://" + p
        return "file:///" + p
    }

    function loadProfile() {
        emailField.text = appController.email
        phoneField.text = appController.phone
        pronounsField.text = appController.pronouns
        profilePictureField.text = appController.profilePicture
        statusLabel.text = ""
        clearPasswordForm()
    }

    function saveProfile() {
        const ok = appController.updateMyProfile(
            emailField.text,
            phoneField.text,
            profilePictureField.text,
            pronounsField.text)
        statusLabel.text = ok ? "Profile saved." : "Failed to save profile."
    }

    function changePassword() {
        if (oldPasswordField.text.length === 0) {
            passwordStatusLabel.text = "Current password is required."
            passwordStatusLabel.color = "#9a1f1f"
            return
        }
        if (newPasswordField.text.length === 0) {
            passwordStatusLabel.text = "New password is required."
            passwordStatusLabel.color = "#9a1f1f"
            return
        }
        if (confirmPasswordField.text !== newPasswordField.text) {
            passwordStatusLabel.text = "New passwords do not match."
            passwordStatusLabel.color = "#9a1f1f"
            return
        }
        if (newPasswordField.text === oldPasswordField.text) {
            passwordStatusLabel.text = "New password must be different from current password."
            passwordStatusLabel.color = "#9a1f1f"
            return
        }

        const ok = appController.changeMyPassword(oldPasswordField.text, newPasswordField.text)
        if (ok) {
            oldPasswordField.text = ""
            newPasswordField.text = ""
            confirmPasswordField.text = ""
            passwordStatusLabel.text = "Password changed successfully."
            passwordStatusLabel.color = "#3b6f3f"
        } else {
            passwordStatusLabel.text = appController.lastError || "Failed to change password."
            passwordStatusLabel.color = "#9a1f1f"
        }
    }

    function clearPasswordForm() {
        oldPasswordField.text = ""
        newPasswordField.text = ""
        confirmPasswordField.text = ""
        passwordStatusLabel.text = ""
    }

    Component.onCompleted: loadProfile()
    onVisibleChanged: {
        if (visible)
            loadProfile()
    }

    FileDialog {
        id: profilePicturePicker
        title: "Select Profile Picture"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "Image Files (*.jpg *.jpeg *.png *.gif *.webp *.bmp *.heic *.tiff)",
            "All Files (*.*)"
        ]
        onAccepted: {
            if (selectedFile)
                profilePictureField.text = selectedFile.toString().replace("file:///", "")
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12

            Label {
                text: "My Profile"
                font.pixelSize: 20
                font.bold: true
            }

            Label {
                text: "Update your contact details, pronouns, and profile picture."
                color: "#59636d"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: 8
                color: "#f7f9fb"
                border.color: "#d6d9dd"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        width: 72
                        height: 72
                        radius: 36
                        color: "#e6edf2"
                        border.color: "#b8c7d3"

                        Image {
                            id: profilePreviewImage
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                            source: root.localFileUrl(profilePictureField.text)
                            visible: status === Image.Ready || status === Image.Loading
                            asynchronous: true
                            cache: true
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: profilePreviewImage.status !== Image.Ready && profilePreviewImage.status !== Image.Loading
                            text: appController.username.length > 0 ? appController.username.charAt(0).toUpperCase() : "?"
                            color: "#4a5c69"
                            font.bold: true
                            font.pixelSize: 24
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label {
                            text: appController.username
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Label {
                            text: appController.role
                            color: "#59636d"
                        }
                    }
                }
            }

            TextField {
                id: emailField
                Layout.fillWidth: true
                placeholderText: "Email"
                selectByMouse: true
            }

            TextField {
                id: phoneField
                Layout.fillWidth: true
                placeholderText: "Phone"
                selectByMouse: true
            }

            TextField {
                id: pronounsField
                Layout.fillWidth: true
                placeholderText: "Pronouns"
                selectByMouse: true
            }

            RowLayout {
                Layout.fillWidth: true

                TextField {
                    id: profilePictureField
                    Layout.fillWidth: true
                    placeholderText: "Profile picture path"
                    selectByMouse: true
                }

                Button {
                    text: "Choose Picture..."
                    onClicked: profilePicturePicker.open()
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Button {
                    text: "Save Profile"
                    onClicked: saveProfile()
                }

                Button {
                    text: "Reload"
                    onClicked: loadProfile()
                }

                Item { Layout.fillWidth: true }

                Label {
                    id: statusLabel
                    color: "#3b6f3f"
                }
            }



            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 12
                height: 1
                color: "#d6d9dd"
            }

            Label {
                text: "Change Password"
                font.pixelSize: 16
                font.bold: true
                Layout.topMargin: 12
            }

            TextField {
                id: oldPasswordField
                Layout.fillWidth: true
                placeholderText: "Current password"
                echoMode: TextField.Password
                selectByMouse: true
            }

            TextField {
                id: newPasswordField
                Layout.fillWidth: true
                placeholderText: "New password"
                echoMode: TextField.Password
                selectByMouse: true
            }

            TextField {
                id: confirmPasswordField
                Layout.fillWidth: true
                placeholderText: "Confirm new password"
                echoMode: TextField.Password
                selectByMouse: true
            }

            RowLayout {
                Layout.fillWidth: true

                Button {
                    text: "Change Password"
                    onClicked: changePassword()
                }

                Button {
                    text: "Clear"
                    onClicked: clearPasswordForm()
                }

                Item { Layout.fillWidth: true }

                Label {
                    id: passwordStatusLabel
                    color: "#3b6f3f"
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Label {
                visible: appController.lastError.length > 0
                text: appController.lastError
                color: "#9a1f1f"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }
}