import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Places, devices and tailnet machines. The place holding the current folder
// stays lit while you dig into it, so you always know which root you're under.
Rectangle {
    id: sidebar

    color: theme.background

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function formatSize(bytes) {
        const units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB")]
        let i = 0
        let value = bytes
        while (value >= 1000 && i < units.length - 1) { value /= 1000; ++i }
        return value.toLocaleString(Qt.locale(), "f", i === 0 ? 0 : 1) + " " + units[i]
    }

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
        return status === "synced" ? qsTr("synced")
             : status === "syncing" ? qsTr("syncing")
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

            Item { implicitHeight: 20 }
            SectionLabel { text: qsTr("Devices") }
            Repeater {
                model: places.devices
                AbstractButton {
                    id: device
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 64
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    Accessible.name: modelData.name
                    onClicked: backend.navigate(modelData.path)
                    background: Rectangle {
                        radius: Math.min(4, theme.radius)
                        color: sidebar.activePath === device.modelData.path ? sidebar.tint(theme.accent, 0.16)
                             : device.hovered ? sidebar.tint(theme.foreground, 0.06) : "transparent"
                    }
                    contentItem: ColumnLayout {
                        spacing: 7
                        RowLayout {
                            spacing: 14
                            Layout.leftMargin: 14
                            Glyph { name: "drive" }
                            Text { text: device.modelData.name; color: theme.foreground; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Rectangle {
                            Layout.leftMargin: 46
                            Layout.rightMargin: 14
                            Layout.fillWidth: true
                            implicitHeight: 3
                            color: sidebar.tint(theme.foreground, 0.12)
                            Rectangle { width: parent.width * device.modelData.used; height: 3; color: theme.accent }
                        }
                        Text {
                            Layout.leftMargin: 46
                            text: qsTr("%1 free of %2").arg(sidebar.formatSize(device.modelData.free)).arg(sidebar.formatSize(device.modelData.total))
                            color: theme.secondaryForeground
                            font.pixelSize: 11
                        }
                    }
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
