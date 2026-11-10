#pragma once

#include <QObject>
#include <QSocketNotifier>
#include <QVariantMap>
#include <QVector>

#include "foldermodel.h"

// The state behind `folio preview`: the file being looked at, its siblings
// to step through, and which viewer shows it. It runs in its own process, as
// Sushi does for Nautilus, so a video or PDF that crashes a decoder takes the
// preview window down, never the file manager.
//
// Talks to the Folio window that started it over stdin and stdout, one path
// per line: Folio writes the item selected in its grid, the preview writes
// the item it steps to, and each side follows the other.
class Previewer : public QObject {
    Q_OBJECT
    // Listing the folder only changes where the item sits among its
    // siblings, so it has a signal of its own: re-reading the item would set
    // a playing video's source again, which stops it.
    Q_PROPERTY(int count READ count NOTIFY listed)
    Q_PROPERTY(int index READ index NOTIFY listed)
    Q_PROPERTY(QVariantMap item READ item NOTIFY changed)
    Q_PROPERTY(QString viewer READ viewer NOTIFY changed)
    Q_PROPERTY(QString url READ url NOTIFY changed)
    Q_PROPERTY(QString text READ text NOTIFY changed)
    Q_PROPERTY(QString type READ type NOTIFY changed)

public:
    explicit Previewer(QObject *parent = nullptr);

    // Shows the file right away, then lists its folder in the background so
    // the arrow keys can step to its neighbours.
    void start(const QString &path, bool showHidden, const QString &sort);
    // Reads paths from stdin and reports steps on stdout.
    void connectToFolio();
    // Shows another file; one in the same folder keeps the list.
    void show(const QString &path);

    int count() const { return m_entries.size(); }
    int index() const { return m_index; }
    QVariantMap item() const;
    QString viewer() const { return m_viewer; }
    QString url() const;
    QString text() const { return m_text; }
    QString type() const;

    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void open();

    // Which view shows a type: image, animated, thumbnail, video, audio,
    // pdf, markdown, text, folder or other.
    static QString viewerFor(const QString &mime, bool isDir);
    // The opening part of a text file, or nothing when it looks binary.
    static QString readText(const QString &path, qint64 limit = 512 * 1024);

signals:
    void changed();
    void listed();

private:
    void setIndex(int index, bool report);

    QVector<FolderModel::Entry> m_entries;
    int m_index = -1;
    QString m_viewer;
    QString m_text;
    bool m_showHidden = false;
    QString m_sort = "name";
    quint64 m_generation = 0;
    bool m_reporting = false;
    QSocketNotifier *m_stdin = nullptr;
    QByteArray m_pending;
};
