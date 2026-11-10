import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Places, devices and tailnet machines. The place holding the current folder
// stays lit while you dig into it, so you always know which root you're under.
Rectangle {
    id: sidebar

    color: theme.background

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // The deepest place the current folder sits under.
    readonly property string activePath: {
        let best = ""
        const here = backend.path
        for (const list of [places.places, places.devices]) {
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

            SectionLabel { text: qsTr("Places") }
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
