import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// History buttons, the breadcrumb path, and the view toggles.
Rectangle {
    id: bar

    property bool previewVisible: true
    signal togglePreview()

    color: theme.background
    implicitHeight: 60

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 4

        IconButton { glyph: "back"; text: qsTr("Back"); enabled: backend.canBack; onClicked: backend.back() }
        IconButton { glyph: "forward"; text: qsTr("Forward"); enabled: backend.canForward; onClicked: backend.forward() }
        Item { implicitWidth: 16 }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: crumbs.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Long paths keep their end in view; that's where you are.
            onContentWidthChanged: contentX = Math.max(0, contentWidth - width)

            Row {
                id: crumbs
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Repeater {
                    model: backend.crumbs
                    Row {
                        id: crumb
                        required property var modelData
                        required property int index
                        readonly property bool last: index === backend.crumbs.length - 1
                        spacing: 10
                        Text {
                            visible: crumb.index > 0
                            text: "/"
                            color: bar.tint(theme.foreground, 0.35)
                            font.pixelSize: 14
                        }
                        Text {
                            text: crumb.modelData.name
                            color: crumb.last ? theme.brightForeground : crumbMouse.containsMouse ? theme.foreground : theme.secondaryForeground
                            font.pixelSize: 14
                            font.weight: crumb.last ? Font.DemiBold : Font.Normal
                            MouseArea {
                                id: crumbMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: crumb.last ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: if (!crumb.last) backend.navigate(crumb.modelData.path)
                            }
                        }
                    }
                }
            }
        }

        Item { implicitWidth: 16 }
        IconButton {
            glyph: "sort"
            text: backend.folder.sortMode === "name" ? qsTr("Sorted by name (S)") : qsTr("Newest first (S)")
            active: backend.folder.sortMode === "modified"
            onClicked: backend.folder.sortMode = backend.folder.sortMode === "name" ? "modified" : "name"
        }
        IconButton {
            glyph: "hidden"
            text: qsTr("Show hidden files (Ctrl+H)")
            active: backend.folder.showHidden
            onClicked: backend.folder.showHidden = !backend.folder.showHidden
        }
        IconButton {
            glyph: "preview"
            text: qsTr("Details (Ctrl+I)")
            active: bar.previewVisible
            onClicked: bar.togglePreview()
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: bar.tint(theme.foreground, 0.12) }
}
