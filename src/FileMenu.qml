import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The right-click menu. On an item: Open, Open With (each app that can),
// Preview, Rename, Duplicate, Copy, Cut, Paste Into, Copy Path, Compress,
// Share (Dropbox link, Taildrop, LocalSend: whichever are available), Pin,
// Terminal, Delete. On empty
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
    // A selected item in the folder being shown stands for the whole
    // selection, so Copy, Compress or Delete act on all of it.
    readonly property bool onSelection: onItem && target.selected === true && backend.folder.selectedCount > 1
                                        && backend.folder.indexOf(target.name) >= 0
    readonly property var paths: !onItem ? [] : onSelection ? backend.folder.selectedPaths() : [target.path]

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
                const shown = entry.subMenu === shareMenu ? canShare : onItem
                entry.visible = shown
                entry.height = shown ? entry.implicitHeight : 0
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
    // Share offers only what this machine has: a Dropbox link for things in
    // the Dropbox folder (while Dropbox runs), Taildrop to the online
    // tailnet machines, and LocalSend when it's installed. With none of
    // them, there's no Share at all.
    readonly property bool canDropbox: onItem && target.path.startsWith(places.home + "/Dropbox/")
                                       && places.dropboxStatus !== "" && places.dropboxStatus !== "stopped"
    readonly property bool canTaildrop: onItem && places.peers.length > 0
    readonly property bool canLocalSend: onItem && fileOps.hasLocalSend()
    readonly property bool canShare: canDropbox || canTaildrop || canLocalSend

    SubMenu {
        id: shareMenu
        title: qsTr("Share")
        Repeater {
            model: menu.canDropbox ? 1 : 0
            MenuItem {
                implicitHeight: 34
                text: qsTr("Dropbox Link")
                onTriggered: fileOps.dropboxLink(menu.target.path)
            }
        }
        Repeater {
            model: menu.canLocalSend ? 1 : 0
            MenuItem {
                implicitHeight: 34
                text: qsTr("LocalSend…")
                onTriggered: fileOps.shareLocalSend(menu.paths)
            }
        }
    }
    // Taildrop is its own menu inside Share, one entry per machine; it's
    // added only while there are machines to send to.
    Instantiator {
        model: menu.canTaildrop ? 1 : 0
        delegate: SubMenu {
            title: qsTr("Taildrop")
            Repeater {
                model: places.peers
                MenuItem {
                    required property var modelData
                    implicitHeight: 34
                    text: modelData.name
                    onTriggered: fileOps.shareTaildrop(menu.paths, modelData.host)
                }
            }
        }
        onObjectAdded: (index, object) => shareMenu.insertMenu(0, object)
        onObjectRemoved: (index, object) => shareMenu.removeMenu(object)
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
        text: menu.onSelection ? qsTr("Delete %n Items", "", menu.paths.length) : qsTr("Delete")
        keys: "Delete"
        onTriggered: fileOps.trash(menu.paths)
    }
}
