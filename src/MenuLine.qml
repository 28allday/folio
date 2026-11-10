import QtQuick
import QtQuick.Controls

// A thin rule between groups of menu entries, with little room around it.
MenuSeparator {
    property bool shown: true
    visible: shown
    height: shown ? implicitHeight : 0
    topPadding: 4
    bottomPadding: 4
    contentItem: Rectangle {
        implicitWidth: 200
        implicitHeight: 1
        color: Qt.alpha(theme.foreground, 0.12)
    }
}
