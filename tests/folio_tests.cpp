#include <QDir>
#include <QFile>
#include <QImage>
#include <QImageReader>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "foldermodel.h"
#include "places.h"
#include "previewer.h"
#include "theme.h"
#include "thumbnails.h"
#include "translator.h"

class FolioTests : public QObject {
    Q_OBJECT

private slots:
    void folderListsDirectoriesFirstWithoutHidden()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkdir("zeta");
        write(dir.filePath("alpha.md"), "# hi");
        write(dir.filePath("photo10.jpg"), "x");
        write(dir.filePath("photo9.jpg"), "x");
        write(dir.filePath(".secret"), "x");

        QString error;
        const auto entries = FolderModel::list(dir.path(), false, "name", &error);
        QVERIFY(error.isEmpty());
        QStringList names;
        for (const auto &e : entries) names << e.name;
        // Folders first, then natural order, so photo9 comes before photo10.
        QCOMPARE(names, QStringList({"zeta", "alpha.md", "photo9.jpg", "photo10.jpg"}));
        QCOMPARE(entries.at(0).kind, QString("folder"));
        QCOMPARE(entries.at(1).kind, QString("text"));
        QCOMPARE(entries.at(2).kind, QString("image"));
        QCOMPARE(entries.at(2).extension, QString("JPG"));

