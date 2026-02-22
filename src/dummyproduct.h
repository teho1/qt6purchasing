#pragma once

#include <QString>

class DummyProduct {
public:
    void setPrice(const QString &price) override {
        Q_UNUSED(price);
    }

    void setTitle(const QString &title) override {
        Q_UNUSED(title);
    }

    void setDescription(const QString &description) override {
        Q_UNUSED(description);
    }

    void setStatus(ProductStatus status) override {
        Q_UNUSED(status);
    }
};