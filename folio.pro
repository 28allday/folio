QT += core gui qml quick quickcontrols2 dbus concurrent

CONFIG += c++17 release
TARGET = folio
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/filemanager1.h \
    src/foldermodel.h \
    src/places.h \
    src/theme.h \
    src/thumbnails.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/filemanager1.cpp \
    src/foldermodel.cpp \
    src/places.cpp \
    src/theme.cpp \
    src/thumbnails.cpp \
    src/translator.cpp

LIBS += -lz

RESOURCES += src/resources.qrc
