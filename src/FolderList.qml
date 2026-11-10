import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The folder as a list: name, size and date in columns (the date, then the
// size, step aside in a narrow window). Clicking a heading sorts by it.
ColumnLayout {
    id: view

    property alias currentIndex: list.currentIndex

    function select(name, keep) { selecting.select(name, keep) }

    Selecting { id: selecting; view: list }
    function focusView() { list.forceActiveFocus() }

    signal contextMenu(var item, string folder)

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    spacing: 0

    // Each heading sorts by its column; Modified flips between newest and
    // oldest first when clicked again.
    component HeaderLabel: Text {
        property string sort
        property string alternate
        readonly property bool sorted: sort.length > 0 && (backend.folder.sortMode === sort || backend.folder.sortMode === alternate)
        color: sorted ? theme.accent : theme.secondaryForeground
        font.pixelSize: 11
        font.letterSpacing: 1.1
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
        TapHandler {
            enabled: parent.sort.length > 0
            onTapped: backend.folder.sortMode = parent.alternate.length > 0 && backend.folder.sortMode === parent.sort ? parent.alternate : parent.sort
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
        HeaderLabel { Layout.fillWidth: true; Layout.minimumWidth: 120; text: qsTr("Name"); sort: "name" }
        HeaderLabel { visible: list.width >= 380; Layout.preferredWidth: 96; horizontalAlignment: Text.AlignRight; text: qsTr("Size"); sort: "size" }
        HeaderLabel {
            visible: list.width >= 560
            Layout.preferredWidth: 168
            Layout.leftMargin: 12
            text: backend.folder.sortMode === "oldest" ? qsTr("Modified ↑") : qsTr("Modified")
            sort: "modified"
            alternate: "oldest"
        }
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

        onCurrentIndexChanged: selecting.cursorMoved()
        Keys.onPressed: (event) => {
            if (!(event.modifiers & Qt.ShiftModifier))
                return
            const step = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0
            if (step !== 0) {
                selecting.extendTo(list.currentIndex + step)
                event.accepted = true
            }
        }

        Band {
            view: list
            rectOf: (i) => Qt.rect(0, i * 32, list.width, 32)
        }

        // → goes into the selected folder and ← back up, as in the columns.
        Keys.onRightPressed: {
            const item = backend.folder.get(list.currentIndex)
            if (item.isDir)
                backend.navigate(item.path)
        }
        Keys.onLeftPressed: backend.goUp()

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (point) => {
                const index = list.indexAt(point.position.x + list.contentX, point.position.y + list.contentY)
                selecting.menuAt(index)
                view.contextMenu(index >= 0 ? backend.folder.get(index) : null, backend.path)
            }
        }

        delegate: FileRow {
            width: list.width
            detailed: true
            current: selected
            onClicked: (modifiers) => { selecting.click(index, modifiers); list.forceActiveFocus() }
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
