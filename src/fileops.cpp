#include "fileops.h"

#include <QClipboard>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QMimeData>
#include <QMimeDatabase>
#include <QProcess>
#include <QStorageInfo>
#include <QStandardPaths>
#include <QUrl>
#include <QtConcurrent>
#include <unistd.h>

// GIO's headers use `signals` as a struct member, which Qt defines as a
// keyword.
#undef signals
#include <gio/gio.h>
#define signals Q_SIGNALS

FileOps::FileOps(QObject *parent) : QObject(parent) {
    if (auto *clipboard = QGuiApplication::clipboard())
        connect(clipboard, &QClipboard::dataChanged, this, &FileOps::clipboardChanged);
}

QMimeData *FileOps::mimeDataFor(const QStringList &paths, bool cut) {
    auto *data = new QMimeData;
    QList<QUrl> urls;
    QByteArray gnome = cut ? "cut" : "copy";
    for (const QString &path : paths) {
        const QUrl url = QUrl::fromLocalFile(path);
        urls << url;
        gnome += '\n' + url.toEncoded();
    }
    data->setUrls(urls);
    data->setData("x-special/gnome-copied-files", gnome);
    data->setText(paths.join('\n'));
    return data;
}

QStringList FileOps::pathsFrom(const QMimeData *data, bool *cut) {
    if (cut)
        *cut = false;
    QStringList paths;
    if (!data)
        return paths;
    if (data->hasFormat("x-special/gnome-copied-files")) {
        const QList<QByteArray> lines = data->data("x-special/gnome-copied-files").split('\n');
        if (cut && !lines.isEmpty())
            *cut = lines.first().trimmed() == "cut";
        for (int i = 1; i < lines.size(); ++i) {
            const QUrl url = QUrl::fromEncoded(lines[i].trimmed());
            if (url.isLocalFile())
                paths << url.toLocalFile();
        }
        return paths;
    }
    for (const QUrl &url : data->urls())
        if (url.isLocalFile())
            paths << url.toLocalFile();
    return paths;
}

bool FileOps::canPaste() const {
    const auto *clipboard = QGuiApplication::clipboard();
    return clipboard && !pathsFrom(clipboard->mimeData(), nullptr).isEmpty();
}

void FileOps::copy(const QStringList &paths) {
    if (!paths.isEmpty())
        QGuiApplication::clipboard()->setMimeData(mimeDataFor(paths, false));
}

void FileOps::cut(const QStringList &paths) {
    if (!paths.isEmpty())
        QGuiApplication::clipboard()->setMimeData(mimeDataFor(paths, true));
}

void FileOps::yank(const QStringList &paths) {
    if (!paths.isEmpty())
        QGuiApplication::clipboard()->setText(paths.join('\n'));
}

int FileOps::extensionStart(const QString &name, bool isDir) {
    int dot = isDir ? -1 : name.lastIndexOf('.');
    if (dot <= 0)
        return -1;
    if (dot > 4 && name.mid(dot - 4, 4).compare(".tar", Qt::CaseInsensitive) == 0)
        dot -= 4;
    return dot;
}

QString FileOps::freeName(const QString &folder, const QString &name) {
    const QDir dir(folder);
    if (!QFileInfo::exists(dir.filePath(name)))
        return name;
    const QFileInfo info(dir.filePath(name));
    const int dot = extensionStart(name, info.isDir());
    const QString base = dot > 0 ? name.left(dot) : name;
    const QString ext = dot > 0 ? name.mid(dot) : QString();
    for (int n = 1;; ++n) {
        const QString candidate = n == 1 ? QObject::tr("%1 (copy)%2").arg(base, ext)
                                         : QObject::tr("%1 (copy %2)%3").arg(base).arg(n).arg(ext);
        if (!QFileInfo::exists(dir.filePath(candidate)))
            return candidate;
    }
}

