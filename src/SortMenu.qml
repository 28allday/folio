import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The orders a folder can be in. Folders stay first in each; S steps
// through them from the keyboard.
FolioMenu {
    id: menu

    readonly property var orders: [
        { mode: "name", label: qsTr("Name") },
        { mode: "kind", label: qsTr("Kind") },
        { mode: "modified", label: qsTr("Newest") },
        { mode: "oldest", label: qsTr("Oldest") },
        { mode: "size", label: qsTr("Size") }
    ]

    Repeater {
        model: menu.orders
        FolioMenuItem {
            required property var modelData
            text: modelData.label
            checkable: true
            checked: backend.folder.sortMode === modelData.mode
            onTriggered: backend.folder.sortMode = modelData.mode
        }
    }
}
