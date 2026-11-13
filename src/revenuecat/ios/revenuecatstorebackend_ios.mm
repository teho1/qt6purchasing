#import "revenuecatstorebackend_ios.h"
// StoreKit must be imported before RevenueCat-Swift.h because the generated
// ObjC bridging header references SKPaymentQueueDelegate, SKPaymentTransactionObserver,
// SKProductsRequestDelegate, and SKRequestDelegate by name.
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
// RevenueCat.h only exports the framework version number.
// All ObjC-visible types (RCPurchases, RCOfferings, etc.) are generated
// by the Swift compiler and exposed via RevenueCat-Swift.h.
#import <RevenueCat/RevenueCat-Swift.h>

#include "../revenuecatproduct.h"
#include "../revenuecattransaction.h"
#include "../../abstractproduct.h"
#include "../../abstracttransaction.h"
#include <QDebug>
#include <QMetaObject>
#include <QString>

// Align with Android RevenueCatBilling: Play-style "subscriptionId:basePlanId" vs app id alone.
// iOS is usually an exact match, but the same Qt identifier is used on both platforms.
static BOOL rh_storeProductIdMatchesRequested(NSString *storeId, NSString *requested)
{
    if (requested.length == 0 || storeId.length == 0)
        return NO;
    if ([storeId isEqualToString:requested])
        return YES;
    NSString *withColon = [requested stringByAppendingString:@":"];
    if ([storeId hasPrefix:withColon])
        return YES;
    NSRange colon = [storeId rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        NSString *base = [storeId substringToIndex:colon.location];
        if ([base isEqualToString:requested])
            return YES;
    }
    return NO;
}

@interface QT_MANGLE_NAMESPACE(RevenueCatManager) : NSObject <RCPurchasesDelegate>
{
    RevenueCatStoreBackend * backend;
}

- (id)initWithBackend:(RevenueCatStoreBackend *)iapBackend;
- (void)configureWithAPIKey:(NSString *)apiKey appUserID:(NSString *)appUserID;
- (void)registerProductWithIdentifier:(NSString *)identifier;
- (void)purchaseProductWithIdentifier:(NSString *)identifier packageIdentifier:(NSString *)packageId;
- (void)restorePurchases;
- (void)logInWithAppUserID:(NSString *)appUserID;
- (void)logOut;
- (void)emitRestoreFinished:(BOOL)success active:(BOOL)active errorCode:(int)code message:(NSString *)message;
- (void)emitLogInFinished:(NSString *)appUserID success:(BOOL)success errorCode:(int)code message:(NSString *)message;
- (void)applyCustomerInfo:(RCCustomerInfo *)customerInfo;
- (void)fetchCurrentCustomerInfoAndApply;
- (BOOL)isQtProductPurchased:(AbstractProduct *)product inCustomerInfo:(RCCustomerInfo *)customerInfo;

@end

@implementation QT_MANGLE_NAMESPACE(RevenueCatManager)

- (id)initWithBackend:(RevenueCatStoreBackend *)iapBackend {
    if (self = [super init]) {
        backend = iapBackend;
    }
    return self;
}

- (void)markQtProductRegistrationFailed:(NSString *)identifier
{
    if (identifier.length == 0)
        return;
    RevenueCatProduct *qtProduct = qobject_cast<RevenueCatProduct *>(
        backend->product(QString::fromNSString(identifier)));
    if (qtProduct)
        qtProduct->setStatus(AbstractProduct::Unknown);
}

- (void)configureWithAPIKey:(NSString *)apiKey appUserID:(NSString *)appUserID {
    if (appUserID && appUserID.length > 0) {
        [RCPurchases configureWithAPIKey:apiKey appUserID:appUserID];
    } else {
        [RCPurchases configureWithAPIKey:apiKey];
    }
    
    RCPurchases.sharedPurchases.delegate = self;
    
    // Fetch offerings to ensure connection
    [RCPurchases.sharedPurchases getOfferingsWithCompletion:^(RCOfferings *offerings, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat error fetching offerings: %@", error.localizedDescription);
        } else {
            NSLog(@"RevenueCat connected successfully");
        }
        // Mark connected even when offerings fail — CustomerInfo / restore still work and
        // products must leave PendingRegistration instead of staying on "Loading" forever.
        QMetaObject::invokeMethod(backend, "connectedChanged", Qt::AutoConnection, Q_ARG(bool, true));
        // Delegate may have fired before Qt products were registered; force a fresh CustomerInfo
        // from the network so subscription state matches App Store / RevenueCat.
        [self fetchCurrentCustomerInfoAndApply];
    }];
}