bool FileOps::copyRecursively(const QString &from, const QString &to, QString *error) {
    const QFileInfo info(from);
    if (info.isSymLink()) {
        // Links are copied as links, not followed.
        if (!QFile::link(info.symLinkTarget(), to)) {
            *error = QObject::tr("Couldn't copy the link %1.").arg(info.fileName());
            return false;
        }
        return true;
    }
    if (!info.isDir()) {
        if (!QFile::copy(from, to)) {
            *error = QObject::tr("Couldn't copy %1.").arg(info.fileName());
            return false;
        }
        return true;
    }
    if (!QDir().mkdir(to)) {
        *error = QObject::tr("Couldn't create %1.").arg(QFileInfo(to).fileName());
        return false;
    }
    const QDir source(from);
    const auto entries = source.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
    for (const QFileInfo &entry : entries)
        if (!copyRecursively(entry.filePath(), QDir(to).filePath(entry.fileName()), error))
            return false;
    return true;
}

QStringList FileOps::transfer(const QStringList &paths, const QString &folder, bool move, QString *error) {
    QStringList made;
    const QString target = QDir::cleanPath(folder);
    for (const QString &path : paths) {
        const QFileInfo info(path);
        if (!info.exists() && !info.isSymLink()) {
            *error = QObject::tr("%1 is no longer there.").arg(info.fileName());
            break;
        }
        // Moving something into the folder it's already in does nothing.
        if (move && QDir::cleanPath(info.absolutePath()) == target)
            continue;
        if (info.isDir() && (target == QDir::cleanPath(path) || target.startsWith(QDir::cleanPath(path) + "/"))) {
            *error = QObject::tr("Can't put %1 inside itself.").arg(info.fileName());
            break;
        }
        const QString name = freeName(target, info.fileName());
        const QString destination = QDir(target).filePath(name);
        // A rename is instant on the same drive; across drives a move is a
        // copy, then removing the original only once the copy is complete.
        if (move && QFile::rename(path, destination)) {
            made << name;
            continue;
        }
        if (!copyRecursively(path, destination, error))
            break;
        if (move) {
            const bool removed = info.isDir() && !info.isSymLink() ? QDir(path).removeRecursively() : QFile::remove(path);
            if (!removed) {
                *error = QObject::tr("Copied %1, but couldn't remove the original.").arg(info.fileName());
                made << name;
                break;
            }
        }
        made << name;
    }
    return made;
}

void FileOps::paste(const QString &folder) {
    bool cut = false;
    const QStringList paths = pathsFrom(QGuiApplication::clipboard()->mimeData(), &cut);
    if (paths.isEmpty() || !m_busy.isEmpty())
        return;
    // Only Delete puts things in the trash, with the note Restore needs.
    if (!QFileInfo(folder).isDir() || inTrash(folder)) {
        emit failed(tr("Files can't be pasted here."));
        return;
    }
    // Cut files are gone from where they were once moved; pasting them
    // again would find nothing, so the clipboard lets go of them.
    transferInBackground(paths, folder, cut, cut);
}

bool FileOps::sameDrive(const QString &a, const QString &b) {
    return QStorageInfo(a).device() == QStorageInfo(b).device();
}

bool FileOps::canDrop(const QList<QUrl> &urls, const QString &folder) const {
    if (!QFileInfo(folder).isDir() || inTrash(folder))
        return false;
    const QString target = QDir::cleanPath(folder);
    bool any = false;
    for (const QUrl &url : urls) {
        if (!url.isLocalFile())
            continue;
        const QString path = QDir::cleanPath(url.toLocalFile());
        // Not onto itself or inside itself.
        if (path == target || target.startsWith(path + "/"))
            return false;
        // Already there: nothing would happen.
        if (QFileInfo(path).absolutePath() != target)
            any = true;
    }
    return any;
}

void FileOps::dropInto(const QList<QUrl> &urls, const QString &folder) {
    if (!canDrop(urls, folder) || !m_busy.isEmpty())
        return;
    const QStringList paths = localPaths(urls);
    transferInBackground(paths, folder, sameDrive(paths.first(), folder), false);
}

QString FileOps::uriList(const QStringList &paths) const {
    QStringList uris;
    for (const QString &path : paths)
        uris << QString::fromLatin1(QUrl::fromLocalFile(path).toEncoded());
    return uris.join("\r\n");
}

QStringList FileOps::localPaths(const QList<QUrl> &urls) const {
    QStringList paths;
    for (const QUrl &url : urls)
        if (url.isLocalFile())
            paths << url.toLocalFile();
    return paths;
}

