#include "filemanager1.h"

#include <QDBusConnection>
#include <QFileInfo>
#include <QUrl>

#include "backend.h"
#include "windows.h"

FileManager1::FileManager1(QObject *host, Windows *windows) : QDBusAbstractAdaptor(host), m_windows(windows) {}

bool FileManager1::registerOn(QObject *host, Windows *windows) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return false;
    new FileManager1(host, windows);
    if (!bus.registerObject("/org/freedesktop/FileManager1", host))
        return false;
    return bus.registerService("org.freedesktop.FileManager1");
}

static QString localPath(const QString &uri) {
    const QUrl url(uri);
    return url.isLocalFile() ? url.toLocalFile() : QString();
}

void FileManager1::ShowFolders(const QStringList &uris, const QString &) {
    for (const QString &uri : uris)
        if (const QString path = localPath(uri); !path.isEmpty()) {
            // The window used last shows it; with none open, a new one.
            if (Backend *backend = m_windows->latest())
                backend->showFolder(path);
            else
                m_windows->open(path);
            return;
        }
}

void FileManager1::ShowItems(const QStringList &uris, const QString &) {
    for (const QString &uri : uris)
        if (const QString path = localPath(uri); !path.isEmpty()) {
            if (Backend *backend = m_windows->latest())
                backend->showItem(path);
            else
                m_windows->open(QFileInfo(path).absolutePath(), QFileInfo(path).fileName());
            return;
        }
}

// There is no properties dialog; the preview pane shows the same details.
void FileManager1::ShowItemProperties(const QStringList &uris, const QString &startupId) {
    ShowItems(uris, startupId);
}
