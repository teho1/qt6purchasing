#include "revenuecatstorebackend_android.h"
#include "../revenuecatproduct.h"
#include "../revenuecattransaction.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSet>
#include <QtCore/qcoreapplication_platform.h> // QNativeInterface::QAndroidApplication (Qt 6 Android)

RevenueCatStoreBackend::RevenueCatStoreBackend(QObject * parent) : AbstractStoreBackend(parent)
{
    qDebug() << "Creating RevenueCat Android backend";
}

RevenueCatStoreBackend::~RevenueCatStoreBackend()
{
    if (_revenueCatJavaClass) {
        delete _revenueCatJavaClass;
    }
}

void RevenueCatStoreBackend::configure(const QString &apiKey, const QString &appUserID)
{
    if (_configured) {
        qWarning() << "RevenueCat already configured";
        return;
    }

    _apiKey = apiKey;
    _appUserID = appUserID.isEmpty() ? QString() : appUserID;
    
    if (_apiKey.isEmpty()) {
        qCritical() << "RevenueCat API key is required";
        return;
    }

    // Initialize Java class (RevenueCatBilling ctor takes Context; see GooglePlayBilling)
    _revenueCatJavaClass = new QJniObject(
        "com/climbsmart/crimptronic/RevenueCatBilling",
        QNativeInterface::QAndroidApplication::context());

    if (!_revenueCatJavaClass->isValid()) {
        qWarning("Cannot initialize RevenueCat backend for Android. Make sure RevenueCatBilling.java exists.");
        return;
    }

    // Register JNI callbacks
    JNINativeMethod methods[] {
        {"connectedChangedHelper", "(Z)V", reinterpret_cast<void *>(connectedChangedHelper)},
        {"productRegistered", "(Ljava/lang/String;)V", reinterpret_cast<void *>(productRegistered)},
        {"purchaseSucceeded", "(Ljava/lang/String;)V", reinterpret_cast<void *>(purchaseSucceeded)},
        {"purchaseRestored", "(Ljava/lang/String;)V", reinterpret_cast<void *>(purchaseRestored)},
        {"purchaseFailed", "(I)V", reinterpret_cast<void *>(jniPurchaseFailed)},
        {"purchaseConsumed", "(Ljava/lang/String;)V", reinterpret_cast<void *>(jniPurchaseConsumed)},
        {"productRegistrationFailed", "(Ljava/lang/String;)V", reinterpret_cast<void *>(productRegistrationFailed)},
        {"activeSubscriptionsChanged", "(Ljava/lang/String;)V", reinterpret_cast<void *>(activeSubscriptionsChanged)},
    };
    QJniEnvironment env;
    jclass objectClass = env->GetObjectClass(_revenueCatJavaClass->object<jobject>());
    env->RegisterNatives(objectClass,
                         methods,
                         sizeof(methods) / sizeof(methods[0]));
    env->DeleteLocalRef(objectClass);

    // Configure RevenueCat
    _revenueCatJavaClass->callMethod<void>(
        "configure",
        "(Ljava/lang/String;Ljava/lang/String;)V",
        QJniObject::fromString(_apiKey).object<jstring>(),
        QJniObject::fromString(_appUserID).object<jstring>()
    );

    _configured = true;
}

void RevenueCatStoreBackend::startConnection()
{
    if (!_configured) {
        qCritical() << "RevenueCat must be configured before starting connection";
        return;
    }
    
    if (_revenueCatJavaClass && _revenueCatJavaClass->isValid()) {
        _revenueCatJavaClass->callMethod<void>("startConnection");
    }
}

void RevenueCatStoreBackend::restorePurchases()
{
    if (!_configured) {
        qWarning() << "RevenueCat not configured; cannot restore purchases";
        return;
    }
    if (!_revenueCatJavaClass || !_revenueCatJavaClass->isValid()) {
        qWarning() << "RevenueCat Java bridge not initialized; cannot restore purchases";
        return;
    }
    _revenueCatJavaClass->callMethod<void>("restorePurchases");
}

