import QtQuick
import QtQuick.Layouts

// GVfs's password request while connecting to another machine whose keys
// aren't set up, put to the user in the window. The wording comes from GVfs,
// already translated.
FolioDialog {
    id: prompt

    readonly property var mounter: backend.mounter

    title: qsTr("Sign in")
    cardWidth: 600
    spacing: 18
    visible: mounter.asking

    onVisibleChanged: if (visible) password.forceActiveFocus()

    function submit() {
        prompt.mounter.providePassword(user.text, password.text)
        password.text = ""
    }

    // A click outside the card does nothing: GVfs waits for an answer,
    // which only the buttons or Escape give.
    Shortcut { sequence: "Escape"; enabled: prompt.visible; context: Qt.WindowShortcut; onActivated: prompt.mounter.cancel() }

    Text {
        Layout.fillWidth: true
        text: prompt.mounter.prompt
        color: theme.foreground
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }

    PlainField {
        id: user
        Layout.fillWidth: true
        placeholderText: qsTr("User")
        text: prompt.mounter.user
    }
    PlainField {
        id: password
        Layout.fillWidth: true
        placeholderText: qsTr("Password")
        echoMode: TextInput.Password
        onAccepted: prompt.submit()
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 10

        PlainButton {
            text: qsTr("Cancel")
            onClicked: prompt.mounter.cancel()
        }
        PlainButton {
            text: qsTr("Connect")
            primary: true
            onClicked: prompt.submit()
        }
    }
}
