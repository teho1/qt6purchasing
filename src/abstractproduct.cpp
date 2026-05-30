#include "abstractproduct.h"
#include "abstracttransaction.h"

#include <QCoreApplication>

AbstractProduct::AbstractProduct(QObject * parent) : QObject(parent), _purchased(false)
{
    connect(this, &AbstractProduct::identifierChanged, this, &AbstractProduct::registerInStore);
    connect(this, &AbstractProduct::storeChanged, this, &AbstractProduct::registerInStore);
}

bool AbstractProduct::purchased() const
{
    return _purchased;
}

void AbstractProduct::setPurchased(bool newPurchased)
{
    qDebug() << "setPurchased: " << newPurchased;
    if (_purchased == newPurchased)
        return;
    _purchased = newPurchased;
    qDebug() << "emit signal";
    emit purchasedChanged();
}

QString AbstractProduct::receipt() const
{
    return _receipt;
}

void AbstractProduct::setReceipt(const QString &newReceipt)
{
    if (_receipt == newReceipt)
        return;
    _receipt = newReceipt;
    emit receiptChanged();
}

void AbstractProduct::setDescription(QString value)
{
    _description = value;
    emit descriptionChanged();
}

void AbstractProduct::setIdentifier(const QString &value)
{
    _identifier = value;
    emit identifierChanged();
}

void AbstractProduct::setPrice(const QString &value)
{
    _price = value;
    emit priceChanged();
}

void AbstractProduct::setBillingPeriodDescription(const QString &value)
{
    if (_billingPeriodDescription == value)
        return;
    _billingPeriodDescription = value;
    emit billingPeriodDescriptionChanged();
}

void AbstractProduct::setProductType(ProductType type)
{
    _productType = type;
    emit productTypeChanged();
}

void AbstractProduct::setTitle(const QString &value)
{
    _title = value;
    emit titleChanged();
}

void AbstractProduct::setStatus(ProductStatus status)
{
    _status = status;
    qDebug() << "Product" << _identifier << _status;
    emit statusChanged();
}

void AbstractProduct::registerInStore()
{
    if (!AbstractStoreBackend::instance()) {
        qCritical() << "Store unavailable!";
        return;
    }

    if(!AbstractStoreBackend::instance()->isConnected()) {
        qCritical() << "No connection to store!";
        return;
    }

    if (_identifier.isEmpty()) {
        qCritical() << "Product has no id!";
        return;
    }

    setStatus(AbstractProduct::PendingRegistration);
    AbstractStoreBackend::instance()->registerProduct(this);
}


void AbstractProduct::purchase()
{
    if (!AbstractStoreBackend::instance()) {
        qCritical() << "Store unavailable!";
        return;
    }

    if(!AbstractStoreBackend::instance()->isConnected()) {
        qCritical() << "No connection to store!";
        return;
    }

    if (_identifier.isEmpty()) {
        qCritical() << "Product has no id!";
        return;
    }

    if (_status != AbstractProduct::Registered) {
        qDebug() << "Trying to purchase an unregistered Product. Aborting";
        return;
    }

    AbstractStoreBackend::instance()->purchaseProduct(this);
}

QString subscriptionBillingSuffixFromRcUnits(int rcUnit, int value)
{
    if (value < 1 || rcUnit < 0 || rcUnit > 3)
        return QString();

    auto trPeriod = [](const char *singular, const char *plural, int n) -> QString {
        if (n == 1)
            return QCoreApplication::translate("PaymentAdPage", singular);
        return QCoreApplication::translate("PaymentAdPage", plural).arg(QString::number(n));
    };

    // RevenueCat RCSubscriptionPeriodUnit: Day=0, Week=1, Month=2, Year=3
    switch (rcUnit) {
    case 0:
        return trPeriod(" / day", " / %1 days", value);
    case 1:
        return trPeriod(" / week", " / %1 weeks", value);
    case 2:
        if (value == 1)
            return QCoreApplication::translate("PaymentAdPage", " / kuukausi");
        return QCoreApplication::translate("PaymentAdPage", " / %1 months").arg(QString::number(value));
    case 3:
        return trPeriod(" / year", " / %1 years", value);
    default:
        return QString();
    }
}
