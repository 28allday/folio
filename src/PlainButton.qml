import QtQuick
import QtQuick.Controls

// A dialog button: the accent when it's the main choice, red when it
// erases something, outlined in the accent when it's the option picked
// among others, quiet otherwise. No ripple, no animation.
AbstractButton {
    id: button
    property bool primary: false
    property bool destructive: false
    // Picked among options (a filesystem to format as).
    property bool active: false
    readonly property bool filled: primary || destructive
    readonly property color fill: destructive ? theme.red : theme.accent

    implicitWidth: Math.max(88, label.implicitWidth + 32)
    implicitHeight: 36
    hoverEnabled: true
    Accessible.name: text

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: button.filled ? (button.hovered ? Qt.lighter(button.fill, 1.08) : button.fill)
             : button.active ? Qt.alpha(theme.accent, 0.16)
             : button.hovered ? Qt.alpha(theme.foreground, 0.10)
             : Qt.alpha(theme.foreground, 0.05)
        border.width: button.visualFocus || button.active ? 1 : 0
        border.color: button.destructive ? theme.brightForeground : theme.accent
    }
    contentItem: Text {
        id: label
        text: button.text
        color: button.destructive ? theme.background : button.primary ? theme.accentForeground
             : button.active ? theme.brightForeground : theme.foreground
        font.weight: button.filled ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
