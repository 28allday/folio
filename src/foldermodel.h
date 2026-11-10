#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QStringList>
#include <QTimer>
#include <QVector>

// One folder's contents, listed off the UI thread so a slow mount (an SFTP
// share over the tailnet, say) never freezes the window. Listing happens in
// two passes: the entries first, then each subfolder's item count and the
// first images inside it, which the folder tiles show peeking out.
class FolderModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int folderCount READ folderCount NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)

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
        PeekRole,
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
        QStringList peek;
    };

    explicit FolderModel(QObject *parent = nullptr);

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

    void setPath(const QString &path);
    Q_INVOKABLE void reload();
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int indexOf(const QString &name) const;

    // Synchronous building blocks, used by the background passes and tests.
    static QVector<Entry> list(const QString &path, bool showHidden, const QString &sort, QString *error);
    static void summarize(Entry &entry, bool showHidden);
    static QString kindForMime(const QString &mime);

signals:
    void pathChanged();
    void countChanged();
    void loadingChanged();
    void errorChanged();
    void showHiddenChanged();
    void sortModeChanged();
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
    bool m_loading = false;
    QString m_error;
    bool m_showHidden = false;
    QString m_sort = "name";
    quint64 m_generation = 0;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QTimer m_staleClear;
};
