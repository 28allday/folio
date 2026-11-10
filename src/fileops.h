#pragma once

#include <QDateTime>
#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

class QMimeData;

// What can be done to files: the clipboard (copy, cut, paste, and yanking
// paths as text), trash, rename, new folder, and opening with another app.
// Long work (copying a folder of videos) runs off the UI thread and reports
// through `busy`; nothing is ever overwritten, so a name that's taken gets a
// "(copy)" name beside it.
class FileOps : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool canPaste READ canPaste NOTIFY clipboardChanged)

public:
    explicit FileOps(QObject *parent = nullptr);

    QString busy() const { return m_busy; }
    bool canPaste() const;

    // The clipboard holds files the way GNOME and KDE apps expect
    // (x-special/gnome-copied-files plus text/uri-list), and their paths as
    // plain text, so pasting into a terminal or editor gives the path.
    Q_INVOKABLE void copy(const QStringList &paths);
    Q_INVOKABLE void cut(const QStringList &paths);
    Q_INVOKABLE void yank(const QStringList &paths);
    Q_INVOKABLE void paste(const QString &folder);
    // Files dropped on a folder: moved when they're on the same drive,
    // copied from another drive. Dropping something where it already is
    // does nothing.
    Q_INVOKABLE void dropInto(const QList<QUrl> &urls, const QString &folder);
    // Whether these can be dropped on `folder`: not onto themselves, and
    // not into the trash, which only Delete fills.
    Q_INVOKABLE bool canDrop(const QList<QUrl> &urls, const QString &folder) const;
    // Files as a text/uri-list, for dragging them somewhere, and back from
    // dropped URLs to the paths of the local ones. QUrl escapes what a
    // path may hold but a URI can't (a "#" or "?" in a name).
    Q_INVOKABLE QString uriList(const QStringList &paths) const;
    Q_INVOKABLE QStringList localPaths(const QList<QUrl> &urls) const;

    // A copy beside the original, named "(copy)".
    Q_INVOKABLE void duplicate(const QString &path);
    // Packs the items into a .zip beside them (bsdtar, from libarchive).
    Q_INVOKABLE void compress(const QStringList &paths);
    // Sends with LocalSend to a nearby device, or with Taildrop to a
    // machine on the tailnet.
    Q_INVOKABLE void shareLocalSend(const QStringList &paths);
    Q_INVOKABLE bool hasLocalSend() const;
    // Asks Dropbox for a share link to a file in the Dropbox folder and
    // puts it on the clipboard.
    Q_INVOKABLE void dropboxLink(const QString &path);
    Q_INVOKABLE void shareTaildrop(const QStringList &paths, const QString &host);

    Q_INVOKABLE void trash(const QStringList &paths);

    // The trash, per the freedesktop Trash spec: each item in Trash/files
    // has a note in Trash/info saying where it came from.
    Q_INVOKABLE bool inTrash(const QString &path) const;
    // Where a trashed item came from, or empty if its note is missing.
    Q_INVOKABLE QString originalPath(const QString &path) const;
    // When it was trashed, from its note.
    Q_INVOKABLE QDateTime deletedAt(const QString &path) const;
    // Puts items back where they came from (recreating the folder if it's
    // gone, and never overwriting what's there now).
    Q_INVOKABLE void restore(const QStringList &paths);
    // Deletes trashed items for good, and empties the whole trash.
    Q_INVOKABLE void deleteForever(const QStringList &paths);
    Q_INVOKABLE void emptyTrash();
    Q_INVOKABLE int trashCount() const;
    // Empty string on success, or why not.
    Q_INVOKABLE QString rename(const QString &path, const QString &name);
    // Makes "New Folder" (or "New Folder 2"...) and returns its name.
    Q_INVOKABLE QString newFolder(const QString &folder);

    // The apps that can open a file, from the desktop's MIME database:
    // {id, name, isDefault}, the default first.
    Q_INVOKABLE QVariantList appsFor(const QString &path) const;
    Q_INVOKABLE void openWith(const QString &path, const QString &appId);
    Q_INVOKABLE void openTerminal(const QString &folder);

    // Building blocks, kept static for tests.
    static QMimeData *mimeDataFor(const QStringList &paths, bool cut);
    // The paths on the clipboard and whether they were cut.
    static QStringList pathsFrom(const QMimeData *data, bool *cut);
    // A name in `folder` that isn't taken: the name itself, or
    // "name (copy).ext", "name (copy 2).ext"...
    static QString freeName(const QString &folder, const QString &name);
    static bool copyRecursively(const QString &from, const QString &to, QString *error);
    // The archive name for compressing these: "name.zip" for one item,
    // "Archive.zip" for several; never one that exists.
    static QString archiveName(const QStringList &paths);
    static bool sameDrive(const QString &a, const QString &b);
    // The trash folders: the home one, then each mounted drive's own.
    static QStringList trashDirs();
    // For an item in <trash>/files: its note, and the path it came from.
    static QString infoFileFor(const QString &trashedPath);
    static QString readOriginalPath(const QString &trashedPath);
    static QDateTime readDeletionDate(const QString &trashedPath);
    // Restores one item; returns where it went, or empty with `error` set.
    static QString restoreOne(const QString &trashedPath, QString *error);
    static bool deleteTrashed(const QString &trashedPath);
    static int emptyTrashDir(const QString &trashDir);
    // Copies or moves each path into `folder`; returns the new names.
    static QStringList transfer(const QStringList &paths, const QString &folder, bool move, QString *error);

signals:
    void busyChanged();
    void clipboardChanged();
    void failed(const QString &message);
    void notice(const QString &notice);
    // Work finished in `folder`, which now holds `name` (to select it).
    void done(const QString &folder, const QString &name);

private:
    void setBusy(const QString &busy);
    void transferInBackground(const QStringList &paths, const QString &folder, bool move, bool releaseClipboard);

    QString m_busy;
};
