#pragma once

#include <QObject>

class DummyTransaction : public QObject
{
    Q_OBJECT

public:
    void setStatus(TransactionStatus status) override {
        Q_UNUSED(status);
    }

    void setOrderId(const QString &orderId) override {
        Q_UNUSED(orderId);
    }

    void setFailureReason(FailureReason reason) override {
        Q_UNUSED(reason);
    }
};