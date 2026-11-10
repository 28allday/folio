import QtQuick
import QtQuick.Layouts

// Every shortcut, one keypress away (?).
Rectangle {
    id: overlay

    signal dismissed()

    color: Qt.rgba(0, 0, 0, 0.55)

    property var shortcuts: [
        ["← ↑ → ↓", qsTr("Move the selection")],
        ["⏎", qsTr("Open")],
        ["Backspace", qsTr("Go to the parent folder")],
        ["Alt+← / Alt+→", qsTr("Back / forward (or the mouse's thumb buttons)")],
        ["Alt+Home", qsTr("Go home")],
        ["Ctrl+1 / 2 / 3", qsTr("Grid, list or columns")],
        ["Space", qsTr("Preview the selected file")],
        ["Ctrl+I", qsTr("Show or hide the details pane")],
        ["Ctrl+D", qsTr("Pin or unpin the folder (or drag it to the sidebar)")],
        ["S", qsTr("Sort by name or newest first")],
        ["Ctrl+H", qsTr("Show hidden files")],
        ["F5", qsTr("Reload")],
        ["?", qsTr("Show these shortcuts")],
        ["Q", qsTr("Quit")]
    ]

    MouseArea { anchors.fill: parent; onClicked: overlay.dismissed() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 520)
        height: content.implicitHeight + 56
        color: theme.background
        border.width: 1
        border.color: theme.accent
        radius: theme.radius

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Text { text: qsTr("Keyboard shortcuts"); color: theme.brightForeground; font.pixelSize: 16; font.weight: Font.DemiBold }

            GridLayout {
                columns: 2
                rowSpacing: 10
                columnSpacing: 28
                Repeater {
                    model: overlay.shortcuts
                    delegate: Text {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 0
                        text: modelData[0]
                        color: theme.accent
                    }
                }
                Repeater {
                    model: overlay.shortcuts
                    delegate: Text {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 1
                        Layout.fillWidth: true
                        text: modelData[1]
                        color: theme.foreground
                    }
                }
            }
        }
    }
}
