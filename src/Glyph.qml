import QtQuick
import QtQuick.Shapes

// One family of line icons, drawn on a 24-unit grid with the same stroke and
// square ends, so places, toolbar and tiles all match. Strokes stay crisp at
// any size because the path is scaled, not the stroke.
Item {
    id: glyph

    property string name: "file"
    property color color: theme.foreground
    property real size: 18
    property real stroke: 1.6
    // Brand marks are solid shapes rather than line drawings.
    readonly property bool filled: name === "dropbox"

    implicitWidth: size
    implicitHeight: size

    function circle(cx, cy, r) {
        return "M" + (cx - r) + " " + cy + "a" + r + " " + r + " 0 1 0 " + (2 * r) + " 0a" + r + " " + r + " 0 1 0 " + (-2 * r) + " 0"
    }

    readonly property var paths: ({
        "home": "M4 10l8-6 8 6v10H4zM10 20v-6h4v6",
        "documents": "M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6",
        "downloads": "M12 4v11M7 10l5 5 5-5M4 20h16",
        "pictures": "M3 5h18v14H3zM3 16l5-5 4 4 3-3 6 6" + circle(16, 9, 1.5),
        "music": "M9 17V5l11-2v12" + circle(6.5, 17, 2.5) + circle(17.5, 15, 2.5),
        "videos": "M3 5h18v14H3zM10 9v6l5-3z",
        // Dropbox's own mark, five diamonds: filled, as the brand draws it.
        "dropbox": "M7 2.5L12 5.7 7 8.9 2 5.7zM17 2.5L22 5.7 17 8.9 12 5.7zM7 8.9L12 12.1 7 15.3 2 12.1zM17 8.9L22 12.1 17 15.3 12 12.1zM12 13.3L17 16.5 12 19.7 7 16.5z",
        "recent": circle(12, 12, 9) + "M12 7v5l3 2",
        "trash": "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
        "drive": "M3 6h18v12H3zM7 14h2",
        "peer": "M4 4h16v11H4zM9 20h6M12 15v5",
        "folder": "M3 6h7l2 2h9v11H3z",
        "file": "M6 3h8l4 4v14H6zM14 3v4h4",
        "back": "M15 6l-6 6 6 6",
        "forward": "M9 6l6 6-6 6",
        "up": "M6 15l6-6 6 6",
        "grid": "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z",
        "list": "M4 6h16M4 12h16M4 18h16",
        "columns": "M3 4h18v16H3zM9 4v16M15 4v16",
        "preview": "M3 5h18v14H3zM14 5v14",
        "hidden": "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z" + circle(12, 12, 3),
        "sort": "M7 4v16M3 16l4 4 4-4M14 6h7M14 12h5M14 18h3",
        "play": "M8 5v14l11-7z",
        "pause": "M8 5v14M16 5v14",
        "open": "M14 4h6v6M20 4l-9 9M18 14v6H4V6h6",
        "audio": "M4 10v4M8 7v10M12 4v16M16 8v8M20 11v2",
        "close": "M6 6l12 12M18 6L6 18"
    })

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: glyph.filled ? "transparent" : glyph.color
            fillColor: glyph.filled ? glyph.color : "transparent"
            strokeWidth: glyph.stroke
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            scale: Qt.size(glyph.size / 24, glyph.size / 24)
            PathSvg { path: glyph.paths[glyph.name] || glyph.paths["file"] }
        }
    }
}
