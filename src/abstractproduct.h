#ifndef ABSTRACTPRODUCT_H
#define ABSTRACTPRODUCT_H

#include <QObject>
#include "abstractstorebackend.h"

class AbstractTransaction;

class AbstractProduct : public QObject
{
    Q_OBJECT
    // writable properties
    Q_PROPERTY(QString identifier READ identifier WRITE setIdentifier NOTIFY identifierChanged REQUIRED)
    Q_PROPERTY(ProductType type READ productType WRITE setProductType NOTIFY productTypeChanged REQUIRED)
    // read only properties
    Q_PROPERTY(ProductStatus status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString description READ description NOTIFY descriptionChanged)
    Q_PROPERTY(QString price READ price NOTIFY priceChanged)
    /// Localized suffix for the billing cycle, e.g. " / month" (from store). Empty until product is registered.
    Q_PROPERTY(QString billingPeriodDescription READ billingPeriodDescription NOTIFY billingPeriodDescriptionChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString receipt READ receipt WRITE setReceipt NOTIFY receiptChanged FINAL)
    Q_PROPERTY(bool purchased READ purchased WRITE setPurchased NOTIFY purchasedChanged)

public:
    enum ProductType {
        Consumable,
        Unlockable,
        Subscription
    };
    Q_ENUM(ProductType)
    enum ProductStatus {
        Unitialized,
        PendingRegistration,
        Registered,
        Unknown
    };
    Q_ENUM(ProductStatus)

    ProductStatus status() const { return _status; }
    QString identifier() const { return _identifier; }
    QString description() const { return _description; }
    QString price() const { return _price; }
    ProductType productType() const { return _productType; }
    QString title() const { return _title; }
    QString billingPeriodDescription() const { return _billingPeriodDescription; }

    void setIdentifier(const QString &value);
    void setProductType(ProductType type);
    void setStatus(ProductStatus status);
    void setDescription(QString value);
    void setPrice(const QString &value);
    void setBillingPeriodDescription(const QString &value);
    void setTitle(const QString &value);

    void registerInStore();

    Q_INVOKABLE void purchase();

    QString receipt() const;
    void setReceipt(const QString &newReceipt);

    bool purchased() const;
    void setPurchased(bool newPurchased);

protected:
    explicit AbstractProduct(QObject * parent = nullptr);

    ProductStatus _status = ProductStatus::Unitialized;
    QString _identifier;
    QString _description;
    QString _price;
    QString _billingPeriodDescription;
    ProductType _productType;
    QString _title;
    QString _receipt;
    bool _purchased = false;

signals:
    void storeChanged();
    void statusChanged();
    void identifierChanged();
    void descriptionChanged();
    void priceChanged();
    void billingPeriodDescriptionChanged();
    void productTypeChanged();
    void titleChanged();

    void purchaseSucceeded(AbstractTransaction * transaction);
    void purchaseFailed(AbstractTransaction * transaction);
    void purchaseRestored(AbstractTransaction * transaction);
    void purchaseConsumed(AbstractTransaction * transaction);

    void receiptChanged();
    void purchasedChanged();

private:
};

/// Maps RevenueCat / StoreKit period (unit + value) to a short UI suffix, e.g. " / month".
QString subscriptionBillingSuffixFromRcUnits(int rcUnit, int value);

#endif // ABSTRACTPRODUCT_H
