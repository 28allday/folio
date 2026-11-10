#include "windows.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWindow>

#include "backend.h"
#include "fileops.h"

Windows::Windows(QQmlEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine), m_component(engine, QUrl("qrc:/Main.qml")) {}

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
    m_windows.prepend({window, backend, fileOps, context});

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
        const Window w = m_windows.takeAt(i);
        // The window goes first, then what its QML was bound to. Closing
        // the backend also closes this window's preview, if one is open.
        w.window->deleteLater();
        w.backend->deleteLater();
        w.fileOps->deleteLater();
        w.context->deleteLater();
        return;
    }
}
