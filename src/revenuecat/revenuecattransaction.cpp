#include "revenuecattransaction.h"
#include "../abstractstorebackend.h"

RevenueCatTransaction::RevenueCatTransaction(AbstractStoreBackend * store, const QString &orderId, const QString &productId, AbstractTransaction::Status status)
    : AbstractTransaction(store, orderId), _productId(productId)
{
    _status = status;
    emit statusChanged();
}
