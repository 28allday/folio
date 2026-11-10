QT += core gui quick quickcontrols2 testlib dbus concurrent
CONFIG += c++17 testcase
TARGET = folio_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/fileops.h ../src/foldermodel.h ../src/mounter.h ../src/places.h ../src/previewer.h ../src/theme.h ../src/thumbnails.h ../src/translator.h
SOURCES += folio_tests.cpp ../src/backend.cpp ../src/fileops.cpp ../src/foldermodel.cpp ../src/mounter.cpp ../src/places.cpp ../src/previewer.cpp ../src/theme.cpp ../src/thumbnails.cpp ../src/translator.cpp

LIBS += -lz
CONFIG += link_pkgconfig
PKGCONFIG += gio-2.0
