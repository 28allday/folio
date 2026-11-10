import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCore

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
    property string viewMode: "grid"
    // The selected name, carried across a switch of view.
    property string lastName: ""
    property string loadedPath: ""
    // While a text field has the keyboard (renaming, a password), single-key
    // and clipboard shortcuts stand aside so typing works.
    readonly property bool typing: rename.visible || backend.mounter.asking || pathBar.editing
    readonly property var selectedPaths: current.path ? [current.path] : []
    onCurrentChanged: {
        if (current.name)
            lastName = current.name
        // An open preview stays on the selected item.
        if (backend.previewing && current.path)
            backend.followSelection(current.path)
    }

    function cycleView() {
        viewMode = viewMode === "grid" ? "list" : viewMode === "list" ? "columns" : "grid"
    }

    FileMenu {
        id: fileMenu
        objectName: "fileMenu"
        onRenameRequested: (target) => rename.open(target)
    }

    // Remembers the view between launches (~/.config/folio/folio.conf).
    Settings {
        property alias viewMode: win.viewMode
    }

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
        const index = view.item ? view.item.currentIndex : -1
        return index >= 0 ? backend.folder.get(index) : ({})
    }

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: backend.togglePreview(win.current.path || "") }
    // Pins the selected folder, or the folder being shown when a file is
    // selected; pressed again, unpins it.
    function togglePin() {
        const target = win.current.isDir ? win.current.path : backend.path
        if (places.isPinned(target)) {
            places.unpin(target)
            return
        }
        const problem = places.pin(target)
        if (problem.length > 0)
            backend.showMessage(problem)
    }
    Shortcut { sequence: "Ctrl+1"; context: Qt.ApplicationShortcut; onActivated: win.viewMode = "grid" }
    Shortcut { sequence: "Ctrl+2"; context: Qt.ApplicationShortcut; onActivated: win.viewMode = "list" }
    Shortcut { sequence: "Ctrl+3"; context: Qt.ApplicationShortcut; onActivated: win.viewMode = "columns" }
    Shortcut { sequences: [StandardKey.Copy]; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: fileOps.copy(win.selectedPaths) }
    Shortcut { sequences: [StandardKey.Cut]; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: fileOps.cut(win.selectedPaths) }
    Shortcut { sequences: [StandardKey.Paste]; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: fileOps.paste(backend.path) }
    // "Yank": the selected path (or the folder's) as text, for a terminal.
    Shortcut { sequence: "Ctrl+Shift+C"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: fileOps.yank(win.selectedPaths.length > 0 ? win.selectedPaths : [backend.path]) }
    Shortcut { sequence: "Delete"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: fileOps.trash(win.selectedPaths) }
    Shortcut { sequence: "F2"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: if (win.current.path) rename.open(win.current) }
    Shortcut { sequence: "Ctrl+Shift+D"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: if (win.current.path) fileOps.duplicate(win.current.path) }
    Shortcut { sequence: "Ctrl+Shift+N"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: fileOps.newFolder(backend.path) }
    // Tab hands the keyboard between the sidebar and the files.
    Shortcut {
        sequences: ["Tab", "Backtab"]
        context: Qt.ApplicationShortcut
        enabled: !win.typing
        onActivated: sidebar.activeFocus ? (view.item && view.item.focusView()) : sidebar.focusSidebar()
    }
    Shortcut { sequences: ["Ctrl+L", "Alt+D"]; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: pathBar.editPath() }
    Shortcut { sequence: "Ctrl+D"; context: Qt.ApplicationShortcut; onActivated: win.togglePin() }
    Shortcut { sequence: "Ctrl+I"; context: Qt.ApplicationShortcut; onActivated: win.previewVisible = !win.previewVisible }
    Shortcut { sequences: ["Return", "Enter"]; context: Qt.ApplicationShortcut; enabled: !win.typing && !sidebar.activeFocus; onActivated: if (win.current.path) backend.open(win.current.path) }
    Shortcut { sequences: ["Backspace", "Alt+Up"]; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: backend.goUp() }
    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; context: Qt.ApplicationShortcut; onActivated: backend.back() }
    Shortcut { sequences: ["Alt+Right", StandardKey.Forward]; context: Qt.ApplicationShortcut; onActivated: backend.forward() }
    Shortcut { sequence: "Alt+Home"; context: Qt.ApplicationShortcut; onActivated: backend.navigate(places.home) }
    Shortcut { sequence: "Ctrl+H"; context: Qt.ApplicationShortcut; onActivated: backend.folder.showHidden = !backend.folder.showHidden }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: !win.typing; onActivated: {
        const modes = ["name", "kind", "modified", "oldest", "size"]
        backend.folder.sortMode = modes[(modes.indexOf(backend.folder.sortMode) + 1) % modes.length]
    } }
    Shortcut { sequences: ["F5", StandardKey.Refresh]; context: Qt.ApplicationShortcut; onActivated: { backend.folder.reload(); places.refresh() } }

    Connections {
        target: backend
        function onSelectRequested(name) { if (view.item) view.item.select(name) }
        function onActivateRequested() { win.raise(); win.requestActivate() }
    }

    Connections {
        target: view.item
        ignoreUnknownSignals: true
        function onContextMenu(item, folder) { fileMenu.show(item, folder) }
    }

    // Finished file work selects what it made (the pasted file, the new
    // folder, the new name) once the folder has re-read.
    Connections {
        target: fileOps
        function onDone(folder, name) { if (folder === backend.path) backend.expectSelection(name) }
        function onFailed(message) { backend.showMessage(message) }
        function onNotice(notice) { backend.showNotice(notice) }
    }

    Connections {
        target: backend.folder
        // A folder arriving selects where we came from (or the first item);
        // the same folder re-read (a remembered listing refreshed, or files
        // changing on disk) keeps what was selected.
        function onLoaded() {
            if (!view.item)
                return
            const pending = backend.takeSelection()
            const same = backend.folder.path === win.loadedPath
            win.loadedPath = backend.folder.path
            view.item.select(pending || (same ? win.lastName : ""))
        }
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
                id: pathBar
                onEditDone: if (view.item) view.item.focusView()
                Layout.fillWidth: true
                previewVisible: win.previewVisible
                viewMode: win.viewMode
                onTogglePreview: win.previewVisible = !win.previewVisible
                onCycleView: win.cycleView()
            }

            // Problems and slow work are said in the window, not swallowed.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                visible: backend.message.length > 0 || backend.busy.length > 0 || fileOps.busy.length > 0 || backend.folder.error.length > 0 || backend.notice.length > 0
                color: backend.message.length > 0 || backend.folder.error.length > 0 ? win.tint(theme.red, 0.14) : win.tint(theme.accent, 0.10)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 12
                    Text {
                        Layout.fillWidth: true
                        text: backend.message || backend.folder.error || backend.busy || fileOps.busy || backend.notice
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
                    id: sidebar
                    onFinished: if (view.item) view.item.focusView()
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
                    }

                    // Grid, list or columns: each takes the folder's model and
                    // keeps the window's one selection.
                    Loader {
                        id: view
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: win.viewMode === "grid" ? 24 : win.viewMode === "list" ? 20 : 0
                        Layout.rightMargin: win.viewMode === "columns" ? 0 : 24
                        sourceComponent: win.viewMode === "list" ? listView
                                       : win.viewMode === "columns" ? columnsView
                                       : gridView
                        // A new view picks up the selection the old one had.
                        onLoaded: { item.select(win.lastName); item.focusView() }
                    }
                    Component { id: gridView; FolderGrid { } }
                    Component { id: listView; FolderList { } }
                    Component { id: columnsView; FolderColumns { } }
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

        RenameDialog {
            id: rename
            anchors.fill: parent
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
