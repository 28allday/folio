#include "foldermodel.h"

#include <QCollator>
#include <QDir>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QMimeDatabase>
#include <QPointer>
#include <QtConcurrent>
#include <algorithm>

FolderModel::FolderModel(QObject *parent) : QAbstractListModel(parent) {
    // Copies, saves and downloads change a folder in bursts; wait for the
    // burst to settle instead of relisting on every event.
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(250);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &FolderModel::reload);
    m_staleClear.setSingleShot(true);
    m_staleClear.setInterval(150);
    connect(&m_staleClear, &QTimer::timeout, this, &FolderModel::clearEntries);
}

void FolderModel::clearEntries() {
    m_staleClear.stop();
    if (m_entries.isEmpty())
        return;
    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();
}

int FolderModel::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant FolderModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};
    const Entry &e = m_entries.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case NameRole: return e.name;
    case PathRole: return e.path;
    case IsDirRole: return e.isDir;
    case SizeRole: return e.size;
    case ModifiedRole: return e.modified;
    case KindRole: return e.kind;
    case MimeRole: return e.mime;
    case ExtensionRole: return e.extension;
    case ItemCountRole: return e.itemCount;
    case PeekRole: return e.peek;
    }
    return {};
}

QHash<int, QByteArray> FolderModel::roleNames() const {
    return {
        {NameRole, "name"}, {PathRole, "path"}, {IsDirRole, "isDir"}, {SizeRole, "size"},
        {ModifiedRole, "modified"}, {KindRole, "kind"}, {MimeRole, "mime"},
        {ExtensionRole, "extension"}, {ItemCountRole, "itemCount"}, {PeekRole, "peek"},
    };
}

int FolderModel::folderCount() const {
    return std::count_if(m_entries.begin(), m_entries.end(), [](const Entry &e) { return e.isDir; });
}

void FolderModel::setShowHidden(bool show) {
    if (show == m_showHidden)
        return;
    m_showHidden = show;
    emit showHiddenChanged();
    reload();
}

void FolderModel::setSortMode(const QString &sort) {
    if (sort == m_sort || (sort != "name" && sort != "modified"))
        return;
    m_sort = sort;
    emit sortModeChanged();
    reload();
}

void FolderModel::setPath(const QString &path) {
    const QString clean = path.isEmpty() ? QString() : QDir::cleanPath(path);
    if (clean == m_path)
        return;
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    m_path = clean;
    emit pathChanged();

    // The old folder stays up while the new one is read, which locally takes
    // a few milliseconds: swapping straight from one to the other avoids an
    // empty frame between them. A slow listing (a tailnet machine) clears it
    // after a moment, so the old folder never lingers under the new path.
    // An empty path is a column with nothing to show yet.
    if (m_path.isEmpty()) {
        clearEntries();
        return;
    }
    m_staleClear.start();
    m_watcher.addPath(m_path);
    reload();
}

QString FolderModel::kindForMime(const QString &mime) {
    if (mime == "inode/directory") return "folder";
    if (mime == "application/pdf") return "pdf";
    if (mime.startsWith("image/")) return "image";
    if (mime.startsWith("video/")) return "video";
    if (mime.startsWith("audio/")) return "audio";
    if (mime.startsWith("text/") || mime == "application/json" || mime == "application/x-shellscript"
        || mime == "application/toml" || mime == "application/xml" || mime == "application/x-yaml")
        return "text";
    static const QStringList archives{"application/zip", "application/x-tar", "application/gzip",
                                      "application/x-xz", "application/zstd", "application/x-7z-compressed",
                                      "application/x-compressed-tar", "application/x-zstd-compressed-tar",
                                      "application/vnd.rar", "application/x-iso9660-image"};
    if (archives.contains(mime)) return "archive";
    return "other";
}

