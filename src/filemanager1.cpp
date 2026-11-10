#include "filemanager1.h"

#include <QDBusConnection>
#include <QUrl>

#include "backend.h"

FileManager1::FileManager1(QObject *host, Backend *backend) : QDBusAbstractAdaptor(host), m_backend(backend) {}

bool FileManager1::registerOn(QObject *host, Backend *backend) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return false;
    new FileManager1(host, backend);
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
            m_backend->showFolder(path);
            return;
        }
}

void FileManager1::ShowItems(const QStringList &uris, const QString &) {
    for (const QString &uri : uris)
        if (const QString path = localPath(uri); !path.isEmpty()) {
            m_backend->showItem(path);
            return;
        }
}

// There is no properties dialog; the preview pane shows the same details.
void FileManager1::ShowItemProperties(const QStringList &uris, const QString &startupId) {
    ShowItems(uris, startupId);
}