- (void)registerProductWithIdentifier:(NSString *)identifier {
    [RCPurchases.sharedPurchases getOfferingsWithCompletion:^(RCOfferings *offerings, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat error fetching offerings: %@", error.localizedDescription);
            [self markQtProductRegistrationFailed:identifier];
            return;
        }
        
        RCPackage *foundPackage = nil;
        for (RCOffering *offering in offerings.all.allValues) {
            for (RCPackage *package in offering.availablePackages) {
                if (rh_storeProductIdMatchesRequested(package.storeProduct.productIdentifier, identifier)) {
                    foundPackage = package;
                    break;
                }
            }
            if (foundPackage) break;
        }

        if (!foundPackage) {
            NSMutableString *seen = [NSMutableString string];
            for (RCOffering *offering in offerings.all.allValues) {
                for (RCPackage *package in offering.availablePackages) {
                    if (seen.length)
                        [seen appendString:@", "];
                    [seen appendString:package.storeProduct.productIdentifier];
                }
            }
            NSLog(@"RevenueCat: no package for app id \"%@\". Store product ids in offerings: [%@]",
                  identifier, seen.length ? seen : @"(none — check RevenueCat offering / App Store Connect)");
            [self markQtProductRegistrationFailed:identifier];
            return;
        }

        if (foundPackage) {
            // In RevenueCat 5.x storeProduct is RCStoreProduct (not SKProduct).
            // localizedPriceString is a pre-formatted locale-aware price string.
            RCStoreProduct *product = foundPackage.storeProduct;

            RevenueCatProduct *qtProduct = qobject_cast<RevenueCatProduct*>(backend->product(QString::fromNSString(identifier)));
            if (qtProduct) {
                qtProduct->setDescription(QString::fromNSString(product.localizedDescription));
                qtProduct->setPrice(QString::fromNSString(product.localizedPriceString));
                if (product.subscriptionPeriod) {
                    qtProduct->setBillingPeriodDescription(
                        subscriptionBillingSuffixFromRcUnits(static_cast<int>(product.subscriptionPeriod.unit),
                                                             static_cast<int>(product.subscriptionPeriod.value)));
                } else {
                    qtProduct->setBillingPeriodDescription(QString());
                }
                qtProduct->setTitle(QString::fromNSString(product.localizedTitle));
                qtProduct->setStatus(AbstractProduct::Registered);
                qtProduct->setPackageIdentifier(QString::fromNSString(foundPackage.identifier));

                QMetaObject::invokeMethod(backend, "productRegistered", Qt::AutoConnection, Q_ARG(AbstractProduct*, qtProduct));
                // Product exists now — apply cached/network entitlement state (delegate may have run too early).
                [self fetchCurrentCustomerInfoAndApply];
            }
        }
    }];
}

- (void)purchaseProductWithIdentifier:(NSString *)identifier packageIdentifier:(NSString *)packageId {
    [RCPurchases.sharedPurchases getOfferingsWithCompletion:^(RCOfferings *offerings, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat error fetching offerings: %@", error.localizedDescription);
            QMetaObject::invokeMethod(backend, "purchaseFailed", Qt::AutoConnection, Q_ARG(int, -1));
            return;
        }
        
        RCPackage *packageToPurchase = nil;
        
        if (packageId && packageId.length > 0) {
            for (RCOffering *offering in offerings.all.allValues) {
                packageToPurchase = [offering packageWithIdentifier:packageId];
                if (packageToPurchase) break;
            }
        } else {
            for (RCOffering *offering in offerings.all.allValues) {
                for (RCPackage *package in offering.availablePackages) {
                    if (rh_storeProductIdMatchesRequested(package.storeProduct.productIdentifier, identifier)) {
                        packageToPurchase = package;
                        break;
                    }
                }
                if (packageToPurchase) break;
            }
        }
        
        if (!packageToPurchase) {
            NSLog(@"RevenueCat: Package not found for identifier: %@", identifier);
            QMetaObject::invokeMethod(backend, "purchaseFailed", Qt::AutoConnection, Q_ARG(int, -2));
            return;
        }
        
        [RCPurchases.sharedPurchases purchasePackage:packageToPurchase
                                       withCompletion:^(RCStoreTransaction *transaction, RCCustomerInfo *customerInfo, NSError *error, BOOL cancelled) {
            if (error) {
                if (cancelled) {
                    QMetaObject::invokeMethod(backend, "purchaseFailed", Qt::AutoConnection, Q_ARG(int, 1));
                } else {
                    QMetaObject::invokeMethod(backend, "purchaseFailed", Qt::AutoConnection, Q_ARG(int, error.code));
                }
                return;
            }
            
            RevenueCatTransaction *qtTransaction = new RevenueCatTransaction(
                backend,
                QString::fromNSString(transaction.transactionIdentifier),
                QString::fromNSString(transaction.productIdentifier),
                AbstractTransaction::PurchaseApproved
            );
            
            QMetaObject::invokeMethod(backend, "purchaseSucceeded", Qt::AutoConnection, Q_ARG(AbstractTransaction*, qtTransaction));
        }];
    }];
}

