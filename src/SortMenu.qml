import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The orders a folder can be in. Folders stay first in each; S steps
// through them from the keyboard.
Menu {
    id: menu

    Material.background: theme.background
    Material.foreground: theme.foreground
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    background: Rectangle {
        implicitWidth: 180
        color: theme.background
        border.width: 1
        border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16)
        radius: Math.min(6, theme.radius)
    }

    readonly property var orders: [
        { mode: "name", label: qsTr("Name") },
        { mode: "kind", label: qsTr("Kind") },
        { mode: "modified", label: qsTr("Newest") },
        { mode: "oldest", label: qsTr("Oldest") },
        { mode: "size", label: qsTr("Size") }
    ]

    Repeater {
        model: menu.orders
        MenuItem {
            required property var modelData
            text: modelData.label
            checkable: true
            checked: backend.folder.sortMode === modelData.mode
            onTriggered: backend.folder.sortMode = modelData.mode
        }
    }
}
