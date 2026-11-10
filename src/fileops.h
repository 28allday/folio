#pragma once

#include <QObject>
#include <QStringList>
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

    // A copy beside the original, named "(copy)".
    Q_INVOKABLE void duplicate(const QString &path);
    // Packs the items into a .zip beside them (bsdtar, from libarchive).
    Q_INVOKABLE void compress(const QStringList &paths);
    // Sends with LocalSend to a nearby device, or with Taildrop to a
    // machine on the tailnet.
    Q_INVOKABLE void shareLocalSend(const QStringList &paths);
    Q_INVOKABLE void shareTaildrop(const QStringList &paths, const QString &host);

    Q_INVOKABLE void trash(const QStringList &paths);
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
    // Copies or moves each path into `folder`; returns the new names.
    static QStringList transfer(const QStringList &paths, const QString &folder, bool move, QString *error);

signals:
    void busyChanged();
    void clipboardChanged();
    void failed(const QString &message);
    // Work finished in `folder`, which now holds `name` (to select it).
    void done(const QString &folder, const QString &name);

private:
    void setBusy(const QString &busy);

    QString m_busy;
};
