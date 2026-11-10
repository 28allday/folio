#include "backend.h"
#include "fileops.h"

#include <QDesktopServices>
#include <QCoreApplication>
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
    m_noticeTimer.setSingleShot(true);
    m_noticeTimer.setInterval(4000);
    connect(&m_noticeTimer, &QTimer::timeout, this, [this] {
        m_notice.clear();
        emit noticeChanged();
    });
    connect(&m_mounter, &Mounter::mounted, this, [this](const QString &, const QString &root) {
        setBusy({});
        // Land in the matching home folder when the other machine has one,
        // which on a tailnet of one person's machines it usually does.
        const QString remoteHome = root + QDir::homePath();
        navigate(QFileInfo(remoteHome).isDir() ? remoteHome : root);
    });
    connect(&m_mounter, &Mounter::failed, this, [this](const QString &, const QString &error) {
        setBusy({});
        // An empty error is the user saying no to a question: nothing to report.
        if (!error.isEmpty())
            setMessage(tr("Couldn't open %1 over SFTP: %2").arg(m_mountHost, error));
    });
    // The preview reports each file it steps to, and the grid follows.
    connect(&m_preview, &QProcess::readyReadStandardOutput, this, [this] {
        while (m_preview.canReadLine()) {
            const QString shown = QString::fromUtf8(m_preview.readLine()).trimmed();
            m_previewed = shown;
            const QFileInfo info(shown);
            if (info.absolutePath() == path())
                emit selectRequested(info.fileName());
        }
    });
    connect(&m_preview, &QProcess::stateChanged, this, &Backend::previewingChanged);
    connect(&m_preview, &QProcess::finished, this, [this](int, QProcess::ExitStatus status) {
        // A decoder that crashed took down the preview, not Folio; say so
        // rather than letting the window just vanish. Closing it from here
        // ends it with SIGTERM, which QProcess also reports as a crash.
        if (status == QProcess::CrashExit && !m_closingPreview)
            setMessage(tr("The preview closed unexpectedly on %1.").arg(QFileInfo(m_previewed).fileName()));
    });
}

QString Backend::gvfsRoot() {
    return QStringLiteral("/run/user/%1/gvfs").arg(getuid());
}

QString Backend::title() const {
    const QString p = path();
    if (p == FolderModel::recentPath())
        return tr("Recents");
    if (p == trashPath())
        return tr("Trash");
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
    if (p == FolderModel::recentPath())
        return {QVariantMap{{"name", tr("Recents")}, {"path", p}}};
    // The trash's files folder is an implementation detail; it's "Trash".
    if (p == trashPath())
        return {QVariantMap{{"name", tr("Trash")}, {"path", p}}};
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
    const QString clean = path == FolderModel::recentPath() ? path : QDir::cleanPath(path);
    // The trash folder only exists once something has been trashed; the
    // spec lets anyone create it, so Trash always opens.
    if (clean == trashPath())
        QDir().mkpath(clean);
    if (clean != FolderModel::recentPath() && !QFileInfo(clean).isDir()) {
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
    // Recents and the trash are places of their own: nothing above them.
    if (path() == FolderModel::recentPath() || path() == trashPath())
        return;
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
    if (m_mounter.busy())
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
    // Tailnet machines are reached over WireGuard to a peer Tailscale has
    // already authenticated, so the SSH "first time seeing this host" check
    // adds nothing but a prompt; it's accepted for them, and only them.
    m_mounter.mount("sftp://" + host + "/", true);
}

void Backend::showNotice(const QString &notice) {
    m_notice = notice;
    emit noticeChanged();
    m_noticeTimer.start();
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

Backend::~Backend() {
    // The preview follows this window; it closes with it.
    if (previewing()) {
        m_preview.terminate();
        m_preview.waitForFinished(1000);
    }
}

QString Backend::trashPath() const {
    return QDir::cleanPath(FileOps::homeTrash() + "/files");
}

QString Backend::typedPath() const {
    const QString p = path();
    if (p == m_home)
        return "~/";
    if (p.startsWith(m_home + "/"))
        return "~" + p.mid(m_home.size()) + "/";
    return p == FolderModel::recentPath() || p == "/" ? p : p + "/";
}

QString Backend::expandTyped(const QString &text, const QString &home, const QString &current) {
    QString t = text.trimmed();
    if (t.startsWith("file://"))
        t = QUrl(t).toLocalFile();
    if (t == "~")
        return home;
    if (t.startsWith("~/"))
        return home + t.mid(1);
    // A relative path is taken from the folder being shown.
    if (!t.startsWith('/') && QFileInfo(current).isDir())
        return QDir(current).filePath(t);
    return t;
}

bool Backend::goTyped(const QString &text) {
    const QString target = QDir::cleanPath(expandTyped(text, m_home, path()));
    const QFileInfo info(target);
    if (info.isDir()) {
        navigate(target);
        return true;
    }
    if (info.exists()) {
        showItem(target);
        return true;
    }
    setMessage(tr("%1 doesn't exist.").arg(text.trimmed()));
    return false;
}

QString Backend::complete(const QString &text, const QString &home, const QString &current) {
    // Completes the last part to the folder names it starts, as far as
    // they agree, keeping how the user typed the front (~, relative).
    const int slash = text.lastIndexOf('/');
    const QString head = slash >= 0 ? text.left(slash + 1) : QString();
    const QString part = text.mid(slash + 1);
    const QString folder = expandTyped(head.isEmpty() ? "." : head, home, current);
    QStringList matches;
    const auto names = QDir(folder).entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden, QDir::Name);
    for (const QString &name : names)
        if (name.startsWith(part) && (part.startsWith('.') || !name.startsWith('.')))
            matches << name;
    if (matches.isEmpty())
        return text;
    if (matches.size() == 1)
        return head + matches.first() + "/";
    QString common = matches.first();
    for (const QString &m : matches)
        while (!m.startsWith(common))
            common.chop(1);
    return head + common;
}

QString Backend::completePath(const QString &text) const {
    return complete(text, m_home, path());
}

void Backend::newWindow() {
    emit newWindowRequested(path() == FolderModel::recentPath() ? m_home : path());
}

void Backend::togglePreview(const QString &path) {
    if (previewing()) {
        m_closingPreview = true;
        m_preview.terminate();
        return;
    }
    if (path.isEmpty())
        return;
    QStringList args{"preview", "--follow", "--sort", m_folder.sortMode()};
    if (m_folder.showHidden())
        args << "--hidden";
    args << path;
    m_previewed = path;
    m_preview.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    m_closingPreview = false;
    m_preview.start(QCoreApplication::applicationFilePath(), args);
}

void Backend::followSelection(const QString &path) {
    if (!previewing() || path.isEmpty() || path == m_previewed)
        return;
    m_previewed = path;
    m_preview.write(path.toUtf8() + '\n');
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
