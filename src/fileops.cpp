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
#include <QStandardPaths>
#include <QUrl>
#include <QtConcurrent>

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

QString FileOps::freeName(const QString &folder, const QString &name) {
    const QDir dir(folder);
    if (!QFileInfo::exists(dir.filePath(name)))
        return name;
    // "notes.tar.gz" keeps its whole extension; folders and dotfiles have none.
    const QFileInfo info(dir.filePath(name));
    QString base = name;
    QString ext;
    const int dot = name.indexOf('.', 1);
    if (!info.isDir() && dot > 0) {
        base = name.left(dot);
        ext = name.mid(dot);
    }
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
    if (!QFileInfo(folder).isDir()) {
        emit failed(tr("Files can't be pasted here."));
        return;
    }
    setBusy(cut ? tr("Moving %n items…", "", paths.size()) : tr("Copying %n items…", "", paths.size()));
    auto *watcher = new QFutureWatcher<QPair<QStringList, QString>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, folder, cut] {
        watcher->deleteLater();
        const auto [made, error] = watcher->result();
        setBusy({});
        // Cut files are gone from where they were; pasting them again
        // would find nothing, so the clipboard lets go of them.
        if (cut && error.isEmpty())
            QGuiApplication::clipboard()->clear();
        if (!error.isEmpty())
            emit failed(error);
        if (!made.isEmpty())
            emit done(folder, made.first());
    });
    watcher->setFuture(QtConcurrent::run([paths, folder, cut] {
        QString error;
        const QStringList made = transfer(paths, folder, cut, &error);
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

QString FileOps::archiveName(const QStringList &paths) {
    const QString folder = QFileInfo(paths.first()).absolutePath();
    const QString base = paths.size() == 1 ? QFileInfo(paths.first()).fileName() : tr("Archive");
    return freeName(folder, base + ".zip");
}

void FileOps::compress(const QStringList &paths) {
    if (paths.isEmpty() || !m_busy.isEmpty())
        return;
    const QString folder = QFileInfo(paths.first()).absolutePath();
    const QString archive = archiveName(paths);
    QStringList args{"-a", "-cf", archive, "-C", folder, "--"};
    for (const QString &path : paths)
        args << QFileInfo(path).fileName();
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

QString FileOps::rename(const QString &path, const QString &name) {
    const QString clean = name.trimmed();
    const QFileInfo info(path);
    if (clean.isEmpty() || clean == info.fileName())
        return {};
    if (clean.contains('/'))
        return tr("A name can't contain \"/\".");
    const QString destination = QDir(info.absolutePath()).filePath(clean);
    if (QFileInfo::exists(destination))
        return tr("%1 already exists here.").arg(clean);
    if (!QFile::rename(path, destination))
        return tr("Couldn't rename %1.").arg(info.fileName());
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
