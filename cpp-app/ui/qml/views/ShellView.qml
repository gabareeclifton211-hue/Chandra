import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int wardrobeRefreshToken: 0
    property bool manualDragActive: false
    property string manualDragFilename: ""
    property string manualDragFromCategory: ""
    property string manualDragHoverCategory: ""
    property point manualDragPosition: Qt.point(0, 0)
    property string runningClockText: ""
    property bool customTab1Enabled: false
    property bool customTab2Enabled: false
    property string customTab1Label: "Custom 1"
    property string customTab2Label: "Custom 2"
    property var categoryCounts: ({})

    function showToast(message) {
        toastLabel.text = message
        toastBar.opacity = 1
        toastTimer.restart()
    }

    function parseBoolSetting(value, fallbackValue) {
        if (value === undefined || value === null)
            return fallbackValue
        const s = String(value).trim().toLowerCase()
        if (s === "true" || s === "1" || s === "yes" || s === "on")
            return true
        if (s === "false" || s === "0" || s === "no" || s === "off")
            return false
        return fallbackValue
    }

    function sanitizeLabel(value, fallbackValue) {
        const t = String(value === undefined || value === null ? "" : value).trim()
        if (t.length === 0)
            return fallbackValue
        return t.length > 24 ? t.slice(0, 24) : t
    }

    function loadCustomTabsFromSettings() {
        const s = appController.getSettings()
        customTab1Enabled = parseBoolSetting(s.customTab1Enabled, false)
        customTab2Enabled = parseBoolSetting(s.customTab2Enabled, false)
        customTab1Label = sanitizeLabel(s.customTab1Label, "Custom 1")
        customTab2Label = sanitizeLabel(s.customTab2Label, "Custom 2")
    }

    function refreshCategoryCounts() {
        const cats = ["panties", "bras", "what-i-wore-today", "accessories", "makeup", "custom-1", "custom-2"]
        const counts = {}
        for (let i = 0; i < cats.length; ++i) {
            const files = appController.listFiles(cats[i])
            counts[cats[i]] = files ? files.length : 0
        }
        categoryCounts = counts
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

    function categoryAt(positionInRoot) {
        const targets = [
            pantiesTab,
            brasTab,
            wiwtTab,
            accessoriesTab,
            makeupTab,
            custom1Tab,
            custom2Tab,
            cameraTab
        ]

        for (let i = 0; i < targets.length; ++i) {
            const item = targets[i]
            if (!item || !item.visible)
                continue

            const local = item.mapFromItem(root, positionInRoot.x, positionInRoot.y)
            if (local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height)
                return item.dropCategoryId
        }

        return ""
    }

    function beginWardrobeDrag(filename, fromCategory, positionInRoot) {
        manualDragFilename = filename
        manualDragFromCategory = fromCategory
        manualDragPosition = positionInRoot
        manualDragHoverCategory = categoryAt(positionInRoot)
        manualDragActive = true
    }

    function updateWardrobeDrag(positionInRoot) {
        manualDragPosition = positionInRoot
        manualDragHoverCategory = categoryAt(positionInRoot)
    }

    function endWardrobeDrag(positionInRoot) {
        const targetCategory = categoryAt(positionInRoot)
        const filename = manualDragFilename
        const fromCategory = manualDragFromCategory

        manualDragActive = false
        manualDragFilename = ""
        manualDragFromCategory = ""
        manualDragHoverCategory = ""

        if (!targetCategory || !filename || !fromCategory || targetCategory === fromCategory)
            return

        if (appController.moveFile(fromCategory, targetCategory, filename))
            wardrobeRefreshToken = wardrobeRefreshToken + 1
    }

    function resolveDragValue(source, propertyName) {
        let current = source
        for (let i = 0; i < 6 && current; ++i) {
            const value = current[propertyName]
            if (value !== undefined && value !== null && String(value).length > 0)
                return String(value)
            current = current.parent
        }
        return ""
    }

    function updateRunningClock() {
        const now = new Date()
        let hour = now.getHours()
        const minute = now.getMinutes()
        const second = now.getSeconds()
        const suffix = hour >= 12 ? "PM" : "AM"

        hour = hour % 12
        if (hour === 0)
            hour = 12

        const mm = minute < 10 ? ("0" + minute) : String(minute)
        const ss = second < 10 ? ("0" + second) : String(second)
        runningClockText = String(hour) + ":" + mm + ":" + ss + " " + suffix
    }

    onWardrobeRefreshTokenChanged: refreshCategoryCounts()

    Component.onCompleted: {
        updateRunningClock()
        loadCustomTabsFromSettings()
        refreshCategoryCounts()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateRunningClock()
    }

    Rectangle {
        anchors.fill: parent
        color: "#f8f8f5"
    }

    Item {
        id: dragLayer
        anchors.fill: parent
        z: 1000

        Rectangle {
            visible: root.manualDragActive
            x: root.manualDragPosition.x + 12
            y: root.manualDragPosition.y + 12
            z: 1001
            radius: 8
            color: "#264653"
            border.color: "#8fb1db"
            opacity: 0.92
            width: dragPreviewLabel.implicitWidth + 18
            height: dragPreviewLabel.implicitHeight + 12

            Label {
                id: dragPreviewLabel
                anchors.centerIn: parent
                text: root.manualDragFilename.length > 0 ? root.manualDragFilename : "Move file"
                color: "#f4f1de"
                font.bold: true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        onVisibleChanged: {
            if (visible) {
                root.loadCustomTabsFromSettings()
                root.refreshCategoryCounts()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: "#264653"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14

                Label {
                    text: "Chandra Journey"
                    color: "#f4f1de"
                    font.pixelSize: 22
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 42
                    height: 42
                    radius: 21
                    color: "#3b5a68"
                    border.color: "#8fb1db"

                    Image {
                        id: headerProfileImage
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        source: root.localFileUrl(appController.profilePicture)
                        visible: status === Image.Ready || status === Image.Loading
                        asynchronous: true
                        cache: true
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: headerProfileImage.status !== Image.Ready && headerProfileImage.status !== Image.Loading
                        text: appController.username.length > 0 ? appController.username.charAt(0).toUpperCase() : "?"
                        color: "#f4f1de"
                        font.bold: true
                    }
                }

                Column {
                    spacing: 2

                    Label {
                        text: appController.pronouns.length > 0
                            ? (appController.username + " (" + appController.pronouns + ")")
                            : appController.username
                        color: "#f4f1de"
                        font.bold: true
                    }

                    Label {
                        text: [appController.role, appController.email, appController.phone]
                            .filter(function(v) { return v && v.length > 0 })
                            .join(" | ")
                        color: "#d9e3e8"
                        visible: text.length > 0
                        font.pixelSize: 12
                    }
                }

                Button {
                    text: "Logout"
                    onClicked: appController.logout()
                }
            }
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            onCurrentIndexChanged: root.loadCustomTabsFromSettings()

            TabButton {
                id: pantiesTab
                property string dropCategoryId: "panties"
                text: "Panties (" + (root.categoryCounts["panties"] || 0) + ")"
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: pantiesTab.text
                    color: root.manualDragHoverCategory === pantiesTab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: pantiesTab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === pantiesTab.dropCategoryId ? "#ffe08a" : (pantiesTab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === pantiesTab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === pantiesTab.dropCategoryId ? "#c97a00" : (pantiesTab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton {
                id: brasTab
                property string dropCategoryId: "bras"
                text: "Bras (" + (root.categoryCounts["bras"] || 0) + ")"
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: brasTab.text
                    color: root.manualDragHoverCategory === brasTab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: brasTab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === brasTab.dropCategoryId ? "#ffe08a" : (brasTab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === brasTab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === brasTab.dropCategoryId ? "#c97a00" : (brasTab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton {
                id: wiwtTab
                property string dropCategoryId: "what-i-wore-today"
                text: "What I Wore Today (" + (root.categoryCounts["what-i-wore-today"] || 0) + ")"
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: wiwtTab.text
                    color: root.manualDragHoverCategory === wiwtTab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: wiwtTab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === wiwtTab.dropCategoryId ? "#ffe08a" : (wiwtTab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === wiwtTab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === wiwtTab.dropCategoryId ? "#c97a00" : (wiwtTab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton {
                id: accessoriesTab
                property string dropCategoryId: "accessories"
                text: "Accessories (" + (root.categoryCounts["accessories"] || 0) + ")"
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: accessoriesTab.text
                    color: root.manualDragHoverCategory === accessoriesTab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: accessoriesTab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === accessoriesTab.dropCategoryId ? "#ffe08a" : (accessoriesTab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === accessoriesTab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === accessoriesTab.dropCategoryId ? "#c97a00" : (accessoriesTab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton {
                id: makeupTab
                property string dropCategoryId: "makeup"
                text: "Makeup (" + (root.categoryCounts["makeup"] || 0) + ")"
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: makeupTab.text
                    color: root.manualDragHoverCategory === makeupTab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: makeupTab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === makeupTab.dropCategoryId ? "#ffe08a" : (makeupTab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === makeupTab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === makeupTab.dropCategoryId ? "#c97a00" : (makeupTab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton {
                id: custom1Tab
                property string dropCategoryId: "custom-1"
                visible: root.customTab1Enabled
                text: root.customTab1Label
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: custom1Tab.text
                    color: root.manualDragHoverCategory === custom1Tab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: custom1Tab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === custom1Tab.dropCategoryId ? "#ffe08a" : (custom1Tab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === custom1Tab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === custom1Tab.dropCategoryId ? "#c97a00" : (custom1Tab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton {
                id: custom2Tab
                property string dropCategoryId: "custom-2"
                visible: root.customTab2Enabled
                text: root.customTab2Label
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: custom2Tab.text
                    color: root.manualDragHoverCategory === custom2Tab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: custom2Tab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === custom2Tab.dropCategoryId ? "#ffe08a" : (custom2Tab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === custom2Tab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === custom2Tab.dropCategoryId ? "#c97a00" : (custom2Tab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton { text: "Journal" }

            TabButton {
                id: cameraTab
                property string dropCategoryId: "camera"
                text: "Camera"
                font.bold: root.manualDragHoverCategory === dropCategoryId || checked
                contentItem: Text {
                    text: cameraTab.text
                    color: root.manualDragHoverCategory === cameraTab.dropCategoryId ? "#0b2239" : "#33414d"
                    font: cameraTab.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 8
                    color: root.manualDragHoverCategory === cameraTab.dropCategoryId ? "#ffe08a" : (cameraTab.checked ? "#dce7f2" : "#ffffff")
                    border.width: root.manualDragHoverCategory === cameraTab.dropCategoryId ? 3 : 1
                    border.color: root.manualDragHoverCategory === cameraTab.dropCategoryId ? "#c97a00" : (cameraTab.checked ? "#5f95c8" : "#bdc7d1")
                }
            }

            TabButton { text: "My Profile" }
            TabButton { text: "Import" }
            TabButton { text: "Settings" }
            TabButton { text: "Admin"; visible: appController.role === "sysop" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            WardrobeView { category: "panties"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            WardrobeView { category: "bras"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            WardrobeView { category: "what-i-wore-today"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            WardrobeView { category: "accessories"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            WardrobeView { category: "makeup"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            WardrobeView { category: "custom-1"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            WardrobeView { category: "custom-2"; refreshToken: root.wardrobeRefreshToken; dragLayer: dragLayer; dragHost: root; toastHost: root }
            JournalView { toastHost: root }
            CameraView { dragLayer: dragLayer; dragHost: root }
            MyProfileView { }
            ImportView { }
            SettingsView { }
            AdminView { }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#f4f4f1"
            border.color: "#d8d8d2"

            Label {
                anchors.centerIn: parent
                text: root.runningClockText
                color: "#000000"
                font.bold: true
                font.pixelSize: 16
            }
        }
    }

    // ── Toast / snackbar ──────────────────────────────────────────────
    Rectangle {
        id: toastBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 50
        width: toastLabel.implicitWidth + 40
        height: 38
        radius: 19
        color: "#264653"
        opacity: 0
        z: 2000

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Timer {
            id: toastTimer
            interval: 2000
            onTriggered: toastBar.opacity = 0
        }

        Label {
            id: toastLabel
            anchors.centerIn: parent
            color: "#f4f1de"
            font.pixelSize: 13
        }
    }
}
