# RevenueCat Setup for ReminderApp

## What's Done

- RevenueCat source files added to `publicLibs/qt6purchasing/src/revenuecat/`
- `qt6purchasing.pri` conditionally includes RevenueCat when `DEFINES += USE_REVENUECAT`
- `main.pro` has `DEFINES += USE_REVENUECAT` enabled
- `main.cpp` registers RevenueCat Store/Product types and exposes `RevenueCatApiKey` from `REVENUECAT_API_KEY` env
- `main.qml` configures the Store with `RevenueCatApiKey` before `startConnection()`

## Next Steps

### 1. Add RevenueCat iOS SDK

The build links `-framework RevenueCat`, so the RevenueCat SDK must be available. Options:

**Option A: CocoaPods (recommended if you use Xcode)**

In your iOS build directory (e.g. `build/Qt_6_10_0_for_iOS-Release/main/`), create a `Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'ReminderApp' do
  pod 'RevenueCat'
end
```

Run `pod install`, then open `ReminderApp.xcworkspace` (not .xcodeproj) to build.

**Option B: Swift Package Manager**

1. Open the generated Xcode project: `build/.../main/ReminderApp.xcodeproj`
2. File → Add Package Dependencies
3. Enter: `https://github.com/RevenueCat/purchases-ios-spm`
4. Add the `RevenueCat` package product

**Option C: Manual XCFramework**

1. Download [RevenueCat.xcframework](https://github.com/RevenueCat/purchases-ios/releases)
2. Add to `publicLibs/qt6purchasing/` or a frameworks folder
3. In `qt6purchasing.pri` (inside the `ios` block), add before `LIBS`:
   ```qmake
   QMAKE_LFLAGS += -F$$PWD/RevenueCat.xcframework/ios-arm64
   ```

### 2. RevenueCat Dashboard Configuration

1. Create an [App](https://app.revenuecat.com/) in the RevenueCat dashboard
2. Add your iOS app (bundle ID from Info.plist)
3. Create a **Product** with identifier `reminderapp_subscription_monthly` (must match QML)
4. Create an **Offering** and add the product
5. Copy the **Public API Key** (starts with `appl_`) and set:
   ```bash
   export REVENUECAT_API_KEY=appl_xxxxxxxxxxxxx
   ```

### 3. Build and Run

```bash
# From project root
cd build/Qt_6_10_0_for_iOS-Release  # or your build dir
qmake ../../reminder-app.pro
make

# Ensure REVENUECAT_API_KEY is set when running
```

### 4. Disable RevenueCat (use native Apple Store)

Comment out in `main/main.pro`:

```qmake
# DEFINES += USE_REVENUECAT
```

### Android (when needed)

- Add to `platforms/android/build.gradle`: `implementation 'com.revenuecat.purchases:purchases:8.0.0'`
- Copy `RevenueCatBilling.java` to `android/src/com/your/package/RevenueCatBilling.java` and update the package/class path in `revenuecatstorebackend_android.cpp`

## Troubleshooting Connection

### "RevenueCat must be configured before starting connection"

- API key is missing or empty. Ensure `REVENUECAT_API_KEY` is set at build time (`qmake REVENUECAT_API_KEY=xxx`) or in the environment when running.
- Check console for `[Store] RevenueCat not configured` — it means the key wasn’t passed to QML.

### "RevenueCat error fetching offerings"

- Product ID `reminderapp_subscription_monthly` must exist in:
  1. RevenueCat dashboard (Products → create/import)
  2. App Store Connect (In‑App Purchases)
  3. An Offering in RevenueCat
- Bundle ID must match in App Store Connect and RevenueCat.
- Simulator: use a StoreKit Configuration file for testing.
- Real device: StoreKit config files can cause issues; production config may differ.

### Product stays "Tilaus ei ole vielä aktivoitu"

- Product not found in offerings. Check Xcode console for `Product 'reminderapp_subscription_monthly' not found in offerings`.
- Ensure the product is in an Offering in the RevenueCat dashboard.
