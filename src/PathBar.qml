import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// The breadcrumb path from the left edge; view buttons on the right. Back and
// forward are keys (Alt+← / Alt+→) and the mouse's thumb buttons.
Rectangle {
    id: bar

    property bool previewVisible: true
    property string viewMode: "grid"
    // Ctrl+L: the path as text to edit. Enter goes there, Escape cancels,
    // Tab completes a folder name.
    property bool editing: false
    // The right pane of a split has a close button (Ctrl+W).
    property bool closable: false
    signal closeRequested()
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

    // Transparent: the window draws one bar across the whole top, so the
    // path bars of one or two panes read as part of it.
    color: "transparent"
    implicitHeight: 60

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 26
        anchors.rightMargin: 20
        spacing: 4


        PlainField {
            id: pathField
            Layout.fillWidth: true
            visible: bar.editing
            font.pixelSize: 14
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
            onWidthChanged: contentX = Math.max(0, contentWidth - width)

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
            // Shows the order in use, and says it on hover.
            readonly property string mode: backend.folder.sortMode
            glyph: mode === "name" ? "sort-name" : mode === "kind" ? "sort-kind"
                 : mode === "modified" ? "sort-newest" : mode === "oldest" ? "sort-oldest" : "sort-size"
            text: mode === "name" ? qsTr("Sorted by name (S)")
                : mode === "kind" ? qsTr("Sorted by kind (S)")
                : mode === "modified" ? qsTr("Newest first (S)")
                : mode === "oldest" ? qsTr("Oldest first (S)")
                : qsTr("Biggest first (S)")
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
        IconButton {
            visible: bar.closable
            glyph: "close"
            text: qsTr("Close this pane (Ctrl+W)")
            onClicked: bar.closeRequested()
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: bar.tint(theme.foreground, 0.12) }
}
