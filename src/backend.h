#pragma once

#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QVariantList>

#include "foldermodel.h"

// Where the window is and how it got there: the current folder, its
// breadcrumbs, back/forward history, and the actions that leave the folder
// (opening files, mounting a tailnet machine).
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(FolderModel *folder READ folder CONSTANT)
    Q_PROPERTY(QString path READ path NOTIFY pathChanged)
    Q_PROPERTY(QString title READ title NOTIFY pathChanged)
    Q_PROPERTY(QVariantList crumbs READ crumbs NOTIFY pathChanged)
    Q_PROPERTY(bool canBack READ canBack NOTIFY pathChanged)
    Q_PROPERTY(bool canForward READ canForward NOTIFY pathChanged)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
    Q_PROPERTY(QString busy READ busy NOTIFY busyChanged)

public:
    explicit Backend(const QString &home = {}, QObject *parent = nullptr);

    FolderModel *folder() { return &m_folder; }
    QString path() const { return m_folder.path(); }
    QString title() const;
    QVariantList crumbs() const;
    bool canBack() const { return m_index > 0; }
    bool canForward() const { return m_index + 1 < m_history.size(); }
    QString message() const { return m_message; }
    QString busy() const { return m_busy; }

    Q_INVOKABLE void navigate(const QString &path);
    Q_INVOKABLE void open(const QString &path);
    Q_INVOKABLE void goUp();
    Q_INVOKABLE void back();
    Q_INVOKABLE void forward();
    Q_INVOKABLE void openPeer(const QString &host);
    Q_INVOKABLE void dismissMessage();
    Q_INVOKABLE QVariantMap details(const QString &path, const QString &kind, const QString &mime) const;
    // The item to select once the folder has loaded (where we came from, or
    // what "Show in folder" asked for); empty means the first item.
    Q_INVOKABLE QString takeSelection();

    // Called for org.freedesktop.FileManager1: open a folder, or open the
    // folder holding a file and select it.
    void showFolder(const QString &path);
    void showItem(const QString &path);

    static QString gvfsRoot();

signals:
    void pathChanged();
    void messageChanged();
    void busyChanged();
    void selectRequested(const QString &name);
    void activateRequested();

private:
    void go(const QString &path, bool record);
    void setMessage(const QString &message);
    void setBusy(const QString &busy);

    QString m_home;
    FolderModel m_folder;
    QStringList m_history;
    int m_index = -1;
    QString m_message;
    QString m_busy;
    QString m_pendingSelection;
    QProcess m_mount;
    QString m_mountHost;
};
