QT += core gui qml quick quickcontrols2 dbus concurrent

CONFIG += c++17 release
TARGET = folio
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/filemanager1.h \
    src/foldermodel.h \
    src/mounter.h \
    src/places.h \
    src/previewer.h \
    src/theme.h \
    src/thumbnails.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/filemanager1.cpp \
    src/foldermodel.cpp \
    src/mounter.cpp \
    src/places.cpp \
    src/previewer.cpp \
    src/theme.cpp \
    src/thumbnails.cpp \
    src/translator.cpp

LIBS += -lz
CONFIG += link_pkgconfig
PKGCONFIG += gio-2.0

RESOURCES += src/resources.qrc