        QCOMPARE(FolderModel::list(dir.path(), true, "name", &error).size(), 5);
    }

    void folderReportsMissingFolders()
    {
        QString error;
        QVERIFY(FolderModel::list("/definitely/not/here", false, "name", &error).isEmpty());
        QVERIFY(!error.isEmpty());
    }

    void folderSummaryCountsAndPeeks()
    {
        QTemporaryDir dir;
        write(dir.filePath("a.jpg"), "x");
        write(dir.filePath("b.png"), "x");
        write(dir.filePath("c.png"), "x");
        write(dir.filePath("notes.txt"), "x");
        FolderModel::Entry entry;
        entry.path = dir.path();
        FolderModel::summarize(entry, false);
        QCOMPARE(entry.itemCount, 4);
        QCOMPARE(entry.peek.size(), 2);
    }

    void folderModelLoadsInTheBackground()
    {
        QTemporaryDir dir;
        write(dir.filePath("one.txt"), "x");
        FolderModel model;
        QSignalSpy loaded(&model, &FolderModel::loaded);
        model.setPath(dir.path());
        QVERIFY(loaded.wait(3000));
        QCOMPARE(model.count(), 1);
        QCOMPARE(model.get(0).value("name").toString(), QString("one.txt"));
        QCOMPARE(model.indexOf("one.txt"), 0);
    }

    void kindsFromMimeTypes()
    {
        QCOMPARE(FolderModel::kindForMime("application/pdf"), QString("pdf"));
        QCOMPARE(FolderModel::kindForMime("video/mp4"), QString("video"));
        QCOMPARE(FolderModel::kindForMime("audio/mp4"), QString("audio"));
        QCOMPARE(FolderModel::kindForMime("application/zip"), QString("archive"));
        QCOMPARE(FolderModel::kindForMime("application/octet-stream"), QString("other"));
    }

    void backendKeepsHistoryAndCrumbs()
    {
        QTemporaryDir home;
        QDir(home.path()).mkpath("Pictures/Trip");
        Backend backend(home.path());
        backend.navigate(home.path());
        backend.navigate(home.filePath("Pictures/Trip"));
        QCOMPARE(backend.title(), QString("Trip"));
        const auto crumbs = backend.crumbs();
        QCOMPARE(crumbs.size(), 3);
        QCOMPARE(crumbs.first().toMap().value("name").toString(), QString("~"));

        backend.goUp();
        QCOMPARE(backend.path(), home.filePath("Pictures"));
        // Coming back up selects the folder we left.
        QCOMPARE(backend.takeSelection(), QString("Trip"));
        backend.back();
        QCOMPARE(backend.path(), home.filePath("Pictures/Trip"));
        QVERIFY(backend.canForward());
    }

    void backendShowItemSelectsTheFile()
    {
        QTemporaryDir home;
        write(home.filePath("report.pdf"), "x");
        Backend backend(home.path());
        backend.showItem(home.filePath("report.pdf"));
        QCOMPARE(backend.path(), home.path());
        QCOMPARE(backend.takeSelection(), QString("report.pdf"));
    }

    void placesShowDropboxOnlyWhenPresent()
    {
        QTemporaryDir home;
        QDir(home.path()).mkpath("Documents");
        auto names = [](const Places &p) {
            QStringList list;
            for (const auto &v : p.places()) list << v.toMap().value("name").toString();
            return list;
        };
        QVERIFY(!names(Places(home.path())).contains("Dropbox"));
        QDir(home.path()).mkpath("Dropbox");
        const QStringList withDropbox = names(Places(home.path()));
        QVERIFY(withDropbox.contains("Dropbox"));
        QVERIFY(withDropbox.contains("Documents"));
        QVERIFY(!withDropbox.contains("Music"));
    }

    void placesParseTailscalePeers()
    {
        const QByteArray json = R"({"Peer":{
            "a":{"HostName":"nas","DNSName":"nas.example.ts.net.","OS":"linux","Online":false},
            "b":{"HostName":"studio","DNSName":"studio.example.ts.net.","OS":"linux","Online":true},
            "c":{"HostName":"phone","DNSName":"phone.example.ts.net.","OS":"iOS","Online":true}}})";
        const auto peers = Places::parseTailscale(json);
        // Offline machines and phones are left out.
        QCOMPARE(peers.size(), 1);
        QCOMPARE(peers.at(0).toMap().value("name").toString(), QString("studio"));
        QCOMPARE(peers.at(0).toMap().value("host").toString(), QString("studio.example.ts.net"));
    }

    void placesParseDropboxStatus()
    {
        QCOMPARE(Places::parseDropboxStatus("Up to date\n"), QString("synced"));
        QCOMPARE(Places::parseDropboxStatus("Syncing 3 files\n"), QString("syncing"));
        QCOMPARE(Places::parseDropboxStatus("Dropbox isn't running!\n"), QString("stopped"));
    }

    void thumbnailsFollowTheFreedesktopCache()
    {
        QTemporaryDir dir;
        QImage picture(800, 400, QImage::Format_RGB32);
        picture.fill(Qt::red);
        const QString file = dir.filePath("wide.png");
        QVERIFY(picture.save(file));

        Thumbnails thumbnails(dir.filePath("cache"), {dir.filePath("none")});
        const QImage thumb = thumbnails.load(file, "image/png", 256);
        QCOMPARE(thumb.size(), QSize(256, 128));

        // Cached under the spec's name, tagged so other apps trust it.
        const QString cached = dir.filePath("cache/large/" + Thumbnails::cacheKey(file));
        QVERIFY(QFile::exists(cached));
        const QImage stored(cached);
        QCOMPARE(stored.text("Thumb::URI"), QUrl::fromLocalFile(file).toString(QUrl::FullyEncoded));
        QVERIFY(!stored.text("Thumb::MTime").isEmpty());

        // A fresh cache entry is served as is: overwrite it with a marker
        // color and the next load must return the cached pixels.
        QImage marked = stored;
        marked.fill(Qt::blue);
        QVERIFY(marked.save(cached));
        QCOMPARE(thumbnails.load(file, "image/png", 256).pixelColor(0, 0), QColor(Qt::blue));
        QCOMPARE(Thumbnails::bucketFor(128), QString("normal"));
        QCOMPARE(Thumbnails::bucketFor(512), QString("x-large"));
    }

    void thumbnailsReadInstalledThumbnailers()
    {
        QTemporaryDir dir;
        write(dir.filePath("demo.thumbnailer"),
              "[Thumbnailer Entry]\nTryExec=/bin/sh\nExec=/bin/sh -c \"exit 1\" %i %o %s\nMimeType=video/mp4;video/webm;\n");
        Thumbnails thumbnails(dir.filePath("cache"), {dir.path()});
        QVERIFY(thumbnails.thumbnailerFor("video/webm").startsWith("/bin/sh"));
        QVERIFY(thumbnails.thumbnailerFor("video/ogg").isEmpty());

        // A thumbnailer that fails leaves a failure marker, so it isn't retried.
        write(dir.filePath("clip.mp4"), "not a video");
        QVERIFY(thumbnails.load(dir.filePath("clip.mp4"), "video/mp4", 128).isNull());
        QVERIFY(QFile::exists(dir.filePath("cache/fail/folio/" + Thumbnails::cacheKey(dir.filePath("clip.mp4")))));
    }

    void previewerPicksAViewerForEachType()
    {
        QCOMPARE(Previewer::viewerFor("image/png", false), QString("image"));
        QCOMPARE(Previewer::viewerFor("image/gif", false), QString("animated"));
        QCOMPARE(Previewer::viewerFor("image/x-canon-cr2", false), QString("thumbnail"));
        QCOMPARE(Previewer::viewerFor("video/mp4", false), QString("video"));
        QCOMPARE(Previewer::viewerFor("audio/mpeg", false), QString("audio"));
        QCOMPARE(Previewer::viewerFor("application/pdf", false), QString("pdf"));
        QCOMPARE(Previewer::viewerFor("text/markdown", false), QString("markdown"));
        QCOMPARE(Previewer::viewerFor("text/x-c++src", false), QString("text"));
        QCOMPARE(Previewer::viewerFor("application/x-shellscript", false), QString("text"));
        QCOMPARE(Previewer::viewerFor("application/zip", false), QString("other"));
        QCOMPARE(Previewer::viewerFor("inode/directory", true), QString("folder"));
    }

    void previewerReadsTextButNotBinaries()
    {
        QTemporaryDir dir;
        write(dir.filePath("notes.txt"), "hello\nworld\n");
        write(dir.filePath("blob.txt"), QByteArray("abc\0def", 7));
        QCOMPARE(Previewer::readText(dir.filePath("notes.txt")), QString("hello\nworld\n"));
        QVERIFY(Previewer::readText(dir.filePath("blob.txt")).isEmpty());
        QCOMPARE(Previewer::readText(dir.filePath("notes.txt"), 5), QString("hello"));

        // A binary with a text name falls back to the plain file view.
        Previewer previewer;
        previewer.start(dir.filePath("blob.txt"), false, "name");
        QCOMPARE(previewer.viewer(), QString("other"));
    }

    void previewerStepsThroughTheFolder()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkdir("album");
        write(dir.filePath("a.md"), "# A");
        write(dir.filePath("b.txt"), "b");
        write(dir.filePath("c.pdf"), "%PDF");
        write(dir.filePath(".hidden"), "h");

        Previewer previewer;
        QSignalSpy changed(&previewer, &Previewer::changed);
        previewer.start(dir.filePath("b.txt"), false, "name");
        // Shown at once, before the folder is listed.
        QCOMPARE(previewer.item().value("name").toString(), QString("b.txt"));
        QCOMPARE(previewer.text(), QString("b"));

        QTRY_COMPARE(previewer.count(), 4);
        QCOMPARE(previewer.index(), 2);
        previewer.previous();
        QCOMPARE(previewer.viewer(), QString("markdown"));
        previewer.previous();
        QCOMPARE(previewer.viewer(), QString("folder"));
        QCOMPARE(previewer.item().value("itemCount").toInt(), 0);
        previewer.previous();
        QCOMPARE(previewer.index(), 0);
        previewer.next();
        previewer.next();
        previewer.next();
        QCOMPARE(previewer.viewer(), QString("pdf"));
        previewer.next();
        QCOMPARE(previewer.index(), 3);

        // Folio pointing at a sibling keeps the list; another folder starts over.
        previewer.show(dir.filePath("a.md"));
        QCOMPARE(previewer.index(), 1);
        QCOMPARE(previewer.count(), 4);
        previewer.show(dir.filePath("album"));
        QCOMPARE(previewer.index(), 0);
        QVERIFY(changed.count() > 0);
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QColor("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QColor("black"));
        QVERIFY(!theme.light());
    }

    void themeReadsThePalette()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml",
              "mode = \"light\"\naccent = \"#112233\"\nbackground = \"#FFFCF0\"\nforeground = \"#100F0F\"\n");
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QColor("#112233"));
        QCOMPARE(theme.accentForeground(), QColor("white"));
        QCOMPARE(theme.background(), QColor("#FFFCF0"));
        // Missing derived backgrounds fall back to the base.
        QCOMPARE(theme.darkBackground(), QColor("#FFFCF0"));
        QVERIFY(theme.light());
    }

    void themeFollowsHyprlandRounding()
    {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        write(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n");
        QVERIFY(QFile::setPermissions(command, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        write(response, "{\"int\":0}");

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        write(response, "{\"int\":6}");
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Open").isNull());
    }

    void translatorPicksPluralForms()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "ru\n");
        write(dir.path() + "/en.json", R"({"%n items": {"one": "%n item", "other": "%n items"}})");
        write(dir.path() + "/ru.json", R"({"%n items": {"one": "%n элемент", "few": "%n элемента", "many": "%n элементов", "other": "%n элемента"}})");
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.translate("Main", "%n items", nullptr, 21), QString("%n элемент"));
        QCOMPARE(translator.translate("Main", "%n items", nullptr, 25), QString("%n элементов"));
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(FolioTests)
#include "folio_tests.moc"
