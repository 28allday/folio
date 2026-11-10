// folio — Omarchy's file manager: airy, keyboard-first, and following the theme.

#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include "backend.h"
#include "filemanager1.h"
#include "places.h"
#include "theme.h"
#include "thumbnails.h"
#include "translator.h"

// Accepts a path, a file:// URI (how launchers and xdg-open pass folders),
// or nothing for home. A file opens its folder with the file selected.
static QString startPath(const QStringList &args, QString *select) {
    if (args.size() < 2)
        return QDir::homePath();
    const QString arg = args.at(1);
    const QUrl url(arg);
    const QString path = url.isLocalFile() ? url.toLocalFile() : QFileInfo(arg).absoluteFilePath();
    const QFileInfo info(path);
    if (info.isDir())
        return info.absoluteFilePath();
    if (info.exists()) {
        *select = info.fileName();
        return info.absolutePath();
    }
    return QDir::homePath();
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("folio");
    app.setApplicationVersion("0.1.0");

    // Matches the window to folio.desktop, so the compositor (Wayland app_id)
    // and the launcher pick up the installed icon.
    app.setDesktopFileName("folio");
    app.setWindowIcon(QIcon::fromTheme("folio"));

    // Omarchy points fontconfig's monospace at the font picked in its menu,
    // so asking for "monospace" follows the user's choice.
    QFont font("monospace");
    font.setStyleHint(QFont::Monospace);
    font.setPixelSize(13);
    app.setFont(font);

    QQuickStyle::setStyle("Material");

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Theme theme;
    Places places;
    Backend backend;
    Thumbnails thumbnails;

    QString select;
    const QString start = startPath(app.arguments(), &select);

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.addImageProvider("thumb", new ThumbnailProvider(&thumbnails));
    qmlRegisterUncreatableType<FolderModel>("Folio", 1, 0, "FolderModel", "Owned by the backend");
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("places", &places);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    FileManager1::registerOn(&backend, &backend);

    if (select.isEmpty())
        backend.navigate(start);
    else
        backend.showItem(start + "/" + select);

    return app.exec();
}
