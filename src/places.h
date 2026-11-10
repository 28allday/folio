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
    Q_PROPERTY(QVariantList places READ places NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(QVariantList peers READ peers NOTIFY changed)
    Q_PROPERTY(QString dropboxStatus READ dropboxStatus NOTIFY changed)

public:
    // `home` is overridable for tests; the real home also consults the XDG
    // user-dirs, so renamed or translated folders are found.
    explicit Places(const QString &home = {}, QObject *parent = nullptr);

    QVariantList places() const { return m_places; }
    QVariantList devices() const { return m_devices; }
    QVariantList peers() const { return m_peers; }
    QString dropboxStatus() const { return m_dropboxStatus; }

    Q_INVOKABLE void refresh();

    static QVariantList parseTailscale(const QByteArray &json);
    static QString parseDropboxStatus(const QByteArray &output);

signals:
    void changed();

private:
    void refreshPlaces();
    void refreshDevices();
    void pollTailscale();
    void pollDropbox();
    QString userDirectory(int location, const QString &fallback) const;

    QString m_home;
    bool m_realHome;
    QVariantList m_places, m_devices, m_peers;
    QString m_dropboxStatus;
    QProcess m_tailscale, m_dropbox;
    QTimer m_poll;
};