void FileOps::transferInBackground(const QStringList &paths, const QString &folder, bool move, bool releaseClipboard) {
    setBusy(move ? tr("Moving %n items…", "", paths.size()) : tr("Copying %n items…", "", paths.size()));
    auto *watcher = new QFutureWatcher<QPair<QStringList, QString>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, paths, folder, releaseClipboard] {
        watcher->deleteLater();
        const auto [made, error] = watcher->result();
        setBusy({});
        // Only the cut that was pasted is let go of; something copied while
        // it moved stays on the clipboard.
        bool cut = false;
        if (releaseClipboard && error.isEmpty() && pathsFrom(QGuiApplication::clipboard()->mimeData(), &cut) == paths && cut)
            QGuiApplication::clipboard()->clear();
        if (!error.isEmpty())
            emit failed(error);
        if (!made.isEmpty())
            emit done(folder, made.first());
    });
    watcher->setFuture(QtConcurrent::run([paths, folder, move] {
        QString error;
        const QStringList made = transfer(paths, folder, move, &error);
        return qMakePair(made, error);
    }));
}

void FileOps::duplicate(const QString &path) {
    if (!m_busy.isEmpty())
        return;
    const QString folder = QFileInfo(path).absolutePath();
    setBusy(tr("Duplicating %1…").arg(QFileInfo(path).fileName()));
    auto *watcher = new QFutureWatcher<QPair<QStringList, QString>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, folder] {
        watcher->deleteLater();
        const auto [made, error] = watcher->result();
        setBusy({});
        if (!error.isEmpty())
            emit failed(error);
        if (!made.isEmpty())
            emit done(folder, made.first());
    });
    watcher->setFuture(QtConcurrent::run([path, folder] {
        QString error;
        const QStringList made = transfer({path}, folder, false, &error);
        return qMakePair(made, error);
    }));
}

QString FileOps::archiveName(const QStringList &paths, const QString &folder) {
    const QString base = paths.size() == 1 ? QFileInfo(paths.first()).fileName() : tr("Archive");
    return freeName(folder, base + ".zip");
}

void FileOps::compress(const QStringList &paths) {
    if (paths.isEmpty() || !m_busy.isEmpty())
        return;
    // Search results and Recents can span folders, so the archive goes in
    // the deepest folder holding them all, with their paths from there.
    const auto holds = [](const QString &folder, const QString &path) {
        const QString relative = QDir(folder).relativeFilePath(QFileInfo(path).absolutePath());
        return relative != ".." && !relative.startsWith("../");
    };
    QString folder = QFileInfo(paths.first()).absolutePath();
    for (const QString &path : paths)
        while (!holds(folder, path))
            folder = QFileInfo(folder).absolutePath();
    const QString archive = archiveName(paths, folder);
    QStringList args{"-a", "-cf", archive, "-C", folder, "--"};
    for (const QString &path : paths)
        args << QDir(folder).relativeFilePath(path);
    auto *process = new QProcess(this);
    process->setWorkingDirectory(folder);
    setBusy(tr("Compressing into %1…").arg(archive));
    connect(process, &QProcess::finished, this, [this, process, folder, archive](int code, QProcess::ExitStatus status) {
        process->deleteLater();
        setBusy({});
        if (code != 0 || status != QProcess::NormalExit) {
            // Leave nothing half-written behind.
            QFile::remove(QDir(folder).filePath(archive));
            emit failed(tr("Couldn't compress: %1").arg(QString::fromUtf8(process->readAllStandardError()).trimmed()));
            return;
        }
        emit done(folder, archive);
    });
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        process->deleteLater();
        setBusy({});
        emit failed(tr("Compressing needs bsdtar, from the libarchive package."));
    });
    process->start("bsdtar", args);
}

void FileOps::shareLocalSend(const QStringList &paths) {
    // The same command Omarchy's Nautilus extension runs.
    if (paths.isEmpty())
        return;
    if (!QProcess::startDetached("localsend", QStringList{"--headless", "send"} + paths))
        emit failed(tr("Sharing nearby needs LocalSend, which isn't installed."));
}

bool FileOps::hasLocalSend() const {
    return !QStandardPaths::findExecutable("localsend").isEmpty();
}

