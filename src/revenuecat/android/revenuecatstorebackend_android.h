#ifndef REVENUECATSTOREBACKEND_ANDROID_H
#define REVENUECATSTOREBACKEND_ANDROID_H

#include "../abstractstorebackend.h"
#include <QJniObject>
#include <QJniEnvironment>

class RevenueCatStoreBackend : public AbstractStoreBackend
{
    Q_OBJECT

public:
    explicit RevenueCatStoreBackend(QObject * parent = nullptr);
    ~RevenueCatStoreBackend();

    void startConnection() override;
    void registerProduct(AbstractProduct * product) override;
    void purchaseProduct(AbstractProduct * product) override;
    void consumePurchase(AbstractTransaction * transaction) override;

    bool supportsConfigure() const override { return true; }
    Q_INVOKABLE void configure(const QString &apiKey, const QString &appUserID = QString());

    // JNI callbacks
    static void connectedChangedHelper(JNIEnv * env, jobject object, jboolean connected);
    static void productRegistered(JNIEnv * env, jobject object, jstring productJson);
    static void purchaseSucceeded(JNIEnv * env, jobject object, jstring transactionJson);
    static void purchaseRestored(JNIEnv * env, jobject object, jstring transactionJson);
    static void purchaseFailed(JNIEnv * env, jobject object, jint errorCode);
    static void purchaseConsumed(JNIEnv * env, jobject object, jstring transactionJson);

private:
    QJniObject * _revenueCatJavaClass = nullptr;
    QString _apiKey;
    QString _appUserID;
    bool _configured = false;
};

#endif // REVENUECATSTOREBACKEND_ANDROID_H
