import QtQuick
import QtQuick.Layouts

// Asks before something that can't be undone (emptying the trash, deleting
// for good). Enter confirms, Escape or a click outside cancels. Asked about
// erasing a whole drive, Enter cancels instead, and the button that erases
// it is red: that one only goes ahead when it's chosen.
FolioDialog {
    id: dialog

    property string message
    property string action
    property var onConfirm: null
    property bool erasing: false

    cardWidth: 480
    edge: theme.red
    visible: false
    onScrimClicked: close()

    function ask(heading, body, button, confirm, erases) {
        title = heading
        message = body
        action = button
        onConfirm = confirm
        erasing = erases === true
        visible = true
        if (erasing)
            cancelButton.forceActiveFocus()
        else
            confirmButton.forceActiveFocus()
    }
    function close() { visible = false; onConfirm = null }
    function accept() {
        const run = onConfirm
        close()
        if (run)
            run()
    }

    Keys.onEscapePressed: dialog.close()

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
            id: cancelButton
            text: qsTr("Cancel")
            onClicked: dialog.close()
            Keys.onReturnPressed: dialog.close()
            Keys.onEnterPressed: dialog.close()
        }
        PlainButton {
            id: confirmButton
            text: dialog.action
            primary: !dialog.erasing
            destructive: dialog.erasing
            onClicked: dialog.accept()
            Keys.onReturnPressed: dialog.accept()
            Keys.onEnterPressed: dialog.accept()
        }
    }
}