void FileOps::dropboxLink(const QString &path) {
    auto *process = new QProcess(this);
    const QString name = QFileInfo(path).fileName();
    setBusy(tr("Getting a Dropbox link for %1…").arg(name));
    connect(process, &QProcess::finished, this, [this, process, name](int code, QProcess::ExitStatus) {
        process->deleteLater();
        setBusy({});
        const QString out = QString::fromUtf8(process->readAllStandardOutput()).trimmed();
        // dropbox-cli prints the link, or a sentence saying why not.
        const QString link = out.section('\n', -1).trimmed();
        if (code != 0 || !link.startsWith("https://")) {
            const QString why = out.isEmpty() ? QString::fromUtf8(process->readAllStandardError()).trimmed() : out;
            emit failed(tr("Couldn't get a Dropbox link for %1: %2").arg(name, why));
            return;
        }
        QGuiApplication::clipboard()->setText(link);
        emit notice(tr("Dropbox link for %1 copied.").arg(name));
    });
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        process->deleteLater();
        setBusy({});
        emit failed(tr("Dropbox links need dropbox-cli, which isn't installed."));
    });
    process->start("dropbox-cli", {"sharelink", path});
}

void FileOps::shareTaildrop(const QStringList &paths, const QString &host) {
    if (paths.isEmpty() || !m_busy.isEmpty())
        return;
    auto *process = new QProcess(this);
    const QString machine = host.section('.', 0, 0);
    setBusy(tr("Sending to %1…").arg(machine));
    connect(process, &QProcess::finished, this, [this, process, machine](int code, QProcess::ExitStatus) {
        process->deleteLater();
        setBusy({});
        if (code != 0)
            emit failed(tr("Couldn't send to %1: %2").arg(machine, QString::fromUtf8(process->readAllStandardError()).trimmed()));
    });
    process->start("tailscale", QStringList{"file", "cp"} + paths + QStringList{host + ":"});
}

void FileOps::trash(const QStringList &paths) {
    if (paths.isEmpty())
        return;
    // GIO follows the freedesktop Trash spec, including each drive's own
    // .Trash folder, so Restore in any file manager puts things back.
    QStringList failedNames;
    for (const QString &path : paths) {
        GFile *file = g_file_new_for_path(path.toUtf8().constData());
        GError *error = nullptr;
        if (!g_file_trash(file, nullptr, &error)) {
            failedNames << QFileInfo(path).fileName() + (error ? QStringLiteral(" (") + QString::fromUtf8(error->message) + ")" : QString());
            if (error)
                g_error_free(error);
        }
        g_object_unref(file);
    }
    if (!failedNames.isEmpty())
        emit failed(tr("Couldn't move to the trash: %1").arg(failedNames.join(", ")));
}

