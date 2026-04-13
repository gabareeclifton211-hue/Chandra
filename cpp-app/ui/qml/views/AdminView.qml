import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    property var usersModel: []
    property var filesModel: []
    property var visibleFilesModel: []
    property string selectedUserId: ""
    property var selectedUserIds: []
    property var selectedFileKeys: []
    property var categoryOptions: ["panties", "bras", "what-i-wore-today", "accessories", "makeup"]
    property var activityLogModel: []

    function inferType(filename) {
        const lower = (filename || "").toLowerCase()
        if (lower.match(/\.(jpg|jpeg|png|gif|webp|bmp|heic|tiff)$/)) return "Image"
        if (lower.match(/\.(mp4|webm|mov|avi|mkv|mpeg|mpg)$/)) return "Video"
        if (lower.match(/\.(mp3|wav|ogg|m4a|flac|aac)$/)) return "Audio"
        return "File"
    }

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

    function userIsSelected(userId) {
        return selectedUserIds.indexOf(userId) >= 0
    }

    function toggleUserSelection(userId) {
        const idx = selectedUserIds.indexOf(userId)
        if (idx >= 0) selectedUserIds.splice(idx, 1)
        else selectedUserIds.push(userId)
        selectedUserIds = selectedUserIds.slice(0)

        if (selectedUserId !== userId) {
            selectedUserId = userId
        } else if (idx >= 0 && selectedUserIds.length === 0) {
            selectedUserId = ""
        }
    }

    function mediaKey(item) {
        return item.userId + "|" + item.category + "|" + item.filename
    }

    function mediaIsSelected(item) {
        return selectedFileKeys.indexOf(mediaKey(item)) >= 0
    }

    function toggleMediaSelection(item) {
        const key = mediaKey(item)
        const idx = selectedFileKeys.indexOf(key)
        if (idx >= 0) selectedFileKeys.splice(idx, 1)
        else selectedFileKeys.push(key)
        selectedFileKeys = selectedFileKeys.slice(0)
    }

    function refreshActivityLog() {
        activityLogModel = appController.getActivityLog()
    }

    function refreshAll() {
        usersModel = appController.listUsers()
        filesModel = appController.listAllFiles()
        selectedUserIds = []
        selectedFileKeys = []
        applyFileFilter()
        refreshActivityLog()
    }

    function selectedUserItem() {
        for (let i = 0; i < usersModel.length; ++i) {
            if (usersModel[i].id === selectedUserId)
                return usersModel[i]
        }
        return null
    }

    function applyFileFilter() {
        if (!selectedUserId || selectedUserId.length === 0) {
            visibleFilesModel = []
            selectedFileKeys = []
            return
        }

        visibleFilesModel = appController.listAdminFilesForUser(selectedUserId)

        selectedFileKeys = selectedFileKeys.filter(function(key) {
            return visibleFilesModel.some(function(item) {
                return mediaKey(item) === key
            })
        })
    }

    function applySelectedUserFields() {
        const user = selectedUserItem()
        if (!user)
            return

        usernameField.text = user.username || ""
        roleBox.currentIndex = Math.max(0, roleBox.find(user.role || "user"))
        emailField.text = user.email || ""
        phoneField.text = user.phone || ""
        pronounsField.text = user.pronouns || ""
        profilePictureField.text = user.profilePicture || ""
    }

    function clearUserEditor(clearUsername) {
        if (clearUsername)
            usernameField.text = ""
        passwordField.text = ""
        emailField.text = ""
        phoneField.text = ""
        pronounsField.text = ""
        profilePictureField.text = ""
        roleBox.currentIndex = 0
    }

    Component.onCompleted: refreshAll()
    onVisibleChanged: {
        if (visible) {
            refreshAll()
        }
    }
    onSelectedUserIdChanged: {
        applySelectedUserFields()
        applyFileFilter()
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Admin"
                font.pixelSize: 20
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Refresh"
                onClicked: refreshAll()
            }
        }

        Label {
            visible: appController.lastError.length > 0
            text: appController.lastError
            color: "#9a1f1f"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 430
                Layout.fillHeight: true
                radius: 8
                color: "#ffffff"
                border.color: "#d6d9dd"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label {
                        text: "Users"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            id: usernameField
                            Layout.fillWidth: true
                            placeholderText: "Username"
                            selectByMouse: true
                        }

                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            placeholderText: "Password"
                            echoMode: TextInput.Password
                            selectByMouse: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            id: emailField
                            Layout.fillWidth: true
                            placeholderText: "Email (optional)"
                            selectByMouse: true
                        }

                        TextField {
                            id: phoneField
                            Layout.fillWidth: true
                            placeholderText: "Phone (optional)"
                            selectByMouse: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            id: pronounsField
                            Layout.preferredWidth: 140
                            placeholderText: "Pronouns"
                            selectByMouse: true
                        }

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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        radius: 6
                        color: "#f7f9fb"
                        border.color: "#d8dde3"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Rectangle {
                                width: 56
                                height: 56
                                radius: 6
                                color: "#f3f5f7"
                                border.color: "#d3d9df"

                                Image {
                                    id: profilePreviewImage
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.PreserveAspectFit
                                    source: root.localFileUrl(profilePictureField.text)
                                    visible: status === Image.Ready || status === Image.Loading
                                    asynchronous: true
                                    cache: true
                                }

                                Label {
                                    anchors.centerIn: parent
                                    visible: profilePreviewImage.status !== Image.Ready && profilePreviewImage.status !== Image.Loading
                                    text: "Profile"
                                    color: "#687684"
                                    font.pixelSize: 11
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: selectedUserId.length > 0
                                    ? "Optional user details for the selected account."
                                    : "Optional fields will be stored when you create the user."
                                color: "#5f6973"
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        ComboBox {
                            id: roleBox
                            model: ["user", "sysop"]
                            currentIndex: 0
                        }

                        Button {
                            text: "Create User"
                            onClicked: {
                                if (appController.createUser(
                                            usernameField.text,
                                            passwordField.text,
                                            roleBox.currentText,
                                            emailField.text,
                                            phoneField.text,
                                            profilePictureField.text,
                                            pronounsField.text)) {
                                    clearUserEditor(true)
                                    refreshAll()
                                }
                            }
                        }

                        Button {
                            text: "Save Profile"
                            enabled: selectedUserId.length > 0
                            onClicked: {
                                if (selectedUserId.length === 0)
                                    return
                                if (appController.updateUserProfile(
                                            selectedUserId,
                                            emailField.text,
                                            phoneField.text,
                                            profilePictureField.text,
                                            pronounsField.text)) {
                                    refreshAll()
                                }
                            }
                        }

                        Button {
                            text: "Reset Password"
                            enabled: selectedUserId.length > 0
                            onClicked: {
                                if (selectedUserId.length === 0)
                                    return
                                if (appController.resetUserPassword(selectedUserId, passwordField.text)) {
                                    passwordField.text = ""
                                    refreshAll()
                                }
                            }
                        }

                        Button {
                            text: "Delete User"
                            enabled: selectedUserId.length > 0
                            onClicked: {
                                if (selectedUserId.length === 0)
                                    return
                                if (appController.deleteUser(selectedUserId)) {
                                    selectedUserId = ""
                                    refreshAll()
                                }
                            }
                        }

                        Button {
                            text: "Delete Selected"
                            enabled: selectedUserIds.length > 0
                            onClicked: {
                                if (appController.deleteUsers(selectedUserIds)) {
                                    selectedUserId = ""
                                    refreshAll()
                                }
                            }
                        }
                    }

                    ListView {
                        id: usersList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: usersModel
                        spacing: 6

                        delegate: Rectangle {
                            required property var modelData
                            width: usersList.width
                            height: 92
                            radius: 6
                            color: (modelData.id === selectedUserId || userIsSelected(modelData.id)) ? "#eef5ff" : "#f9fafb"
                            border.color: modelData.id === selectedUserId ? "#8fb1db" : "#d8dde3"

                            TapHandler {
                                onTapped: {
                                    selectedUserId = modelData.id
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                CheckBox {
                                    checked: userIsSelected(modelData.id)
                                    onClicked: toggleUserSelection(modelData.id)
                                }

                                Rectangle {
                                    width: 56
                                    height: 56
                                    radius: 6
                                    color: "#f3f5f7"
                                    border.color: "#d3d9df"

                                    Image {
                                        id: userPreviewImage
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        fillMode: Image.PreserveAspectFit
                                        source: root.localFileUrl(modelData.profilePicture)
                                        visible: status === Image.Ready || status === Image.Loading
                                        asynchronous: true
                                        cache: true
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        visible: userPreviewImage.status !== Image.Ready && userPreviewImage.status !== Image.Loading
                                        text: "User"
                                        color: "#68727d"
                                        font.pixelSize: 11
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: modelData.username + " (" + modelData.role + ")"
                                        font.bold: true
                                    }
                                    Label {
                                        text: modelData.pronouns && modelData.pronouns.length > 0
                                            ? (modelData.pronouns + " | " + modelData.createdAt)
                                            : modelData.createdAt
                                        color: "#68727d"
                                    }
                                    Label {
                                        visible: (modelData.email && modelData.email.length > 0)
                                                 || (modelData.phone && modelData.phone.length > 0)
                                        text: [modelData.email || "", modelData.phone || ""]
                                                .filter(function(v) { return v.length > 0 })
                                                .join(" | ")
                                        color: "#68727d"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: "#ffffff"
                border.color: "#d6d9dd"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label {
                        text: selectedUserId.length > 0 && selectedUserItem()
                            ? (selectedUserItem().username + " Media Items")
                            : "Select a User to View Files"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "Move to:"
                            color: "#5f6973"
                        }

                        ComboBox {
                            id: moveTargetUserBox
                            Layout.preferredWidth: 170
                            model: usersModel
                            textRole: "username"
                            valueRole: "id"
                        }

                        ComboBox {
                            id: moveTargetCategoryBox
                            Layout.preferredWidth: 190
                            model: categoryOptions
                            editable: true
                        }

                        Button {
                            text: "Move Selected"
                            enabled: selectedUserId.length > 0 &&
                                     selectedFileKeys.length > 0 &&
                                     moveTargetUserBox.currentIndex >= 0 &&
                                     moveTargetCategoryBox.editText.trim().length > 0
                            onClicked: {
                                const selected = visibleFilesModel.filter(function(item) {
                                    return selectedFileKeys.indexOf(mediaKey(item)) >= 0
                                })
                                if (selected.length === 0)
                                    return
                                if (appController.moveAdminFiles(
                                            selected,
                                            String(moveTargetUserBox.currentValue),
                                            moveTargetCategoryBox.editText.trim())) {
                                    refreshAll()
                                }
                            }
                        }

                        Label {
                            text: selectedFileKeys.length + " selected"
                            color: "#5f6973"
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Delete Selected"
                            enabled: selectedUserId.length > 0 && selectedFileKeys.length > 0
                            onClicked: {
                                const selected = visibleFilesModel.filter(function(item) {
                                    return selectedFileKeys.indexOf(mediaKey(item)) >= 0
                                })
                                if (selected.length === 0)
                                    return
                                if (appController.deleteAdminFiles(selected)) {
                                    refreshAll()
                                }
                            }
                        }
                    }

                    ListView {
                        id: filesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: visibleFilesModel
                        spacing: 6

                        delegate: Rectangle {
                            required property var modelData
                            width: filesList.width
                            height: 92
                            radius: 6
                            color: mediaIsSelected(modelData) ? "#eef5ff" : "#f9fafb"
                            border.color: mediaIsSelected(modelData) ? "#8fb1db" : "#d8dde3"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                CheckBox {
                                    checked: mediaIsSelected(modelData)
                                    onClicked: toggleMediaSelection(modelData)
                                }

                                Rectangle {
                                    width: 64
                                    height: 64
                                    radius: 6
                                    color: "#f3f5f7"
                                    border.color: "#d3d9df"

                                    Image {
                                        id: previewImage
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        fillMode: Image.PreserveAspectFit
                                        source: root.localFileUrl(modelData.filePath)
                                        visible: status === Image.Ready || status === Image.Loading
                                        asynchronous: true
                                        cache: true
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        visible: previewImage.status !== Image.Ready && previewImage.status !== Image.Loading
                                        text: root.inferType(modelData.filename)
                                        color: "#687684"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appController.openFile(modelData.filePath)
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: modelData.filename + "  [" + modelData.category + "]"
                                        font.bold: true
                                    }
                                    Label {
                                        text: modelData.filePath
                                        color: "#5f6973"
                                        elide: Label.ElideRight
                                        width: parent.width
                                    }
                                    Label {
                                        text: "UserId: " + modelData.userId
                                        color: "#5f6973"
                                        width: parent.width
                                    }
                                }

                                Button {
                                    text: "Open"
                                    onClicked: appController.openFile(modelData.filePath)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 240
            radius: 8
            color: "#ffffff"
            border.color: "#d6d9dd"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Activity Log"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Label {
                        text: activityLogModel.length + " entries"
                        color: "#5f6973"
                        Layout.leftMargin: 8
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Refresh"
                        onClicked: refreshActivityLog()
                    }

                    Button {
                        text: "Clear Log"
                        onClicked: {
                            if (appController.clearActivityLog()) {
                                refreshActivityLog()
                            }
                        }
                    }
                }

                ListView {
                    id: activityLogList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: activityLogModel
                    spacing: 2

                    delegate: Rectangle {
                        required property var modelData
                        width: activityLogList.width
                        height: 28
                        radius: 3
                        color: modelData.isWebSearch ? "#ffdddd" : "#f9fafb"
                        border.color: modelData.isWebSearch ? "#cc4444" : "#e0e3e7"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            spacing: 8

                            Label {
                                text: modelData.ts ? modelData.ts.replace("T", " ").replace("Z", "") : ""
                                color: modelData.isWebSearch ? "#880000" : "#607080"
                                font.pixelSize: 11
                                Layout.preferredWidth: 160
                                elide: Label.ElideRight
                            }
                            Label {
                                text: modelData.username || ""
                                font.bold: modelData.isWebSearch
                                font.pixelSize: 11
                                color: modelData.isWebSearch ? "#aa0000" : "#3f4f5f"
                                Layout.preferredWidth: 90
                                elide: Label.ElideRight
                            }
                            Label {
                                text: modelData.action || ""
                                font.pixelSize: 11
                                color: modelData.isWebSearch ? "#cc2200" : "#4f5f70"
                                Layout.preferredWidth: 150
                                elide: Label.ElideRight
                            }
                            Label {
                                text: modelData.details || ""
                                font.pixelSize: 11
                                color: modelData.isWebSearch ? "#880000" : "#3f4f5f"
                                Layout.fillWidth: true
                                elide: Label.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}

