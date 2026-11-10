import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCore

// The window: the sidebar, one folder pane or two side by side
// (Ctrl+Shift+N splits, Ctrl+W closes the right one), and the details pane.
// The sidebar and the details follow the pane used last.
ApplicationWindow {
    id: win
    width: 1280
    height: 800
    minimumWidth: 720
    minimumHeight: 460
    visible: true
    title: activePane && activePane.paneBackend.title.length > 0 ? activePane.paneBackend.title : "Folio"
    color: theme.background

    Material.theme: theme.light ? Material.Light : Material.Dark
    Material.accent: theme.accent
    Material.foreground: theme.foreground
    Material.background: theme.background
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    property bool previewVisible: true
    property string viewMode: "grid"

    // The pane keys, the sidebar and the details go to.
    property var activePane: leftPane
    // The right pane while the window is split.
    property var rightPane: null
    readonly property bool split: rightPane !== null

    // Remembers the view between launches (~/.config/folio/folio.conf).
    Settings {
        property alias viewMode: win.viewMode
    }

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Ctrl+Shift+N: a second pane on the right, starting where the active
    // one is. Pressed again, it moves the keyboard there.
    function openSplit() {
        if (!rightPane) {
            rightPane = windows.openSplit(win, activePane.paneBackend.path)
            if (!rightPane)
                return
            rightPane.closable = true
            rightPane.closeRequested.connect(closeSplit)
        }
        rightPane.focusView()
    }
    function closeSplit() {
        if (!rightPane)
            return
        activePane = leftPane
        rightPane = null
        windows.closeSplit(win)
        leftPane.focusView()
    }

    Shortcut { sequence: "?"; enabled: !win.activePane.typing || win.helpVisible; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; enabled: !win.activePane.typing; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: !win.activePane.typing; onActivated: win.openSplit() }
    Shortcut { sequence: "Ctrl+W"; enabled: win.split; onActivated: win.closeSplit() }
    Shortcut { sequence: "Ctrl+I"; onActivated: win.previewVisible = !win.previewVisible }
    // Tab moves the keyboard: sidebar, left pane, right pane, and around.
    Shortcut {
        sequences: ["Tab", "Backtab"]
        enabled: !win.activePane.typing
        onActivated: {
            if (sidebar.activeFocus)
                leftPane.focusView()
            else if (win.split && win.activePane === leftPane)
                win.rightPane.focusView()
            else
                sidebar.focusSidebar()
        }
    }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                id: sidebar
                target: win.activePane ? win.activePane.paneBackend : backend
                onFinished: win.activePane.focusView()
                Layout.preferredWidth: 236
                Layout.fillHeight: true
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: win.tint(theme.foreground, 0.12) }

            FolderPane {
                id: leftPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: true
            }

            // The right pane of a split; Folio puts it here (see windows.cpp).
            Rectangle { visible: win.split; Layout.fillHeight: true; implicitWidth: 1; color: win.tint(theme.foreground, 0.12) }
            Item {
                id: splitHost
                objectName: "splitHost"
                visible: win.split
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            PreviewPane {
                visible: win.previewVisible && win.width >= (win.split ? 1400 : 960)
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                item: win.activePane ? win.activePane.current : ({})
            }
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