- (void)restorePurchases {
    [RCPurchases.sharedPurchases restorePurchasesWithCompletion:^(RCCustomerInfo *customerInfo, NSError *error) {
        if (error) {
            // Surface the failure (e.g. RCReceiptAlreadyInUseError when the App Store receipt
            // belongs to another RevenueCat App User ID); swallowing it left the paywall up
            // with no explanation.
            NSLog(@"RevenueCat restore error (code %ld): %@", (long)error.code, error.localizedDescription);
            [self emitRestoreFinished:NO active:NO errorCode:(int)error.code message:error.localizedDescription];
            return;
        }

        [self applyCustomerInfo:customerInfo];

        BOOL hasActive = NO;
        for (AbstractProduct *product : backend->products()) {
            if (product->productType() == AbstractProduct::Subscription
                && [self isQtProductPurchased:product inCustomerInfo:customerInfo])
                hasActive = YES;
        }

        for (NSString *productId in customerInfo.allPurchasedProductIdentifiers) {
            AbstractProduct *qtProduct = backend->product(QString::fromNSString(productId));
            if (qtProduct && qtProduct->productType() == AbstractProduct::Subscription
                && ![self isQtProductPurchased:qtProduct inCustomerInfo:customerInfo]) {
                NSLog(@"RevenueCat restore: ignoring expired subscription history for %@", productId);
                continue;
            }

            RevenueCatTransaction *qtTransaction = new RevenueCatTransaction(
                backend,
                QString("restored_%1").arg(QString::fromNSString(productId)),
                QString::fromNSString(productId),
                AbstractTransaction::PurchaseRestored
            );
            
            QMetaObject::invokeMethod(backend, "purchaseRestored", Qt::AutoConnection, Q_ARG(AbstractTransaction*, qtTransaction));
        }

        NSLog(@"RevenueCat restore finished (active subscription: %@)", hasActive ? @"YES" : @"NO");
        [self emitRestoreFinished:YES active:hasActive errorCode:0 message:nil];
    }];
}

- (void)emitRestoreFinished:(BOOL)success active:(BOOL)active errorCode:(int)code message:(NSString *)message {
    AbstractStoreBackend *b = backend;
    const bool ok = success;
    const bool act = active;
    const QString msg = message ? QString::fromNSString(message) : QString();
    QMetaObject::invokeMethod(b, [b, ok, act, code, msg]() {
        emit b->restoreFinished(ok, act, code, msg);
    }, Qt::AutoConnection);
}

- (void)emitLogInFinished:(NSString *)appUserID success:(BOOL)success errorCode:(int)code message:(NSString *)message {
    AbstractStoreBackend *b = backend;
    const QString uid = QString::fromNSString(appUserID);
    const bool ok = success;
    const QString msg = message ? QString::fromNSString(message) : QString();
    QMetaObject::invokeMethod(b, [b, uid, ok, code, msg]() {
        emit b->logInFinished(uid, ok, code, msg);
    }, Qt::AutoConnection);
}

- (void)logInWithAppUserID:(NSString *)appUserID {
    if (!appUserID || appUserID.length == 0) {
        NSLog(@"RevenueCat logIn: empty app user ID");
        return;
    }

    [RCPurchases.sharedPurchases logIn:appUserID
                            completion:^(RCCustomerInfo *customerInfo, BOOL created, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat logIn error (code %ld): %@", (long)error.code, error.localizedDescription);
            [self emitLogInFinished:appUserID success:NO errorCode:(int)error.code message:error.localizedDescription];
            return;
        }
        NSLog(@"RevenueCat logIn success for %@ (created=%@)", appUserID, created ? @"YES" : @"NO");
        [self applyCustomerInfo:customerInfo];
        // Queued after applyCustomerInfo's purchased-state updates, so listeners already see
        // the logged-in user's subscription state.
        [self emitLogInFinished:appUserID success:YES errorCode:0 message:nil];
    }];
}

