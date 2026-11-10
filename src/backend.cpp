#include "backend.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QMimeDatabase>
#include <QStandardPaths>
#include <QUrl>
#include <unistd.h>

Backend::Backend(const QString &home, QObject *parent)
    : QObject(parent), m_home(home.isEmpty() ? QDir::homePath() : home) {
    connect(&m_mount, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        setBusy({});
        const QString root = gvfsRoot() + "/sftp:host=" + m_mountHost;
        const QString output = QString::fromUtf8(m_mount.readAllStandardError()).trimmed();
        // "Already mounted" is as good as a fresh mount.
        if ((code != 0 || status != QProcess::NormalExit) && !QFileInfo(root).isDir()) {
            setMessage(tr("Couldn't open %1 over SFTP: %2").arg(m_mountHost, output.isEmpty() ? tr("the mount failed") : output));
            return;
        }
        // Land in the matching home folder when the other machine has one,
        // which on a tailnet of one person's machines it usually does.
        const QString remoteHome = root + QDir::homePath();
        navigate(QFileInfo(remoteHome).isDir() ? remoteHome : root);
    });
    connect(&m_mount, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        setBusy({});
        setMessage(tr("Opening tailnet machines needs gio from GVfs, which isn't installed."));
    });
}

QString Backend::gvfsRoot() {
    return QStringLiteral("/run/user/%1/gvfs").arg(getuid());
}

QString Backend::title() const {
    const QString p = path();
    if (p == m_home)
        return tr("Home");
    if (p == "/")
        return tr("Computer");
    if (QFileInfo(p).absolutePath() == gvfsRoot())
        return QFileInfo(p).fileName().section('=', 1);
    return QFileInfo(p).fileName();
}

QVariantList Backend::crumbs() const {
    // Breadcrumbs start at the nearest root that means something to a person:
    // ~ for home, a tailnet machine's name for its mount, / otherwise.
    const QString p = path();
    QString base = "/";
    QString label = "/";
    if (p == m_home || p.startsWith(m_home + "/")) {
        base = m_home;
        label = "~";
    } else if (p.startsWith(gvfsRoot() + "/")) {
        const QString mount = p.section('/', 0, 5);
        base = mount;
        label = mount.section('/', -1).section('=', 1);
    }

    QVariantList crumbs{QVariantMap{{"name", label}, {"path", base}}};
    const QString rest = p.mid(base.length());
    QString walk = base;
    for (const QString &part : rest.split('/', Qt::SkipEmptyParts)) {
        walk = walk.endsWith('/') ? walk + part : walk + "/" + part;
        crumbs << QVariantMap{{"name", part}, {"path", walk}};
    }
    return crumbs;
}

void Backend::navigate(const QString &path) {
    go(path, true);
}

void Backend::go(const QString &path, bool record) {
    const QString clean = QDir::cleanPath(path);
    if (!QFileInfo(clean).isDir()) {
        setMessage(tr("%1 isn't a folder.").arg(clean));
        return;
    }
    if (record) {
        if (m_index >= 0 && m_history.value(m_index) == clean)
            return;
        m_history = m_history.mid(0, m_index + 1);
        m_history << clean;
        m_index = m_history.size() - 1;
    }
    m_folder.setPath(clean);
    emit pathChanged();
}

void Backend::open(const QString &path) {
    const QFileInfo info(path);
    if (info.isDir()) {
        navigate(path);
        return;
    }
    // The desktop's default app for the type, via xdg-open, same as a click
    // anywhere else in Omarchy.
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(path)))
        setMessage(tr("No app is set up to open %1.").arg(info.fileName()));
}

void Backend::goUp() {
    const QString parent = QFileInfo(path()).absolutePath();
    if (parent == path())
        return;
    // Arriving back in the parent keeps the folder we came from selected, so
    // going up and down again is one keystroke each way.
    m_pendingSelection = QFileInfo(path()).fileName();
    navigate(parent);
}

void Backend::back() {
    if (!canBack())
        return;
    m_pendingSelection = QFileInfo(path()).fileName();
    --m_index;
    go(m_history.at(m_index), false);
}

void Backend::forward() {
    if (!canForward())
        return;
    ++m_index;
    go(m_history.at(m_index), false);
}

void Backend::openPeer(const QString &host) {
    if (m_mount.state() != QProcess::NotRunning)
        return;
    const QString root = gvfsRoot() + "/sftp:host=" + host;
    if (QFileInfo(root).isDir()) {
        const QString remoteHome = root + QDir::homePath();
        navigate(QFileInfo(remoteHome).isDir() ? remoteHome : root);
        return;
    }
    // SFTP over the tailnet: with Tailscale SSH on the other machine there
    // are no keys or passwords to manage, and GVfs makes the mount look like
    // any other folder.
    m_mountHost = host;
    setBusy(tr("Connecting to %1…").arg(host));
    m_mount.start("gio", {"mount", "sftp://" + host + "/"});
    m_mount.closeWriteChannel();
}

void Backend::dismissMessage() {
    setMessage({});
}

QString Backend::takeSelection() {
    const QString name = m_pendingSelection;
    m_pendingSelection.clear();
    return name;
}

QVariantMap Backend::details(const QString &path, const QString &kind, const QString &mime) const {
    QVariantMap map;
    // The system's own name for the type ("JPEG image"), already translated.
    map.insert("type", QMimeDatabase().mimeTypeForName(mime).comment());
    if (kind == "image") {
        QImageReader reader(path);
        reader.setAutoTransform(true);
        const QSize size = reader.size();
        if (size.isValid())
            map.insert("dimensions", QString("%1 × %2").arg(size.width()).arg(size.height()));
    } else if (kind == "text") {
        // Enough of the top of the file to recognize it, never the whole
        // thing: a log can be gigabytes.
        QFile file(path);
        if (file.open(QIODevice::ReadOnly)) {
            const QByteArray head = file.read(6000);
            if (!head.contains('\0'))
                map.insert("text", QString::fromUtf8(head).section('\n', 0, 40));
        }
    }
    return map;
}

void Backend::showFolder(const QString &path) {
    navigate(path);
    emit activateRequested();
}

void Backend::showItem(const QString &path) {
    const QFileInfo info(path);
    m_pendingSelection = info.fileName();
    const QString parent = info.absolutePath();
    if (parent == this->path()) {
        emit selectRequested(m_pendingSelection);
        m_pendingSelection.clear();
    } else {
        navigate(parent);
    }
    emit activateRequested();
}

void Backend::setMessage(const QString &message) {
    if (message == m_message)
        return;
    m_message = message;
    emit messageChanged();
}

void Backend::setBusy(const QString &busy) {
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}
