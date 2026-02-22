#include "revenuecatproduct.h"

RevenueCatProduct::RevenueCatProduct(QObject * parent) : AbstractProduct(parent)
{
}

void RevenueCatProduct::setPackageIdentifier(const QString &identifier)
{
    if (_packageIdentifier == identifier)
        return;
    _packageIdentifier = identifier;
    emit packageIdentifierChanged();
}
