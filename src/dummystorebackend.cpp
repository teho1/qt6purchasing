void DummyStoreBackend::registerProduct(AbstractProduct *product)
{
    Q_UNUSED(product);
}

void DummyStoreBackend::purchaseProduct(AbstractProduct *product)
{
    Q_UNUSED(product);
}

void DummyStoreBackend::consumePurchase(AbstractTransaction *transaction)
{
    Q_UNUSED(transaction);
} 