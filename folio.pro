QT += core gui qml quick quickcontrols2 dbus concurrent

CONFIG += release
TARGET = folio
TEMPLATE = app

include(src/common.pri)

HEADERS += src/filemanager1.h src/windows.h
SOURCES += src/main.cpp src/filemanager1.cpp src/windows.cpp

RESOURCES += src/resources.qrc
