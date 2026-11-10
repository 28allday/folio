#include "windows.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlProperty>
#include <QQuickItem>
#include <QQuickWindow>

#include "backend.h"
#include "fileops.h"

Windows::Windows(QQmlEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine), m_component(engine, QUrl("qrc:/Main.qml")),
      m_pane(engine, QUrl("qrc:/FolderPane.qml")) {
    // Main.qml calls windows.openSplit() and windows.closeSplit().
    engine->rootContext()->setContextProperty("windows", this);
}

Backend *Windows::open(const QString &folder, const QString &select) {
    if (m_component.isError()) {
        qWarning().noquote() << m_component.errorString();
        return nullptr;
    }
    // A context per window overrides `backend` and `fileOps`; everything
    // else comes from the engine's root context, shared.
    auto *context = new QQmlContext(m_engine->rootContext(), this);
    auto *backend = new Backend({}, this);
    auto *fileOps = new FileOps(this);
    context->setContextProperty("backend", backend);
    context->setContextProperty("fileOps", fileOps);

    auto *window = qobject_cast<QQuickWindow *>(m_component.create(context));
    if (!window) {
        qWarning().noquote() << m_component.errorString();
        delete backend;
        delete fileOps;
        delete context;
        return nullptr;
    }
    m_windows.prepend({window, backend, fileOps, context, {}});

    connect(backend, &Backend::newWindowRequested, this, [this](const QString &path) { open(path); });
    // Whichever window was used last answers "Show in folder".
    connect(window, &QQuickWindow::activeChanged, this, [this, window] {
        if (!window->isActive())
            return;
        for (int i = 0; i < m_windows.size(); ++i)
            if (m_windows[i].window == window)
                m_windows.move(i, 0);
    });
    connect(window, &QQuickWindow::closing, this, [this, window] { close(window); });

    if (select.isEmpty())
        backend->navigate(folder);
    else
        backend->showItem(folder + "/" + select);
    return backend;
}

Backend *Windows::latest() const {
    return m_windows.isEmpty() ? nullptr : m_windows.first().backend;
}

void Windows::close(QQuickWindow *window) {
    for (int i = 0; i < m_windows.size(); ++i) {
        if (m_windows[i].window != window)
            continue;
        Window w = m_windows.takeAt(i);
        release(w.split);
        // The window goes first, then what its QML was bound to. Closing
        // the backend also closes this window's preview, if one is open.
        w.window->deleteLater();
        w.backend->deleteLater();
        w.fileOps->deleteLater();
        w.context->deleteLater();
        return;
    }
}

Windows::Window *Windows::find(QObject *window) {
    for (Window &w : m_windows)
        if (w.window == window)
            return &w;
    return nullptr;
}

QObject *Windows::openSplit(QObject *window, const QString &folder) {
    Window *w = find(window);
    if (!w)
        return nullptr;
    if (w->split.item)
        return w->split.item;
    auto *host = w->window->findChild<QQuickItem *>("splitHost");
    if (!host || m_pane.isError()) {
        qWarning().noquote() << m_pane.errorString();
        return nullptr;
    }
    // Inside the window's context, with its own backend and file work.
    Pane pane;
    pane.context = new QQmlContext(w->context, this);
    pane.backend = new Backend({}, this);
    pane.fileOps = new FileOps(this);
    pane.context->setContextProperty("backend", pane.backend);
    pane.context->setContextProperty("fileOps", pane.fileOps);
    auto *item = qobject_cast<QQuickItem *>(m_pane.create(pane.context));
    if (!item) {
        qWarning().noquote() << m_pane.errorString();
        release(pane);
        return nullptr;
    }
    // Owned here, not by QML's garbage collector, though QML holds it.
    QQmlEngine::setObjectOwnership(item, QQmlEngine::CppOwnership);
    item->setParent(host);
    item->setParentItem(host);
    QQmlProperty(item, "anchors.fill").write(QVariant::fromValue(host));
    pane.item = item;
    connect(pane.backend, &Backend::newWindowRequested, this, [this](const QString &path) { open(path); });
    pane.backend->navigate(folder);
    w->split = pane;
    return item;
}

void Windows::closeSplit(QObject *window) {
    if (Window *w = find(window))
        release(w->split);
}

void Windows::release(Pane &pane) {
    // The pane goes first, then what its QML was bound to.
    if (pane.item)
        pane.item->deleteLater();
    if (pane.backend)
        pane.backend->deleteLater();
    if (pane.fileOps)
        pane.fileOps->deleteLater();
    if (pane.context)
        pane.context->deleteLater();
    pane = {};
}
