#pragma once

#include <QHash>
#include <QImage>
#include <QQuickAsyncImageProvider>
#include <QStringList>
#include <QThreadPool>

// Thumbnails per the freedesktop thumbnail spec: one shared cache under
// ~/.cache/thumbnails, keyed by the MD5 of the file's URI and invalidated by
// its modification time, so thumbnails made by any other app are reused and
// ours are useful to them. Images are scaled in-process; everything else goes
// through the thumbnailers installed in /usr/share/thumbnailers (videos via
// ffmpegthumbnailer, PDFs via Papers, and so on). Nothing is generated until a
// tile asks for it: there is no background crawl.
class Thumbnails {
public:
    explicit Thumbnails(const QString &cacheDirectory = {}, const QStringList &thumbnailerDirectories = {});

    // Returns a thumbnail no larger than `size` on its longest side, from the
    // cache when it is fresh, or a null image when none can be made.
    QImage load(const QString &path, const QString &mime, int size) const;

    static QString cacheKey(const QString &path);
    static QString bucketFor(int size);
    QString thumbnailerFor(const QString &mime) const { return m_thumbnailers.value(mime); }

private:
    QString cachePath(const QString &path, int size) const;
    QString failPath(const QString &path) const;
    // Sets `attempted` when Qt's reader or a thumbnailer could take the file.
    QImage generate(const QString &path, const QString &mime, int pixels, bool &attempted) const;
    QImage runThumbnailer(const QString &command, const QString &path, int pixels) const;
    void remember(QImage image, const QString &path, int size, const QString &mtime) const;
    void rememberFailure(const QString &path, const QString &mtime) const;
    bool failedBefore(const QString &path, const QString &mtime) const;
    void save(QImage image, const QString &target, const QString &path, const QString &mtime) const;

    QString m_cache;
    QHash<QString, QString> m_thumbnailers;
};

// Serves image://thumb/<size>/<modified>/<mime>/<path> to QML on a thread pool.
class ThumbnailProvider : public QQuickAsyncImageProvider {
public:
    explicit ThumbnailProvider(const Thumbnails *thumbnails);
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

private:
    const Thumbnails *m_thumbnails;
    QThreadPool m_pool;
};
