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

QVariantList Places::physicalDrives(const QList<Mount> &mounts, const QString &systemDevice) {
    // Where the system itself lives; a drive mounted here is the computer,
    // not a device to browse to.
    static const QStringList systemRoots{"/", "/boot", "/efi", "/home", "/var", "/usr", "/opt", "/srv",
                                         "/root", "/tmp", "/nix", "/snap", "/swap"};
    static const QStringList pseudo{"tmpfs", "devtmpfs", "squashfs", "overlay", "ramfs", "fuse.portal",
                                    "fuse.gvfsd-fuse", "efivarfs", "autofs"};
    QVariantList drives;
    QStringList seen;
    for (const Mount &m : mounts) {
        const bool system = systemRoots.contains(m.root)
            || std::any_of(systemRoots.begin() + 1, systemRoots.end(),
                           [&](const QString &r) { return m.root.startsWith(r + "/"); })
            || m.root.startsWith("/.");
        // Only block devices; loop images (snaps, AppImages) and zram aren't
        // drives. Btrfs subvolumes of the system disk share its device.
        const bool block = m.device.startsWith("/dev/") && !m.device.startsWith("/dev/loop")
                           && !m.device.startsWith("/dev/zram");
        if (system || !block || pseudo.contains(m.type) || m.device == systemDevice || seen.contains(m.device))
            continue;
        seen << m.device;
        const QString name = m.label.isEmpty() ? QFileInfo(m.root).fileName() : m.label;
        drives << QVariantMap{{"name", name.isEmpty() ? m.root : name}, {"path", m.root}, {"icon", "drive"}};
    }
    return drives;
}

void Places::refreshDevices() {
    QList<Mount> mounts;
    auto volumes = QStorageInfo::mountedVolumes();
    // Shortest path first, so a drive mounted twice is listed at its top.
    std::sort(volumes.begin(), volumes.end(),
              [](const QStorageInfo &a, const QStorageInfo &b) { return a.rootPath().size() < b.rootPath().size(); });
    for (const QStorageInfo &v : volumes) {
        if (v.isValid() && v.isReady())
            mounts << Mount{v.rootPath(), QString::fromUtf8(v.device()), QString::fromUtf8(v.fileSystemType()),
                            v.name()};
    }
    m_devices = physicalDrives(mounts, QString::fromUtf8(QStorageInfo::root().device()));
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
