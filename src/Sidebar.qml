import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Home's folders, pinned folders, views, drives and tailnet machines. The one holding the current folder
// stays lit while you dig into it, so you always know which root you're under.
Rectangle {
    id: sidebar

    color: theme.background
    // A long tailnet scrolls inside the sidebar instead of spilling over
    // the status bar below it.
    clip: true

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Keyboard: Tab moves here from the files and back. ↑ ↓ move between
    // rows, ⏎ (or →) opens one and hands the keyboard back to the files.
    signal finished()
    property int cursor: 0
    readonly property var rows: [].concat(
        places.places.map(p => ({ path: p.path })),
        places.pinned.map(p => ({ path: p.path })),
        places.views.map(p => ({ path: p.path })),
        places.devices.map(p => ({ path: p.path })),
        places.peers.map(p => ({ host: p.host })))
    readonly property int pinnedAt: places.places.length
    readonly property int viewsAt: pinnedAt + places.pinned.length
    readonly property int devicesAt: viewsAt + places.views.length
    readonly property int peersAt: devicesAt + places.devices.length

    function focusSidebar() {
        // Start on the row for where we are, or the top.
        let at = 0
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].path !== undefined && rows[i].path === activePath)
                at = i
        cursor = at
        forceActiveFocus()
    }
    function activate(i) {
        const row = rows[i]
        if (!row)
            return
        if (row.host !== undefined)
            backend.openPeer(row.host)
        else
            backend.navigate(row.path)
        finished()
    }
    function reveal(item) {
        const y = item.mapToItem(column, 0, 0).y
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y - 20)
        else if (y + item.height > flick.contentY + flick.height)
            flick.contentY = y + item.height - flick.height + 20
    }

    Keys.onUpPressed: cursor = Math.max(0, cursor - 1)
    Keys.onDownPressed: cursor = Math.min(rows.length - 1, cursor + 1)
    Keys.onReturnPressed: activate(cursor)
    Keys.onEnterPressed: activate(cursor)
    Keys.onRightPressed: activate(cursor)
    Keys.onEscapePressed: finished()

    // The deepest place the current folder sits under.
    readonly property string activePath: {
        let best = ""
        const here = backend.path
        for (const list of [places.places, places.pinned, places.views, places.devices]) {
            for (const p of list) {
                if ((here === p.path || here.startsWith(p.path === "/" ? "/" : p.path + "/")) && p.path.length > best.length && p.path !== "/")
                    best = p.path
            }
        }
        return best
    }

    function statusText(status) {
        // Up to date is the normal state and says nothing; only syncing or
        // a stopped Dropbox is worth a word.
        return status === "syncing" ? qsTr("syncing")
             : status === "stopped" ? qsTr("stopped") : ""
    }

    component SectionLabel: Text {
        Layout.leftMargin: 14
        Layout.bottomMargin: 6
        color: theme.secondaryForeground
        font.pixelSize: 11
        font.letterSpacing: 1.3
        font.capitalization: Font.AllUppercase
    }

    component PlaceRow: AbstractButton {
        id: row
        property string glyph
        property bool active: false
        // The keyboard is on this row (the sidebar has focus).
        property bool keyed: false
        property bool dim: false
        property string status
        property color statusColor: theme.green

        Layout.fillWidth: true
        implicitHeight: 34
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        Accessible.name: text

        // Inline components don't see the file's ids, so this keeps its own.
        function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Keyboard: Tab moves here from the files and back. ↑ ↓ move between
    // rows, ⏎ (or →) opens one and hands the keyboard back to the files.
    signal finished()
    property int cursor: 0
    readonly property var rows: [].concat(
        places.places.map(p => ({ path: p.path })),
        places.pinned.map(p => ({ path: p.path })),
        places.views.map(p => ({ path: p.path })),
        places.devices.map(p => ({ path: p.path })),
        places.peers.map(p => ({ host: p.host })))
    readonly property int pinnedAt: places.places.length
    readonly property int viewsAt: pinnedAt + places.pinned.length
    readonly property int devicesAt: viewsAt + places.views.length
    readonly property int peersAt: devicesAt + places.devices.length

    function focusSidebar() {
        // Start on the row for where we are, or the top.
        let at = 0
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].path !== undefined && rows[i].path === activePath)
                at = i
        cursor = at
        forceActiveFocus()
    }
    function activate(i) {
        const row = rows[i]
        if (!row)
            return
        if (row.host !== undefined)
            backend.openPeer(row.host)
        else
            backend.navigate(row.path)
        finished()
    }
    function reveal(item) {
        const y = item.mapToItem(column, 0, 0).y
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y - 20)
        else if (y + item.height > flick.contentY + flick.height)
            flick.contentY = y + item.height - flick.height + 20
    }

    Keys.onUpPressed: cursor = Math.max(0, cursor - 1)
    Keys.onDownPressed: cursor = Math.min(rows.length - 1, cursor + 1)
    Keys.onReturnPressed: activate(cursor)
    Keys.onEnterPressed: activate(cursor)
    Keys.onRightPressed: activate(cursor)
    Keys.onEscapePressed: finished()

        background: Rectangle {
            radius: Math.min(4, theme.radius)
            color: row.active ? row.tint(theme.accent, 0.16)
                 : row.hovered && row.enabled ? row.tint(theme.foreground, 0.06) : "transparent"
            border.width: row.keyed ? 1 : 0
            border.color: theme.accent
        }
        contentItem: RowLayout {
            spacing: 14
            Item { implicitWidth: 0 }
            Glyph { name: row.glyph; color: row.active ? theme.brightForeground : row.dim ? theme.secondaryForeground : theme.foreground }
            Text {
                Layout.fillWidth: true
                text: row.text
                elide: Text.ElideRight
                color: row.active ? theme.brightForeground : row.dim ? theme.secondaryForeground : theme.foreground
            }
            Text { visible: row.status.length > 0; text: row.status; color: row.statusColor; font.pixelSize: 11 }
            Item { implicitWidth: 0 }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            for (const url of drop.urls) {
                const path = decodeURIComponent(url.toString().replace(/^file:\/\//, ""))
                const problem = places.pin(path)
                if (problem.length > 0)
                    backend.showMessage(problem)
            }
            drop.accept(Qt.LinkAction)
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            x: 12
            y: 20
            width: sidebar.width - 24
            spacing: 1

            // The section's label is home itself: click it to go there.
            SectionLabel {
                text: qsTr("Home")
                color: backend.path === places.home ? theme.accent
                     : homeHover.hovered ? theme.foreground : theme.secondaryForeground
                Accessible.role: Accessible.Button
                HoverHandler { id: homeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: backend.navigate(places.home) }
            }
            Repeater {
                model: places.places
                PlaceRow {
                    required property var modelData
                    required property int index
                    keyed: sidebar.activeFocus && sidebar.cursor === 0 + index
                    onKeyedChanged: if (keyed) sidebar.reveal(this)
                    text: modelData.name
                    glyph: modelData.icon
                    active: sidebar.activePath === modelData.path
                    status: sidebar.statusText(modelData.status)
                    statusColor: modelData.status === "stopped" ? theme.red : modelData.status === "syncing" ? theme.yellow : theme.green
                    onClicked: backend.navigate(modelData.path)
                }
            }

            // Pinned folders from anywhere, kept in GTK's bookmarks. While a
            // folder is dragged over the sidebar, the section shows (even
            // empty) as the place to drop it.
            Item { implicitHeight: 20; visible: places.pinned.length > 0 || drop.containsDrag }
            SectionLabel { text: qsTr("Pinned"); visible: places.pinned.length > 0 || drop.containsDrag }
            Repeater {
                model: places.pinned
                PlaceRow {
                    id: pinRow
                    required property var modelData
                    required property int index
                    keyed: sidebar.activeFocus && sidebar.cursor === sidebar.pinnedAt + index
                    onKeyedChanged: if (keyed) sidebar.reveal(this)
                    text: modelData.name
                    glyph: "folder"
                    active: sidebar.activePath === modelData.path
                    onClicked: backend.navigate(modelData.path)
                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 28
                        implicitHeight: 28
                        visible: pinRow.hovered || hovered
                        glyph: "close"
                        text: qsTr("Unpin")
                        onClicked: places.unpin(pinRow.modelData.path)
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                visible: drop.containsDrag
                color: sidebar.tint(theme.accent, 0.10)
                border.width: 1
                border.color: theme.accent
                radius: Math.min(4, theme.radius)
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Drop to pin")
                    color: theme.accent
                    font.pixelSize: 12
                }
            }

            // Views: lists that aren't a folder of their own.
            Item { implicitHeight: 20 }
            SectionLabel { text: qsTr("Views") }
            Repeater {
                model: places.views
                PlaceRow {
                    required property var modelData
                    required property int index
                    text: modelData.name
                    glyph: modelData.icon
                    active: sidebar.activePath === modelData.path
                    onClicked: backend.navigate(modelData.path)
                    keyed: sidebar.activeFocus && sidebar.cursor === sidebar.viewsAt + index
                    onKeyedChanged: if (keyed) sidebar.reveal(this)
                }
            }

            Item { implicitHeight: 20; visible: places.devices.length > 0 }
            SectionLabel { text: qsTr("Devices"); visible: places.devices.length > 0 }
            Repeater {
                model: places.devices
                PlaceRow {
                    required property var modelData
                    required property int index
                    keyed: sidebar.activeFocus && sidebar.cursor === sidebar.devicesAt + index
                    onKeyedChanged: if (keyed) sidebar.reveal(this)
                    text: modelData.name
                    glyph: "drive"
                    active: sidebar.activePath === modelData.path
                    onClicked: backend.navigate(modelData.path)
                }
            }

            Item { implicitHeight: 20; visible: places.peers.length > 0 }
            SectionLabel { text: qsTr("Tailnet"); visible: places.peers.length > 0 }
            Repeater {
                model: places.peers
                PlaceRow {
                    required property var modelData
                    required property int index
                    keyed: sidebar.activeFocus && sidebar.cursor === sidebar.peersAt + index
                    onKeyedChanged: if (keyed) sidebar.reveal(this)
                    text: modelData.name
                    glyph: "peer"
                    active: backend.path.indexOf("/sftp:host=" + modelData.host) >= 0
                    onClicked: backend.openPeer(modelData.host)
                }
            }
        }
    }
}
