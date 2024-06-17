# Define the sources and headers common to all platforms
SOURCES += \
    $$PWD/src/abstractstorebackend.cpp \
    $$PWD/src/abstractproduct.cpp \
    $$PWD/src/abstracttransaction.cpp

HEADERS += \
    $$PWD/src/dummystorebackend.h \
    $$PWD/src/abstractstorebackend.h \
    $$PWD/src/abstractproduct.h \
    $$PWD/src/abstracttransaction.h

INCLUDEPATH += $$PWD/src

# Desktop builds: DummyStoreBackend and DummyProduct are fully defined inline in dummystorebackend.h
# No separate .cpp file needed since all methods are inline

android {
    INCLUDEPATH += $$PWD/src/android
    SOURCES += \
        $$PWD/src/android/googleplaystorebackend.cpp \
        $$PWD/src/android/googleplaystoreproduct.cpp \
        $$PWD/src/android/googleplaystoretransaction.cpp

    HEADERS += \
        $$PWD/src/android/googleplaystorebackend.h \
        $$PWD/src/android/googleplaystoreproduct.h \
        $$PWD/src/android/googleplaystoretransaction.h \
        $$PWD/src/android/GooglePlayBilling.java
}
ios {
    !debug {
        message("IOS: $$PWD/src/apple")
        INCLUDEPATH += /System/Library/Frameworks
        INCLUDEPATH += $$PWD/src/apple
        LIBS += -framework Foundation \
                -framework StoreKit

        SOURCES += \
            $$PWD/src/apple/appleappstorebackend.mm \
            $$PWD/src/apple/appleappstoreproduct.mm \
            $$PWD/src/apple/appleappstoretransaction.mm

        HEADERS += \
            $$PWD/src/apple/appleappstorebackend.h \
            $$PWD/src/apple/appleappstoreproduct.h \
            $$PWD/src/apple/appleappstoretransaction.h
    }
}
