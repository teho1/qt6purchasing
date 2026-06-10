package com.climbsmart.crimptronic;

import android.app.Activity;
import android.content.Context;
import com.revenuecat.purchases.Purchases;
import com.revenuecat.purchases.PurchasesConfiguration;
import com.revenuecat.purchases.Offerings;
import com.revenuecat.purchases.Offering;
import com.revenuecat.purchases.Package;
import com.revenuecat.purchases.CustomerInfo;
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback;
import com.revenuecat.purchases.interfaces.PurchaseCallback;
import com.revenuecat.purchases.models.StoreProduct;
import com.revenuecat.purchases.models.StoreTransaction;
import com.revenuecat.purchases.models.Period;
import com.revenuecat.purchases.PurchasesError;
import com.revenuecat.purchases.ProductType;
import com.revenuecat.purchases.EntitlementInfo;
import com.revenuecat.purchases.interfaces.GetStoreProductsCallback;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;
import android.util.Log;

import java.util.Arrays;
import java.util.List;

public class RevenueCatBilling {
    private static native void connectedChangedHelper(boolean connected);
    private static native void productRegistered(String productJson);
    private static native void purchaseSucceeded(String transactionJson);
    private static native void purchaseRestored(String transactionJson);
    private static native void purchaseFailed(int errorCode);
    private static native void purchaseConsumed(String transactionJson);
    private static native void productRegistrationFailed(String productIdentifier);
    private static native void activeSubscriptionsChanged(String activeProductIdsJson);

    private static final String TAG = "RevenueCatBilling";

    private Activity activity;
    private boolean configured = false;

    public RevenueCatBilling(Context context) {
        if (!(context instanceof Activity)) {
            throw new IllegalStateException("RevenueCatBilling requires an Activity context");
        }
        this.activity = (Activity) context;
    }

    private static int revenueCatErrorCode(PurchasesError error) {
        return error.getCode().getCode();
    }

    /**
     * Google Play subscription SKUs are often "subscriptionId:basePlanId" in Billing 5 / RevenueCat,
     * while the app may use the subscription id alone (e.g. "righthere").
     */
    private static boolean storeProductMatchesRequested(StoreProduct product, String requested) {
        if (requested == null || requested.isEmpty()) {
            return false;
        }
        String storeId = product.getId();
        if (storeId.equals(requested)) {
            return true;
        }
        if (storeId.startsWith(requested + ":")) {
            return true;
        }
        int colon = storeId.indexOf(':');
        return colon > 0 && storeId.substring(0, colon).equals(requested);
    }

    private static void notifyActiveSubscriptions(CustomerInfo customerInfo) {
        if (customerInfo == null) {
            return;
        }
        JSONArray arr = new JSONArray();
        for (String id : customerInfo.getActiveSubscriptions()) {
            arr.put(id);
        }
        for (EntitlementInfo entitlement : customerInfo.getEntitlements().getActive().values()) {
            if (entitlement.isActive()) {
                arr.put(entitlement.getProductIdentifier());
            }
        }
        activeSubscriptionsChanged(arr.toString());
    }

    private static StoreProduct findMatchingStoreProduct(List<StoreProduct> products, String productIdentifier) {
        if (products == null) {
            return null;
        }
        for (StoreProduct product : products) {
            if (storeProductMatchesRequested(product, productIdentifier)) {
                return product;
            }
        }
        return null;
    }

    private void emitRegisteredProduct(String productIdentifier, StoreProduct product, String packageIdentifier)
            throws JSONException {
        JSONObject json = new JSONObject();
        json.put("productId", productIdentifier);
        json.put("storeProductId", product.getId());
        json.put("title", product.getTitle());
        json.put("description", product.getDescription());
        json.put("price", product.getPrice().getFormatted());
        if (packageIdentifier != null && !packageIdentifier.isEmpty()) {
            json.put("packageIdentifier", packageIdentifier);
        }
        Period period = product.getPeriod();
        if (period != null) {
            json.put("billingPeriodUnit", period.getUnit().ordinal());
            json.put("billingPeriodValue", period.getValue());
        }
        productRegistered(json.toString());
        refreshCustomerInfo();
    }

