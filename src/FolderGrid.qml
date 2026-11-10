import QtQuick
import QtQuick.Controls

// The folder as a grid of tiles with real previews.
GridView {
    id: grid

    function select(name) {
        const found = name ? backend.folder.indexOf(name) : -1
        currentIndex = found >= 0 ? found : (count > 0 ? 0 : -1)
        if (currentIndex >= 0)
            positionViewAtIndex(currentIndex, GridView.Contain)
    }
    function focusView() { forceActiveFocus() }

    // Right-click on an item (selecting it) or on empty space.
    signal contextMenu(var item, string folder)
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (point) => {
            const index = grid.indexAt(point.position.x + grid.contentX, point.position.y + grid.contentY)
            if (index >= 0)
                grid.currentIndex = index
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
    cellHeight: 176
    highlightFollowsCurrentItem: false
    ScrollBar.vertical: ScrollBar { }

    delegate: FileTile {
        width: grid.cellWidth
        height: grid.cellHeight
        current: GridView.isCurrentItem
        onClicked: { grid.currentIndex = index; grid.forceActiveFocus() }
        onActivated: backend.open(path)
    }

    Text {
        anchors.centerIn: parent
        visible: grid.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
        text: qsTr("This folder is empty")
        color: theme.secondaryForeground
    }
}
