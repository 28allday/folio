CONFIG += c++17 link_pkgconfig
PKGCONFIG += gio-2.0 gio-unix-2.0
LIBS += -lz
INCLUDEPATH += $$PWD

HEADERS += \
    $$PWD/backend.h \
    $$PWD/fileops.h \
    $$PWD/foldermodel.h \
    $$PWD/mounter.h \
    $$PWD/places.h \
    $$PWD/previewer.h \
    $$PWD/theme.h \
    $$PWD/thumbnails.h \
    $$PWD/translator.h

SOURCES += \
    $$PWD/backend.cpp \
    $$PWD/fileops.cpp \
    $$PWD/foldermodel.cpp \
    $$PWD/mounter.cpp \
    $$PWD/places.cpp \
    $$PWD/previewer.cpp \
    $$PWD/theme.cpp \
    $$PWD/thumbnails.cpp \
    $$PWD/translator.cpp
