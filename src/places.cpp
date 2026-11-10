#include "places.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QStorageInfo>
#include <algorithm>

Places::Places(const QString &home, QObject *parent)
    : QObject(parent), m_home(home.isEmpty() ? QDir::homePath() : home), m_realHome(home.isEmpty()) {
    connect(&m_tailscale, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        const QVariantList peers = code == 0 && status == QProcess::NormalExit
            ? parseTailscale(m_tailscale.readAllStandardOutput()) : QVariantList();
        if (peers != m_peers) {
            m_peers = peers;
            emit changed();
        }
    });
    connect(&m_dropbox, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        const QString status = parseDropboxStatus(m_dropbox.readAllStandardOutput());
        if (status != m_dropboxStatus) {
            m_dropboxStatus = status;
            refreshPlaces();
            emit changed();
        }
    });

    // Tailnet peers come and go, drives get plugged in, Dropbox syncs: a
    // gentle poll keeps the sidebar honest without any background service.
    m_poll.setInterval(15000);
    connect(&m_poll, &QTimer::timeout, this, &Places::refresh);
    if (m_realHome)
        m_poll.start();
    refresh();
}

void Places::refresh() {
    refreshPlaces();
    refreshDevices();
    if (m_realHome) {
        pollTailscale();
        pollDropbox();
    }
    emit changed();
}

QString Places::userDirectory(int location, const QString &fallback) const {
    if (m_realHome) {
        const QString path = QStandardPaths::writableLocation(QStandardPaths::StandardLocation(location));
        if (!path.isEmpty() && path != m_home)
            return path;
    }
    return m_home + "/" + fallback;
}

void Places::refreshPlaces() {
    QVariantList places;
    auto add = [&](const QString &name, const QString &path, const QString &icon, const QString &status = {}) {
        if (QFileInfo(path).isDir())
            places << QVariantMap{{"name", name}, {"path", path}, {"icon", icon}, {"status", status}};
    };
    add(tr("Home"), m_home, "home");
    add(tr("Documents"), userDirectory(QStandardPaths::DocumentsLocation, "Documents"), "documents");
    add(tr("Downloads"), userDirectory(QStandardPaths::DownloadLocation, "Downloads"), "downloads");
    add(tr("Pictures"), userDirectory(QStandardPaths::PicturesLocation, "Pictures"), "pictures");
    add(tr("Music"), userDirectory(QStandardPaths::MusicLocation, "Music"), "music");
    add(tr("Videos"), userDirectory(QStandardPaths::MoviesLocation, "Videos"), "videos");
    // Dropbox's folder only exists once it's set up (omarchy-install-service-
    // dropbox), so its presence is the signal to show it.
    add("Dropbox", m_home + "/Dropbox", "dropbox", m_dropboxStatus);
    add(tr("Trash"), m_home + "/.local/share/Trash/files", "trash");
    m_places = places;
}

void Places::refreshDevices() {
    QVariantList devices;
    auto add = [&](const QString &name, const QStorageInfo &storage) {
        const double total = storage.bytesTotal();
        devices << QVariantMap{
            {"name", name}, {"path", storage.rootPath()}, {"icon", "drive"},
            {"total", storage.bytesTotal()}, {"free", storage.bytesAvailable()},
            {"used", total > 0 ? 1.0 - storage.bytesAvailable() / total : 0.0},
        };
    };
    add(tr("System"), QStorageInfo::root());

    // Removable drives land under /run/media/<user>; network mounts and
    // pseudo filesystems are left out.
    for (const QStorageInfo &storage : QStorageInfo::mountedVolumes()) {
        const QString root = storage.rootPath();
        if (storage.isValid() && storage.isReady()
            && (root.startsWith("/run/media/") || root.startsWith("/media/")))
            add(storage.displayName(), storage);
    }
    m_devices = devices;
}

void Places::pollTailscale() {
    if (m_tailscale.state() != QProcess::NotRunning)
        return;
    const QString tailscale = QStandardPaths::findExecutable("tailscale");
    if (tailscale.isEmpty())
        return;
    m_tailscale.start(tailscale, {"status", "--json"});
}

void Places::pollDropbox() {
    if (m_dropbox.state() != QProcess::NotRunning || !QFileInfo(m_home + "/Dropbox").isDir())
        return;
    const QString cli = QStandardPaths::findExecutable("dropbox-cli");
    if (cli.isEmpty())
        return;
    m_dropbox.start(cli, {"status"});
}

QVariantList Places::parseTailscale(const QByteArray &json) {
    const QJsonObject root = QJsonDocument::fromJson(json).object();
    QVariantList peers;
    const QJsonObject all = root.value("Peer").toObject();
    for (auto it = all.begin(); it != all.end(); ++it) {
        const QJsonObject peer = it.value().toObject();
        QString host = peer.value("DNSName").toString();
        if (host.endsWith('.'))
            host.chop(1);
        const QString name = peer.value("HostName").toString();
        // Only machines that can hold files and can be reached right now:
        // phones can't be browsed over SFTP, and offline machines would only
        // be dead ends. The 15-second poll brings them back when they wake.
        const QString os = peer.value("OS").toString();
        if (name.isEmpty() || host.isEmpty() || (os != "linux" && os != "macOS" && os != "windows")
            || !peer.value("Online").toBool())
            continue;
        peers << QVariantMap{{"name", name}, {"host", host}, {"os", os}};
    }
    std::sort(peers.begin(), peers.end(), [](const QVariant &a, const QVariant &b) {
        return QString::localeAwareCompare(a.toMap().value("name").toString(), b.toMap().value("name").toString()) < 0;
    });
    return peers;
}

QString Places::parseDropboxStatus(const QByteArray &output) {
    const QString text = QString::fromUtf8(output).trimmed();
    if (text.isEmpty() || text.contains("isn't running", Qt::CaseInsensitive))
        return "stopped";
    if (text.startsWith("Up to date", Qt::CaseInsensitive))
        return "synced";
    return "syncing";
}
