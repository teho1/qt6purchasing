#ifndef ABSTRACTSTOREBACKEND_H
#define ABSTRACTSTOREBACKEND_H

#include <QJsonDocument>
#include <QObject>
#include <QQmlListProperty>

class AbstractProduct;
class AbstractTransaction;

class AbstractStoreBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQmlListProperty<AbstractProduct> productsQml READ productsQml)
    Q_CLASSINFO("DefaultProperty", "productsQml")

public:
    static AbstractStoreBackend * instance() { return _instance; }
    QQmlListProperty<AbstractProduct> productsQml() { return {this, &_products}; }
    QList<AbstractProduct *> products() { return _products; }
    AbstractProduct * product(const QString &identifier);
    bool isConnected() const { return _connected; }

    Q_PROPERTY(bool supportsLogIn READ supportsLogIn CONSTANT)
    /**
     * True when the store runs against a sandbox environment (e.g. iOS TestFlight / Xcode).
     * Purchases from the production store are not visible there, so a paywall is expected.
     */
    Q_PROPERTY(bool sandbox READ isSandbox NOTIFY sandboxChanged)
    bool isSandbox() const { return _sandbox; }

    virtual void startConnection() = 0;
    /** QML cannot call pure virtuals; delegates to the concrete store implementation. */
    Q_INVOKABLE void startStoreConnection() { startConnection(); }
    virtual void registerProduct(AbstractProduct * product) = 0;
    virtual void purchaseProduct(AbstractProduct * product) = 0;
    virtual void consumePurchase(AbstractTransaction * transaction) = 0;

    virtual bool supportsLogIn() const { return false; }
    Q_INVOKABLE virtual void logIn(const QString &appUserID) { Q_UNUSED(appUserID); }
    Q_INVOKABLE virtual void logOut() {}

protected:
    explicit AbstractStoreBackend(QObject * parent = nullptr);
    static AbstractStoreBackend * _instance;
    QList<AbstractProduct *> _products;
    bool _connected = false;
    bool _sandbox = false;
    void setSandbox(bool sandbox)
    {
        if (_sandbox == sandbox)
            return;
        _sandbox = sandbox;
        emit sandboxChanged();
    }

signals:
    void connectedChanged(bool connected);
    void sandboxChanged();
    void productRegistered(AbstractProduct * product);
    void purchaseSucceeded(AbstractTransaction * transaction);
    void purchaseRestored(AbstractTransaction * transaction);
    void purchaseFailed(int code);
    void purchaseConsumed(AbstractTransaction * transaction);
    /** Result of logIn(). Emitted on the Qt (GUI) thread by backends that support logIn. */
    void logInFinished(const QString &appUserID, bool success, int errorCode, const QString &errorMessage);
    /**
     * Result of restorePurchases(). hasActiveSubscription is true when the restored customer
     * owns an active subscription for a registered product. errorCode is the store SDK error
     * code (RevenueCat PurchasesErrorCode, e.g. 7 = receipt already in use) or 0 on success.
     */
    void restoreFinished(bool success, bool hasActiveSubscription, int errorCode, const QString &errorMessage);
};

#endif // ABSTRACTSTOREBACKEND_H
