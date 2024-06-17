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
    Q_PROPERTY(QObject * firstProduct READ firstProduct)
    Q_PROPERTY(bool supportsConfigure READ supportsConfigure CONSTANT)
    Q_CLASSINFO("DefaultProperty", "productsQml")

public:
    static AbstractStoreBackend * instance() { return _instance; }
    QQmlListProperty<AbstractProduct> productsQml() { return {this, &_products}; }
    QList<AbstractProduct *> products() { return _products; }
    QObject * firstProduct() const;
    AbstractProduct * product(const QString &identifier);
    bool isConnected() const { return _connected; }
    virtual bool supportsConfigure() const { return false; }

    /// No-op by default; RevenueCatStoreBackend overrides with real implementation.
    Q_INVOKABLE virtual void configure(const QString &apiKey, const QString &appUserID = QString()) { Q_UNUSED(apiKey); Q_UNUSED(appUserID); }

    Q_INVOKABLE virtual void startConnection() = 0;
    Q_INVOKABLE void addProduct(QObject *product);
    virtual void registerProduct(AbstractProduct * product) = 0;
    virtual void purchaseProduct(AbstractProduct * product) = 0;
    virtual void consumePurchase(AbstractTransaction * transaction) = 0;

protected:
    explicit AbstractStoreBackend(QObject * parent = nullptr);
    static AbstractStoreBackend * _instance;
    QList<AbstractProduct *> _products;
    bool _connected = false;

signals:
    void connectedChanged(bool connected);
    void productRegistered(AbstractProduct * product);
    void purchaseSucceeded(AbstractTransaction * transaction);
    void purchaseRestored(AbstractTransaction * transaction);
    void purchaseFailed(int code);
    void purchaseConsumed(AbstractTransaction * transaction);
};

#endif // ABSTRACTSTOREBACKEND_H
