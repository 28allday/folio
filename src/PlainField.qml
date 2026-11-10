import QtQuick
import QtQuick.Controls

// A text field in Folio's look: a dark box with an accent edge while typing
// and the hint inside it, where it stays (no floating label animation).
TextField {
    id: field
    font.pixelSize: 13
    color: theme.brightForeground
    selectionColor: theme.accent
    selectedTextColor: theme.accentForeground
    placeholderTextColor: theme.secondaryForeground
    leftPadding: 12
    rightPadding: 12
    topPadding: 9
    bottomPadding: 9
    background: Rectangle {
        implicitHeight: 38
        color: theme.darkBackground
        border.width: 1
        border.color: field.activeFocus ? theme.accent : Qt.alpha(theme.foreground, 0.18)
        radius: Math.min(4, theme.radius)
    }
}
