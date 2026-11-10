import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The folder as a list: name, kind, size and date in columns. Clicking Name
// or Modified sorts by it.
ColumnLayout {
    id: view

    property alias currentIndex: list.currentIndex

    function select(name) {
        const found = name ? backend.folder.indexOf(name) : -1
        list.currentIndex = found >= 0 ? found : (list.count > 0 ? 0 : -1)
        if (list.currentIndex >= 0)
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }
    function focusView() { list.forceActiveFocus() }

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    spacing: 0

    component HeaderLabel: Text {
        property string sort
        color: sort.length > 0 && backend.folder.sortMode === sort ? theme.accent : theme.secondaryForeground
        font.pixelSize: 11
        font.letterSpacing: 1.1
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
        TapHandler {
            enabled: parent.sort.length > 0
            onTapped: backend.folder.sortMode = parent.sort
        }
        HoverHandler { enabled: parent.sort.length > 0; cursorShape: Qt.PointingHandCursor }
    }

    // The same widths as FileRow, so headings sit over their values.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 14 + 20 + 12
        Layout.rightMargin: 14
        Layout.bottomMargin: 8
        spacing: 12
        HeaderLabel { Layout.fillWidth: true; text: qsTr("Name"); sort: "name" }
        HeaderLabel { Layout.preferredWidth: 120; text: qsTr("Kind") }
        HeaderLabel { Layout.preferredWidth: 96; horizontalAlignment: Text.AlignRight; text: qsTr("Size") }
        HeaderLabel { Layout.preferredWidth: 168; Layout.leftMargin: 12; text: qsTr("Modified"); sort: "modified" }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: view.tint(theme.foreground, 0.1) }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: 6
        clip: true
        focus: true
        keyNavigationEnabled: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false
        model: backend.folder
        ScrollBar.vertical: ScrollBar { }

        delegate: FileRow {
            width: list.width
            detailed: true
            current: ListView.isCurrentItem
            onClicked: { list.currentIndex = index; list.forceActiveFocus() }
            onActivated: backend.open(path)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
            text: qsTr("This folder is empty")
            color: theme.secondaryForeground
        }
    }
}
