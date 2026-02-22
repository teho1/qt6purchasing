#include "dummystorebackend.h"
#include "abstractproduct.h"
#include "abstracttransaction.h"
#include <QDebug>

DummyTransaction::DummyTransaction(AbstractStoreBackend *store, const QString &orderId, const QString &productId)
    : AbstractTransaction(store, orderId), _productId(productId)
{
}

void DummyStoreBackend::startConnection()
{
    qDebug() << "DummyStoreBackend: Simulating connection for testing";
    _connected = true;
    emit connectedChanged(true);
}

void DummyStoreBackend::registerProduct(AbstractProduct *product)
{
    if (!product) return;
    product->setStatus(AbstractProduct::Registered);
    product->setDescription(product->identifier() + " (test)");
    product->setPrice("2.99€");
    emit productRegistered(product);
}

void DummyStoreBackend::purchaseProduct(AbstractProduct *product)
{
    if (!product || product->status() != AbstractProduct::Registered) {
        emit purchaseFailed(-1);
        return;
    }
    auto *tx = new DummyTransaction(this, "dummy_" + QString::number(QDateTime::currentMSecsSinceEpoch()), product->identifier());
    emit purchaseSucceeded(tx);
}

void DummyStoreBackend::consumePurchase(AbstractTransaction *transaction)
{
    if (transaction)
        emit purchaseConsumed(transaction);
}