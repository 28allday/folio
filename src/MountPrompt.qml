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

    // Each request starts fresh, whichever way the last one closed
    // (Connect, Cancel, Escape or GVfs giving up), so a password typed for
    // one machine is never offered to the next, nor kept once it's closed.
    onVisibleChanged: {
        password.text = ""
        if (visible) {
            user.text = mounter.user
            password.forceActiveFocus()
        }
    }

    function submit() {
        prompt.mounter.providePassword(user.text, password.text)
    }

    // A click outside the card does nothing: GVfs waits for an answer,
    // which only the buttons or Escape give.
    Shortcut { sequence: "Escape"; enabled: prompt.visible; context: Qt.WindowShortcut; onActivated: prompt.mounter.cancel() }

    // Aligned explicitly, so that it's mirrored: GVfs may word it in
    // another language than Folio's.
    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignLeft
        text: prompt.mounter.prompt
        color: theme.foreground
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }

    PlainField {
        id: user
        Layout.fillWidth: true
        placeholderText: qsTr("User")
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
