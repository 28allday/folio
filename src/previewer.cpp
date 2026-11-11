#include "previewer.h"

#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImageReader>
#include <QMimeDatabase>
#include <QUrl>
#include <QtConcurrent>
#include <cstdio>
#include <unistd.h>

Previewer::Previewer(QObject *parent) : QObject(parent) {}

QString Previewer::viewerFor(const QString &mime, bool isDir) {
    if (isDir)
        return "folder";
    if (mime == "application/pdf")
        return "pdf";
    if (mime.startsWith("video/"))
        return "video";
    if (mime.startsWith("audio/"))
        return "audio";
    if (mime.startsWith("image/")) {
        // Formats that can move are drawn by AnimatedImage, which shows the
        // still ones just as well.
        if (mime == "image/gif" || mime == "image/webp" || mime == "image/apng")
            return "animated";
        // Qt decodes the common formats at full size; the rest (HEIC, JPEG
        // XL, raw camera files) go through the installed thumbnailers at the
        // largest size the cache spec has.
        if (QImageReader::supportedMimeTypes().contains(mime.toLatin1()))
            return "image";
        return "thumbnail";
    }
    if (mime == "text/markdown")
        return "markdown";
    const QMimeType type = QMimeDatabase().mimeTypeForName(mime);
    if (mime.startsWith("text/") || type.inherits("text/plain"))
        return "text";
    return "other";
}

QString Previewer::readText(const QString &path, qint64 limit) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QByteArray data = file.read(limit);
    if (data.left(8192).contains('\0'))
        return {};
    return QString::fromUtf8(data);
}

void Previewer::start(const QString &path, bool showHidden, const QString &sort) {
    m_showHidden = showHidden;
    m_sort = sort;
    show(path);
}

void Previewer::show(const QString &path) {
    const QString absolute = QFileInfo(path).absoluteFilePath();
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries[i].path == absolute) {
            if (i != m_index)
                setIndex(i, false);
            return;
        }
    }

    // A file from another folder: show it alone, then fill in its siblings.
    m_entries = {FolderModel::entryFor(QFileInfo(absolute), QMimeDatabase())};
    setIndex(0, false);

    const quint64 generation = ++m_generation;
    const QString folder = QFileInfo(absolute).absolutePath();
    const bool showHidden = m_showHidden;
    const QString sort = m_sort;
    auto *watcher = new QFutureWatcher<QVector<FolderModel::Entry>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, generation] {
        watcher->deleteLater();
        if (generation != m_generation)
            return;
        const auto entries = watcher->result();
        const QString current = m_entries.at(m_index).path;
        for (int i = 0; i < entries.size(); ++i) {
            if (entries[i].path == current) {
                // Keep the entry already shown: it has the folder summary.
                const FolderModel::Entry shown = m_entries.at(m_index);
                m_entries = entries;
                m_entries[i] = shown;
                m_index = i;
                emit listed();
                return;
            }
        }
    });
    watcher->setFuture(QtConcurrent::run([folder, showHidden, sort] {
        return FolderModel::list(folder, showHidden, sort, nullptr);
    }));
}

QVariantMap Previewer::item() const {
    if (m_index < 0 || m_index >= m_entries.size())
        return {};
    // Only the preview fills in a folder's first pictures (in setIndex), so
    // only its items carry them; the folder model's would always be empty.
    const FolderModel::Entry &e = m_entries.at(m_index);
    QVariantMap map = FolderModel::toMap(e);
    map.insert("peek", e.peek);
    return map;
}

QString Previewer::url() const {
    if (m_index < 0 || m_index >= m_entries.size())
        return {};
    return QUrl::fromLocalFile(m_entries.at(m_index).path).toString();
}

QString Previewer::type() const {
    if (m_index < 0 || m_index >= m_entries.size())
        return {};
    return QMimeDatabase().mimeTypeForName(m_entries.at(m_index).mime).comment();
}

void Previewer::next() {
    if (m_index + 1 < m_entries.size())
        setIndex(m_index + 1, true);
}

void Previewer::previous() {
    if (m_index > 0)
        setIndex(m_index - 1, true);
}

void Previewer::open() {
    if (m_index >= 0)
        QDesktopServices::openUrl(QUrl::fromLocalFile(m_entries.at(m_index).path));
}

void Previewer::setIndex(int index, bool report) {
    m_index = index;
    FolderModel::Entry &e = m_entries[index];
    if (e.isDir && e.itemCount < 0)
        FolderModel::summarize(e, m_showHidden);
    m_viewer = viewerFor(e.mime, e.isDir);
    m_text.clear();
    if (m_viewer == "text" || m_viewer == "markdown") {
        m_text = readText(e.path);
        // A ".txt" that turns out to be binary is shown as a plain file.
        if (m_text.isEmpty() && e.size > 0)
            m_viewer = "other";
    }
    emit changed();
    emit listed();

    if (report && m_reporting) {
        std::fprintf(stdout, "%s\n", e.path.toUtf8().constData());
        std::fflush(stdout);
    }
}

void Previewer::connectToFolio() {
    m_reporting = true;
    m_stdin = new QSocketNotifier(STDIN_FILENO, QSocketNotifier::Read, this);
    connect(m_stdin, &QSocketNotifier::activated, this, [this] {
        char buffer[4096];
        const ssize_t n = ::read(STDIN_FILENO, buffer, sizeof buffer);
        if (n <= 0) {
            // Folio went away; there's nothing left to follow.
            m_stdin->setEnabled(false);
            return;
        }
        m_pending.append(buffer, n);
        int newline;
        while ((newline = m_pending.indexOf('\n')) >= 0) {
            const QString path = QString::fromUtf8(m_pending.left(newline));
            m_pending.remove(0, newline + 1);
            if (!path.isEmpty())
                show(path);
        }
    });
}
