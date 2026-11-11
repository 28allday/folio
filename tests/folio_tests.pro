QT += core gui quick testlib concurrent
CONFIG += testcase
TARGET = folio_tests
TEMPLATE = app

include(../src/common.pri)

SOURCES += folio_tests.cpp
