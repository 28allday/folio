import QtQuick
import QtQuick.Controls

// The folder as a grid of tiles with real previews.
GridView {
    id: grid

    function select(name, keep) { selecting.select(name, keep) }
    function focusView() { forceActiveFocus() }
    // Where the keyboard's menu (Alt+Return) opens: beside the cursor's item.
    function menuAnchor() { return currentItem }

    Selecting { id: selecting; view: grid }
    onCurrentIndexChanged: selecting.cursorMoved()
    Keys.onPressed: (event) => {
        if (!(event.modifiers & Qt.ShiftModifier))
            return
        const step = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1
                   : event.key === Qt.Key_Up ? -columns : event.key === Qt.Key_Down ? columns : 0
        if (step !== 0) {
            selecting.extendTo(currentIndex + step)
            event.accepted = true
        }
    }

    Band {
        view: grid
        rectOf: (i) => Qt.rect((i % grid.columns) * grid.cellWidth + 20, Math.floor(i / grid.columns) * grid.cellHeight + 12,
                               grid.cellWidth - 40, grid.cellHeight - 24)
    }

    // Right-click on an item (selecting it) or on empty space.
    signal contextMenu(var item, string folder)
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (point) => {
            const index = grid.indexAt(point.position.x + grid.contentX, point.position.y + grid.contentY)
            selecting.menuAt(index)
            grid.contextMenu(index >= 0 ? backend.folder.get(index) : null, backend.path)
        }
    }

    clip: true
    focus: true
    keyNavigationEnabled: true
    // Pressing and dragging picks up a file (to pin it, or drop it in another
    // app) rather than flicking; the wheel and touchpad still scroll.
    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    model: backend.folder
    readonly property int columns: Math.max(1, Math.floor(width / 168))
    cellWidth: Math.floor(width / columns)
    cellHeight: 192
    highlightFollowsCurrentItem: false
    ScrollBar.vertical: FolioScrollBar { }

    delegate: FileTile {
        width: grid.cellWidth
        height: grid.cellHeight
        current: selected
        onClicked: (modifiers) => { selecting.click(index, modifiers); grid.forceActiveFocus() }
        onActivated: backend.open(path)
    }

    Text {
        anchors.centerIn: parent
        visible: grid.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
        text: qsTr("This folder is empty")
        color: theme.secondaryForeground
    }
}
