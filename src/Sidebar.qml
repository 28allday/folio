import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Home's folders, pinned folders, drives and tailnet machines. The one holding the current folder
// stays lit while you dig into it, so you always know which root you're under.
Rectangle {
    id: sidebar

    color: theme.background
    // A long tailnet scrolls inside the sidebar instead of spilling over
    // the status bar below it.
    clip: true

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // The deepest place the current folder sits under.
    readonly property string activePath: {
        let best = ""
        const here = backend.path
        for (const list of [places.places, places.pinned, places.devices]) {
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

        background: Rectangle {
            radius: Math.min(4, theme.radius)
            color: row.active ? row.tint(theme.accent, 0.16)
                 : row.hovered && row.enabled ? row.tint(theme.foreground, 0.06) : "transparent"
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

            Item { implicitHeight: 20; visible: places.devices.length > 0 }
            SectionLabel { text: qsTr("Devices"); visible: places.devices.length > 0 }
            Repeater {
                model: places.devices
                PlaceRow {
                    required property var modelData
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
                    text: modelData.name
                    glyph: "peer"
                    active: backend.path.indexOf("/sftp:host=" + modelData.host) >= 0
                    onClicked: backend.openPeer(modelData.host)
                }
            }
        }
    }
}
