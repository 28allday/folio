#pragma once

#include <QList>
#include <QObject>
#include <QQmlComponent>

class Backend;
class FileOps;
class QQmlContext;
class QQmlEngine;
class QQuickWindow;

// Folio's windows, all in one process. Each has its own folder, history,
// preview and file work (a Backend and a FileOps); they share the theme,
// the sidebar, the thumbnail cache and the compiled interface, so Ctrl+N
// opens a window in the time it takes to draw one rather than to start an
// app.
class Windows : public QObject {
    Q_OBJECT

public:
    explicit Windows(QQmlEngine *engine, QObject *parent = nullptr);

    // Opens a window on a folder, or on a file's folder with it selected.
    // Null if the interface failed to load (the errors are on stderr).
    Backend *open(const QString &folder, const QString &select = {});

    // The window used most recently, for "Show in folder" from other apps.
    Backend *latest() const;

    // Splits a window: a second folder pane on the right, with its own
    // folder, history and selection, starting at `folder`. Returns the pane.
    Q_INVOKABLE QObject *openSplit(QObject *window, const QString &folder);
    Q_INVOKABLE void closeSplit(QObject *window);

private:
    struct Pane {
        QObject *item = nullptr;
        Backend *backend = nullptr;
        FileOps *fileOps = nullptr;
        QQmlContext *context = nullptr;
    };
    struct Window {
        QQuickWindow *window;
        Backend *backend;
        FileOps *fileOps;
        QQmlContext *context;
        Pane split;
    };
    Window *find(QObject *window);
    static void release(Pane &pane);
    void close(QQuickWindow *window);

    QQmlEngine *m_engine;
    QQmlComponent m_component;
    QQmlComponent m_pane;
    // Most recently used first.
    QList<Window> m_windows;
};
