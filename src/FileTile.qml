import QtQuick
import QtQuick.Shapes

// One item in the grid: a preview on top, its name below. Folders are a
// quiet card with a dot per item inside; files show a real thumbnail when one
// can be made, and a drawn stand-in for their kind when not.
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

    // A folder's outline: a card with a tab on its top left edge, drawn as
    // one silhouette.
    component FolderShape: Shape {
        id: shape
        property color fill: theme.lighterBackground
        property color stroke: "transparent"
        property real strokeWidth: 1
        width: 128
        height: 92
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: shape.fill
            strokeColor: shape.stroke
            strokeWidth: shape.strokeWidth
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: "M4.5 88.5V0.5H46L50 6.5H123.5V88.5Z" }
        }
    }

    // Folders are a plain card with a dot for each thing inside, up to eight,
    // so full and empty folders read differently without a number or a
    // picture competing with the files around them.
    Component {
        id: folderArt

        Item {
            FolderShape {
                fill: tile.current ? Qt.tint(theme.lighterBackground, tile.tint(theme.accent, 0.22)) : theme.lighterBackground
                stroke: tile.current ? theme.accent : "transparent"
            }
            Row {
                x: 14
                y: 74
                spacing: 4
                Repeater {
                    model: Math.max(0, Math.min(8, tile.itemCount))
                    Rectangle { width: 4; height: 4; color: tile.tint(theme.foreground, 0.45) }
                }
                Text {
                    visible: tile.itemCount > 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    color: tile.tint(theme.foreground, 0.45)
                    font.pixelSize: 9
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
