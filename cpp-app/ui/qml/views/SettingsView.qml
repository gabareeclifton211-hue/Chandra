import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    function normalizeLabel(value, fallbackValue) {
        const t = String(value === undefined || value === null ? "" : value).trim()
        if (t.length === 0)
            return fallbackValue
        return t.length > 24 ? t.slice(0, 24) : t
    }

    function resetCameraDefaults() {
        cameraOutputDirField.text = "C:/Users/Public/Pictures"
        cameraCountdownBox.value = 0
        cameraQualityBox.currentIndex = cameraQualityBox.find("Normal")
        cameraVideoExtBox.currentIndex = cameraVideoExtBox.find(".mp4")
    }

    function loadSettings() {
        const s = appController.getSettings()
        homeUrlField.text = s.importHomeUrl ? s.importHomeUrl : "https://duckduckgo.com/"
        const idx = categoryBox.find(s.importDefaultCategory ? s.importDefaultCategory : "panties")
        categoryBox.currentIndex = idx >= 0 ? idx : 0
        const searchIdx = searchEngineBox.find(s.importSearchEngine ? s.importSearchEngine : "duckduckgo")
        searchEngineBox.currentIndex = searchIdx >= 0 ? searchIdx : 0

        cameraOutputDirField.text = s.cameraOutputDir ? s.cameraOutputDir : "C:/Users/Public/Pictures"
        const cd = s.cameraCountdown ? Number(s.cameraCountdown) : 0
        cameraCountdownBox.value = Math.max(0, Math.min(10, isNaN(cd) ? 0 : cd))

        const quality = s.cameraQuality ? s.cameraQuality : "Normal"
        const qIdx = cameraQualityBox.find(quality)
        cameraQualityBox.currentIndex = qIdx >= 0 ? qIdx : 2

        const ext = s.cameraVideoExtension ? s.cameraVideoExtension : ".mp4"
        const extIdx = cameraVideoExtBox.find(ext)
        cameraVideoExtBox.currentIndex = extIdx >= 0 ? extIdx : 0

        customTab1EnabledBox.checked = String(s.customTab1Enabled ? s.customTab1Enabled : "false").toLowerCase() === "true"
        customTab2EnabledBox.checked = String(s.customTab2Enabled ? s.customTab2Enabled : "false").toLowerCase() === "true"
        customTab1LabelField.text = normalizeLabel(s.customTab1Label, "Custom 1")
        customTab2LabelField.text = normalizeLabel(s.customTab2Label, "Custom 2")
    }

    function saveSettings() {
        const okA = appController.setSetting("importHomeUrl", homeUrlField.text.trim())
        const okB = appController.setSetting("importDefaultCategory", categoryBox.currentText)
        const okC = appController.setSetting("importSearchEngine", searchEngineBox.currentText)
        const okD = appController.setSetting("cameraOutputDir", cameraOutputDirField.text.trim())
        const okE = appController.setSetting("cameraCountdown", String(cameraCountdownBox.value))
        const okF = appController.setSetting("cameraQuality", cameraQualityBox.currentText)
        const okG = appController.setSetting("cameraVideoExtension", cameraVideoExtBox.currentText)
        const okH = appController.setSetting("customTab1Enabled", customTab1EnabledBox.checked ? "true" : "false")
        const okI = appController.setSetting("customTab2Enabled", customTab2EnabledBox.checked ? "true" : "false")
        const okJ = appController.setSetting("customTab1Label", normalizeLabel(customTab1LabelField.text, "Custom 1"))
        const okK = appController.setSetting("customTab2Label", normalizeLabel(customTab2LabelField.text, "Custom 2"))
        statusLabel.text = (okA && okB && okC && okD && okE && okF && okG && okH && okI && okJ && okK)
            ? "Settings saved."
            : "Failed to save one or more settings."
    }

    Component.onCompleted: loadSettings()
    onVisibleChanged: {
        if (visible) {
            loadSettings()
            statusLabel.text = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Label {
            text: "Settings"
            font.pixelSize: 20
            font.bold: true
        }

        Label {
            text: "Import Home URL"
            color: "#505860"
        }

        TextField {
            id: homeUrlField
            Layout.fillWidth: true
            placeholderText: "https://duckduckgo.com/"
            selectByMouse: true
        }

        Label {
            text: "Default Import Category"
            color: "#505860"
        }

        ComboBox {
            id: categoryBox
            Layout.preferredWidth: 260
            model: ["panties", "bras", "what-i-wore-today", "accessories", "makeup", "custom-1", "custom-2", "camera"]
        }

        Label {
            text: "Search Engine"
            color: "#505860"
        }

        ComboBox {
            id: searchEngineBox
            Layout.preferredWidth: 260
            model: ["duckduckgo", "google", "bing"]
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#d7dde3"
        }

        Label {
            text: "Camera Output Folder"
            color: "#505860"
        }

        TextField {
            id: cameraOutputDirField
            Layout.fillWidth: true
            placeholderText: "C:/Users/Public/Pictures"
            selectByMouse: true
        }

        Label {
            text: "Camera Countdown (seconds)"
            color: "#505860"
        }

        SpinBox {
            id: cameraCountdownBox
            from: 0
            to: 10
            value: 0
            editable: true
            Layout.preferredWidth: 120
        }

        Label {
            text: "Camera Video Quality"
            color: "#505860"
        }

        ComboBox {
            id: cameraQualityBox
            Layout.preferredWidth: 260
            model: ["VeryLow", "Low", "Normal", "High", "VeryHigh"]
            currentIndex: 2
        }

        Label {
            text: "Camera Video Extension"
            color: "#505860"
        }

        ComboBox {
            id: cameraVideoExtBox
            Layout.preferredWidth: 260
            model: [".mp4", ".webm", ".mov"]
            currentIndex: 0
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#d7dde3"
        }

        Label {
            text: "Custom Tabs"
            font.bold: true
            color: "#394049"
        }

        CheckBox {
            id: customTab1EnabledBox
            text: "Enable Custom Tab 1"
        }

        TextField {
            id: customTab1LabelField
            Layout.fillWidth: true
            placeholderText: "Custom 1"
            enabled: customTab1EnabledBox.checked
            selectByMouse: true
        }

        CheckBox {
            id: customTab2EnabledBox
            text: "Enable Custom Tab 2"
        }

        TextField {
            id: customTab2LabelField
            Layout.fillWidth: true
            placeholderText: "Custom 2"
            enabled: customTab2EnabledBox.checked
            selectByMouse: true
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: "Save"
                onClicked: saveSettings()
            }

            Button {
                text: "Reload"
                onClicked: loadSettings()
            }

            Button {
                text: "Reset Camera Defaults"
                onClicked: {
                    resetCameraDefaults()
                    statusLabel.text = "Camera defaults restored in form. Click Save to persist."
                }
            }

            Item { Layout.fillWidth: true }

            Label {
                id: statusLabel
                color: "#3b6f3f"
            }
        }

        Label {
            visible: appController.lastError.length > 0
            text: appController.lastError
            color: "#9a1f1f"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        Item { Layout.fillHeight: true }
    }
}
