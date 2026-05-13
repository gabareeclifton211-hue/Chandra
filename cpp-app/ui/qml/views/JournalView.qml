import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property Item toastHost: null

    property var entriesModel: []
    property var filteredEntriesModel: []
    property string selectedEntryId: ""
    property var selectedEntryIds: []
    property string journalSearch: ""

    function isSelected(entryId) {
        return selectedEntryIds.indexOf(entryId) >= 0
    }

    function toggleSelection(entryId) {
        const idx = selectedEntryIds.indexOf(entryId)
        if (idx >= 0) selectedEntryIds.splice(idx, 1)
        else selectedEntryIds.push(entryId)
        selectedEntryIds = selectedEntryIds.slice(0)
    }

    function stripHtml(html) {
        return (html || "").replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim()
    }

    function applyJournalSearch() {
        const q = journalSearch.trim().toLowerCase()
        if (q.length === 0) {
            filteredEntriesModel = entriesModel.slice()
        } else {
            filteredEntriesModel = entriesModel.filter(function(e) {
                return (e.title || "").toLowerCase().indexOf(q) >= 0 ||
                       stripHtml(e.body || "").toLowerCase().indexOf(q) >= 0
            })
        }
    }

    function refreshEntries() {
        entriesModel = appController.listJournal()
        applyJournalSearch()
        if (entriesModel.length === 0) {
            selectedEntryId = ""
            titleField.text = ""
            bodyField.text = ""
            return
        }

        if (!selectedEntryId) {
            selectedEntryId = entriesModel[0].id
        }

        for (let i = 0; i < entriesModel.length; i += 1) {
            if (entriesModel[i].id === selectedEntryId) {
                titleField.text = entriesModel[i].title
                bodyField.text = entriesModel[i].body
                return
            }
        }

        selectedEntryId = entriesModel[0].id
        titleField.text = entriesModel[0].title
        bodyField.text = entriesModel[0].body
    }

    Component.onCompleted: refreshEntries()
    onVisibleChanged: {
        if (visible) {
            refreshEntries()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 320
            radius: 8
            color: "#ffffff"
            border.color: "#d6d9dd"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Journal Entries"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        text: selectedEntryIds.length + " selected"
                        color: "#5f6973"
                    }

                    Button {
                        text: "Delete Selected"
                        enabled: selectedEntryIds.length > 0
                        onClicked: {
                            if (appController.deleteJournalEntries(selectedEntryIds)) {
                                selectedEntryIds = []
                                if (selectedEntryId.length > 0 && selectedEntryIds.indexOf(selectedEntryId) >= 0) {
                                    selectedEntryId = ""
                                }
                                refreshEntries()
                            }
                        }
                    }

                    Button {
                        text: "New"
                        onClicked: {
                            selectedEntryId = ""
                            titleField.text = ""
                            bodyField.text = ""
                            titleField.forceActiveFocus()
                        }
                    }
                }

                TextField {
                    Layout.fillWidth: true
                    placeholderText: "Search entries..."
                    selectByMouse: true
                    onTextChanged: {
                        root.journalSearch = text
                        root.applyJournalSearch()
                    }
                }

                ListView {
                    id: entriesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.filteredEntriesModel
                    spacing: 6

                    delegate: Rectangle {
                        required property var modelData
                        width: entriesList.width
                        height: 76
                        radius: 6
                        color: (modelData.id === root.selectedEntryId || isSelected(modelData.id)) ? "#eef5ff" : "#f9fafb"
                        border.color: modelData.id === root.selectedEntryId ? "#8fb1db" : "#d8dde3"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            CheckBox {
                                checked: isSelected(modelData.id)
                                onClicked: toggleSelection(modelData.id)
                            }

                            MouseArea {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedEntryId = modelData.id
                                    titleField.text = modelData.title
                                    bodyField.text = modelData.body
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    spacing: 4

                                    Label {
                                        text: modelData.title
                                        font.bold: true
                                        elide: Label.ElideRight
                                        width: parent.width
                                    }
                                    Label {
                                        text: root.stripHtml(modelData.body)
                                        color: "#626b74"
                                        elide: Label.ElideRight
                                        width: parent.width
                                        font.pixelSize: 11
                                    }
                                    Label {
                                        text: modelData.updatedAt
                                        color: "#8a9199"
                                        elide: Label.ElideRight
                                        width: parent.width
                                        font.pixelSize: 10
                                    }
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
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Entry title"
                    selectByMouse: true
                    font.pixelSize: 18
                    font.bold: true
                }

                // ── Formatting toolbar ─────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 6
                    color: "#f4f6f8"
                    border.color: "#d6d9dd"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 2

                        // Bold
                        ToolButton {
                            text: "<b>B</b>"
                            checkable: true
                            checked: bodyField.cursorSelection.font.bold
                            ToolTip.text: "Bold (Ctrl+B)"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.font.bold = checked
                                bodyField.forceActiveFocus()
                            }
                        }

                        // Italic
                        ToolButton {
                            text: "<i>I</i>"
                            checkable: true
                            checked: bodyField.cursorSelection.font.italic
                            ToolTip.text: "Italic (Ctrl+I)"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.font.italic = checked
                                bodyField.forceActiveFocus()
                            }
                        }

                        // Underline
                        ToolButton {
                            text: "<u>U</u>"
                            checkable: true
                            checked: bodyField.cursorSelection.font.underline
                            ToolTip.text: "Underline (Ctrl+U)"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.font.underline = checked
                                bodyField.forceActiveFocus()
                            }
                        }

                        // Strikethrough
                        ToolButton {
                            text: "<s>S</s>"
                            checkable: true
                            checked: bodyField.cursorSelection.font.strikeout
                            ToolTip.text: "Strikethrough"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.font.strikeout = checked
                                bodyField.forceActiveFocus()
                            }
                        }

                        Rectangle { width: 1; height: 24; color: "#ccd3da" }

                        // Align Left
                        ToolButton {
                            text: "\u2261"
                            ToolTip.text: "Align Left"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.alignment = Qt.AlignLeft
                                bodyField.forceActiveFocus()
                            }
                        }

                        // Align Center
                        ToolButton {
                            text: "\u2263"
                            ToolTip.text: "Align Center"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.alignment = Qt.AlignHCenter
                                bodyField.forceActiveFocus()
                            }
                        }

                        // Align Right
                        ToolButton {
                            text: "\u2260"
                            ToolTip.text: "Align Right"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.alignment = Qt.AlignRight
                                bodyField.forceActiveFocus()
                            }
                        }

                        Rectangle { width: 1; height: 24; color: "#ccd3da" }

                        // Font size
                        Label { text: "Size:"; color: "#505860"; font.pixelSize: 12 }
                        SpinBox {
                            id: fontSizeBox
                            from: 8
                            to: 72
                            value: 14
                            implicitWidth: 72
                            onValueModified: {
                                bodyField.cursorSelection.font.pixelSize = value
                                bodyField.forceActiveFocus()
                            }
                        }

                        Rectangle { width: 1; height: 24; color: "#ccd3da" }

                        // Heading shortcuts
                        ToolButton {
                            text: "H1"
                            font.bold: true
                            ToolTip.text: "Heading 1"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.font.pixelSize = 26
                                bodyField.cursorSelection.font.bold = true
                                bodyField.forceActiveFocus()
                            }
                        }
                        ToolButton {
                            text: "H2"
                            font.bold: true
                            ToolTip.text: "Heading 2"
                            ToolTip.visible: hovered
                            onClicked: {
                                bodyField.cursorSelection.font.pixelSize = 20
                                bodyField.cursorSelection.font.bold = true
                                bodyField.forceActiveFocus()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Undo / Redo
                        ToolButton {
                            text: "\u21B6"
                            ToolTip.text: "Undo"
                            ToolTip.visible: hovered
                            enabled: bodyField.canUndo
                            onClicked: bodyField.undo()
                        }
                        ToolButton {
                            text: "\u21B7"
                            ToolTip.text: "Redo"
                            ToolTip.visible: hovered
                            enabled: bodyField.canRedo
                            onClicked: bodyField.redo()
                        }
                    }
                }

                // ── Editor area ────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    border.color: bodyField.activeFocus ? "#8fb1db" : "#d6d9dd"
                    color: "#ffffff"

                    Flickable {
                        id: bodyFlickable
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: bodyField.contentWidth
                        contentHeight: bodyField.contentHeight
                        flickableDirection: Flickable.VerticalFlick
                        ScrollBar.vertical: ScrollBar {}

                        TextEdit {
                            id: bodyField
                            width: bodyFlickable.width
                            height: Math.max(bodyFlickable.height, contentHeight)
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.RichText
                            selectByMouse: true
                            font.pixelSize: 14
                            focus: true

                            onCursorRectangleChanged: {
                                if (cursorRectangle.y < bodyFlickable.contentY)
                                    bodyFlickable.contentY = cursorRectangle.y
                                else if (cursorRectangle.y + cursorRectangle.height > bodyFlickable.contentY + bodyFlickable.height)
                                    bodyFlickable.contentY = cursorRectangle.y + cursorRectangle.height - bodyFlickable.height

                                fontSizeBox.value = cursorSelection.font.pixelSize > 0 ? cursorSelection.font.pixelSize : 14
                            }

                            // Keyboard shortcuts
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_B && (event.modifiers & Qt.ControlModifier)) {
                                    cursorSelection.font.bold = !cursorSelection.font.bold
                                    event.accepted = true
                                } else if (event.key === Qt.Key_I && (event.modifiers & Qt.ControlModifier)) {
                                    cursorSelection.font.italic = !cursorSelection.font.italic
                                    event.accepted = true
                                } else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
                                    cursorSelection.font.underline = !cursorSelection.font.underline
                                    event.accepted = true
                                } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                                    saveButton.clicked()
                                    event.accepted = true
                                }
                            }
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

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        id: saveButton
                        text: "Save"
                        onClicked: {
                            const html = bodyField.getFormattedText(0, bodyField.length)
                            const savedId = appController.saveJournal(root.selectedEntryId, titleField.text, html)
                            if (savedId.length > 0) {
                                root.selectedEntryId = savedId
                                if (root.toastHost) root.toastHost.showToast("Entry saved")
                                refreshEntries()
                            }
                        }
                    }

                    Button {
                        text: "Delete"
                        enabled: root.selectedEntryId.length > 0
                        onClicked: {
                            if (!root.selectedEntryId)
                                return
                            if (appController.deleteJournal(root.selectedEntryId)) {
                                root.selectedEntryId = ""
                                refreshEntries()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Refresh"
                        onClicked: refreshEntries()
                    }
                }
            }
        }
    }
}
