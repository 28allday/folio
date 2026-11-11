#include "filemanager1.h"

#include <QDBusConnection>
#include <QFileInfo>
#include <QUrl>

#include "backend.h"
#include "windows.h"

FileManager1::FileManager1(Windows *windows) : QDBusAbstractAdaptor(windows), m_windows(windows) {}

void FileManager1::registerOn(Windows *windows) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return;
    new FileManager1(windows);
    if (bus.registerObject("/org/freedesktop/FileManager1", windows))
        bus.registerService("org.freedesktop.FileManager1");
}

// Folio shows one place at a time: the first local file or folder asked for.
static QString firstLocalPath(const QStringList &uris) {
    for (const QString &uri : uris)
        if (const QString path = QUrl(uri).toLocalFile(); !path.isEmpty())
            return path;
    return {};
}

void FileManager1::ShowFolders(const QStringList &uris, const QString &) {
    const QString path = firstLocalPath(uris);
    if (path.isEmpty())
        return;
    // The window used last shows it; with none open, a new one.
    if (Backend *backend = m_windows->latest())
        backend->showFolder(path);
    else
        m_windows->open(path);
}

void FileManager1::ShowItems(const QStringList &uris, const QString &) {
    const QString path = firstLocalPath(uris);
    if (path.isEmpty())
        return;
    if (Backend *backend = m_windows->latest())
        backend->showItem(path);
    else
        m_windows->open(QFileInfo(path).absolutePath(), QFileInfo(path).fileName());
}

// There is no properties dialog; the preview pane shows the same details.
void FileManager1::ShowItemProperties(const QStringList &uris, const QString &startupId) {
    ShowItems(uris, startupId);
}
