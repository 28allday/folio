import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// History buttons, the breadcrumb path, and the view toggles.
Rectangle {
    id: bar

    property bool previewVisible: true
    property string viewMode: "grid"
    // Ctrl+L: the path as text to edit. Enter goes there, Escape cancels,
    // Tab completes a folder name.
    property bool editing: false
    signal togglePreview()
    signal cycleView()
    signal editDone()

    function editPath() {
        pathField.text = backend.typedPath()
        editing = true
        pathField.forceActiveFocus()
        pathField.selectAll()
    }
    function stopEditing() {
        editing = false
        editDone()
    }

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

        TextField {
            id: pathField
            Layout.fillWidth: true
            visible: bar.editing
            font.pixelSize: 14
            color: theme.brightForeground
            selectionColor: theme.accent
            selectedTextColor: theme.accentForeground
            leftPadding: 12
            rightPadding: 12
            topPadding: 8
            bottomPadding: 8
            background: Rectangle {
                implicitHeight: 36
                color: theme.darkBackground
                border.width: 1
                border.color: theme.accent
                radius: Math.min(4, theme.radius)
            }
            onAccepted: {
                if (backend.goTyped(text))
                    bar.stopEditing()
            }
            Keys.onEscapePressed: bar.stopEditing()
            Keys.onTabPressed: {
                text = backend.completePath(text)
                cursorPosition = text.length
            }
            onActiveFocusChanged: if (!activeFocus && bar.editing) bar.stopEditing()
        }

        Flickable {
            visible: !bar.editing
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
        // Shows the current view; clicking moves to the next one.
        IconButton {
            glyph: bar.viewMode
            text: bar.viewMode === "grid" ? qsTr("Grid (Ctrl+1); click for list")
                : bar.viewMode === "list" ? qsTr("List (Ctrl+2); click for columns")
                : qsTr("Columns (Ctrl+3); click for grid")
            onClicked: bar.cycleView()
        }
        IconButton {
            id: sortButton
            glyph: "sort"
            text: qsTr("Sort (S)")
            active: sortMenu.visible
            onClicked: sortMenu.popup(sortButton, 0, sortButton.height + 4)
        }
        SortMenu { id: sortMenu }
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
