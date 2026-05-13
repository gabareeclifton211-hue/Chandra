import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root
    required property string category
    property Item dragLayer: null
    property Item dragHost: null
    property Item toastHost: null
    property int refreshToken: 0
    property bool dragInProgress: false

    property var filesModel: []
    property var visibleFilesModel: []
    property var allCategories: ["panties", "bras", "what-i-wore-today", "accessories", "makeup"]
    property string searchQuery: ""
    property string selectedType: "All"
    property string tagFilter: ""
    property var selectedNames: []
    property bool gridView: true
    property string sortOrder: "newest"

    function clearSelection() {
        selectedNames = []
    }

    function toggleSelection(filename) {
        const idx = selectedNames.indexOf(filename)
        if (idx >= 0) {
            selectedNames.splice(idx, 1)
        } else {
            selectedNames.push(filename)
        }
        selectedNames = selectedNames.slice(0)
    }

    function isSelected(filename) {
        return selectedNames.indexOf(filename) >= 0
    }

    function inferType(filename) {
        const lower = filename.toLowerCase()
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

    function applyFilters() {
        const q = searchQuery.trim().toLowerCase()
        const tf = tagFilter.trim().toLowerCase()
        let filtered = filesModel.filter(function(item) {
            const name = (item.filename || "").toLowerCase()
            const desc = (item.description || "").toLowerCase()
            const matchesText = q.length === 0 || name.indexOf(q) >= 0 || desc.indexOf(q) >= 0
            const type = inferType(item.filename || "")
            const matchesType = selectedType === "All" || type === selectedType
            const itemTags = (item.tags || "").toLowerCase().split(",").map(function(t){ return t.trim() }).filter(function(t){ return t.length > 0 })
            const matchesTag = tf.length === 0 || itemTags.indexOf(tf) >= 0
            return matchesText && matchesType && matchesTag
        })
        if (root.sortOrder === "az") {
            filtered = filtered.slice().sort(function(a, b) { return (a.filename || "").localeCompare(b.filename || "") })
        } else if (root.sortOrder === "za") {
            filtered = filtered.slice().sort(function(a, b) { return (b.filename || "").localeCompare(a.filename || "") })
        } else if (root.sortOrder === "oldest") {
            filtered = filtered.slice().reverse()
        }
        // "newest" keeps the default DB order (most recent first)
        visibleFilesModel = filtered
    }

    function refreshFiles() {
        filesModel = appController.listFiles(category)
        applyFilters()
        clearSelection()
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

    function uploadPathList(paths) {
        if (!paths || paths.length === 0)
            return

        if (appController.uploadFiles(root.category, paths)) {
            refreshFiles()
        }
    }

    function deleteAllFiles() {
        if (filesModel.length === 0)
            return;
        confirmDeleteAllDialog.open();
    }

    MessageDialog {
        id: confirmDeleteAllDialog
        title: "Delete All Files?"
        text: "Are you sure you want to delete ALL files in this category? This cannot be undone."
        buttons: MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function(button) {
            if (button === MessageDialog.Yes) {
                if (appController.deleteFiles(root.category, filesModel.map(function(item){return item.filename;}))) {
                    refreshFiles();
                }
            }
        }
    }

    FileDialog {
        id: mediaPicker
        title: "Select Media Files"
        fileMode: FileDialog.OpenFiles
        nameFilters: [
            "Media Files (*.jpg *.jpeg *.png *.gif *.webp *.bmp *.heic *.tiff *.mp4 *.webm *.mov *.avi *.mkv *.mpeg *.mpg *.mp3 *.wav *.ogg *.m4a *.flac *.aac)",
            "All Files (*.*)"
        ]
        onAccepted: {
            const paths = selectedFiles.map(function(u) { return u.toString() })
            uploadPathList(paths)
        }
    }

    Component.onCompleted: refreshFiles()
    onRefreshTokenChanged: refreshFiles()
    onVisibleChanged: {
        if (visible) {
            refreshFiles()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Category: " + root.category
                font.pixelSize: 18
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Button {
                text: root.gridView ? "List View" : "Grid View"
                onClicked: root.gridView = !root.gridView
            }

            Button {
                text: "Refresh"
                onClicked: refreshFiles()
            }
        }

        RowLayout {
            Layout.fillWidth: true

            TextField {
                Layout.fillWidth: true
                placeholderText: "Search filename or description"
                selectByMouse: true
                onTextChanged: {
                    root.searchQuery = text
                    applyFilters()
                }
            }

            ComboBox {
                id: typeFilter
                model: ["All", "Images", "Videos", "Audio", "Other"]
                currentIndex: 0
                onCurrentTextChanged: {
                    root.selectedType = currentText
                    applyFilters()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Tag:"
                color: "#505860"
            }

            TextField {
                id: tagFilterField
                Layout.preferredWidth: 180
                placeholderText: "Filter by tag"
                selectByMouse: true
                onTextChanged: {
                    root.tagFilter = text
                    applyFilters()
                }
            }

            Button {
                text: "Clear"
                visible: tagFilterField.text.length > 0
                onClicked: {
                    tagFilterField.text = ""
                }
            }

            Item { Layout.fillWidth: true }

            Label { text: "Sort:"; color: "#505860" }

            ComboBox {
                id: sortCombo
                model: ["Newest", "Oldest", "A – Z", "Z – A"]
                currentIndex: 0
                Layout.preferredWidth: 110
                onCurrentIndexChanged: {
                    const map = ["newest", "oldest", "az", "za"]
                    root.sortOrder = map[currentIndex]
                    applyFilters()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: selectedNames.length + " selected"
                color: "#505860"
            }

            Item { Layout.fillWidth: true }

            ComboBox {
                id: batchMoveCategory
                model: root.allCategories.filter(function(c) { return c !== root.category })
                Layout.preferredWidth: 180
            }

            Button {
                text: "Move Selected"
                enabled: selectedNames.length > 0 && batchMoveCategory.currentText.length > 0
                onClicked: {
                    if (appController.moveFiles(root.category, batchMoveCategory.currentText, selectedNames)) {
                        refreshFiles()
                    }
                }
            }

            Button {
                text: "Delete Selected"
                enabled: selectedNames.length > 0
                onClicked: {
                    if (appController.deleteFiles(root.category, selectedNames)) {
                        refreshFiles()
                    }
                }
            }

            Button {
                text: "Delete All"
                enabled: filesModel.length > 0
                onClicked: deleteAllFiles()
                ToolTip.text: "Delete all files in this category"
            }
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
                    text: "Add files from Explorer or portable drives"
                    color: "#555"
                    Layout.fillWidth: true
                }

                Button {
                    text: "Choose Files..."
                    onClicked: mediaPicker.open()
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Grid view ─────────────────────────────────────────────
            GridView {
                id: filesGrid
                anchors.fill: parent
                visible: root.gridView
                clip: true
                model: root.visibleFilesModel
                cellWidth: 160
                cellHeight: 185

                delegate: Item {
                    required property var modelData
                    width: filesGrid.cellWidth
                    height: filesGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 8
                        color: isSelected(modelData.filename) ? "#eef5ff" : "#ffffff"
                        border.color: isSelected(modelData.filename) ? "#8fb1db" : "#d6d9dd"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Image {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 130
                                fillMode: Image.PreserveAspectCrop
                                source: root.localFileUrl(modelData.filePath)
                                clip: true
                                asynchronous: true
                                cache: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#f3f5f7"
                                    visible: parent.status !== Image.Ready && parent.status !== Image.Loading
                                    Label {
                                        anchors.centerIn: parent
                                        text: inferType(modelData.filename)
                                        color: "#687684"
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Label {
                                text: modelData.filename
                                Layout.fillWidth: true
                                elide: Label.ElideRight
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                CheckBox {
                                    checked: isSelected(modelData.filename)
                                    onClicked: toggleSelection(modelData.filename)
                                }
                                Item { Layout.fillWidth: true }
                                Button {
                                    text: "Open"
                                    font.pixelSize: 10
                                    padding: 4
                                    onClicked: appController.openFile(modelData.filePath)
                                }
                            }
                        }
                    }
                }
            }

            // ── List view ─────────────────────────────────────────────
            ListView {
                id: filesList
                anchors.fill: parent
                visible: !root.gridView
                clip: true
                interactive: !root.dragInProgress
                model: root.visibleFilesModel
                spacing: 6

            delegate: Rectangle {
                required property var modelData
                property string dragFilename: modelData.filename
                property string dragCategory: root.category
                property bool editingDescription: false
                property bool editingTags: false
                width: filesList.width
                height: itemContent.implicitHeight + 20
                radius: 8
                color: isSelected(modelData.filename) ? "#eef5ff" : "#ffffff"
                border.color: isSelected(modelData.filename) ? "#8fb1db" : "#d6d9dd"

                RowLayout {
                    id: itemContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: 96
                        height: 96
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
                            text: inferType(modelData.filename)
                            color: "#687684"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appController.openFile(modelData.filePath)
                        }
                    }

                    CheckBox {
                        checked: isSelected(modelData.filename)
                        onClicked: toggleSelection(modelData.filename)
                    }

                    Item {
                        id: dragHandleHome
                        width: 36
                        height: 36
                        Rectangle {
                            id: dragHandle
                            width: dragHandleHome.width
                            height: dragHandleHome.height
                            radius: 6
                            property string dragFilename: modelData.filename
                            property string dragCategory: root.category
                            color: fileDragHandler.active ? "#c6d8f7" : "#eef1f4"
                            border.color: fileDragHandler.active ? "#5f95c8" : "#ccd3da"
                            HoverHandler { cursorShape: Qt.OpenHandCursor }

                            Label {
                                anchors.centerIn: parent
                                text: "::"
                                color: "#5a6470"
                                font.bold: true
                                font.pixelSize: 15
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
                                                root.category,
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: modelData.filename
                                font.bold: true
                            }

                            Label {
                                text: inferType(modelData.filename)
                                color: "#36506a"
                                font.pixelSize: 12
                            }
                        }
                        Label {
                            text: modelData.filePath
                            color: "#60666c"
                            elide: Label.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: modelData.description.length > 0 ? modelData.description : "Add description..."
                            color: modelData.description.length > 0 ? "#60666c" : "#a8b0b8"
                            font.italic: modelData.description.length === 0
                            visible: !editingDescription
                            elide: Label.ElideRight
                            Layout.fillWidth: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: {
                                    descField.text = modelData.description
                                    editingDescription = true
                                    descField.forceActiveFocus()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            TextField {
                                id: renameField
                                Layout.fillWidth: true
                                text: modelData.filename
                                selectByMouse: true
                            }

                            Button {
                                text: "Rename"
                                onClicked: {
                                    const nextName = renameField.text.trim()
                                    if (!nextName || nextName === modelData.filename)
                                        return
                                    if (appController.renameFile(root.category, modelData.filename, nextName)) {
                                        if (root.toastHost) root.toastHost.showToast("Renamed")
                                        refreshFiles()
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: editingDescription

                            TextField {
                                id: descField
                                Layout.fillWidth: true
                                placeholderText: "Description"
                                selectByMouse: true
                                Keys.onEscapePressed: editingDescription = false
                                Keys.onReturnPressed: {
                                    if (appController.setFileDescription(root.category, modelData.filename, descField.text)) {
                                        editingDescription = false
                                        if (root.toastHost) root.toastHost.showToast("Description saved")
                                        refreshFiles()
                                    }
                                }
                            }

                            Button {
                                text: "Save"
                                onClicked: {
                                    if (appController.setFileDescription(root.category, modelData.filename, descField.text)) {
                                        editingDescription = false
                                        if (root.toastHost) root.toastHost.showToast("Description saved")
                                        refreshFiles()
                                    }
                                }
                            }

                            Button {
                                text: "✕"
                                onClicked: editingDescription = false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: editingTags

                            Label {
                                text: "Tags:"
                                color: "#505860"
                            }

                            TextField {
                                id: tagsField
                                Layout.fillWidth: true
                                placeholderText: "comma-separated tags"
                                selectByMouse: true
                                Keys.onEscapePressed: editingTags = false
                                Keys.onReturnPressed: {
                                    if (appController.setFileTags(root.category, modelData.filename, tagsField.text)) {
                                        editingTags = false
                                        if (root.toastHost) root.toastHost.showToast("Tags saved")
                                        refreshFiles()
                                    }
                                }
                            }

                            Button {
                                text: "Save"
                                onClicked: {
                                    if (appController.setFileTags(root.category, modelData.filename, tagsField.text)) {
                                        editingTags = false
                                        if (root.toastHost) root.toastHost.showToast("Tags saved")
                                        refreshFiles()
                                    }
                                }
                            }

                            Button {
                                text: "✕"
                                onClicked: editingTags = false
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            visible: !editingTags
                            implicitHeight: tagsDisplayLayout.implicitHeight

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tagsField.text = modelData.tags || ""
                                    editingTags = true
                                    tagsField.forceActiveFocus()
                                }
                            }

                            RowLayout {
                                id: tagsDisplayLayout
                                width: parent.width
                                spacing: 4

                                Label {
                                    text: "Tags:"
                                    color: "#505860"
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: (modelData.tags || "").split(",").map(function(t){ return t.trim() }).filter(function(t){ return t.length > 0 })

                                        delegate: Rectangle {
                                            required property string modelData
                                            height: tagChipLabel.implicitHeight + 6
                                            width: tagChipLabel.implicitWidth + 16
                                            radius: height / 2
                                            color: root.tagFilter.trim().toLowerCase() === modelData.trim().toLowerCase() ? "#4a90d9" : "#dde8f5"

                                            Label {
                                                id: tagChipLabel
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: 11
                                                color: root.tagFilter.trim().toLowerCase() === modelData.trim().toLowerCase() ? "#ffffff" : "#2d5a8e"
                                            }
                                        }
                                    }

                                    Label {
                                        visible: (modelData.tags || "").length === 0
                                        text: "Add tags..."
                                        color: "#a8b0b8"
                                        font.italic: true
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 6

                        ComboBox {
                            id: moveCategory
                            model: root.allCategories.filter(function(c) { return c !== root.category })
                            Layout.preferredWidth: 180
                        }

                        Button {
                            text: "Open"
                            Layout.fillWidth: true
                            onClicked: appController.openFile(modelData.filePath)
                        }

                        Button {
                            text: "Move"
                            Layout.fillWidth: true
                            enabled: moveCategory.currentText.length > 0
                            onClicked: {
                                if (!moveCategory.currentText)
                                    return
                                if (appController.moveFile(root.category, moveCategory.currentText, modelData.filename)) {
                                    refreshFiles()
                                }
                            }
                        }

                        Button {
                            text: "Delete"
                            Layout.fillWidth: true
                            onClicked: {
                                if (appController.deleteFile(root.category, modelData.filename)) {
                                    refreshFiles()
                                }
                            }
                        }
                    }
                }
            }
            } // end Item (grid+list container)
        }
    }
}