QStringList FileOps::trashDirs() {
    QStringList dirs{QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash"};
    // Drives keep their own trash at the top, so deleting never copies
    // across disks: .Trash-<uid> (or .Trash/<uid>).
    const QString uid = QString::number(getuid());
    for (const QStorageInfo &volume : QStorageInfo::mountedVolumes()) {
        for (const QString &dir : {volume.rootPath() + "/.Trash-" + uid, volume.rootPath() + "/.Trash/" + uid})
            if (QFileInfo(dir + "/files").isDir() && !dirs.contains(dir))
                dirs << dir;
    }
    return dirs;
}

bool FileOps::inTrash(const QString &path) const {
    const QString clean = QDir::cleanPath(path);
    for (const QString &dir : trashDirs())
        if (clean == dir + "/files" || clean.startsWith(dir + "/files/"))
            return true;
    return false;
}

QString FileOps::infoFileFor(const QString &trashedPath) {
    const QFileInfo item(trashedPath);
    const QString trashDir = QFileInfo(item.absolutePath()).absolutePath();
    return trashDir + "/info/" + item.fileName() + ".trashinfo";
}

QString FileOps::readOriginalPath(const QString &trashedPath) {
    QFile info(infoFileFor(trashedPath));
    if (!info.open(QIODevice::ReadOnly))
        return {};
    for (const QByteArray &line : info.readAll().split('\n')) {
        if (!line.startsWith("Path="))
            continue;
        const QString path = QUrl::fromPercentEncoding(line.mid(5).trimmed());
        if (path.startsWith('/'))
            return path;
        // A drive's own trash records paths from the top of that drive.
        const QString trashDir = QFileInfo(QFileInfo(trashedPath).absolutePath()).absolutePath();
        const QString top = trashDir.contains("/.Trash/") ? trashDir.section("/.Trash/", 0, 0)
                                                          : QFileInfo(trashDir).absolutePath();
        return QDir(top).filePath(path);
    }
    return {};
}

QDateTime FileOps::readDeletionDate(const QString &trashedPath) {
    QFile info(infoFileFor(trashedPath));
    if (!info.open(QIODevice::ReadOnly))
        return {};
    for (const QByteArray &line : info.readAll().split('\n'))
        if (line.startsWith("DeletionDate="))
            // Local time, without a zone, as the spec writes it.
            return QDateTime::fromString(QString::fromUtf8(line.mid(13).trimmed()), Qt::ISODate);
    return {};
}

QDateTime FileOps::deletedAt(const QString &path) const {
    return readDeletionDate(path);
}

QString FileOps::originalPath(const QString &path) const {
    return readOriginalPath(path);
}

QString FileOps::restoreOne(const QString &trashedPath, QString *error) {
    const QString original = readOriginalPath(trashedPath);
    if (original.isEmpty()) {
        *error = tr("%1 has no record of where it came from.").arg(QFileInfo(trashedPath).fileName());
        return {};
    }
    const QString folder = QFileInfo(original).absolutePath();
    if (!QDir().mkpath(folder)) {
        *error = tr("Couldn't recreate %1.").arg(folder);
        return {};
    }
    const QString destination = QDir(folder).filePath(freeName(folder, QFileInfo(original).fileName()));
    if (!QFile::rename(trashedPath, destination)) {
        // Across drives (rare: trash lives on the item's own drive), copy.
        if (!copyRecursively(trashedPath, destination, error))
            return {};
        deleteTrashed(trashedPath);
    }
    QFile::remove(infoFileFor(trashedPath));
    return destination;
}

bool FileOps::deleteTrashed(const QString &trashedPath) {
    const QFileInfo item(trashedPath);
    const bool removed = item.isDir() && !item.isSymLink() ? QDir(trashedPath).removeRecursively()
                                                           : QFile::remove(trashedPath);
    QFile::remove(infoFileFor(trashedPath));
    return removed;
}

int FileOps::emptyTrashDir(const QString &trashDir) {
    int count = 0;
    const QDir files(trashDir + "/files");
    for (const QFileInfo &item : files.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System))
        if (deleteTrashed(item.absoluteFilePath()))
            ++count;
    // Notes left without a file, and the size cache, go too.
    QDir info(trashDir + "/info");
    for (const QString &name : info.entryList(QDir::Files | QDir::Hidden))
        info.remove(name);
    QFile::remove(trashDir + "/directorysizes");
    return count;
}

int FileOps::trashCount() const {
    int count = 0;
    for (const QString &dir : trashDirs())
        count += QDir(dir + "/files").entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).size();
    return count;
}

void FileOps::restore(const QStringList &paths) {
    QStringList failures;
    QString last;
    for (const QString &path : paths) {
        QString error;
        const QString to = restoreOne(path, &error);
        if (to.isEmpty())
            failures << error;
        else
            last = to;
    }
    if (!failures.isEmpty())
        emit failed(failures.join(' '));
    else if (!last.isEmpty())
        emit notice(paths.size() == 1 ? tr("Restored %1 to %2.").arg(QFileInfo(last).fileName(), QFileInfo(last).absolutePath())
                                      : tr("Restored %n items.", "", paths.size()));
}

void FileOps::deleteForever(const QStringList &paths) {
    int failures = 0;
    for (const QString &path : paths)
        if (!deleteTrashed(path))
            ++failures;
    if (failures > 0)
        emit failed(tr("Couldn't delete %n items.", "", failures));
}

