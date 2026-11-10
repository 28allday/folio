import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Renaming (F2): the name with everything but its extension selected, so
// typing replaces the name and keeps the type. Enter renames, Escape leaves
// it alone; a clash with an existing name is said here, never overwritten.
Rectangle {
    id: dialog

    property var item: null
    property string problem: ""

    color: Qt.rgba(0, 0, 0, 0.55)
    visible: item !== null

    function open(target) {
        problem = ""
        item = target
        field.text = target.name
        const dot = target.isDir ? -1 : target.name.indexOf(".", 1)
        field.forceActiveFocus()
        field.select(0, dot > 0 ? dot : target.name.length)
    }
    function close() { item = null }
    function submit() {
        problem = fileOps.rename(item.path, field.text)
        if (problem.length === 0)
            close()
    }

    MouseArea { anchors.fill: parent; onClicked: dialog.close() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 520)
        height: content.implicitHeight + 56
        color: theme.background
        border.width: 1
        border.color: theme.accent
        radius: theme.radius
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                text: qsTr("Rename")
                color: theme.brightForeground
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            PlainField {
                id: field
                Layout.fillWidth: true
                onAccepted: dialog.submit()
                Keys.onEscapePressed: dialog.close()
            }
            Text {
                Layout.fillWidth: true
                visible: dialog.problem.length > 0
                text: dialog.problem
                color: theme.red
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10
                PlainButton {
                    text: qsTr("Cancel")
                    onClicked: dialog.close()
                }
                PlainButton {
                    text: qsTr("Rename")
                    primary: true
                    onClicked: dialog.submit()
                }
            }
        }
    }
}
