import QtQuick
import QtQuick.Layouts

// GVfs's questions while connecting to another machine, put to the user in
// the window: trust a host key seen for the first time, or a password when
// keys aren't set up. The wording comes from GVfs, already translated.
FolioDialog {
    id: prompt

    readonly property var mounter: backend.mounter

    title: mounter.wantsPassword ? qsTr("Sign in") : qsTr("Connecting")
    cardWidth: 600
    spacing: 18
    visible: mounter.asking

    onVisibleChanged: if (visible && mounter.wantsPassword) password.forceActiveFocus()

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
        visible: prompt.mounter.wantsPassword
        placeholderText: qsTr("User")
        text: prompt.mounter.user
    }
    PlainField {
        id: password
        Layout.fillWidth: true
        visible: prompt.mounter.wantsPassword
        placeholderText: qsTr("Password")
        echoMode: TextInput.Password
        onAccepted: prompt.submit()
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 10

        // GVfs lists the safe way out last ("Cancel Login"); it gets the
        // plain look, the other choices the accent.
        Repeater {
            model: prompt.mounter.wantsPassword ? [] : prompt.mounter.choices
            delegate: PlainButton {
                required property string modelData
                required property int index
                text: modelData
                primary: index < prompt.mounter.choices.length - 1
                onClicked: prompt.mounter.choose(index)
            }
        }
        PlainButton {
            visible: prompt.mounter.wantsPassword
            text: qsTr("Cancel")
            onClicked: prompt.mounter.cancel()
        }
        PlainButton {
            visible: prompt.mounter.wantsPassword
            text: qsTr("Connect")
            primary: true
            onClicked: prompt.submit()
        }
    }
}
