import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var entriesModel: []
    property string selectedEntryId: ""
    property var selectedEntryIds: []

    function isSelected(entryId) {
        return selectedEntryIds.indexOf(entryId) >= 0
    }

    function toggleSelection(entryId) {
        const idx = selectedEntryIds.indexOf(entryId)
        if (idx >= 0) selectedEntryIds.splice(idx, 1)
        else selectedEntryIds.push(entryId)
        selectedEntryIds = selectedEntryIds.slice(0)
    }

    function refreshEntries() {
        entriesModel = appController.listJournal()
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

                ListView {
                    id: entriesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.entriesModel
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
                                onClicked: {
                                    root.selectedEntryId = modelData.id
                                    titleField.text = modelData.title
                                    bodyField.text = modelData.body
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                Label {
                                    text: modelData.title
                                    font.bold: true
                                    elide: Label.ElideRight
                                    width: parent.width
                                }
                                Label {
                                    text: modelData.updatedAt
                                    color: "#626b74"
                                    elide: Label.ElideRight
                                    width: parent.width
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
                spacing: 10

                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Entry title"
                    selectByMouse: true
                }

                TextArea {
                    id: bodyField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "Write your journal entry..."
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
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
                        text: "Save"
                        onClicked: {
                            const savedId = appController.saveJournal(root.selectedEntryId, titleField.text, bodyField.text)
                            if (savedId.length > 0) {
                                root.selectedEntryId = savedId
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
