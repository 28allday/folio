import QtQuick
import QtQuick.Controls

// A dialog button: the accent when it's the main choice, quiet otherwise.
// No ripple, no animation.
AbstractButton {
    id: button
    property bool primary: false

    implicitWidth: Math.max(88, label.implicitWidth + 32)
    implicitHeight: 36
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: text

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: button.primary ? (button.hovered ? Qt.lighter(theme.accent, 1.08) : theme.accent)
             : button.hovered ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.10)
             : Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.05)
        border.width: button.visualFocus ? 1 : 0
        border.color: theme.accent
    }
    contentItem: Text {
        id: label
        text: button.text
        color: button.primary ? theme.accentForeground : theme.foreground
        font.weight: button.primary ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
