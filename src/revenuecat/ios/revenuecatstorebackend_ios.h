#ifndef REVENUECATSTOREBACKEND_IOS_H
#define REVENUECATSTOREBACKEND_IOS_H

#include "../abstractstorebackend.h"

Q_FORWARD_DECLARE_OBJC_CLASS(QT_MANGLE_NAMESPACE(RevenueCatManager));

QT_BEGIN_NAMESPACE

class RevenueCatStoreBackend : public AbstractStoreBackend
{
public:
    RevenueCatStoreBackend(QObject * parent = nullptr);
    ~RevenueCatStoreBackend();

    void startConnection() override;
    void registerProduct(AbstractProduct * product) override;
    void purchaseProduct(AbstractProduct * product) override;
    void consumePurchase(AbstractTransaction * transaction) override;

    bool supportsConfigure() const override { return true; }
    Q_INVOKABLE void configure(const QString &apiKey, const QString &appUserID = QString());

protected:
    void initializePlatform();
    void cleanupPlatform();

private:
    QT_MANGLE_NAMESPACE(RevenueCatManager) * _manager = nullptr;
    QString _apiKey;
    QString _appUserID;
    bool _configured = false;
};

QT_END_NAMESPACE

#endif // REVENUECATSTOREBACKEND_IOS_H
