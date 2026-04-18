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

android {
    INCLUDEPATH += $$PWD/src/android
    INCLUDEPATH += $$PWD/src/revenuecat
    INCLUDEPATH += $$PWD/src/revenuecat/android
    
    SOURCES += \
        $$PWD/src/android/googleplaystorebackend.cpp \
        $$PWD/src/android/googleplaystoreproduct.cpp \
        $$PWD/src/android/googleplaystoretransaction.cpp \
        $$PWD/src/revenuecat/revenuecatproduct.cpp \
        $$PWD/src/revenuecat/revenuecattransaction.cpp \
        $$PWD/src/revenuecat/android/revenuecatstorebackend_android.cpp

    HEADERS += \
        $$PWD/src/android/googleplaystorebackend.h \
        $$PWD/src/android/googleplaystoreproduct.h \
        $$PWD/src/android/googleplaystoretransaction.h \
        $$PWD/src/android/GooglePlayBilling.java \
        $$PWD/src/revenuecat/revenuecatproduct.h \
        $$PWD/src/revenuecat/revenuecattransaction.h \
        $$PWD/src/revenuecat/revenuecatstorebackend.h \
        $$PWD/src/revenuecat/android/revenuecatstorebackend_android.h \
        $$PWD/src/revenuecat/android/RevenueCatBilling.java
}

ios {
    !debug {
        message("IOS: $$PWD/src/apple")
        INCLUDEPATH += /System/Library/Frameworks
        INCLUDEPATH += $$PWD/src/apple
        INCLUDEPATH += $$PWD/src/revenuecat
        INCLUDEPATH += $$PWD/src/revenuecat/ios
        LIBS += -framework Foundation \
                -framework StoreKit \
                -framework RevenueCat

        SOURCES += \
            $$PWD/src/apple/appleappstorebackend.mm \
            $$PWD/src/apple/appleappstoreproduct.mm \
            $$PWD/src/apple/appleappstoretransaction.mm \
            $$PWD/src/revenuecat/revenuecatproduct.cpp \
            $$PWD/src/revenuecat/revenuecattransaction.cpp \
            $$PWD/src/revenuecat/ios/revenuecatstorebackend_ios.mm

        HEADERS += \
            $$PWD/src/apple/appleappstorebackend.h \
            $$PWD/src/apple/appleappstoreproduct.h \
            $$PWD/src/apple/appleappstoretransaction.h \
            $$PWD/src/revenuecat/revenuecatproduct.h \
            $$PWD/src/revenuecat/revenuecattransaction.h \
            $$PWD/src/revenuecat/revenuecatstorebackend.h \
            $$PWD/src/revenuecat/ios/revenuecatstorebackend_ios.h
    }
}