QVector<FolderModel::Entry> FolderModel::list(const QString &path, bool showHidden, const QString &sort,
                                              QString *error) {
    QVector<Entry> entries;
    QDir dir(path);
    if (!dir.exists()) {
        if (error) *error = QObject::tr("This folder no longer exists.");
        return entries;
    }
    if (!QFileInfo(path).isReadable()) {
        if (error) *error = QObject::tr("You don't have permission to open this folder.");
        return entries;
    }

    QDir::Filters filters = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
    if (showHidden)
        filters |= QDir::Hidden;

    // Extension-only matching: reading every file's header would make large
    // folders and network mounts crawl.
    QMimeDatabase mimes;
    const auto infos = dir.entryInfoList(filters, QDir::NoSort);
    entries.reserve(infos.size());
    for (const QFileInfo &info : infos) {
        Entry e;
        e.name = info.fileName();
        e.path = info.absoluteFilePath();
        e.isDir = info.isDir();
        e.size = e.isDir ? 0 : info.size();
        e.modified = info.lastModified();
        e.mime = e.isDir ? QStringLiteral("inode/directory")
                         : mimes.mimeTypeForFile(info, QMimeDatabase::MatchExtension).name();
        e.kind = kindForMime(e.mime);
        e.extension = e.isDir ? QString() : info.suffix().toUpper();
        entries.push_back(e);
    }

    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(entries.begin(), entries.end(), [&](const Entry &a, const Entry &b) {
        if (a.isDir != b.isDir)
            return a.isDir;
        if (sort == "modified" && a.modified != b.modified)
            return a.modified > b.modified;
        return collator.compare(a.name, b.name) < 0;
    });
    return entries;
}

void FolderModel::summarize(Entry &entry, bool showHidden) {
    QDir::Filters filters = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
    if (showHidden)
        filters |= QDir::Hidden;
    QDir dir(entry.path);
    const QStringList names = dir.entryList(filters, QDir::Name);
    entry.itemCount = names.size();
    entry.peek.clear();

    static const QStringList pictures{"jpg", "jpeg", "png", "webp", "gif", "heic", "avif", "jxl"};
    for (const QString &name : names) {
        if (pictures.contains(QFileInfo(name).suffix().toLower()))
            entry.peek << dir.filePath(name);
        if (entry.peek.size() == 2)
            break;
    }
}

void FolderModel::reload() {
    if (m_path.isEmpty())
        return;
    const quint64 generation = ++m_generation;
    setLoading(true);

    const QString path = m_path;
    const bool showHidden = m_showHidden;
    const QString sort = m_sort;
    auto *watcher = new QFutureWatcher<QPair<QVector<Entry>, QString>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, generation] {
        watcher->deleteLater();
        if (generation != m_generation)
            return; // A newer listing replaced this one while it ran.
        m_staleClear.stop();
        const auto [entries, error] = watcher->result();
        beginResetModel();
        m_entries = entries;
        endResetModel();
        emit countChanged();
        setError(error);
        setLoading(false);
        emit loaded();
        summarizeFolders(generation);
    });
    watcher->setFuture(QtConcurrent::run([path, showHidden, sort] {
        QString error;
        auto entries = list(path, showHidden, sort, &error);
        return qMakePair(entries, error);
    }));
}

void FolderModel::summarizeFolders(quint64 generation) {
    QVector<QPair<int, Entry>> folders;
    for (int row = 0; row < m_entries.size(); ++row)
        if (m_entries[row].isDir)
            folders.push_back({row, m_entries[row]});
    if (folders.isEmpty())
        return;

    const bool showHidden = m_showHidden;
    auto *watcher = new QFutureWatcher<QVector<QPair<int, Entry>>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, generation] {
        watcher->deleteLater();
        if (generation != m_generation)
            return;
        for (const auto &[row, summary] : watcher->result()) {
            if (row >= m_entries.size() || m_entries[row].path != summary.path)
                continue;
            m_entries[row].itemCount = summary.itemCount;
            m_entries[row].peek = summary.peek;
            const QModelIndex at = index(row);
            emit dataChanged(at, at, {ItemCountRole, PeekRole});
        }
    });
    watcher->setFuture(QtConcurrent::run([folders, showHidden]() mutable {
        for (auto &folder : folders)
            summarize(folder.second, showHidden);
        return folders;
    }));
}

QVariantMap FolderModel::get(int row) const {
    if (row < 0 || row >= m_entries.size())
        return {};
    const Entry &e = m_entries.at(row);
    return {
        {"name", e.name}, {"path", e.path}, {"isDir", e.isDir}, {"size", e.size},
        {"modified", e.modified}, {"kind", e.kind}, {"mime", e.mime},
        {"extension", e.extension}, {"itemCount", e.itemCount}, {"peek", e.peek},
    };
}

int FolderModel::indexOf(const QString &name) const {
    for (int row = 0; row < m_entries.size(); ++row)
        if (m_entries[row].name == name)
            return row;
    return -1;
}

void FolderModel::setLoading(bool loading) {
    if (loading == m_loading)
        return;
    m_loading = loading;
    emit loadingChanged();
}

void FolderModel::setError(const QString &error) {
    if (error == m_error)
        return;
    m_error = error;
    emit errorChanged();
}
