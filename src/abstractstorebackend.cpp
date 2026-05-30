#include "abstractstorebackend.h"
#include "abstractproduct.h"
#include "abstracttransaction.h"

AbstractStoreBackend * AbstractStoreBackend::_instance = nullptr;

AbstractStoreBackend::AbstractStoreBackend(QObject * parent) : QObject(parent)
{
    _instance = this;

    qDebug() << "Creating store backend";

    connect(this, &AbstractStoreBackend::connectedChanged, [this](bool connected) {
        _connected = connected;
        if (connected) {
            qDebug() << "Connected to store";
            qDebug() << "Found" << _products.size() << "product(s) awaiting registration";
            for (AbstractProduct * product : _products) {
                product->registerInStore();
            }
        } else {
            qDebug() << "Disconnected from store";
        }
    });
    connect(this, &AbstractStoreBackend::productRegistered, [](AbstractProduct * product){
        qDebug() << "Product registered:" << product->identifier();
    });
    connect(this, &AbstractStoreBackend::purchaseSucceeded, [this](AbstractTransaction * transaction){
        qDebug() << "purchaseSucceeded:" << transaction->orderId();

        AbstractProduct * ap = product(transaction->productId());
        if (ap) {
            emit ap->purchaseSucceeded(transaction);
            ap->setPurchased(true);
        } else {
            qCritical() << "Failed to map successful purchase to a product!";
        }
    });
    connect(this, &AbstractStoreBackend::purchaseRestored, [this](AbstractTransaction * transaction){
        qDebug() << "purchaseRestored:" << transaction->orderId() << " productId: " << transaction->productId();

        AbstractProduct * ap = product(transaction->productId());
        if (ap) {
            emit ap->purchaseRestored(transaction);
            ap->setPurchased(true);
        } else {
            qCritical() << "Failed to map restored purchase to a product!";
        }
    });
    connect(this, &AbstractStoreBackend::purchaseFailed, [](int code){
        qDebug() << "purchaseFailed:" << code;
    });
    connect(this, &AbstractStoreBackend::purchaseConsumed, [this](AbstractTransaction * transaction){
        qDebug() << "purchaseConsumed:" << transaction->orderId();

        AbstractProduct * ap = product(transaction->productId());
        if (ap) {
            emit ap->purchaseConsumed(transaction);
            ap->setPurchased(true);
        } else {
            qCritical() << "Failed to map consumed purchase to a product!";
        }
    });
}

AbstractProduct * AbstractStoreBackend::product(const QString &identifier)
{
    if (identifier.isEmpty())
        return nullptr;

    for (AbstractProduct * ap : _products) {
        const QString pid = ap->identifier();
        if (pid.isEmpty())
            continue;
        if (pid == identifier)
            return ap;
        // Google Play (Billing 5 / RevenueCat): store id is often "subscriptionId:basePlanId"
        if (identifier.startsWith(pid + QLatin1Char(':')))
            return ap;
        if (pid.startsWith(identifier + QLatin1Char(':')))
            return ap;
        const int ic = identifier.indexOf(QLatin1Char(':'));
        if (ic > 0 && pid == identifier.left(ic))
            return ap;
        const int pc = pid.indexOf(QLatin1Char(':'));
        if (pc > 0 && identifier == pid.left(pc))
            return ap;
    }
    return nullptr;
}
