import QtQuick
import QtQuick.Controls

// The folder as a list: name, size and date (the date, then the size, step
// aside in a narrow window). No headings: the sort menu and S sort it.
ListView {
    id: list

    function select(name, keep) { selecting.select(name, keep) }
    function focusView() { forceActiveFocus() }
    // Where the keyboard's menu (Alt+Return) opens: beside the cursor's item.
    function menuAnchor() { return currentItem }

    Selecting { id: selecting; view: list }
    onCurrentIndexChanged: selecting.cursorMoved()
    Keys.onPressed: (event) => {
        if (!(event.modifiers & Qt.ShiftModifier))
            return
        const step = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0
        if (step !== 0) {
            selecting.extendTo(currentIndex + step)
            event.accepted = true
        }
    }

    Band {
        view: list
        rectOf: (i) => Qt.rect(0, i * 32, list.width, 32)
    }

    // → goes into the selected folder and ← back up, as in the columns.
    Keys.onRightPressed: {
        const item = backend.folder.get(currentIndex)
        if (item.isDir)
            backend.navigate(item.path)
    }
    Keys.onLeftPressed: backend.goUp()

    // Right-click on an item (selecting it) or on empty space.
    signal contextMenu(var item, string folder)
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (point) => {
            const index = list.indexAt(point.position.x + list.contentX, point.position.y + list.contentY)
            selecting.menuAt(index)
            list.contextMenu(index >= 0 ? backend.folder.get(index) : null, backend.path)
        }
    }

    clip: true
    focus: true
    keyNavigationEnabled: true
    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    model: backend.folder
    ScrollBar.vertical: FolioScrollBar { }

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
        text: backend.folder.query ? qsTr("Nothing matches “%1”").arg(backend.folder.query) : qsTr("This folder is empty")
        color: theme.secondaryForeground
    }
}
