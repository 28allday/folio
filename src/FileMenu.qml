import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The right-click menu. On an item: Open, Open With (each app that can),
// Preview, Rename, Duplicate, Copy, Cut, Paste Into, Copy Path, Compress,
// Share (LocalSend or a tailnet machine), Pin, Terminal, Delete. On empty
// space: Paste, New Folder, Copy Path, Terminal, hidden files. Entries show
// their keys, so the menu also teaches the shortcuts.
Menu {
    id: menu

    // What was clicked ({path, name, isDir}), or null for empty space.
    property var target: null
    // The folder the click happened in.
    property string folder

    signal renameRequested(var target)

    readonly property bool onItem: !!target && target.path !== undefined
    readonly property bool onFolder: onItem && target.isDir === true
    readonly property var apps: onItem ? fileOps.appsFor(target.path) : []
    readonly property var paths: onItem ? [target.path] : []

    Material.background: theme.background
    Material.foreground: theme.foreground
    Material.accent: theme.accent
    Material.roundedScale: theme.radius
    Material.elevation: 2

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Submenu entries (Open With, Share) match the rest in size.
    font.pixelSize: 13
    delegate: MenuItem { implicitHeight: 34 }

    background: Rectangle {
        implicitWidth: 260
        color: theme.background
        border.width: 1
        border.color: menu.tint(theme.foreground, 0.16)
        radius: Math.min(6, theme.radius)
    }

    function show(clicked, where) {
        target = clicked
        folder = where
        // Submenus (Open With, Share) only make sense on an item; their
        // entries are made by Menu itself, so they're hidden here.
        for (let i = 0; i < count; ++i) {
            const entry = itemAt(i)
            if (entry && entry.subMenu) {
                entry.visible = onItem
                entry.height = onItem ? entry.implicitHeight : 0
            }
        }
        popup()
    }

    // A menu entry with its key on the right. Hidden entries take no room.
    component Entry: MenuItem {
        id: entry
        property string keys
        property bool shown: true
        visible: shown
        height: shown ? implicitHeight : 0
        implicitHeight: 34
        contentItem: Item {
            implicitWidth: label.implicitWidth + hint.implicitWidth + 48
            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: entry.text
                color: entry.enabled ? theme.foreground : theme.secondaryForeground
            }
            Text {
                id: hint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: entry.keys
                color: theme.secondaryForeground
                font.pixelSize: 11
            }
        }
    }
    component Line: MenuSeparator {
        property bool shown: true
        visible: shown
        height: shown ? implicitHeight : 0
    }
    component SubMenu: Menu {
        id: sub
        font.pixelSize: 13
        background: Rectangle {
            implicitWidth: 240
            color: theme.background
            border.width: 1
            border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16)
            radius: Math.min(6, theme.radius)
        }
        Material.background: theme.background
        Material.foreground: theme.foreground
        Material.accent: theme.accent
        Material.roundedScale: theme.radius
    }

    Entry {
        shown: menu.onItem
        text: menu.onFolder ? qsTr("Open Folder") : qsTr("Open")
        keys: "⏎"
        onTriggered: backend.open(menu.target.path)
    }
    // Every app that says it can open this type, the default first.
    SubMenu {
        id: openWith
        title: qsTr("Open With")
        enabled: menu.apps.length > 0
        Repeater {
            model: menu.apps
            MenuItem {
                required property var modelData
                implicitHeight: 34
                text: modelData.isDefault ? qsTr("%1 (default)").arg(modelData.name) : modelData.name
                onTriggered: fileOps.openWith(menu.target.path, modelData.id)
            }
        }
    }
    Entry {
        shown: menu.onItem
        text: qsTr("Preview")
        keys: "Space"
        onTriggered: backend.togglePreview(menu.target.path)
    }
    Line { shown: menu.onItem }
    Entry {
        shown: menu.onItem
        text: qsTr("Rename…")
        keys: "F2"
        onTriggered: menu.renameRequested(menu.target)
    }
    Entry {
        shown: menu.onItem
        text: qsTr("Duplicate")
        keys: "Ctrl+Shift+D"
        onTriggered: fileOps.duplicate(menu.target.path)
    }
    Entry {
        shown: menu.onItem
        text: qsTr("Copy")
        keys: "Ctrl+C"
        onTriggered: fileOps.copy(menu.paths)
    }
    Entry {
        shown: menu.onItem
        text: qsTr("Cut")
        keys: "Ctrl+X"
        onTriggered: fileOps.cut(menu.paths)
    }
    Entry {
        shown: !menu.onItem || menu.onFolder
        text: menu.onFolder ? qsTr("Paste Into Folder") : qsTr("Paste")
        keys: menu.onItem ? "" : "Ctrl+V"
        enabled: fileOps.canPaste
        onTriggered: fileOps.paste(menu.onItem ? menu.target.path : menu.folder)
    }
    Entry {
        text: qsTr("Copy Path")
        keys: "Ctrl+Shift+C"
        onTriggered: fileOps.yank(menu.onItem ? menu.paths : [menu.folder])
    }
    Entry {
        shown: !menu.onItem
        text: qsTr("New Folder")
        keys: "Ctrl+Shift+N"
        onTriggered: fileOps.newFolder(menu.folder)
    }
    Line { }
    Entry {
        shown: menu.onItem
        text: qsTr("Compress")
        onTriggered: fileOps.compress(menu.paths)
    }
    SubMenu {
        title: qsTr("Share")
        enabled: menu.onItem
        MenuItem {
            implicitHeight: 34
            text: qsTr("Nearby with LocalSend…")
            onTriggered: fileOps.shareLocalSend(menu.paths)
        }
        Repeater {
            model: places.peers
            MenuItem {
                required property var modelData
                implicitHeight: 34
                text: qsTr("To %1 (Taildrop)").arg(modelData.name)
                onTriggered: fileOps.shareTaildrop(menu.paths, modelData.host)
            }
        }
    }
    Entry {
        shown: menu.onFolder
        text: menu.onFolder && places.isPinned(menu.target.path) ? qsTr("Unpin") : qsTr("Pin")
        keys: "Ctrl+D"
        onTriggered: {
            if (places.isPinned(menu.target.path)) {
                places.unpin(menu.target.path)
                return
            }
            const problem = places.pin(menu.target.path)
            if (problem.length > 0)
                backend.showMessage(problem)
        }
    }
    Entry {
        shown: !menu.onItem || menu.onFolder
        text: qsTr("Open Terminal Here")
        onTriggered: fileOps.openTerminal(menu.onItem ? menu.target.path : menu.folder)
    }
    Entry {
        shown: !menu.onItem
        text: backend.folder.showHidden ? qsTr("Hide Hidden Files") : qsTr("Show Hidden Files")
        keys: "Ctrl+H"
        onTriggered: backend.folder.showHidden = !backend.folder.showHidden
    }
    Line { shown: menu.onItem }
    // Delete moves to the trash; Restore in any file manager brings it back.
    Entry {
        shown: menu.onItem
        text: qsTr("Delete")
        keys: "Delete"
        onTriggered: fileOps.trash(menu.paths)
    }
}