void RevenueCatStoreBackend::registerProduct(AbstractProduct * product)
{
    if (!_configured) {
        qWarning() << "RevenueCat not configured; product registration failed for" << product->identifier();
        product->setStatus(AbstractProduct::Unknown);
        return;
    }

    if (!_revenueCatJavaClass || !_revenueCatJavaClass->isValid()) {
        qCritical() << "RevenueCat Java class not initialized";
        product->setStatus(AbstractProduct::Unknown);
        return;
    }

    _revenueCatJavaClass->callMethod<void>(
        "registerProduct",
        "(Ljava/lang/String;)V",
        QJniObject::fromString(product->identifier()).object<jstring>()
    );
}

void RevenueCatStoreBackend::purchaseProduct(AbstractProduct * product)
{
    if (!isConnected()) {
        qCritical() << "Not connected to RevenueCat";
        emit purchaseFailed(-1);
        return;
    }

    RevenueCatProduct * rcProduct = qobject_cast<RevenueCatProduct*>(product);
    if (!rcProduct) {
        qCritical() << "Product must be a RevenueCatProduct";
        emit purchaseFailed(-2);
        return;
    }

    QString packageId = rcProduct->packageIdentifier();
    if (packageId.isEmpty()) {
        // Purchase by product identifier
        _revenueCatJavaClass->callMethod<void>(
            "purchaseProduct",
            "(Ljava/lang/String;)V",
            QJniObject::fromString(product->identifier()).object<jstring>()
        );
    } else {
        // Purchase by package identifier
        _revenueCatJavaClass->callMethod<void>(
            "purchasePackage",
            "(Ljava/lang/String;Ljava/lang/String;)V",
            QJniObject::fromString(product->identifier()).object<jstring>(),
            QJniObject::fromString(packageId).object<jstring>()
        );
    }
}

void RevenueCatStoreBackend::consumePurchase(AbstractTransaction * transaction)
{
    if (!transaction) {
        qWarning() << "Cannot consume null transaction";
        return;
    }

    qDebug() << "Consuming RevenueCat transaction:" << transaction->orderId();
    // RevenueCat handles consumables automatically
    emit purchaseConsumed(transaction);
}

/*static*/ void RevenueCatStoreBackend::connectedChangedHelper(JNIEnv * env, jobject object, jboolean connected)
{
    Q_UNUSED(env)
    Q_UNUSED(object)
    emit RevenueCatStoreBackend::instance()->connectedChanged(connected);
}

static void applyActiveSubscriptionIds(AbstractStoreBackend *backend, const QJsonArray &activeIds)
{
    if (!backend)
        return;

    QSet<AbstractProduct *> matchedProducts;
    for (const QJsonValue &value : activeIds) {
        const QString storeId = value.toString();
        if (storeId.isEmpty())
            continue;
        AbstractProduct *matched = backend->product(storeId);
        if (matched)
            matchedProducts.insert(matched);
    }

    for (AbstractProduct *product : backend->products()) {
        if (product->productType() != AbstractProduct::Subscription)
            continue;
        const bool active = matchedProducts.contains(product);
        if (product->purchased() != active)
            product->setPurchased(active);
    }
}

/*static*/ void RevenueCatStoreBackend::productRegistrationFailed(JNIEnv * env, jobject object, jstring productIdentifier)
{
    Q_UNUSED(object)
    const char *nativeId = env->GetStringUTFChars(productIdentifier, nullptr);
    const QString id = QString::fromUtf8(nativeId);
    env->ReleaseStringUTFChars(productIdentifier, nativeId);

    RevenueCatProduct *product = qobject_cast<RevenueCatProduct*>(
        RevenueCatStoreBackend::instance()->product(id));
    if (product) {
        product->setStatus(AbstractProduct::Unknown);
        qWarning() << "[IAP] Subscription product not found in RevenueCat offerings for id:" << id;
    }
}

/*static*/ void RevenueCatStoreBackend::activeSubscriptionsChanged(JNIEnv * env, jobject object, jstring activeProductIdsJson)
{
    Q_UNUSED(object)
    const char *nativeMessage = env->GetStringUTFChars(activeProductIdsJson, nullptr);
    const QJsonArray activeIds = QJsonDocument::fromJson(QByteArray(nativeMessage)).array();
    env->ReleaseStringUTFChars(activeProductIdsJson, nativeMessage);

    applyActiveSubscriptionIds(RevenueCatStoreBackend::instance(), activeIds);
}

