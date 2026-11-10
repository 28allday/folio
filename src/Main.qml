import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 1280
    height: 800
    minimumWidth: 720
    minimumHeight: 460
    visible: true
    title: backend.title.length > 0 ? backend.title : "Folio"
    color: theme.background

    Material.theme: theme.light ? Material.Light : Material.Dark
    Material.accent: theme.accent
    Material.foreground: theme.foreground
    Material.background: theme.background
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    property bool previewVisible: true

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function formatSize(bytes) {
        const units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB")]
        let i = 0
        let value = bytes
        while (value >= 1000 && i < units.length - 1) { value /= 1000; ++i }
        return value.toLocaleString(Qt.locale(), "f", i === 0 ? 0 : 1) + " " + units[i]
    }

    readonly property var current: {
        // Re-read when the folder changes underneath the selection.
        backend.folder.count
        return grid.currentIndex >= 0 ? backend.folder.get(grid.currentIndex) : ({})
    }

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.togglePreview(win.current.path || "") }
    Shortcut { sequence: "Ctrl+I"; context: Qt.ApplicationShortcut; onActivated: win.previewVisible = !win.previewVisible }
    Shortcut { sequences: ["Return", "Enter"]; context: Qt.ApplicationShortcut; onActivated: if (win.current.path) backend.open(win.current.path) }
    Shortcut { sequences: ["Backspace", "Alt+Up"]; context: Qt.ApplicationShortcut; onActivated: backend.goUp() }
    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; context: Qt.ApplicationShortcut; onActivated: backend.back() }
    Shortcut { sequences: ["Alt+Right", StandardKey.Forward]; context: Qt.ApplicationShortcut; onActivated: backend.forward() }
    Shortcut { sequence: "Alt+Home"; context: Qt.ApplicationShortcut; onActivated: backend.navigate(places.places.length > 0 ? places.places[0].path : "/") }
    Shortcut { sequence: "Ctrl+H"; context: Qt.ApplicationShortcut; onActivated: backend.folder.showHidden = !backend.folder.showHidden }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; onActivated: backend.folder.sortMode = backend.folder.sortMode === "name" ? "modified" : "name" }
    Shortcut { sequences: ["F5", StandardKey.Refresh]; context: Qt.ApplicationShortcut; onActivated: { backend.folder.reload(); places.refresh() } }

    Connections {
        target: backend
        function onSelectRequested(name) { grid.select(name) }
        function onActivateRequested() { win.raise(); win.requestActivate() }
    }

    Connections {
        target: backend.folder
        function onLoaded() { grid.select(backend.takeSelection()) }
    }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PathBar {
                Layout.fillWidth: true
                previewVisible: win.previewVisible
                onTogglePreview: win.previewVisible = !win.previewVisible
            }

            // Problems and slow work are said in the window, not swallowed.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                visible: backend.message.length > 0 || backend.busy.length > 0 || backend.folder.error.length > 0
                color: backend.message.length > 0 || backend.folder.error.length > 0 ? win.tint(theme.red, 0.14) : win.tint(theme.accent, 0.10)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 12
                    Text {
                        Layout.fillWidth: true
                        text: backend.message || backend.folder.error || backend.busy
                        color: theme.brightForeground
                        elide: Text.ElideRight
                    }
                    IconButton {
                        visible: backend.message.length > 0
                        glyph: "close"
                        text: qsTr("Dismiss")
                        onClicked: backend.dismissMessage()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Sidebar {
                    Layout.preferredWidth: 236
                    Layout.fillHeight: true
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: win.tint(theme.foreground, 0.12) }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 28
                        Layout.leftMargin: 36
                        Layout.rightMargin: 36
                        Text {
                            Layout.fillWidth: true
                            text: backend.title
                            color: theme.brightForeground
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: backend.folder.sortMode === "name" ? qsTr("By name") : qsTr("Newest first")
                            color: theme.secondaryForeground
                            font.pixelSize: 12
                        }
                    }

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        clip: true
                        focus: true
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: backend.folder
                        readonly property int columns: Math.max(1, Math.floor(width / 168))
                        cellWidth: Math.floor(width / columns)
                        cellHeight: 176
                        highlightFollowsCurrentItem: false
                        // An open preview stays on the selected item.
                        onCurrentIndexChanged: if (backend.previewing) backend.followSelection(backend.folder.get(currentIndex).path || "")
                        ScrollBar.vertical: ScrollBar { }

                        function select(name) {
                            const found = name ? backend.folder.indexOf(name) : -1
                            currentIndex = found >= 0 ? found : (count > 0 ? 0 : -1)
                            if (currentIndex >= 0)
                                positionViewAtIndex(currentIndex, GridView.Contain)
                        }

                        delegate: FileTile {
                            width: grid.cellWidth
                            height: grid.cellHeight
                            current: GridView.isCurrentItem
                            onClicked: { grid.currentIndex = index; grid.forceActiveFocus() }
                            onActivated: backend.open(path)
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: grid.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
                            text: qsTr("This folder is empty")
                            color: theme.secondaryForeground
                        }
                    }
                }

                PreviewPane {
                    visible: win.previewVisible && win.width >= 960
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    item: win.current
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                color: theme.background
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: win.tint(theme.foreground, 0.12) }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("%n items", "", backend.folder.count)
                              + (backend.folder.folderCount > 0 ? " · " + qsTr("%n folders", "", backend.folder.folderCount) : "")
                        color: theme.secondaryForeground
                        font.pixelSize: 12
                    }
                    Text {
                        text: win.current.name ? (win.current.isDir ? win.current.name : win.current.name + " · " + win.formatSize(win.current.size)) : ""
                        color: theme.foreground
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: win.width * 0.5
                    }
                    Text { text: "?"; color: theme.secondaryForeground; font.pixelSize: 12; Layout.leftMargin: 16 }
                }
            }
        }

        // The mouse's back and forward thumb buttons move through history,
        // as in a browser. Only those buttons are taken; every other click
        // passes through to what's underneath.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => mouse.button === Qt.BackButton ? backend.back() : backend.forward()
        }

        MountPrompt {
            anchors.fill: parent
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
