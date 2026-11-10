#pragma once

#include <QDBusAbstractAdaptor>
#include <QStringList>

class Windows;

// org.freedesktop.FileManager1: what browsers and other apps call for "Show
// in folder". Without it, those buttons do nothing once Nautilus is gone.
class FileManager1 : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.FileManager1")

public:
    explicit FileManager1(Windows *windows);

    // Claims the bus name and object path; when another file manager holds
    // the name, folio runs without it.
    static void registerOn(Windows *windows);

public slots:
    void ShowFolders(const QStringList &uris, const QString &startupId);
    void ShowItems(const QStringList &uris, const QString &startupId);
    void ShowItemProperties(const QStringList &uris, const QString &startupId);

private:
    Windows *m_windows;
};
