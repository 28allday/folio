import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The folder as a list: name, size and date (the date, then the size, step
// aside in a narrow window). No headings: the sort menu and S sort it.
ColumnLayout {
    id: view

    property alias currentIndex: list.currentIndex

    function select(name, keep) { selecting.select(name, keep) }

    Selecting { id: selecting; view: list }
    function focusView() { list.forceActiveFocus() }
    function menuAnchor() { return list.currentItem }

    signal contextMenu(var item, string folder)

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    spacing: 0

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        focus: true
        keyNavigationEnabled: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false
        model: backend.folder
        ScrollBar.vertical: FolioScrollBar { }

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
