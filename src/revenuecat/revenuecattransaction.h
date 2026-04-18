#ifndef REVENUECATTRANSACTION_H
#define REVENUECATTRANSACTION_H

#include "../abstracttransaction.h"

class AbstractStoreBackend;

class RevenueCatTransaction : public AbstractTransaction
{
    Q_OBJECT

public:
    RevenueCatTransaction(AbstractStoreBackend * store, const QString &orderId, const QString &productId, AbstractTransaction::Status status = AbstractTransaction::PurchaseApproved);

    QString productId() const override { return _productId; }

private:
    QString _productId;
};

#endif // REVENUECATTRANSACTION_H
