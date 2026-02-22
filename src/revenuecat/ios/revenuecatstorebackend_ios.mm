#import "revenuecatstorebackend_ios.h"
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "RevenueCat.h"
#import "RevenueCat-Swift.h"

#include "../revenuecatproduct.h"
#include "../revenuecattransaction.h"
#include "../../abstractproduct.h"
#include "../../abstracttransaction.h"
#include <QDebug>
#include <QMetaObject>
#include <QString>

@interface QT_MANGLE_NAMESPACE(RevenueCatManager) : NSObject <RCPurchasesDelegate>
{
    RevenueCatStoreBackend * backend;
}

- (id)initWithBackend:(RevenueCatStoreBackend *)iapBackend;
- (void)configureWithAPIKey:(NSString *)apiKey appUserID:(NSString *)appUserID;
- (void)registerProductWithIdentifier:(NSString *)identifier;
- (void)purchaseProductWithIdentifier:(NSString *)identifier packageIdentifier:(NSString *)packageId;
- (void)restorePurchases;

@end

@implementation QT_MANGLE_NAMESPACE(RevenueCatManager)

- (id)initWithBackend:(RevenueCatStoreBackend *)iapBackend {
    if (self = [super init]) {
        backend = iapBackend;
    }
    return self;
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
            NSLog(@"RevenueCat error fetching offerings: %@ (domain=%@ code=%ld)", error.localizedDescription, error.domain, (long)error.code);
            if (error.userInfo) {
                NSLog(@"RevenueCat error details: %@", error.userInfo);
            }
            // Still emit connected so products can attempt registration (they may retry later)
            QMetaObject::invokeMethod(backend, "connectedChanged", Qt::AutoConnection, Q_ARG(bool, true));
        } else {
            NSLog(@"RevenueCat connected successfully");
            QMetaObject::invokeMethod(backend, "connectedChanged", Qt::AutoConnection, Q_ARG(bool, true));
        }
    }];
}

- (void)registerProductWithIdentifier:(NSString *)identifier {
    [RCPurchases.sharedPurchases getOfferingsWithCompletion:^(RCOfferings *offerings, NSError *error) {
        if (error) {
            NSLog(@"RevenueCat error fetching offerings: %@", error.localizedDescription);
            return;
        }

        RCPackage *foundPackage = nil;
        for (RCOffering *offering in offerings.all.allValues) {
            for (RCPackage *package in offering.availablePackages) {
                if ([package.storeProduct.productIdentifier isEqualToString:identifier]) {
                    foundPackage = package;
                    break;
                }
            }
            if (foundPackage) break;
        }

        if (foundPackage) {
            RCStoreProduct *product = foundPackage.storeProduct;

            RevenueCatProduct *qtProduct = qobject_cast<RevenueCatProduct*>(backend->product(QString::fromNSString(identifier)));
            if (qtProduct) {
                qtProduct->setDescription(QString::fromNSString(product.localizedDescription));
                qtProduct->setPrice(QString::fromNSString(product.localizedPriceString));
                qtProduct->setTitle(QString::fromNSString(product.localizedTitle));
                qtProduct->setStatus(AbstractProduct::Registered);
                qtProduct->setPackageIdentifier(QString::fromNSString(foundPackage.identifier));

                QMetaObject::invokeMethod(backend, "productRegistered", Qt::AutoConnection, Q_ARG(AbstractProduct*, qtProduct));
            }
        } else {
            NSLog(@"RevenueCat: Product '%@' not found in offerings. Ensure it matches RevenueCat dashboard and App Store Connect.", identifier);
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
                    if ([package.storeProduct.productIdentifier isEqualToString:identifier]) {
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
                    QMetaObject::invokeMethod(backend, "purchaseFailed", Qt::AutoConnection, Q_ARG(int, static_cast<int>(error.code)));
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
            NSLog(@"RevenueCat restore error: %@", error.localizedDescription);
            return;
        }

        for (NSString *productId in customerInfo.allPurchasedProductIdentifiers) {
            RevenueCatTransaction *qtTransaction = new RevenueCatTransaction(
                backend,
                QString("restored_%1").arg(QString::fromNSString(productId)),
                QString::fromNSString(productId),
                AbstractTransaction::PurchaseRestored
            );

            QMetaObject::invokeMethod(backend, "purchaseRestored", Qt::AutoConnection, Q_ARG(AbstractTransaction*, qtTransaction));
        }
    }];
}

#pragma mark - RCPurchasesDelegate

- (void)purchases:(RCPurchases *)purchases didReceiveUpdatedCustomerInfo:(RCCustomerInfo *)customerInfo {
    NSLog(@"RevenueCat: Customer info updated");
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

    qDebug() << "RevenueCat configure: apiKey length=" << _apiKey.length() << "appUserID=" << (_appUserID.isEmpty() ? "(anon)" : _appUserID);
    initializePlatform();
    _configured = true;
}

void RevenueCatStoreBackend::initializePlatform()
{
    if (!_manager) return;

    NSString *apiKey = [NSString stringWithUTF8String:_apiKey.toUtf8().constData()];
    NSString *appUserID = _appUserID.isEmpty() ? nil : [NSString stringWithUTF8String:_appUserID.toUtf8().constData()];

    [_manager configureWithAPIKey:apiKey appUserID:appUserID];
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

    qDebug() << "RevenueCat startConnection (connection is async via getOfferings)";
    // Connection is handled in configureWithAPIKey via getOfferings completion
    // If already connected, re-emit so products get registered
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
