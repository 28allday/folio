#pragma once

#include <QAbstractListModel>
#include <functional>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QStringList>
#include <QTimer>
#include <QSet>
#include <QVector>
#include <atomic>
#include <memory>

// One folder's contents, listed off the UI thread so a slow mount (an SFTP
// share over the tailnet, say) never freezes the window. Listing happens in
// two passes: the entries first, then each subfolder's item count.
class QFileInfo;
class QMimeDatabase;

class FolderModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int folderCount READ folderCount NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    // Set, the folder lists what matches it here and in every folder below.
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IsDirRole,
        SizeRole,
        ModifiedRole,
        KindRole,
        MimeRole,
        ExtensionRole,
        ItemCountRole,
        SelectedRole,
    };

    struct Entry {
        QString name;
        QString path;
        bool isDir = false;
        qint64 size = 0;
        QDateTime modified;
        QString kind;
        QString mime;
        QString extension;
        int itemCount = -1;
        // The first pictures in a folder, for the preview window.
        QStringList peek;
    };

    explicit FolderModel(QObject *parent = nullptr);
    ~FolderModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString path() const { return m_path; }
    int count() const { return m_entries.size(); }
    int folderCount() const;
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool show);
    QString sortMode() const { return m_sort; }
    void setSortMode(const QString &sort);
    QString query() const { return m_query; }
    void setQuery(const QString &query);

    void setPath(const QString &path);
    Q_INVOKABLE void reload();
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int indexOf(const QString &name) const;

    // The selection, kept by path so it survives a re-read or a re-sort.
    // The views keep the cursor (the current item) themselves.
    int selectedCount() const { return m_selected.size(); }
    Q_INVOKABLE void selectOnly(int row);
    Q_INVOKABLE void toggleSelected(int row);
    Q_INVOKABLE void selectRange(int from, int to, bool add);
    Q_INVOKABLE void selectRows(const QList<int> &rows);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE bool isSelected(int row) const;
    Q_INVOKABLE QStringList selectedPaths() const;

    // Synchronous building blocks, used by the background passes and tests.
    static QVector<Entry> list(const QString &path, bool showHidden, const QString &sort, QString *error);
    static Entry entryFor(const QFileInfo &info, const QMimeDatabase &mimes);
    static void summarize(Entry &entry, bool showHidden);
    static QStringList sortModes();
    static void sortEntries(QVector<Entry> &entries, const QString &sort);
    // The Recents view: a path that isn't a folder, listing recently used files.
    static QString recentPath() { return QStringLiteral("recent:"); }
    static QString recentFile();
    static QVector<Entry> listRecent(const QString &xbel, bool showHidden, int limit = 200);
    static QString kindForMime(const QString &mime);
    // Everything under `root` whose name contains `query` (ignoring case),
    // named by its path from `root`. Stops at `limit` matches, at other
    // filesystems and at symlinks, and as soon as `stop` returns true.
    static QVector<Entry> search(const QString &root, const QString &query, bool showHidden, const QString &sort,
                                 const std::function<bool()> &stop = {}, int limit = 1000);

signals:
    void pathChanged();
    void countChanged();
    void loadingChanged();
    void errorChanged();
    void showHiddenChanged();
    void sortModeChanged();
    void queryChanged();
    void selectionChanged();
    void loaded();

private:
    void setLoading(bool loading);
    void clearEntries();
    QString cacheKey() const;
    void remember();
    static bool sameListing(const QVector<Entry> &a, const QVector<Entry> &b);
    void setError(const QString &error);
    void summarizeFolders(quint64 generation);

    QString m_path;
    QVector<Entry> m_entries;
    QSet<QString> m_selected;
    void setSelected(const QSet<QString> &paths);
    bool m_loading = false;
    QString m_error;
    bool m_showHidden = false;
    QString m_sort = "name";
    QString m_query;
    quint64 m_generation = 0;
    // The newest listing's generation, shared with the background searches
    // so one that's been overtaken by more typing stops walking.
    std::shared_ptr<std::atomic<quint64>> m_latest = std::make_shared<std::atomic<quint64>>(0);
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QTimer m_staleClear;
};
