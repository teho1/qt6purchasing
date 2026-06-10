#ifndef REVENUECATSTOREBACKEND_ANDROID_H
#define REVENUECATSTOREBACKEND_ANDROID_H

#include "../abstractstorebackend.h"
#include <QJniObject>
#include <QJniEnvironment>

class RevenueCatStoreBackend : public AbstractStoreBackend
{
    Q_OBJECT
    // Matches iOS backend: QML only calls configure() when true (see main.qml).
    Q_PROPERTY(bool supportsConfigure READ supportsConfigure CONSTANT)

public:
    explicit RevenueCatStoreBackend(QObject * parent = nullptr);
    ~RevenueCatStoreBackend();

    bool supportsConfigure() const { return true; }

    void startConnection() override;
    void registerProduct(AbstractProduct * product) override;
    void purchaseProduct(AbstractProduct * product) override;
    void consumePurchase(AbstractTransaction * transaction) override;

    Q_INVOKABLE void configure(const QString &apiKey, const QString &appUserID = QString());
    Q_INVOKABLE void restorePurchases();

    // JNI callbacks
    static void connectedChangedHelper(JNIEnv * env, jobject object, jboolean connected);
    static void productRegistered(JNIEnv * env, jobject object, jstring productJson);
    static void purchaseSucceeded(JNIEnv * env, jobject object, jstring transactionJson);
    static void purchaseRestored(JNIEnv * env, jobject object, jstring transactionJson);
    // Names must not shadow QObject signals purchaseFailed / purchaseConsumed.
    static void jniPurchaseFailed(JNIEnv * env, jobject object, jint errorCode);
    static void jniPurchaseConsumed(JNIEnv * env, jobject object, jstring transactionJson);
    static void productRegistrationFailed(JNIEnv * env, jobject object, jstring productIdentifier);
    static void activeSubscriptionsChanged(JNIEnv * env, jobject object, jstring activeProductIdsJson);

private:
    QJniObject * _revenueCatJavaClass = nullptr;
    QString _apiKey;
    QString _appUserID;
    bool _configured = false;
};

#endif // REVENUECATSTOREBACKEND_ANDROID_H