    /**
     * Fallback when the subscription is on Play but not packaged in a RevenueCat offering
     * (native Play Billing queried SKU details directly; RevenueCat offerings are stricter).
     */
    private void fetchStoreProductFallback(String productIdentifier, StoreProductConsumer consumer) {
        Purchases.getSharedInstance().getProducts(
                Arrays.asList(productIdentifier),
                ProductType.SUBS,
                new GetStoreProductsCallback() {
                    @Override
                    public void onReceived(List<StoreProduct> storeProducts) {
                        StoreProduct matched = findMatchingStoreProduct(storeProducts, productIdentifier);
                        if (matched != null) {
                            consumer.accept(matched);
                        } else {
                            Log.w(TAG, "getProducts: no Play subscription for app id \"" + productIdentifier + "\"");
                            consumer.accept(null);
                        }
                    }

                    @Override
                    public void onError(PurchasesError error) {
                        Log.w(TAG, "getProducts error for \"" + productIdentifier + "\": " + error.getMessage());
                        consumer.accept(null);
                    }
                });
    }

    private interface StoreProductConsumer {
        void accept(StoreProduct product);
    }

    private void refreshCustomerInfo() {
        Purchases.getSharedInstance().getCustomerInfo(
                new com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback() {
                    @Override
                    public void onReceived(CustomerInfo customerInfo) {
                        notifyActiveSubscriptions(customerInfo);
                    }

                    @Override
                    public void onError(PurchasesError error) {
                        Log.w(TAG, "getCustomerInfo: " + error.getMessage());
                    }
                });
    }

