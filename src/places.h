#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantList>

// The sidebar: the user's places (with Dropbox first-class when it's set up),
// the drives, and the machines on the tailnet. Each list is small, so it is
// handed to QML as plain maps rather than a model.
class Places : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString home READ home CONSTANT)
    Q_PROPERTY(QVariantList places READ places NOTIFY changed)
    Q_PROPERTY(QVariantList pinned READ pinned NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(QVariantList peers READ peers NOTIFY changed)
    Q_PROPERTY(QString dropboxStatus READ dropboxStatus NOTIFY changed)

public:
    // `home` is overridable for tests; the real home also consults the XDG
    // user-dirs, so renamed or translated folders are found.
    explicit Places(const QString &home = {}, QObject *parent = nullptr);

    QString home() const { return m_home; }
    QVariantList places() const { return m_places; }
    QVariantList pinned() const { return m_pinned; }
    QVariantList devices() const { return m_devices; }
    QVariantList peers() const { return m_peers; }
    QString dropboxStatus() const { return m_dropboxStatus; }

    Q_INVOKABLE void refresh();

    // Pins are GTK's bookmarks (~/.config/gtk-3.0/bookmarks), so a folder
    // pinned here is also in every GTK file dialog, and the other way round.
    // Returns an empty string, or why it couldn't be pinned.
    Q_INVOKABLE QString pin(const QString &path);
    Q_INVOKABLE void unpin(const QString &path);
    Q_INVOKABLE bool isPinned(const QString &path) const;

    // Reads bookmark lines ("file:///path Label") into pinned entries,
    // leaving out folders already listed under Home and missing folders.
    static QVariantList parseBookmarks(const QByteArray &contents, const QString &home);
    static QString displayName(const QString &name);

    static QVariantList parseTailscale(const QByteArray &json);
    static QString parseDropboxStatus(const QByteArray &output);

    struct Mount {
        QString root;
        QString device;
        QString type;
        QString label;
    };
    // The physical drives among the mounts, one entry per drive: removable
    // and extra internal disks, never the system's own partitions.
    static QVariantList physicalDrives(const QList<Mount> &mounts, const QString &systemDevice);

signals:
    void changed();

private:
    void refreshPlaces();
    void refreshDevices();
    void refreshPinned();
    QString bookmarksPath() const;
    QStringList readBookmarkLines() const;
    bool writeBookmarkLines(const QStringList &lines);
    void pollTailscale();
    void pollDropbox();
    QString userDirectory(int location, const QString &fallback) const;

    QString m_home;
    bool m_realHome;
    QVariantList m_places, m_pinned, m_devices, m_peers;
    QString m_dropboxStatus;
    QProcess m_tailscale, m_dropbox;
    QTimer m_poll;
};
