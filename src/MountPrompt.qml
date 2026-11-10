import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// GVfs's questions while connecting to another machine, put to the user in
// the window: trust a host key seen for the first time, or a password when
// keys aren't set up. The wording comes from GVfs, already translated.
Rectangle {
    id: prompt

    readonly property var mounter: backend.mounter

    color: Qt.rgba(0, 0, 0, 0.55)
    visible: mounter.asking

    onVisibleChanged: if (visible && mounter.wantsPassword) password.forceActiveFocus()

    function submit() {
        prompt.mounter.providePassword(user.text, password.text)
        password.text = ""
    }

    // Swallows clicks so the grid underneath stays put while asking.
    MouseArea { anchors.fill: parent }

    Shortcut { sequence: "Escape"; enabled: prompt.visible; context: Qt.WindowShortcut; onActivated: prompt.mounter.cancel() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 600)
        height: content.implicitHeight + 56
        color: theme.background
        border.width: 1
        border.color: theme.accent
        radius: theme.radius

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            Text {
                text: prompt.mounter.wantsPassword ? qsTr("Sign in") : qsTr("Connecting")
                color: theme.brightForeground
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: prompt.mounter.prompt
                color: theme.foreground
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            TextField {
                id: user
                Layout.fillWidth: true
                visible: prompt.mounter.wantsPassword
                placeholderText: qsTr("User")
                text: prompt.mounter.user
            }
            TextField {
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

                // GVfs lists the safe way out last ("Cancel Login"); it gets
                // the plain look, the other choices the accent.
                Repeater {
                    model: prompt.mounter.wantsPassword ? [] : prompt.mounter.choices
                    delegate: Button {
                        required property string modelData
                        required property int index
                        text: modelData
                        highlighted: index < prompt.mounter.choices.length - 1
                        Material.accent: theme.accent
                        Material.roundedScale: theme.radius
                        onClicked: prompt.mounter.choose(index)
                    }
                }
                Button {
                    visible: prompt.mounter.wantsPassword
                    text: qsTr("Cancel")
                    flat: true
                    Material.roundedScale: theme.radius
                    onClicked: prompt.mounter.cancel()
                }
                Button {
                    visible: prompt.mounter.wantsPassword
                    text: qsTr("Connect")
                    highlighted: true
                    Material.accent: theme.accent
                    Material.roundedScale: theme.radius
                    onClicked: prompt.submit()
                }
            }
        }
    }
}
