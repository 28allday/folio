.pragma library
.import QtQml as QtQml

// Sizes, dates, counts and thumbnail URLs as the views show them, in one
// copy that every tile and row shares. A library can't see context
// properties, so a binding that shows a date reads translator.language
// itself to follow a language switch; whatever goes through qsTr here is
// refreshed with the rest of the strings.

function size(bytes) {
    const units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB")]
    let i = 0
    let value = bytes
    while (value >= 1000 && i < units.length - 1) { value /= 1000; ++i }
    return value.toLocaleString(Qt.locale(), "f", i === 0 ? 0 : 1) + " " + units[i]
}

// When it changed: the time for today, the date before that.
function when(date) {
    if (!date)
        return ""
    const locale = Qt.locale()
    const now = new Date()
    const today = date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() && date.getDate() === now.getDate()
    return today ? date.toLocaleTimeString(locale, QtQml.Locale.ShortFormat) : date.toLocaleDateString(locale, QtQml.Locale.ShortFormat)
}

// A folder's contents; nothing until they've been counted.
function count(n) {
    return n === 0 ? qsTr("Empty") : n > 0 ? qsTr("%n items", "", n) : ""
}

// What an item is and how big, under its name in the details and the preview.
function summary(item, type) {
    if (!item || !item.path)
        return ""
    if (item.isDir)
        return item.itemCount === 0 ? qsTr("Folder · Empty") : item.itemCount > 0 ? qsTr("Folder · %n items", "", item.itemCount) : qsTr("Folder")
    return (type || item.mime) + " · " + size(item.size)
}

function thumb(path, mime, px) {
    return "image://thumb/" + px + "/" + encodeURIComponent(mime) + "/" + encodeURIComponent(path)
}