- (void)logOut {
    [RCPurchases.sharedPurchases logOutWithCompletion:^(RCCustomerInfo *customerInfo, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat logOut error: %@", error.localizedDescription);
            return;
        }
        NSLog(@"RevenueCat logOut success");
        [self applyCustomerInfo:customerInfo];
    }];
}

#pragma mark - Customer info → Qt product state

- (BOOL)isSubscriptionProductIdentifierActive:(NSString *)pid inCustomerInfo:(RCCustomerInfo *)info
{
    if (!pid.length || !info)
        return NO;

    for (NSString *activeSubscriptionId in info.activeSubscriptions) {
        if (rh_storeProductIdMatchesRequested(activeSubscriptionId, pid))
            return YES;
    }

    NSDictionary<NSString *, RCEntitlementInfo *> *activeEnts = info.entitlements.activeInCurrentEnvironment;
    for (NSString *key in activeEnts) {
        RCEntitlementInfo *e = activeEnts[key];
        if (e.isActive && rh_storeProductIdMatchesRequested(e.productIdentifier, pid))
            return YES;
    }

    return NO;
}

- (BOOL)isProductIdentifierHistoricallyPurchased:(NSString *)pid inCustomerInfo:(RCCustomerInfo *)info
{
    if (!pid.length || !info)
        return NO;

    for (NSString *purchasedProductId in info.allPurchasedProductIdentifiers) {
        if (rh_storeProductIdMatchesRequested(purchasedProductId, pid))
            return YES;
    }

    return NO;
}

- (BOOL)isQtProductPurchased:(AbstractProduct *)product inCustomerInfo:(RCCustomerInfo *)customerInfo
{
    if (!product || !customerInfo)
        return NO;

    NSString *pid = [NSString stringWithUTF8String:product->identifier().toUtf8().constData()];
    if (product->productType() == AbstractProduct::Subscription)
        return [self isSubscriptionProductIdentifierActive:pid inCustomerInfo:customerInfo];

    // Non-subscription purchases do not expire, so the RevenueCat historical set remains valid.
    return [self isProductIdentifierHistoricallyPurchased:pid inCustomerInfo:customerInfo];
}

- (void)applyCustomerInfo:(RCCustomerInfo *)customerInfo
{
    if (!customerInfo)
        return;
    for (AbstractProduct *product : backend->products()) {
        BOOL active = [self isQtProductPurchased:product inCustomerInfo:customerInfo];
        if (!active && product->productType() == AbstractProduct::Subscription) {
            NSString *pid = [NSString stringWithUTF8String:product->identifier().toUtf8().constData()];
            if ([self isProductIdentifierHistoricallyPurchased:pid inCustomerInfo:customerInfo])
                NSLog(@"RevenueCat: subscription %@ was purchased historically but is not active", pid);
        }
        if (active != product->purchased()) {
            QMetaObject::invokeMethod(product, [product, active]() {
                product->setPurchased(active);
            }, Qt::AutoConnection);
        }
    }
}

- (void)fetchCurrentCustomerInfoAndApply
{
    [RCPurchases.sharedPurchases getCustomerInfoWithFetchPolicy:RCCacheFetchPolicyFetchCurrent
                                                     completion:^(RCCustomerInfo *info, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat getCustomerInfo: %@", error.localizedDescription);
            return;
        }
        [self applyCustomerInfo:info];
    }];
}

#pragma mark - RCPurchasesDelegate

- (void)purchases:(RCPurchases *)purchases didReceiveUpdatedCustomerInfo:(RCCustomerInfo *)customerInfo {
    NSLog(@"RevenueCat: Customer info updated");
    [self applyCustomerInfo:customerInfo];
}

@end

// C++ implementation
RevenueCatStoreBackend::RevenueCatStoreBackend(QObject * parent) : AbstractStoreBackend(parent)
{
    _manager = [[QT_MANGLE_NAMESPACE(RevenueCatManager) alloc] initWithBackend:this];
}

RevenueCatStoreBackend::~RevenueCatStoreBackend()
{
    if (_manager) {
        [_manager release];
    }
}

void RevenueCatStoreBackend::configure(const QString &apiKey, const QString &appUserID)
{
    if (_configured) {
        qWarning() << "RevenueCat already configured";
        return;
    }

    _apiKey = apiKey;
    _appUserID = appUserID.isEmpty() ? QString() : appUserID;
    
    if (_apiKey.isEmpty()) {
        qCritical() << "RevenueCat API key is required";
        return;
    }

    initializePlatform();
    _configured = true;
}

