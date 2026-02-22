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

# RevenueCat: when DEFINES += USE_REVENUECAT, use RevenueCat backend instead of native stores
contains(DEFINES, "USE_REVENUECAT") {
    android {
        INCLUDEPATH += $$PWD/src/android
        INCLUDEPATH += $$PWD/src/revenuecat
        INCLUDEPATH += $$PWD/src/revenuecat/android

        SOURCES += \
            $$PWD/src/revenuecat/revenuecatproduct.cpp \
            $$PWD/src/revenuecat/revenuecattransaction.cpp \
            $$PWD/src/revenuecat/android/revenuecatstorebackend_android.cpp

        HEADERS += \
            $$PWD/src/revenuecat/revenuecatproduct.h \
            $$PWD/src/revenuecat/revenuecattransaction.h \
            $$PWD/src/revenuecat/revenuecatstorebackend.h \
            $$PWD/src/revenuecat/android/revenuecatstorebackend_android.h \
            $$PWD/src/revenuecat/android/RevenueCatBilling.java
    }
    ios {
        message("IOS RevenueCat: $$PWD/src/revenuecat")
        # Prefer Debug xcframework for Debug builds when it exists
        contains(CONFIG, debug) {
            REVENUECAT_XCFRAMEWORK = $$PWD/../RevenueCat-Debug.xcframework
            !exists($$REVENUECAT_XCFRAMEWORK): REVENUECAT_XCFRAMEWORK = $$PWD/../RevenueCat.xcframework
        } else {
            REVENUECAT_XCFRAMEWORK = $$PWD/../RevenueCat.xcframework
        }
        exists($$REVENUECAT_XCFRAMEWORK) {
            # Use device path for device builds, simulator path for simulator - avoid wrong slice
            CONFIG(iphoneos,iphoneos|iphonesimulator) {
                REVENUECAT_SLICE = $$REVENUECAT_XCFRAMEWORK/ios-arm64
            } else: CONFIG(iphonesimulator,iphoneos|iphonesimulator) {
                REVENUECAT_SLICE = $$REVENUECAT_XCFRAMEWORK/ios-arm64_x86_64-simulator
            } else {
                # Fallback: device path
                REVENUECAT_SLICE = $$REVENUECAT_XCFRAMEWORK/ios-arm64
            }
            QMAKE_LFLAGS += -F$$REVENUECAT_SLICE
            INCLUDEPATH += $$REVENUECAT_SLICE/RevenueCat.framework/Headers
            # Link and embed: LIBS links; QMAKE_POST_LINK runs embed script after each build
            LIBS += -framework RevenueCat
            EMBED_SCRIPT = $$shell_path($$_PRO_FILE_PWD_/../scripts/embed_revenuecat_ios.sh)
            QMAKE_POST_LINK += REVENUECAT_SLICE=$$REVENUECAT_SLICE $$quote($$EMBED_SCRIPT)
        }
        INCLUDEPATH += /System/Library/Frameworks
        INCLUDEPATH += $$PWD/src/revenuecat
        INCLUDEPATH += $$PWD/src/revenuecat/ios
        LIBS += -framework Foundation \
                -framework StoreKit

        SOURCES += \
            $$PWD/src/revenuecat/revenuecatproduct.cpp \
            $$PWD/src/revenuecat/revenuecattransaction.cpp \
            $$PWD/src/revenuecat/ios/revenuecatstorebackend_ios.mm

        HEADERS += \
            $$PWD/src/revenuecat/revenuecatproduct.h \
            $$PWD/src/revenuecat/revenuecattransaction.h \
            $$PWD/src/revenuecat/revenuecatstorebackend.h \
            $$PWD/src/revenuecat/ios/revenuecatstorebackend_ios.h
    }
} else {
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
}

