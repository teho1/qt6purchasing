#ifndef REVENUECATSTOREBACKEND_IOS_H
#define REVENUECATSTOREBACKEND_IOS_H

#include "../abstractstorebackend.h"

Q_FORWARD_DECLARE_OBJC_CLASS(QT_MANGLE_NAMESPACE(RevenueCatManager));

QT_BEGIN_NAMESPACE

class RevenueCatStoreBackend : public AbstractStoreBackend
{
    Q_OBJECT
    // QML guard: only configure() when this returns true, so the DummyStoreBackend
    // (which has no configure method) never causes a QML warning.
    Q_PROPERTY(bool supportsConfigure READ supportsConfigure CONSTANT)
    Q_PROPERTY(bool supportsLogIn READ supportsLogIn CONSTANT)
public:
    RevenueCatStoreBackend(QObject * parent = nullptr);
    ~RevenueCatStoreBackend();

    bool supportsConfigure() const { return true; }
    bool supportsLogIn() const { return true; }

    void startConnection() override;
    void registerProduct(AbstractProduct * product) override;
    void purchaseProduct(AbstractProduct * product) override;
    void consumePurchase(AbstractTransaction * transaction) override;

    Q_INVOKABLE void configure(const QString &apiKey, const QString &appUserID = QString());
    Q_INVOKABLE void restorePurchases();
    Q_INVOKABLE void logIn(const QString &appUserID) override;
    Q_INVOKABLE void logOut() override;

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