void FileOps::emptyTrash() {
    if (!m_busy.isEmpty())
        return;
    setBusy(tr("Emptying the trash…"));
    auto *watcher = new QFutureWatcher<int>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher] {
        watcher->deleteLater();
        setBusy({});
        emit notice(tr("Emptied the trash: %n items deleted.", "", watcher->result()));
    });
    watcher->setFuture(QtConcurrent::run([] {
        int count = 0;
        for (const QString &dir : trashDirs())
            count += emptyTrashDir(dir);
        return count;
    }));
}

QString FileOps::rename(const QString &path, const QString &name) {
    const QString clean = name.trimmed();
    const QFileInfo info(path);
    if (clean.isEmpty() || clean == info.fileName())
        return {};
    if (clean.contains('/'))
        return tr("A name can't contain \"/\".");
    const QString destination = QDir(info.absolutePath()).filePath(clean);
    // QFile::rename never overwrites, and lets a name change only its case
    // on drives that ignore case, where the new name already "exists".
    if (!QFile::rename(path, destination))
        return QFileInfo::exists(destination) ? tr("%1 already exists here.").arg(clean)
                                              : tr("Couldn't rename %1.").arg(info.fileName());
    emit done(info.absolutePath(), clean);
    return {};
}

QString FileOps::newFolder(const QString &folder) {
    if (!QFileInfo(folder).isDir()) {
        emit failed(tr("Folders can't be made here."));
        return {};
    }
    QString name = tr("New Folder");
    for (int n = 2; QFileInfo::exists(QDir(folder).filePath(name)); ++n)
        name = tr("New Folder %1").arg(n);
    if (!QDir(folder).mkdir(name)) {
        emit failed(tr("Couldn't create a folder here."));
        return {};
    }
    emit done(folder, name);
    return name;
}

QVariantList FileOps::appsFor(const QString &path) const {
    QVariantList apps;
    const QString mime = QFileInfo(path).isDir() ? QStringLiteral("inode/directory")
                                                  : QMimeDatabase().mimeTypeForFile(path).name();
    char *type = g_content_type_from_mime_type(mime.toUtf8().constData());
    if (!type)
        return apps;
    GAppInfo *fallback = g_app_info_get_default_for_type(type, FALSE);
    const QString defaultId = fallback ? QString::fromUtf8(g_app_info_get_id(fallback)) : QString();
    if (fallback)
        g_object_unref(fallback);
    GList *all = g_app_info_get_all_for_type(type);
    for (GList *l = all; l; l = l->next) {
        auto *info = G_APP_INFO(l->data);
        if (!g_app_info_should_show(info))
            continue;
        const QString id = QString::fromUtf8(g_app_info_get_id(info));
        const QVariantMap app{{"id", id}, {"name", QString::fromUtf8(g_app_info_get_name(info))},
                              {"isDefault", id == defaultId}};
        if (id == defaultId)
            apps.prepend(app);
        else
            apps << app;
    }
    g_list_free_full(all, g_object_unref);
    g_free(type);
    return apps;
}

void FileOps::openWith(const QString &path, const QString &appId) {
    GList *all = g_app_info_get_all();
    bool launched = false;
    for (GList *l = all; l && !launched; l = l->next) {
        auto *info = G_APP_INFO(l->data);
        if (QString::fromUtf8(g_app_info_get_id(info)) != appId)
            continue;
        GFile *file = g_file_new_for_path(path.toUtf8().constData());
        GList *files = g_list_append(nullptr, file);
        GError *error = nullptr;
        launched = g_app_info_launch(info, files, nullptr, &error);
        if (!launched)
            emit failed(tr("Couldn't open %1 with %2: %3")
                            .arg(QFileInfo(path).fileName(), QString::fromUtf8(g_app_info_get_name(info)),
                                 QString::fromUtf8(error ? error->message : "")));
        if (error)
            g_error_free(error);
        g_list_free_full(files, g_object_unref);
        launched = true;
    }
    g_list_free_full(all, g_object_unref);
}

void FileOps::openTerminal(const QString &folder) {
    // xdg-terminal-exec starts the terminal Omarchy is set up with.
    if (!QProcess::startDetached("xdg-terminal-exec", {"--dir=" + folder}, folder))
        emit failed(tr("Couldn't start a terminal: xdg-terminal-exec isn't installed."));
}

void FileOps::setBusy(const QString &busy) {
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}
