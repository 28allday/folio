import QtQuick
import QtQuick.Controls
import Folio

// Columns, as in the macOS Finder: the folders on the way here from the
// root (~, a tailnet machine, or /), the current folder, and what's inside
// the selected subfolder. → goes into the selected folder, ← back out;
// clicking anywhere to the left jumps there.
Item {
    id: view

    property alias currentIndex: here.currentIndex
    readonly property int columnWidth: 260

    function select(name) {
        const found = name ? backend.folder.indexOf(name) : -1
        here.currentIndex = found >= 0 ? found : (here.count > 0 ? 0 : -1)
        if (here.currentIndex >= 0)
            here.positionViewAtIndex(here.currentIndex, ListView.Contain)
    }
    function focusView() { here.forceActiveFocus() }

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property var crumbs: backend.crumbs
    readonly property var selected: here.currentIndex >= 0 ? (backend.folder.count, backend.folder.get(here.currentIndex)) : ({})

    // Keeps the newest columns in view as the trail grows.
    function revealEnd() { flick.contentX = Math.max(0, flick.contentWidth - flick.width) }

    component Separator: Rectangle { width: 1; height: parent ? parent.height : 0; color: view.tint(theme.foreground, 0.1) }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        interactive: false
        contentWidth: row.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        onContentWidthChanged: view.revealEnd()
        onWidthChanged: view.revealEnd()
        ScrollBar.horizontal: ScrollBar { }

        Row {
            id: row
            height: flick.height

            // The folders on the way here, each showing which way the trail goes.
            Repeater {
                model: view.crumbs.length - 1
                Row {
                    id: ancestor
                    required property int index
                    readonly property string next: view.crumbs[index + 1].name
                    height: row.height

                    ListView {
                        id: column
                        width: view.columnWidth
                        height: parent.height
                        clip: true
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        model: FolderModel {
                            id: folder
                            path: view.crumbs[ancestor.index].path
                            showHidden: backend.folder.showHidden
                            sortMode: backend.folder.sortMode
                            onLoaded: column.positionViewAtIndex(Math.max(0, folder.indexOf(ancestor.next)), ListView.Contain)
                        }
                        delegate: FileRow {
                            width: column.width
                            chevron: true
                            trail: name === ancestor.next
                            onClicked: isDir ? backend.navigate(path) : backend.showItem(path)
                            onActivated: backend.open(path)
                        }
                    }
                    Separator { }
                }
            }

            // The folder being shown: its selection is the window's.
            ListView {
                id: here
                width: view.columnWidth
                height: row.height
                clip: true
                focus: true
                keyNavigationEnabled: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                model: backend.folder
                ScrollBar.vertical: ScrollBar { }

                Keys.onRightPressed: if (view.selected.isDir) backend.navigate(view.selected.path)
                Keys.onLeftPressed: backend.goUp()

                delegate: FileRow {
                    width: here.width
                    chevron: true
                    current: ListView.isCurrentItem
                    onClicked: { here.currentIndex = index; here.forceActiveFocus() }
                    onActivated: backend.open(path)
                }

                Text {
                    anchors.centerIn: parent
                    visible: here.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
                    text: qsTr("Empty")
                    color: theme.secondaryForeground
                }
            }
            Separator { }

            // A look inside the selected folder; clicking in it goes there.
            ListView {
                id: inside
                width: view.columnWidth
                height: row.height
                visible: view.selected.isDir === true
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                model: FolderModel {
                    path: view.selected.isDir === true ? view.selected.path : ""
                    showHidden: backend.folder.showHidden
                    sortMode: backend.folder.sortMode
                }
                delegate: FileRow {
                    width: inside.width
                    chevron: true
                    onClicked: backend.showItem(path)
                    onActivated: backend.open(path)
                }

                Text {
                    anchors.centerIn: parent
                    visible: inside.count === 0
                    text: qsTr("Empty")
                    color: theme.secondaryForeground
                }
            }
        }
    }
}