/*static*/ void RevenueCatStoreBackend::productRegistered(JNIEnv * env, jobject object, jstring productJson)
{
    Q_UNUSED(object)
    const char *nativeMessage = env->GetStringUTFChars(productJson, nullptr);
    QJsonObject json = QJsonDocument::fromJson(nativeMessage).object();
    env->ReleaseStringUTFChars(productJson, nativeMessage);

    RevenueCatProduct * product = qobject_cast<RevenueCatProduct*>(
        RevenueCatStoreBackend::instance()->product(json["productId"].toString())
    );

    if (product) {
        product->setDescription(json["description"].toString());
        product->setPrice(json["price"].toString());
        if (json.contains(QStringLiteral("billingPeriodUnit")) && json.contains(QStringLiteral("billingPeriodValue"))) {
            const int u = json.value(QStringLiteral("billingPeriodUnit")).toInt(-1);
            const int v = json.value(QStringLiteral("billingPeriodValue")).toInt(0);
            product->setBillingPeriodDescription(subscriptionBillingSuffixFromRcUnits(u, v));
        } else {
            product->setBillingPeriodDescription(QString());
        }
        product->setTitle(json["title"].toString());
        product->setStatus(AbstractProduct::Registered);
        if (json.contains("packageIdentifier")) {
            product->setPackageIdentifier(json["packageIdentifier"].toString());
        }
        emit RevenueCatStoreBackend::instance()->productRegistered(product);
    }
}

/*static*/ void RevenueCatStoreBackend::purchaseSucceeded(JNIEnv * env, jobject object, jstring transactionJson)
{
    Q_UNUSED(object)
    const char *nativeMessage = env->GetStringUTFChars(transactionJson, nullptr);
    QJsonObject json = QJsonDocument::fromJson(nativeMessage).object();
    env->ReleaseStringUTFChars(transactionJson, nativeMessage);

    RevenueCatTransaction * transaction = new RevenueCatTransaction(
        RevenueCatStoreBackend::instance(),
        json["orderId"].toString(),
        json["productId"].toString(),
        AbstractTransaction::PurchaseApproved
    );

    emit RevenueCatStoreBackend::instance()->purchaseSucceeded(transaction);
}

/*static*/ void RevenueCatStoreBackend::purchaseRestored(JNIEnv * env, jobject object, jstring transactionJson)
{
    Q_UNUSED(object)
    const char *nativeMessage = env->GetStringUTFChars(transactionJson, nullptr);
    QJsonObject json = QJsonDocument::fromJson(nativeMessage).object();
    env->ReleaseStringUTFChars(transactionJson, nativeMessage);

    RevenueCatTransaction * transaction = new RevenueCatTransaction(
        RevenueCatStoreBackend::instance(),
        json["orderId"].toString(),
        json["productId"].toString(),
        AbstractTransaction::PurchaseRestored
    );

    emit RevenueCatStoreBackend::instance()->purchaseRestored(transaction);
}

/*static*/ void RevenueCatStoreBackend::jniPurchaseFailed(JNIEnv * env, jobject object, jint errorCode)
{
    Q_UNUSED(env)
    Q_UNUSED(object)
    emit RevenueCatStoreBackend::instance()->purchaseFailed(errorCode);
}

/*static*/ void RevenueCatStoreBackend::jniPurchaseConsumed(JNIEnv * env, jobject object, jstring transactionJson)
{
    Q_UNUSED(object)
    const char *nativeMessage = env->GetStringUTFChars(transactionJson, nullptr);
    QJsonObject json = QJsonDocument::fromJson(nativeMessage).object();
    env->ReleaseStringUTFChars(transactionJson, nativeMessage);

    RevenueCatTransaction * transaction = new RevenueCatTransaction(
        RevenueCatStoreBackend::instance(),
        json["orderId"].toString(),
        json["productId"].toString(),
        AbstractTransaction::PurchaseConsumed
    );

    emit RevenueCatStoreBackend::instance()->purchaseConsumed(transaction);
}
