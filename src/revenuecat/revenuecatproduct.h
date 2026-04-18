#ifndef REVENUECATPRODUCT_H
#define REVENUECATPRODUCT_H

#include "../abstractproduct.h"

class RevenueCatProduct : public AbstractProduct
{
    Q_OBJECT

public:
    RevenueCatProduct(QObject * parent = nullptr);

    // RevenueCat-specific: package identifier for offerings
    Q_PROPERTY(QString packageIdentifier READ packageIdentifier WRITE setPackageIdentifier NOTIFY packageIdentifierChanged)
    QString packageIdentifier() const { return _packageIdentifier; }
    void setPackageIdentifier(const QString &identifier);

signals:
    void packageIdentifierChanged();

private:
    QString _packageIdentifier;
};

#endif // REVENUECATPRODUCT_H