void RevenueCatStoreBackend::initializePlatform()
{
    if (!_manager) return;
    
    NSString *apiKey = [NSString stringWithUTF8String:_apiKey.toUtf8().constData()];
    NSString *appUserID = _appUserID.isEmpty() ? nil : [NSString stringWithUTF8String:_appUserID.toUtf8().constData()];
    
    [_manager configureWithAPIKey:apiKey appUserID:appUserID];
    // TestFlight / Xcode builds use the App Store sandbox, where production subscriptions
    // are not visible; expose it so the UI can explain an unexpected paywall.
    setSandbox(RCPurchases.sharedPurchases.isSandbox);
    if (isSandbox())
        qWarning() << "[IAP] RevenueCat is running against the App Store sandbox";
}

void RevenueCatStoreBackend::cleanupPlatform()
{
    // RevenueCat SDK handles cleanup automatically
}

void RevenueCatStoreBackend::startConnection()
{
    if (!_configured) {
        qCritical() << "RevenueCat must be configured before starting connection";
        return;
    }
    
    // Connection is handled in configureWithAPIKey
    // This method is called after products are registered
    if (isConnected()) {
        emit connectedChanged(true);
    }
}

void RevenueCatStoreBackend::registerProduct(AbstractProduct * product)
{
    if (!_configured) {
        qWarning() << "RevenueCat not configured, product registration deferred";
        return;
    }

    RevenueCatProduct * rcProduct = qobject_cast<RevenueCatProduct*>(product);
    if (!rcProduct) {
        qCritical() << "Product must be a RevenueCatProduct";
        return;
    }

    NSString *identifier = [NSString stringWithUTF8String:product->identifier().toUtf8().constData()];
    [_manager registerProductWithIdentifier:identifier];
}

void RevenueCatStoreBackend::purchaseProduct(AbstractProduct * product)
{
    if (!isConnected()) {
        qCritical() << "Not connected to RevenueCat";
        emit purchaseFailed(-1);
        return;
    }

    RevenueCatProduct * rcProduct = qobject_cast<RevenueCatProduct*>(product);
    if (!rcProduct) {
        qCritical() << "Product must be a RevenueCatProduct";
        emit purchaseFailed(-2);
        return;
    }

    NSString *identifier = [NSString stringWithUTF8String:product->identifier().toUtf8().constData()];
    NSString *packageId = rcProduct->packageIdentifier().isEmpty() ? nil : [NSString stringWithUTF8String:rcProduct->packageIdentifier().toUtf8().constData()];
    
    [_manager purchaseProductWithIdentifier:identifier packageIdentifier:packageId];
}

void RevenueCatStoreBackend::consumePurchase(AbstractTransaction * transaction)
{
    if (!transaction) {
        qWarning() << "Cannot consume null transaction";
        return;
    }

    qDebug() << "Consuming RevenueCat transaction:" << transaction->orderId();
    // RevenueCat handles consumables automatically
    emit purchaseConsumed(transaction);
}

void RevenueCatStoreBackend::restorePurchases()
{
    if (!_configured || !_manager) {
        qWarning() << "RevenueCat not configured; cannot restore purchases";
        emit restoreFinished(false, false, -1, QStringLiteral("RevenueCat not configured"));
        return;
    }
    [_manager restorePurchases];
}

void RevenueCatStoreBackend::logIn(const QString &appUserID)
{
    if (!_configured || !_manager) {
        qWarning() << "[IAP] RevenueCat not configured; cannot logIn" << appUserID;
        emit logInFinished(appUserID, false, -1, QStringLiteral("RevenueCat not configured"));
        return;
    }
    if (appUserID.isEmpty()) {
        qWarning() << "[IAP] RevenueCat logIn: empty app user ID";
        emit logInFinished(appUserID, false, -1, QStringLiteral("Empty app user ID"));
        return;
    }

    qDebug() << "[IAP] logIn uid" << appUserID;
    NSString *uid = [NSString stringWithUTF8String:appUserID.toUtf8().constData()];
    [_manager logInWithAppUserID:uid];
}

void RevenueCatStoreBackend::logOut()
{
    if (!_configured || !_manager) {
        qDebug() << "[IAP] RevenueCat not configured; logOut no-op";
        return;
    }

    qDebug() << "[IAP] logOut";
    [_manager logOut];
}
