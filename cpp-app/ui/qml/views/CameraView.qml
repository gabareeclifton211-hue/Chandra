import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtCore
import QtMultimedia

Item {
    id: root
    property Item dragLayer: null
    property Item dragHost: null
    property bool dragInProgress: false
    property var filesModel: []
    property var selectedNames: []
    property var allCategories: ["panties", "bras", "what-i-wore-today", "accessories", "makeup", "camera"]
    property string selectedCategory: "camera"
    property string captureStatus: ""
    property int captureCountdown: 0
    property int captureRemaining: 0
    property string selectedVideoExtension: ".mp4"
    property int selectedRecorderQuality: MediaRecorder.NormalQuality
    property real cameraSplitRatio: 0.66
    property bool loadingCameraSettings: false
    property bool photoRetryUsingDefaultPath: false
    property bool pendingPhotoCapture: false
    property bool videoRetryUsingDefaultPath: false

    readonly property bool hasCameraDevice: mediaDevices.videoInputs.length > 0

    function inferType(filename) {
        const lower = (filename || "").toLowerCase()
        if (lower.match(/\.(jpg|jpeg|png|gif|webp|bmp|heic|tiff)$/)) return "Images"
        if (lower.match(/\.(mp4|webm|mov|avi|mkv|mpeg|mpg)$/)) return "Videos"
        if (lower.match(/\.(mp3|wav|ogg|m4a|flac|aac)$/)) return "Audio"
        return "Other"
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

    function qualityNameFromIndex(index) {
        if (index === 0) return "VeryLow"
        if (index === 1) return "Low"
        if (index === 2) return "Normal"
        if (index === 3) return "High"
        return "VeryHigh"
    }

    function qualityIndexFromName(name) {
        if (name === "VeryLow") return 0
        if (name === "Low") return 1
        if (name === "Normal") return 2
        if (name === "High") return 3
        if (name === "VeryHigh") return 4
        return 2
    }

    function applyQualityFromIndex(index) {
        if (index === 0) root.selectedRecorderQuality = MediaRecorder.VeryLowQuality
        else if (index === 1) root.selectedRecorderQuality = MediaRecorder.LowQuality
        else if (index === 2) root.selectedRecorderQuality = MediaRecorder.NormalQuality
        else if (index === 3) root.selectedRecorderQuality = MediaRecorder.HighQuality
        else root.selectedRecorderQuality = MediaRecorder.VeryHighQuality
    }

    function clampedSplitRatio(value) {
        const n = Number(value)
        if (isNaN(n))
            return 0.66
        return Math.max(0.45, Math.min(0.82, n))
    }

    function resolvedWritableOutputDir(preferredDir) {
        const requested = (preferredDir !== undefined && preferredDir !== null)
            ? String(preferredDir)
            : String(outputDirField.text || "")
        const resolved = appController.ensureCaptureOutputDir(requested)
        if (resolved && resolved.length > 0) {
            outputDirField.text = resolved
            return resolved
        }
        return ""
    }

    function persistCameraSetting(key, value) {
        if (root.loadingCameraSettings)
            return
        appController.setSetting(key, value)
    }

    function isKnownCategory(value) {
        return root.allCategories.indexOf(value) >= 0
    }

    function applyCameraSettings() {
        root.loadingCameraSettings = true
        const s = appController.getSettings()

        outputDirField.text = s.cameraOutputDir ? s.cameraOutputDir : "C:/Users/Public/Pictures"
        const c = s.cameraCountdown ? Number(s.cameraCountdown) : 0
        countdownBox.value = Math.max(0, Math.min(10, isNaN(c) ? 0 : c))
        root.captureCountdown = countdownBox.value

        const ext = s.cameraVideoExtension ? s.cameraVideoExtension : ".mp4"
        const extIndex = videoExtBox.find(ext)
        videoExtBox.currentIndex = extIndex >= 0 ? extIndex : 0
        root.selectedVideoExtension = videoExtBox.currentText

        const qName = s.cameraQuality ? s.cameraQuality : "Normal"
        const qIndex = qualityIndexFromName(qName)
        qualityBox.currentIndex = qIndex
        applyQualityFromIndex(qIndex)

        const categoryName = s.cameraSelectedCategory ? s.cameraSelectedCategory : "camera"
        root.selectedCategory = isKnownCategory(categoryName) ? categoryName : "camera"
        const categoryIndex = categoryBox.find(root.selectedCategory)
        categoryBox.currentIndex = categoryIndex >= 0 ? categoryIndex : 0

        root.cameraSplitRatio = clampedSplitRatio(s.cameraSplitRatio ? s.cameraSplitRatio : 0.66)

        root.loadingCameraSettings = false
    }

    function refreshFiles() {
        filesModel = appController.listFiles(root.selectedCategory)
        selectedNames = []
    }

    function promoteDragHandle(handle, home) {
        if (!handle || !home || !dragLayer || handle.parent === dragLayer)
            return

        const position = handle.mapToItem(dragLayer, 0, 0)
        handle.parent = dragLayer
        handle.x = position.x
        handle.y = position.y
        handle.z = 1000
    }

    function restoreDragHandle(handle, home) {
        if (!handle || !home || handle.parent === home)
            return

        handle.parent = home
        handle.x = 0
        handle.y = 0
        handle.z = 0
    }

    function handleCenterInDragHost(handle) {
        if (!handle || !dragHost)
            return Qt.point(0, 0)

        return handle.mapToItem(dragHost, handle.width / 2, handle.height / 2)
    }

    function isSelected(filename) {
        return selectedNames.indexOf(filename) >= 0
    }

    function toggleSelection(filename) {
        const idx = selectedNames.indexOf(filename)
        if (idx >= 0) selectedNames.splice(idx, 1)
        else selectedNames.push(filename)
        selectedNames = selectedNames.slice(0)
    }

    function timestampName(prefix, extension) {
        const d = new Date()
        const parts = [
            d.getFullYear(),
            ("0" + (d.getMonth() + 1)).slice(-2),
            ("0" + d.getDate()).slice(-2),
            "-",
            ("0" + d.getHours()).slice(-2),
            ("0" + d.getMinutes()).slice(-2),
            ("0" + d.getSeconds()).slice(-2)
        ]
        return prefix + parts.join("") + extension
    }

    function selectedVideoInput() {
        if (mediaDevices.videoInputs.length === 0) {
            return null
        }
        const idx = Math.max(0, Math.min(deviceBox.currentIndex, mediaDevices.videoInputs.length - 1))
        return mediaDevices.videoInputs[idx]
    }

    function capturePhotoNow() {
        const baseDir = resolvedWritableOutputDir(outputDirField.text)
        root.photoRetryUsingDefaultPath = false
        if (!baseDir) {
            root.captureStatus = "Photo capture failed: no writable output folder."
            return
        }

        const photoPath = baseDir + "/" + root.timestampName("photo-", ".jpg")
        imageCapture.captureToFile(photoPath)
    }

    function startRecordingNow(useDefaultDir) {
        const preferred = useDefaultDir ? "" : outputDirField.text
        const baseDir = resolvedWritableOutputDir(preferred)
        if (!baseDir) {
            root.captureStatus = "Recording failed: no writable output folder."
            return
        }
        const videoPath = baseDir + "/" + root.timestampName("video-", root.selectedVideoExtension)
        mediaRecorder.outputLocation = root.localFileUrl(videoPath)
        mediaRecorder.record()
    }

    function requestPhotoCapture() {
        if (!root.hasCameraDevice) {
            root.captureStatus = "No camera device detected"
            return
        }

        if (!camera.active) {
            root.pendingPhotoCapture = true
            root.captureStatus = "Starting camera..."
            camera.active = true
            activateAndCaptureTimeout.restart()
            return
        }

        root.captureStatus = "Capturing photo..."
        root.capturePhotoNow()
    }

    Component.onCompleted: {
        refreshFiles()
        applyCameraSettings()
    }
    onVisibleChanged: {
        if (visible) {
            refreshFiles()
            applyCameraSettings()
        }
        camera.active = visible && hasCameraDevice
    }

    MediaDevices {
        id: mediaDevices
    }

    Camera {
        id: camera
        active: false
        cameraDevice: root.selectedVideoInput()
        onActiveChanged: {
            if (active && root.pendingPhotoCapture) {
                root.pendingPhotoCapture = false
                activateAndCaptureTimeout.stop()
                Qt.callLater(function() {
                    root.captureStatus = "Capturing photo..."
                    root.capturePhotoNow()
                })
            }
        }
    }

    AudioInput {
        id: micInput
    }

    ImageCapture {
        id: imageCapture
        onImageSaved: function(requestId, filePath) {
            root.photoRetryUsingDefaultPath = false
            const ok = appController.uploadFiles(root.selectedCategory, [filePath])
            root.captureStatus = ok
                ? ("Photo captured and added to " + root.selectedCategory + ".")
                : "Photo captured, but library import failed."
            if (ok) {
                refreshFiles()
            }
        }
        onErrorOccurred: function(requestId, error, errorString) {
            if (!root.photoRetryUsingDefaultPath) {
                root.photoRetryUsingDefaultPath = true
                root.captureStatus = "Primary photo path failed, retrying default location..."
                imageCapture.captureToFile()
                return
            }
            root.captureStatus = "Photo capture failed: " + errorString
        }
    }

    MediaRecorder {
        id: mediaRecorder
        quality: root.selectedRecorderQuality
        encodingMode: MediaRecorder.ConstantQualityEncoding
        onRecorderStateChanged: {
            if (recorderState === MediaRecorder.StoppedState && actualLocation.toString().length > 0) {
                const ok = appController.uploadFiles(root.selectedCategory, [actualLocation.toString()])
                root.captureStatus = ok
                    ? ("Video saved and added to " + root.selectedCategory + ".")
                    : "Video recorded, but library import failed."
                if (ok) {
                    refreshFiles()
                }
            }
        }
        onErrorOccurred: function(error, errorString) {
            if (!root.videoRetryUsingDefaultPath) {
                root.videoRetryUsingDefaultPath = true
                root.captureStatus = "Primary video output path failed, retrying default location..."
                root.startRecordingNow(true)
                return
            }
            root.captureStatus = "Recording failed: " + errorString
        }
    }

    CaptureSession {
        id: captureSession
        camera: camera
        audioInput: micInput
        imageCapture: imageCapture
        recorder: mediaRecorder
        videoOutput: livePreview
    }

    Timer {
        id: photoCountdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.captureRemaining = root.captureRemaining - 1
            if (root.captureRemaining <= 0) {
                stop()
                root.requestPhotoCapture()
            }
        }
    }

    Timer {
        id: activateAndCaptureTimeout
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.pendingPhotoCapture) {
                root.pendingPhotoCapture = false
                root.captureStatus = "Photo capture failed: camera did not become active."
            }
        }
    }

    FolderDialog {
        id: outputFolderDialog
        currentFolder: "file:///C:/Users/Public/Pictures"
        onAccepted: {
            outputDirField.text = selectedFolder.toString().replace("file:///", "")
        }
    }

    FileDialog {
        id: cameraImportPicker
        title: "Select Media Files"
        fileMode: FileDialog.OpenFiles
        nameFilters: [
            "Media Files (*.jpg *.jpeg *.png *.gif *.webp *.bmp *.heic *.tiff *.mp4 *.webm *.mov *.avi *.mkv *.mpeg *.mpg *.mp3 *.wav *.ogg *.m4a *.flac *.aac)",
            "All Files (*.*)"
        ]
        onAccepted: {
            const paths = selectedFiles.map(function(u) { return u.toString() })
            if (paths.length > 0 && appController.uploadFiles(root.selectedCategory, paths)) {
                refreshFiles()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Camera Library"
                font.pixelSize: 18
                font.bold: true
            }

            ComboBox {
                id: categoryBox
                model: root.allCategories
                Layout.preferredWidth: 180
                onCurrentTextChanged: {
                    if (!currentText)
                        return
                    root.selectedCategory = currentText
                    persistCameraSetting("cameraSelectedCategory", currentText)
                    refreshFiles()
                }
            }

            Item { Layout.fillWidth: true }

            ComboBox {
                id: deviceBox
                model: mediaDevices.videoInputs
                textRole: "description"
                Layout.preferredWidth: 260
                enabled: root.hasCameraDevice
                onActivated: {
                    camera.cameraDevice = root.selectedVideoInput()
                }
            }

            Button {
                text: camera.active ? "Stop Camera" : "Start Camera"
                enabled: root.hasCameraDevice
                onClicked: camera.active = !camera.active
            }

            Button {
                text: "Refresh"
                onClicked: refreshFiles()
            }

            Label {
                text: selectedNames.length + " selected"
                color: "#59636d"
            }

            Button {
                text: "Delete Selected"
                enabled: selectedNames.length > 0
                onClicked: {
                    if (appController.deleteFiles(root.selectedCategory, selectedNames)) {
                        refreshFiles()
                    }
                }
            }
        }

        Item {
            id: splitContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 520

            readonly property real splitterWidth: 12
            readonly property real minLeftWidth: 520
            readonly property real minRightWidth: 320
            readonly property real availableWidth: Math.max(0, width - splitterWidth)
            readonly property real preferredLeftWidth: availableWidth * root.cameraSplitRatio
            readonly property real maxLeftWidth: Math.max(minLeftWidth, availableWidth - minRightWidth)
            readonly property real leftPaneWidth: Math.max(minLeftWidth, Math.min(maxLeftWidth, preferredLeftWidth))

            ColumnLayout {
                id: leftPane
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: splitContainer.leftPaneWidth
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 460
                    radius: 8
                    color: "#0e1217"
                    border.color: "#2f3946"

                    VideoOutput {
                        id: livePreview
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: !root.hasCameraDevice
                        text: "No camera device detected"
                        color: "#b7c2ce"
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    TextField {
                        id: outputDirField
                        Layout.fillWidth: true
                        placeholderText: "Capture staging folder (e.g. C:/Users/Public/Pictures)"
                        text: "C:/Users/Public/Pictures"
                        selectByMouse: true
                        onEditingFinished: persistCameraSetting("cameraOutputDir", text.trim())
                    }

                    Button {
                        text: "Browse"
                        onClicked: outputFolderDialog.open()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    SpinBox {
                        id: countdownBox
                        from: 0
                        to: 10
                        value: 0
                        editable: true
                        Layout.preferredWidth: 100
                        onValueModified: {
                            root.captureCountdown = value
                            persistCameraSetting("cameraCountdown", String(value))
                        }
                    }

                    Label {
                        text: "sec"
                        color: "#59636d"
                    }

                    ComboBox {
                        id: qualityBox
                        model: ["VeryLow", "Low", "Normal", "High", "VeryHigh"]
                        currentIndex: 2
                        Layout.preferredWidth: 120
                        onCurrentIndexChanged: {
                            applyQualityFromIndex(currentIndex)
                            persistCameraSetting("cameraQuality", qualityNameFromIndex(currentIndex))
                        }
                    }

                    ComboBox {
                        id: videoExtBox
                        model: [".mp4", ".webm", ".mov"]
                        currentIndex: 0
                        Layout.preferredWidth: 100
                        onCurrentTextChanged: {
                            root.selectedVideoExtension = currentText
                            persistCameraSetting("cameraVideoExtension", currentText)
                        }
                    }

                    Button {
                        text: "Capture Photo"
                        enabled: root.hasCameraDevice
                        onClicked: {
                            root.captureCountdown = countdownBox.value
                            if (root.captureCountdown <= 0) {
                                root.requestPhotoCapture()
                            } else {
                                root.captureRemaining = root.captureCountdown
                                root.captureStatus = "Capturing in " + root.captureRemaining + "s"
                                photoCountdownTimer.start()
                            }
                        }
                    }

                    Button {
                        text: mediaRecorder.recorderState === MediaRecorder.RecordingState ? "Stop Recording" : "Start Recording"
                        enabled: root.hasCameraDevice
                        onClicked: {
                            if (mediaRecorder.recorderState === MediaRecorder.RecordingState) {
                                mediaRecorder.stop()
                            } else {
                                root.videoRetryUsingDefaultPath = false
                                root.startRecordingNow(false)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Label {
                    visible: captureStatus.length > 0
                    text: photoCountdownTimer.running
                        ? ("Capturing in " + root.captureRemaining + "s")
                        : captureStatus
                    color: "#4f5f2a"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 8
                    color: "#f1f3f5"
                    border.color: "#d6d9dd"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        Label {
                            text: "Add existing media from Explorer or portable drives"
                            color: "#555"
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Choose Files..."
                            onClicked: cameraImportPicker.open()
                        }
                    }
                }

                Label {
                    visible: appController.lastError.length > 0
                    text: appController.lastError
                    color: "#9a1f1f"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                id: splitterBar
                x: leftPane.width
                y: 0
                width: splitContainer.splitterWidth
                height: splitContainer.height
                color: splitterHoverArea.containsMouse || splitterHoverArea.pressed ? "#bcc8d4" : "#d6d9dd"

                Label {
                    anchors.centerIn: parent
                    text: "||"
                    color: "#7d8791"
                    font.bold: true
                }

                MouseArea {
                    id: splitterHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    drag.target: splitterBar
                    drag.axis: Drag.XAxis
                    drag.minimumX: splitContainer.minLeftWidth
                    drag.maximumX: splitContainer.width - splitContainer.minRightWidth

                    onPositionChanged: {
                        if (!pressed)
                            return
                        const usable = Math.max(1, splitContainer.availableWidth)
                        root.cameraSplitRatio = root.clampedSplitRatio(splitterBar.x / usable)
                    }

                    onReleased: {
                        persistCameraSetting("cameraSplitRatio", String(root.cameraSplitRatio))
                    }
                }
            }

            ColumnLayout {
                id: rightPane
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.left: splitterBar.right
                spacing: 8

                Label {
                    text: "Camera Files"
                    font.pixelSize: 16
                    font.bold: true
                }

                ListView {
                    id: filesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 220
                    clip: true
                    interactive: !root.dragInProgress
                    model: root.filesModel
                    spacing: 4

                    delegate: Rectangle {
                        required property var modelData
                        property string dragFilename: modelData.filename
                        property string dragCategory: root.selectedCategory
                        width: filesList.width
                        height: 62
                        radius: 8
                        color: isSelected(modelData.filename) ? "#eef5ff" : "#ffffff"
                        border.color: isSelected(modelData.filename) ? "#8fb1db" : "#d6d9dd"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8

                            CheckBox {
                                checked: isSelected(modelData.filename)
                                onClicked: toggleSelection(modelData.filename)
                            }

                            Item {
                                id: dragHandleHome
                                width: 28
                                height: 28

                                Rectangle {
                                    id: dragHandle
                                    width: dragHandleHome.width
                                    height: dragHandleHome.height
                                    radius: 6
                                    property string dragFilename: modelData.filename
                                    property string dragCategory: root.selectedCategory
                                    color: fileDragHandler.active ? "#c6d8f7" : "#eef1f4"
                                    border.color: fileDragHandler.active ? "#5f95c8" : "#ccd3da"

                                    HoverHandler { cursorShape: Qt.OpenHandCursor }

                                    Label {
                                        anchors.centerIn: parent
                                        text: "::"
                                        color: "#5a6470"
                                        font.bold: true
                                        font.pixelSize: 13
                                    }

                                    DragHandler {
                                        id: fileDragHandler
                                        target: dragHandle
                                        dragThreshold: 0
                                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                                        onActiveChanged: {
                                            root.dragInProgress = active
                                            if (active) {
                                                root.promoteDragHandle(dragHandle, dragHandleHome)
                                                if (root.dragHost) {
                                                    root.dragHost.beginWardrobeDrag(
                                                        modelData.filename,
                                                        root.selectedCategory,
                                                        root.handleCenterInDragHost(dragHandle))
                                                }
                                            } else {
                                                if (root.dragHost) {
                                                    root.dragHost.endWardrobeDrag(root.handleCenterInDragHost(dragHandle))
                                                }
                                                persistentTranslation = Qt.vector2d(0, 0)
                                                root.restoreDragHandle(dragHandle, dragHandleHome)
                                            }
                                        }
                                        onActiveTranslationChanged: {
                                            if (active && root.dragHost) {
                                                root.dragHost.updateWardrobeDrag(root.handleCenterInDragHost(dragHandle))
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 44
                                height: 44
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
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appController.openFile(modelData.filePath)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: modelData.filename
                                    font.bold: true
                                    elide: Label.ElideRight
                                    Layout.fillWidth: true
                                }

                                Label {
                                    text: modelData.filePath
                                    color: "#60666c"
                                    elide: Label.ElideRight
                                    Layout.fillWidth: true
                                    font.pixelSize: 11
                                }
                            }

                            Button {
                                text: "Open"
                                onClicked: appController.openFile(modelData.filePath)
                            }

                            Button {
                                text: "Delete"
                                onClicked: {
                                    if (appController.deleteFile(root.selectedCategory, modelData.filename)) {
                                        refreshFiles()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
