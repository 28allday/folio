import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// A menu in Folio's look: the theme's colors, a hairline border, entries
// tinted in the accent when highlighted, and no opening or closing
// animation. Used for the right-click menu, its submenus and the sort menu.
Menu {
    id: menu

    Material.background: theme.background
    Material.foreground: theme.foreground
    Material.accent: theme.accent
    Material.roundedScale: theme.radius
    font.pixelSize: 13

    enter: null
    exit: null
    topPadding: 4
    bottomPadding: 4
    // Submenu entries (Open With, Share) are made from this.
    delegate: FolioMenuItem { }

    background: Rectangle {
        implicitWidth: 240
        color: theme.background
        border.width: 1
        border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.16)
        radius: Math.min(6, theme.radius)
    }
}
