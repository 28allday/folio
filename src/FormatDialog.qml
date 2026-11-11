import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Formatting a drive, as Omarchy's format-drive does: the whole drive
// erased to one partition under the name given here, exFAT (which Linux,
// macOS and Windows all read) unless another filesystem is picked. The
// drive is named the way it's known (its name, maker, model and size), and
// erasing it is said plainly. Format is red and never the default: Enter
// and Escape cancel.
FolioDialog {
    id: dialog

    // The drive, as fileOps.driveAt() describes it, or null when closed.
    property var drive: null
    // What this machine can format it as, and which is picked.
    property var choices: []
    property int choice: 0
    readonly property var picked: choices.length > choice ? choices[choice] : ({ type: "exfat", labelLimit: 11 })

    title: qsTr("Format Drive")
    edge: theme.red
    cardWidth: 480
    visible: drive !== null
    onScrimClicked: close()

    function open(target) {
        choices = fileOps.formatChoices()
        choice = 0
        drive = target
        field.text = target.label.slice(0, field.maximumLength)
        field.forceActiveFocus()
        field.selectAll()
    }
    function close() { drive = null }
    function format() {
        const id = drive.id
        const name = field.text
        const type = picked.type
        close()
        fileOps.format(id, name, type)
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
        // What to format it as, exFAT unless picked otherwise; what each is
        // good for is said on hover.
        PlainButton {
            id: fsButton
            visible: dialog.choices.length > 1
            text: (dialog.picked.name || "") + "  ▾"
            ToolTip.visible: hovered
            ToolTip.delay: 600
            ToolTip.text: dialog.picked.detail || ""
            onClicked: fsMenu.popup(fsButton, 0, fsButton.height + 4)
            FolioMenu {
                id: fsMenu
                Repeater {
                    model: dialog.choices
                    FolioMenuItem {
                        required property var modelData
                        required property int index
                        text: modelData.name
                        tip: modelData.detail
                        keys: dialog.choice === index ? "✓" : ""
                        onTriggered: dialog.choice = index
                    }
                }
            }
        }
    }
    PlainField {
        id: field
        Layout.fillWidth: true
        // The longest name the picked filesystem keeps.
        maximumLength: dialog.picked.labelLimit
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