    public void configure(String apiKey, String appUserID) {
        PurchasesConfiguration.Builder configBuilder = new PurchasesConfiguration.Builder(activity, apiKey);
        
        if (appUserID != null && !appUserID.isEmpty()) {
            configBuilder.appUserID(appUserID);
        }
        
        Purchases.configure(configBuilder.build());
        configured = true;
        
        // Test connection by fetching offerings
        Purchases.getSharedInstance().getOfferings(new ReceiveOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                connectedChangedHelper(true);
                refreshCustomerInfo();
            }

            @Override
            public void onError(PurchasesError error) {
                Log.w(TAG, "configure offerings error: " + error.getMessage());
                connectedChangedHelper(false);
            }
        });
    }

    public void startConnection() {
        if (!configured) {
            return;
        }
        
        Purchases.getSharedInstance().getOfferings(new ReceiveOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                connectedChangedHelper(true);
                refreshCustomerInfo();
            }

            @Override
            public void onError(PurchasesError error) {
                Log.w(TAG, "startConnection offerings error: " + error.getMessage());
                connectedChangedHelper(false);
            }
        });
    }

    public void registerProduct(String productIdentifier) {
        if (!configured) {
            Log.w(TAG, "registerProduct called before configure for \"" + productIdentifier + "\"");
            productRegistrationFailed(productIdentifier);
            return;
        }

        Purchases.getSharedInstance().getOfferings(new ReceiveOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                Package foundPackage = null;

                for (Offering offering : offerings.getAll().values()) {
                    for (Package pkg : offering.getAvailablePackages()) {
                        if (storeProductMatchesRequested(pkg.getProduct(), productIdentifier)) {
                            foundPackage = pkg;
                            break;
                        }
                    }
                    if (foundPackage != null) break;
                }

                if (foundPackage != null) {
                    try {
                        emitRegisteredProduct(
                                productIdentifier,
                                foundPackage.getProduct(),
                                foundPackage.getIdentifier());
                    } catch (JSONException e) {
                        Log.w(TAG, "registerProduct JSON error for " + productIdentifier, e);
                        productRegistrationFailed(productIdentifier);
                    }
                    return;
                }

                Log.w(TAG, "registerProduct: no RevenueCat package for \"" + productIdentifier
                        + "\"; querying Play Store directly.");
                fetchStoreProductFallback(productIdentifier, matched -> {
                    if (matched == null) {
                        productRegistrationFailed(productIdentifier);
                        return;
                    }
                    try {
                        emitRegisteredProduct(productIdentifier, matched, null);
                    } catch (JSONException e) {
                        Log.w(TAG, "registerProduct fallback JSON error for " + productIdentifier, e);
                        productRegistrationFailed(productIdentifier);
                    }
                });
            }

            @Override
            public void onError(PurchasesError error) {
                Log.w(TAG, "registerProduct offerings error for \"" + productIdentifier + "\": "
                        + error.getMessage() + "; querying Play Store directly.");
                fetchStoreProductFallback(productIdentifier, matched -> {
                    if (matched == null) {
                        productRegistrationFailed(productIdentifier);
                        return;
                    }
                    try {
                        emitRegisteredProduct(productIdentifier, matched, null);
                    } catch (JSONException e) {
                        Log.w(TAG, "registerProduct fallback JSON error for " + productIdentifier, e);
                        productRegistrationFailed(productIdentifier);
                    }
                });
            }
        });
    }

    public void purchaseProduct(String productIdentifier) {
        purchasePackage(productIdentifier, null);
    }

    public void purchasePackage(String productIdentifier, String packageIdentifier) {
        if (!configured) {
            purchaseFailed(-1);
            return;
        }

        Purchases.getSharedInstance().getOfferings(new ReceiveOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                Package packageToPurchase = null;
                
                if (packageIdentifier != null && !packageIdentifier.isEmpty()) {
                    // Find package by identifier
                    for (Offering offering : offerings.getAll().values()) {
                        packageToPurchase = offering.getPackage(packageIdentifier);
                        if (packageToPurchase != null) break;
                    }
                } else {
                    // Find package by product identifier
                    for (Offering offering : offerings.getAll().values()) {
                        for (Package pkg : offering.getAvailablePackages()) {
                            if (storeProductMatchesRequested(pkg.getProduct(), productIdentifier)) {
                                packageToPurchase = pkg;
                                break;
                            }
                        }
                        if (packageToPurchase != null) break;
                    }
                }
                
                if (packageToPurchase != null) {
                    launchPurchase(
                            new com.revenuecat.purchases.PurchaseParams.Builder(activity, packageToPurchase).build(),
                            productIdentifier);
                    return;
                }

                Log.w(TAG, "purchasePackage: no RevenueCat package for \"" + productIdentifier
                        + "\"; purchasing Play Store product directly.");
                fetchStoreProductFallback(productIdentifier, matched -> {
                    if (matched == null) {
                        purchaseFailed(-2);
                        return;
                    }
                    launchPurchase(
                            new com.revenuecat.purchases.PurchaseParams.Builder(activity, matched).build(),
                            productIdentifier);
                });
            }

            @Override
            public void onError(PurchasesError error) {
                Log.w(TAG, "purchasePackage offerings error for \"" + productIdentifier + "\": "
                        + error.getMessage() + "; purchasing Play Store product directly.");
                fetchStoreProductFallback(productIdentifier, matched -> {
                    if (matched == null) {
                        purchaseFailed(revenueCatErrorCode(error));
                        return;
                    }
                    launchPurchase(
                            new com.revenuecat.purchases.PurchaseParams.Builder(activity, matched).build(),
                            productIdentifier);
                });
            }
        });
    }

    private void launchPurchase(com.revenuecat.purchases.PurchaseParams params, String productIdentifier) {
        Purchases.getSharedInstance().purchase(params, new PurchaseCallback() {
            @Override
            public void onCompleted(StoreTransaction storeTransaction, CustomerInfo customerInfo) {
                try {
                    JSONObject json = new JSONObject();
                    String orderId = storeTransaction.getOrderId();
                    if (orderId == null || orderId.isEmpty()) {
                        orderId = storeTransaction.getPurchaseToken();
                    }
                    json.put("orderId", orderId != null ? orderId : "");
                    json.put("productId", productIdentifier);
                    purchaseSucceeded(json.toString());
                    notifyActiveSubscriptions(customerInfo);
                } catch (JSONException e) {
                    purchaseFailed(-3);
                }
            }

            @Override
            public void onError(PurchasesError error, boolean userCancelled) {
                if (userCancelled) {
                    purchaseFailed(1);
                } else {
                    purchaseFailed(revenueCatErrorCode(error));
                }
            }
        });
    }

    public void restorePurchases() {
        if (!configured) {
            return;
        }

        Purchases.getSharedInstance().restorePurchases(new com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback() {
            @Override
            public void onReceived(CustomerInfo customerInfo) {
                notifyActiveSubscriptions(customerInfo);
                for (String productId : customerInfo.getActiveSubscriptions()) {
                    try {
                        JSONObject json = new JSONObject();
                        json.put("orderId", "restored_" + productId);
                        json.put("productId", productId);
                        purchaseRestored(json.toString());
                    } catch (JSONException e) {
                        Log.w(TAG, "restorePurchases JSON error", e);
                    }
                }
            }

            @Override
            public void onError(PurchasesError error) {
                // Restore failed
            }
        });
    }
}
