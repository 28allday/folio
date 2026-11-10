import QtQuick
import QtQuick.Layouts

// Asks before something that can't be undone (emptying the trash, deleting
// for good). Enter confirms, Escape or a click outside cancels.
Rectangle {
    id: dialog

    property string title
    property string message
    property string action
    property var onConfirm: null

    color: Qt.rgba(0, 0, 0, 0.55)
    visible: false

    function ask(heading, body, button, confirm) {
        title = heading
        message = body
        action = button
        onConfirm = confirm
        visible = true
        confirmButton.forceActiveFocus()
    }
    function close() { visible = false; onConfirm = null }
    function accept() {
        const run = onConfirm
        close()
        if (run)
            run()
    }

    MouseArea { anchors.fill: parent; onClicked: dialog.close() }
    Keys.onEscapePressed: dialog.close()

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 480)
        height: content.implicitHeight + 56
        color: theme.background
        border.width: 1
        border.color: theme.red
        radius: theme.radius
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                text: dialog.title
                color: theme.brightForeground
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: dialog.message
                color: theme.foreground
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10
                PlainButton {
                    text: qsTr("Cancel")
                    onClicked: dialog.close()
                    Keys.onEscapePressed: dialog.close()
                }
                PlainButton {
                    id: confirmButton
                    text: dialog.action
                    primary: true
                    onClicked: dialog.accept()
                    Keys.onReturnPressed: dialog.accept()
                    Keys.onEnterPressed: dialog.accept()
                    Keys.onEscapePressed: dialog.close()
                }
            }
        }
    }
}
