#ifndef DUMMYSTOREBACKEND_H
#define DUMMYSTOREBACKEND_H

#include <QObject>
#include <QDateTime>
#include "abstractstorebackend.h"
#include "abstractproduct.h"
#include "abstracttransaction.h"


class DummyTransaction : public AbstractTransaction
{
public:
    DummyTransaction(AbstractStoreBackend *store, const QString &orderId, const QString &productId);

    QString productId() const override { return _productId; }

private:
    QString _productId;
};

class DummyStoreBackend : public AbstractStoreBackend
{
public:
    explicit DummyStoreBackend(QObject *parent = nullptr) : AbstractStoreBackend(parent) {
        _connected = false;
    }

    virtual void startConnection() override;
    virtual void registerProduct(AbstractProduct *product) override;
    virtual void purchaseProduct(AbstractProduct *product) override;
    virtual void consumePurchase(AbstractTransaction *transaction) override;

};

class DummyProduct : public AbstractProduct
{
public:
    explicit DummyProduct(QObject *parent = nullptr) : AbstractProduct(parent) {
        // Initialize properties with default values
        _identifier = "";
        _description = "";
        _price = "0.00";
        _productType = ProductType::Consumable;
        _title = "";
        _receipt = "";
        _purchased = false;
        _status = ProductStatus::Unitialized;
    }

    // Implementation of property setters to simply store values
    void setIdentifier(const QString &value) {
        if (_identifier != value) {
            _identifier = value;
            emit identifierChanged();
        }
    }

    void setProductType(ProductType type) {
        if (_productType != type) {
            _productType = type;
            emit productTypeChanged();
        }
    }

    void setStatus(ProductStatus status) {
        if (_status != status) {
            _status = status;
            emit statusChanged();
        }
    }

    void setDescription(QString value) {
        if (_description != value) {
            _description = value;
            emit descriptionChanged();
        }
    }

    void setPrice(const QString &value) {
        if (_price != value) {
            _price = value;
            emit priceChanged();
        }
    }

    void setTitle(const QString &value) {
        if (_title != value) {
            _title = value;
            emit titleChanged();
        }
    }

    QString receipt() const {
        return _receipt;
    }

    void setReceipt(const QString &newReceipt) {
        if (_receipt != newReceipt) {
            _receipt = newReceipt;
            emit receiptChanged();
        }
    }

    bool purchased() const {
        return _purchased;
    }

    void setPurchased(bool newPurchased) {
        if (_purchased != newPurchased) {
            _purchased = newPurchased;
            emit purchasedChanged();
        }
    }

    // Mock implementations of other operations
    void registerInStore() {
        // Simulate registration logic
        setStatus(ProductStatus::Registered);
    }

    Q_INVOKABLE void purchase() {
        // Simulate purchase logic
        if (_status == ProductStatus::Registered) {
            emit purchaseSucceeded(nullptr);  // Send a null transaction
            setPurchased(true);
        } else {
            emit purchaseFailed(nullptr);  // Send a null transaction
        }
    }
};

#endif // DUMMYSTOREBACKEND_H
