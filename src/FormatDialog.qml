import QtQuick
import QtQuick.Layouts

// Formatting a drive, as Omarchy's format-drive does: the whole drive
// erased to one exFAT partition, which Linux, macOS and Windows all read,
// under the name given here. The drive is named the way it's known (its
// name, maker, model and size), and erasing it is said plainly. Format is
// red and never the default: Enter and Escape cancel.
FolioDialog {
    id: dialog

    // The drive, as fileOps.driveAt() describes it, or null when closed.
    property var drive: null

    title: qsTr("Format Drive")
    edge: theme.red
    cardWidth: 480
    visible: drive !== null
    onScrimClicked: close()

    function open(target) {
        drive = target
        field.text = target.label.slice(0, field.maximumLength)
        field.forceActiveFocus()
        field.selectAll()
    }
    function close() { drive = null }
    function format() {
        const id = drive.id
        const name = field.text
        close()
        fileOps.format(id, name)
    }

    Keys.onEscapePressed: dialog.close()

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Glyph { name: "drive"; color: theme.foreground }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                visible: !!dialog.drive && dialog.drive.label.length > 0
                text: dialog.drive ? dialog.drive.label : ""
                color: theme.brightForeground
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: dialog.drive ? dialog.drive.title : ""
                color: dialog.drive && dialog.drive.label.length > 0 ? theme.secondaryForeground : theme.brightForeground
                elide: Text.ElideRight
            }
        }
    }
    PlainField {
        id: field
        Layout.fillWidth: true
        // exFAT keeps no longer a name (Disks::labelLimit).
        maximumLength: 11
        placeholderText: qsTr("Name")
        // Typing the name and pressing Enter mustn't erase the drive.
        Keys.onReturnPressed: cancelButton.forceActiveFocus()
        Keys.onEnterPressed: cancelButton.forceActiveFocus()
    }
    Text {
        Layout.fillWidth: true
        text: qsTr("Everything on this drive will be erased. This can't be undone.")
        color: theme.red
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
            text: qsTr("Format")
            destructive: true
            onClicked: dialog.format()
        }
    }
}
