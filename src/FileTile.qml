import QtQuick

// One item in the grid: a preview on top, its name below. Folders show the
// first pictures inside them peeking out; files show a real thumbnail when
// one can be made, and a drawn stand-in for their kind when not.
Item {
    id: tile

    required property int index
    required property string name
    required property string path
    required property bool isDir
    required property string kind
    required property string mime
    required property string extension
    required property int itemCount
    required property var peek

    property bool current: false

    signal clicked()
    signal activated()

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function thumbUrl(file, type, size) {
        return "image://thumb/" + size + "/" + encodeURIComponent(type) + "/" + encodeURIComponent(file)
    }

    function guessImageMime(file) {
        const ext = file.split(".").pop().toLowerCase()
        return "image/" + (ext === "jpg" ? "jpeg" : ext === "heic" ? "heif" : ext)
    }

    // The badge and stand-in color for each kind, from the theme's palette.
    readonly property color kindColor: kind === "pdf" ? theme.red
                                     : kind === "text" ? theme.blue
                                     : kind === "audio" ? theme.magenta
                                     : kind === "video" ? theme.orange
                                     : kind === "archive" ? theme.yellow
                                     : kind === "image" ? theme.cyan
                                     : theme.secondaryForeground

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: Math.min(4, theme.radius)
        color: tile.current ? tile.tint(theme.accent, 0.16)
             : hover.hovered ? tile.tint(theme.foreground, 0.05)
             : "transparent"
        border.width: tile.current ? 1 : 0
        border.color: theme.accent
    }

    Item {
        id: art
        width: 128
        height: 92
        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter

        Loader {
            anchors.fill: parent
            sourceComponent: tile.isDir ? folderArt : fileArt
        }
    }

    Text {
        anchors.top: art.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        text: tile.name
        color: tile.current ? theme.brightForeground : theme.foreground
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 1.15
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: tile.clicked()
        onDoubleTapped: tile.activated()
    }

    Component {
        id: folderArt

        Item {
            readonly property color panel: theme.lighterBackground

            // Back of the folder and its tab.
            Rectangle { x: 4; y: 0; width: 46; height: 10; color: parent.panel; radius: Math.min(2, theme.radius) }
            Rectangle { x: 4; y: 8; width: 120; height: 84; color: parent.panel; radius: Math.min(2, theme.radius) }

            // Up to two pictures from inside, peeking over the front panel.
            Repeater {
                model: tile.peek
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    x: index === 0 ? 18 : 58
                    y: index === 0 ? 16 : 22
                    width: 52
                    height: 40
                    color: theme.darkBackground
                    border.width: 1
                    border.color: theme.lighterBackground
                    clip: true
                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: tile.thumbUrl(modelData, tile.guessImageMime(modelData), 128)
                    }
                }
            }

            // Front panel, tinted toward the accent, with the item count.
            Rectangle {
                x: 4; y: 40; width: 120; height: 52
                color: Qt.tint(theme.lighterBackground, tile.tint(theme.accent, 0.16))
                radius: Math.min(2, theme.radius)
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: theme.accent }
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    visible: tile.itemCount >= 0
                    text: qsTr("%n items", "", tile.itemCount)
                    color: theme.brightForeground
                    font.pixelSize: 10
                }
            }
        }
    }

    Component {
        id: fileArt

        Item {
            Image {
                id: thumb
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                asynchronous: true
                fillMode: tile.kind === "image" || tile.kind === "video" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                source: tile.kind === "text" ? "" : tile.thumbUrl(tile.path, tile.mime, 256)
                visible: status === Image.Ready
            }

            // Videos get a play mark over their frame.
            Rectangle {
                visible: thumb.status === Image.Ready && tile.kind === "video"
                anchors.centerIn: parent
                width: 30; height: 30
                radius: Math.min(4, theme.radius)
                color: tile.tint(theme.darkBackground, 0.75)
                Glyph { anchors.centerIn: parent; name: "play"; size: 16; color: theme.brightForeground }
            }

            // Stand-ins while a thumbnail loads, or when none can be made.
            Loader {
                anchors.fill: parent
                active: thumb.status !== Image.Ready
                sourceComponent: tile.kind === "audio" ? waveArt : tile.kind === "video" ? reelArt : pageArt
            }
        }
    }

    Component {
        id: pageArt

        Item {
            Rectangle {
                id: page
                anchors.horizontalCenter: parent.horizontalCenter
                width: 66; height: 92
                color: theme.lighterBackground
                border.width: 1
                border.color: tile.tint(theme.foreground, 0.16)
                radius: Math.min(2, theme.radius)
                Column {
                    x: 9; y: 11
                    spacing: 6
                    Rectangle { width: 34; height: 4; color: tile.kindColor }
                    Repeater {
                        model: [48, 48, 40, 48, 30]
                        Rectangle { required property int modelData; width: modelData; height: 2; color: tile.tint(theme.foreground, 0.3) }
                    }
                }
            }
            Rectangle {
                visible: tile.extension.length > 0
                anchors.left: page.left
                anchors.bottom: page.bottom
                anchors.bottomMargin: 6
                width: badge.implicitWidth + 8
                height: badge.implicitHeight + 2
                color: tile.kindColor
                Text { id: badge; anchors.centerIn: parent; text: tile.extension.slice(0, 4); font.pixelSize: 9; font.bold: true; color: theme.background }
            }
        }
    }

    Component {
        id: waveArt

        // Decorative, not the real waveform: bars seeded from the name so each
        // file keeps its own shape. Album art replaces it when the file has some.
        Rectangle {
            color: theme.lighterBackground
            radius: Math.min(2, theme.radius)
            Row {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 18
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: {
                            let h = 0
                            for (let i = 0; i < tile.name.length; ++i) h = (h * 31 + tile.name.charCodeAt(i) + index * 7) % 997
                            return 10 + (h % 40)
                        }
                        color: tile.kindColor
                    }
                }
            }
            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5; text: tile.extension; font.pixelSize: 9; color: theme.secondaryForeground }
        }
    }

    Component {
        id: reelArt

        Rectangle {
            color: theme.darkBackground
            radius: Math.min(2, theme.radius)
            Glyph { anchors.centerIn: parent; name: "play"; size: 22; color: tile.kindColor }
        }
    }
}
