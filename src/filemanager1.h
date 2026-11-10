#pragma once

#include <QDBusAbstractAdaptor>
#include <QStringList>

class Backend;

// org.freedesktop.FileManager1: what browsers and other apps call for "Show
// in folder". Without it, those buttons do nothing once Nautilus is gone.
class FileManager1 : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.FileManager1")

public:
    FileManager1(QObject *host, Backend *backend);

    // Claims the bus name and object path; false when another file manager
    // already holds it, in which case folio simply runs without it.
    static bool registerOn(QObject *host, Backend *backend);

public slots:
    void ShowFolders(const QStringList &uris, const QString &startupId);
    void ShowItems(const QStringList &uris, const QString &startupId);
    void ShowItemProperties(const QStringList &uris, const QString &startupId);

private:
    Backend *m_backend;
};
