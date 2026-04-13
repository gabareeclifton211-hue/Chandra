import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import QtWebEngine

Item {
    id: root

    property string currentCategory: "panties"
    property string importStatus: ""
    property string currentSearchEngine: "duckduckgo"
    property string importDownloadDir: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    property var eventIndexByKey: ({})
    property int maxImportEvents: 200

    ListModel {
        id: importEvents
    }

    function appendEvent(stage, message) {
        importEvents.append({
            ts: (new Date()).toLocaleTimeString(),
            stage: stage,
            message: message
        })
        trimEvents()
    }

    function rebuildEventIndexMap() {
        const rebuilt = ({})
        for (const key in eventIndexByKey) {
            if (!Object.prototype.hasOwnProperty.call(eventIndexByKey, key))
                continue
            const index = eventIndexByKey[key]
            if (index >= 0 && index < importEvents.count) {
                rebuilt[key] = index
            }
        }
        eventIndexByKey = rebuilt
    }

    function trimEvents() {
        while (importEvents.count > maxImportEvents) {
            importEvents.remove(0)
            for (const key in eventIndexByKey) {
                if (!Object.prototype.hasOwnProperty.call(eventIndexByKey, key))
                    continue
                eventIndexByKey[key] = eventIndexByKey[key] - 1
            }
            rebuildEventIndexMap()
        }
    }

    function upsertEvent(key, stage, message) {
        const found = eventIndexByKey[key]
        if (found === undefined) {
            importEvents.append({
                ts: (new Date()).toLocaleTimeString(),
                stage: stage,
                message: message
            })
            eventIndexByKey[key] = importEvents.count - 1
            trimEvents()
        } else {
            importEvents.setProperty(found, "ts", (new Date()).toLocaleTimeString())
            importEvents.setProperty(found, "stage", stage)
            importEvents.setProperty(found, "message", message)
        }
    }

    function formatBytes(value) {
        if (value < 1024) return value + " B"
        if (value < 1024 * 1024) return (value / 1024).toFixed(1) + " KB"
        if (value < 1024 * 1024 * 1024) return (value / (1024 * 1024)).toFixed(1) + " MB"
        return (value / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    function clearEvents() {
        importEvents.clear()
        eventIndexByKey = ({})
    }

    function searchBaseUrl(engine) {
        if (engine === "google") return "https://www.google.com/search?q="
        if (engine === "bing") return "https://www.bing.com/search?q="
        return "https://duckduckgo.com/?q="
    }

    function defaultHomeForEngine(engine) {
        if (engine === "google") return "https://www.google.com/"
        if (engine === "bing") return "https://www.bing.com/"
        return "https://duckduckgo.com/"
    }

    function openSearchQuery() {
        const query = searchField.text.trim()
        if (!query)
            return

        const target = searchBaseUrl(root.currentSearchEngine) + encodeURIComponent(query)
        urlField.text = target
        webView.url = target
    }

    function importFromCurrentUrl() {
        appendEvent("queued", "Queued URL import for: " + urlField.text)
        const ok = appController.importFromUrl(root.currentCategory, urlField.text)
        appendEvent(ok ? "imported" : "failed", ok
            ? ("Imported URL to category '" + root.currentCategory + "'.")
            : ("URL import failed for category '" + root.currentCategory + "'."))
        root.importStatus = ok ? "Imported successfully." : "Import failed."
    }

    function applySettings() {
        const s = appController.getSettings()
        const searchEngine = s.importSearchEngine ? s.importSearchEngine : "duckduckgo"
        const defaultUrl = s.importHomeUrl ? s.importHomeUrl : defaultHomeForEngine(searchEngine)
        const defaultCategory = s.importDefaultCategory ? s.importDefaultCategory : "panties"

        root.currentSearchEngine = searchEngine
        const searchIndex = searchEngineBox.find(searchEngine)
        searchEngineBox.currentIndex = searchIndex >= 0 ? searchIndex : 0

        urlField.text = defaultUrl
        webView.url = defaultUrl

        const idx = targetCategory.find(defaultCategory)
        targetCategory.currentIndex = idx >= 0 ? idx : 0
    }

    Component.onCompleted: applySettings()
    onVisibleChanged: {
        if (visible) {
            applySettings()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            ComboBox {
                id: searchEngineBox
                model: ["duckduckgo", "google", "bing"]
                currentIndex: 0
                onCurrentTextChanged: {
                    root.currentSearchEngine = currentText
                }
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                selectByMouse: true
                placeholderText: "Search query"
                onAccepted: openSearchQuery()
            }

            Button {
                text: "Search"
                onClicked: openSearchQuery()
            }

            Button {
                text: "Home"
                onClicked: {
                    const home = defaultHomeForEngine(root.currentSearchEngine)
                    urlField.text = home
                    webView.url = home
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            TextField {
                id: urlField
                Layout.fillWidth: true
                text: "https://duckduckgo.com/"
                selectByMouse: true
                placeholderText: "Enter URL"
                onAccepted: webView.url = text
            }

            Button {
                text: "Go"
                onClicked: webView.url = urlField.text
            }

            ComboBox {
                id: targetCategory
                model: ["panties", "bras", "what-i-wore-today", "accessories", "makeup", "camera"]
                currentIndex: 0
                onCurrentTextChanged: root.currentCategory = currentText
            }

            Button {
                text: "Clear Events"
                onClicked: clearEvents()
            }
        }

        Label {
            text: "Import target category: " + root.currentCategory + " | Browser downloads are intercepted and saved to this category."
            color: "#59636d"
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: "Save Current URL To Category"
                onClicked: importFromCurrentUrl()
            }

            Label {
                text: root.importStatus
                color: "#3b6f3f"
                visible: root.importStatus.length > 0 && appController.lastError.length === 0
            }
        }

        Label {
            text: "Import Events"
            color: "#59636d"
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 8
            color: "#f7f9fb"
            border.color: "#d2d9df"

            ListView {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                model: importEvents
                spacing: 4

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 30
                    radius: 4
                    color: modelData.stage === "failed" ? "#fdecec" : (modelData.stage === "imported" ? "#edf8ee" : "#eef3f8")
                    border.color: "#d2d9df"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 8

                        Label {
                            text: modelData.ts
                            color: "#607080"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: modelData.stage
                            font.bold: true
                            color: "#3f4f5f"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: modelData.message
                            color: "#3f4f5f"
                            elide: Label.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            border.color: "#cfd6dd"
            color: "#ffffff"

            WebEngineView {
                id: webView
                anchors.fill: parent
                url: "https://duckduckgo.com/"
                profile: importProfile
                onUrlChanged: {
                    urlField.text = url.toString()
                    const urlStr = url.toString()
                    if (urlStr.length > 0 && urlStr !== "about:blank") {
                        appController.logWebSearch(urlStr)
                    }
                }
            }
        }

        WebEngineProfile {
            id: importProfile
            onDownloadRequested: function(download) {
                const sourceUrl = download.url.toString()
                const suggested = download.downloadFileName && download.downloadFileName.length > 0
                    ? download.downloadFileName
                    : ("import-" + Date.now() + ".bin")
                const eventKey = sourceUrl + "|" + suggested + "|" + Date.now()

                download.downloadDirectory = root.importDownloadDir
                download.downloadFileName = suggested

                upsertEvent(eventKey, "queued", "Intercepted download: " + sourceUrl)
                appController.logActivity("import_download_queued", "url: " + sourceUrl)

                const updateProgress = function() {
                    const total = download.totalBytes
                    const received = download.receivedBytes
                    let progressText = "Downloading " + download.downloadFileName
                    if (total > 0) {
                        const pct = Math.min(100, Math.floor((received * 100) / total))
                        progressText += " (" + pct + "%, " + formatBytes(received) + " / " + formatBytes(total) + ")"
                    } else {
                        progressText += " (" + formatBytes(received) + ")"
                    }
                    upsertEvent(eventKey, "downloading", progressText)
                }

                download.stateChanged.connect(function() {
                    if (download.state === WebEngineDownloadRequest.DownloadInProgress) {
                        updateProgress()
                    } else if (download.state === WebEngineDownloadRequest.DownloadCompleted) {
                        const localPath = download.downloadDirectory + "/" + download.downloadFileName
                        const ok = appController.importDownloadedFile(root.currentCategory, localPath)
                        const reason = appController.lastError && appController.lastError.length > 0
                            ? (" | " + appController.lastError)
                            : ""
                        upsertEvent(eventKey, ok ? "imported" : "failed", ok
                            ? ("Imported downloaded file to '" + root.currentCategory + "': " + download.downloadFileName)
                            : ("Downloaded file import failed for '" + root.currentCategory + "': " + download.downloadFileName + reason))
                        root.importStatus = ok ? "Download imported." : "Downloaded, but import failed."
                        appController.logActivity(ok ? "import_download_saved" : "import_download_failed",
                            "file: " + download.downloadFileName + ", category: " + root.currentCategory)
                    } else if (download.state === WebEngineDownloadRequest.DownloadCancelled
                               || download.state === WebEngineDownloadRequest.DownloadInterrupted) {
                        const interruptReason = download.interruptReasonString && download.interruptReasonString.length > 0
                            ? (" | " + download.interruptReasonString)
                            : ""
                        upsertEvent(eventKey, "failed", "Download did not complete: " + download.downloadFileName + interruptReason)
                        root.importStatus = "Download interrupted or cancelled."
                    }
                })

                try {
                    download.receivedBytesChanged.connect(updateProgress)
                } catch (e) {
                }

                download.accept()
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
}
