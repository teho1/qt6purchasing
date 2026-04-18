# RevenueCat Integration for qt6purchasing

## Overview

This integration adds RevenueCat support to the existing qt6purchasing wrapper, allowing you to use RevenueCat's subscription management platform while maintaining compatibility with the existing QML interface.

## Architecture Decision

**Decision: Reuse existing wrapper interface**

The existing `AbstractStoreBackend` pattern is perfect for adding RevenueCat as another backend implementation. This approach:
- Maintains 100% compatibility with existing QML code
- Follows the same pattern as Google Play and Apple App Store implementations
- Allows easy switching between native stores and RevenueCat via compile-time flag
- Preserves all existing functionality

## Implementation Structure

```
publicLibs/qt6purchasing/src/revenuecat/
├── revenuecatproduct.h/cpp          # RevenueCat-specific product (adds packageIdentifier)
├── revenuecattransaction.h/cpp      # RevenueCat transaction wrapper
├── revenuecatstorebackend.h         # Base header (platform-agnostic)
├── ios/
│   ├── revenuecatstorebackend_ios.h
│   └── revenuecatstorebackend_ios.mm  # iOS implementation (Objective-C++)
└── android/
    ├── revenuecatstorebackend_android.h
    ├── revenuecatstorebackend_android.cpp
    └── RevenueCatBilling.java      # Android JNI wrapper
```

## Features

### RevenueCat-Specific Features
- **Package Support**: `RevenueCatProduct` includes `packageIdentifier` property for RevenueCat offerings/packages
- **Configuration**: `configure(apiKey, appUserID)` method to initialize RevenueCat SDK
- **Offerings**: Automatically fetches products from RevenueCat offerings
- **Cross-platform**: Same QML interface works on both iOS and Android

### Maintained Compatibility
- All existing `AbstractStoreBackend` methods work identically
- Same signals: `connectedChanged`, `productRegistered`, `purchaseSucceeded`, etc.
- Same QML usage pattern as native stores

## Usage

### 1. Enable RevenueCat in Build

Add to your `.pro` or `CMakeLists.txt`:
```qmake
DEFINES += USE_REVENUECAT
```

### 2. Configure RevenueCat SDK

In your QML:
```qml
import Store
import Product

Store {
    id: iapStore
    Component.onCompleted: {
        configure("your_revenuecat_api_key", "optional_user_id")
    }
    
    Product {
        id: premiumProduct
        identifier: "premium_monthly"
        type: Product.Subscription
    }
}
```

### 3. Use Products (Same as Before)

```qml
Button {
    text: premiumProduct.price
    enabled: premiumProduct.status === Product.Registered
    onClicked: premiumProduct.purchase()
}

Connections {
    target: premiumProduct
    function onPurchaseSucceeded(transaction) {
        console.log("Purchase successful:", transaction.orderId)
        transaction.finalize()
    }
}
```

## Platform Setup

### iOS

1. **Add RevenueCat SDK**:
   - Add RevenueCat via CocoaPods, SPM, or manual framework
   - Framework is already linked in `qt6purchasing.pri` (`-framework RevenueCat`)

2. **Import in Xcode**: Ensure RevenueCat.framework is included

### Android

1. **Add RevenueCat SDK**:
   - Add to `build.gradle`:
   ```gradle
   dependencies {
       implementation 'com.revenuecat.purchases:purchases:8.0.0'
   }
   ```

2. **Java File Location**:
   - `RevenueCatBilling.java` must be placed at:
   - `android/src/com/climbsmart/crimptronic/RevenueCatBilling.java`
   - (Adjust package name to match your app)

## API Key Configuration

RevenueCat requires an API key from your RevenueCat dashboard. Configure it in QML:

```qml
Store {
    Component.onCompleted: {
        configure("appl_xxxxxxxxxxxxx")  // iOS public key
        // or
        configure("goog_xxxxxxxxxxxxx")   // Android public key
    }
}
```

## Differences from Native Stores

1. **Product Registration**: RevenueCat fetches products from offerings automatically
2. **Package Support**: Can specify package identifier for offerings
3. **Subscription Management**: RevenueCat handles subscription status server-side
4. **Receipt Validation**: Handled automatically by RevenueCat backend

## Migration from Native Stores

To switch from native stores to RevenueCat:

1. Add `DEFINES += USE_REVENUECAT` to build config
2. Change `GooglePlayStoreProduct` / `AppleAppStoreProduct` to `RevenueCatProduct` in QML
3. Add `configure()` call with RevenueCat API key
4. Optionally set `packageIdentifier` on products if using RevenueCat offerings

Existing QML code remains unchanged!

## Benefits of RevenueCat

- **Unified Backend**: Single API for iOS and Android
- **Server-side Validation**: Automatic receipt validation
- **Subscription Management**: Built-in subscription status tracking
- **Webhooks**: Real-time subscription events
- **Analytics**: Built-in purchase analytics
- **Cross-platform Sync**: User purchases sync across platforms

## Testing

Use RevenueCat's sandbox environment for testing:
- iOS: Use sandbox test accounts
- Android: Use license testing accounts
- Both: RevenueCat dashboard shows test purchases

## Notes

- RevenueCat SDK must be installed separately (not included in this wrapper)
- The wrapper provides Qt/QML bindings only
- All RevenueCat SDK features are accessible through the wrapper
- Compatible with RevenueCat's offerings, packages, and entitlements system
