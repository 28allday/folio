QT += core gui quick quickcontrols2 testlib dbus concurrent
CONFIG += c++17 testcase
TARGET = folio_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/foldermodel.h ../src/places.h ../src/theme.h ../src/thumbnails.h ../src/translator.h
SOURCES += folio_tests.cpp ../src/backend.cpp ../src/foldermodel.cpp ../src/places.cpp ../src/theme.cpp ../src/thumbnails.cpp ../src/translator.cpp

LIBS += -lz
