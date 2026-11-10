import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The right-click menu. On an item: Open, Open With (each app that can),
// Preview, Rename, Duplicate, Copy, Cut, Paste Into, Copy Path, Compress,
// Share (Dropbox link, Taildrop, LocalSend: whichever are available), Pin,
// Terminal, Delete. On empty
// space: Paste, New Folder, Copy Path, Terminal, hidden files. Entries show
// their keys, so the menu also teaches the shortcuts.
FolioMenu {
    id: menu

    // What was clicked ({path, name, isDir}), or null for empty space.
    property var target: null
    // The folder the click happened in.
    property string folder

    signal renameRequested(var target)
    signal deleteRequested()
    signal emptyTrashRequested()
    // In the trash the menu is about getting things back, or letting go.
    readonly property bool trashView: fileOps.inTrash(folder)

    readonly property bool onItem: !!target && target.path !== undefined
    readonly property bool onFolder: onItem && target.isDir === true
    readonly property var apps: onItem ? fileOps.appsFor(target.path) : []
    // A selected item in the folder being shown stands for the whole
    // selection, so Copy, Compress or Delete act on all of it.
    readonly property bool onSelection: onItem && target.selected === true && backend.folder.selectedCount > 1
                                        && backend.folder.indexOf(target.name) >= 0
    readonly property var paths: !onItem ? [] : onSelection ? backend.folder.selectedPaths() : [target.path]


    // Opens at the pointer, or (from the keyboard, Alt+Return) beside the
    // item it's about.
    function show(clicked, where, near) {
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
        if (near)
            popup(near, Math.min(near.width / 2, 120), near.height / 2)
        else
            popup()
    }

    FolioMenuItem {
        shown: menu.onItem && menu.trashView
        text: menu.onSelection ? qsTr("Restore %n Items", "", menu.paths.length) : qsTr("Restore")
        onTriggered: fileOps.restore(menu.paths)
    }
    FolioMenuItem {
        shown: !menu.onItem && menu.trashView
        text: qsTr("Empty Trash…")
        onTriggered: menu.emptyTrashRequested()
    }
    FolioMenuItem {
        shown: menu.onItem
        text: menu.onFolder ? qsTr("Open Folder") : qsTr("Open")
        keys: "⏎"
        onTriggered: backend.open(menu.target.path)
    }
    // Every app that says it can open this type, the default first.
    FolioMenu {
        id: openWith
        title: qsTr("Open With")
        enabled: menu.apps.length > 0
        Repeater {
            model: menu.apps
            FolioMenuItem {
                required property var modelData
                text: modelData.isDefault ? qsTr("%1 (default)").arg(modelData.name) : modelData.name
                onTriggered: fileOps.openWith(menu.target.path, modelData.id)
            }
        }
    }
    FolioMenuItem {
        shown: menu.onItem
        text: qsTr("Preview")
        keys: "Space"
        onTriggered: backend.togglePreview(menu.target.path)
    }
    MenuLine { shown: menu.onItem }
    FolioMenuItem {
        shown: !menu.trashView && (menu.onItem)
        text: qsTr("Rename…")
        keys: "F2"
        onTriggered: menu.renameRequested(menu.target)
    }
    FolioMenuItem {
        shown: !menu.trashView && (menu.onItem)
        text: qsTr("Duplicate")
        keys: "Ctrl+Shift+D"
        onTriggered: fileOps.duplicate(menu.target.path)
    }
    FolioMenuItem {
        shown: menu.onItem
        text: qsTr("Copy")
        keys: "Ctrl+C"
        onTriggered: fileOps.copy(menu.paths)
    }
    FolioMenuItem {
        shown: !menu.trashView && (menu.onItem)
        text: qsTr("Cut")
        keys: "Ctrl+X"
        onTriggered: fileOps.cut(menu.paths)
    }
    FolioMenuItem {
        shown: !menu.trashView && (!menu.onItem || menu.onFolder)
        text: menu.onFolder ? qsTr("Paste Into Folder") : qsTr("Paste")
        keys: menu.onItem ? "" : "Ctrl+V"
        enabled: fileOps.canPaste
        onTriggered: fileOps.paste(menu.onItem ? menu.target.path : menu.folder)
    }
    FolioMenuItem {
        text: qsTr("Copy Path")
        keys: "Ctrl+Shift+C"
        onTriggered: fileOps.yank(menu.onItem ? menu.paths : [menu.folder])
    }
    FolioMenuItem {
        shown: !menu.onItem && !menu.trashView
        text: qsTr("New Folder")
        keys: "Ctrl+Shift+N"
        onTriggered: fileOps.newFolder(menu.folder)
    }
    MenuLine { }
    FolioMenuItem {
        shown: !menu.trashView && (menu.onItem)
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

    FolioMenu {
        id: shareMenu
        title: qsTr("Share")
        Repeater {
            model: menu.canDropbox ? 1 : 0
            FolioMenuItem {
                text: qsTr("Dropbox Link")
                onTriggered: fileOps.dropboxLink(menu.target.path)
            }
        }
        Repeater {
            model: menu.canLocalSend ? 1 : 0
            FolioMenuItem {
                text: qsTr("LocalSend…")
                onTriggered: fileOps.shareLocalSend(menu.paths)
            }
        }
    }
    // Taildrop is its own menu inside Share, one entry per machine; it's
    // added only while there are machines to send to.
    Instantiator {
        model: menu.canTaildrop ? 1 : 0
        delegate: FolioMenu {
            title: qsTr("Taildrop")
            Repeater {
                model: places.peers
                FolioMenuItem {
                    required property var modelData
                        text: modelData.name
                    onTriggered: fileOps.shareTaildrop(menu.paths, modelData.host)
                }
            }
        }
        onObjectAdded: (index, object) => shareMenu.insertMenu(0, object)
        onObjectRemoved: (index, object) => shareMenu.removeMenu(object)
    }
    FolioMenuItem {
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
    FolioMenuItem {
        shown: !menu.onItem || menu.onFolder
        text: qsTr("Open Terminal Here")
        onTriggered: fileOps.openTerminal(menu.onItem ? menu.target.path : menu.folder)
    }
    FolioMenuItem {
        shown: !menu.onItem
        text: backend.folder.showHidden ? qsTr("Hide Hidden Files") : qsTr("Show Hidden Files")
        keys: "Ctrl+H"
        onTriggered: backend.folder.showHidden = !backend.folder.showHidden
    }
    MenuLine { shown: menu.onItem }
    // Delete moves to the trash; Restore in any file manager brings it back.
    FolioMenuItem {
        shown: menu.onItem
        text: menu.trashView ? qsTr("Delete Permanently…")
            : menu.onSelection ? qsTr("Delete %n Items", "", menu.paths.length) : qsTr("Delete")
        keys: "Delete"
        onTriggered: menu.trashView ? menu.deleteRequested() : fileOps.trash(menu.paths)
    }
}
