#ifndef APPLEAPPSTOREPRODUCT_H
#define APPLEAPPSTOREPRODUCT_H

#include "../abstractproduct.h"

Q_FORWARD_DECLARE_OBJC_CLASS(SKProduct);
Q_FORWARD_DECLARE_OBJC_CLASS(NSBundle);
Q_FORWARD_DECLARE_OBJC_CLASS(NSError);

class AppleAppStoreProduct : public AbstractProduct
{
    Q_OBJECT

public:
    AppleAppStoreProduct(QObject * parent = nullptr);

    SKProduct * nativeProduct() { return _nativeProduct; }
    void setNativeProduct(SKProduct * np);

private:
    SKProduct * _nativeProduct = nullptr;
};

#endif // APPLEAPPSTOREPRODUCT_H
