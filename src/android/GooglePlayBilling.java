package com.climbsmart.crimptronic;

import android.app.Activity;
import android.content.Context;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClient.BillingResponseCode;
import com.android.billingclient.api.BillingClient.SkuType;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ConsumeResponseListener;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.SkuDetails;
import com.android.billingclient.api.SkuDetailsParams;
import com.android.billingclient.api.SkuDetailsResponseListener;
import com.android.billingclient.api.QueryPurchasesParams;
import com.android.billingclient.api.PurchasesResponseListener;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class GooglePlayBilling {

    private static native void debugMessage(String message);
    private static native void connectedChangedHelper(boolean connected);
    private static native void billingResponseReceived(int billingResponseCode);
    private static native void productRegistered(String productJson);

    private static native void purchaseSucceeded(String purchaseJson);
    private static native void purchaseRestored(String purchaseJson);
    private static native void purchaseFailed(int billingResponseCode);
    private static native void purchaseConsumed(String purchaseJson);

    private Context context;
    private PurchasesUpdatedListener purchasesUpdatedListener;
    private BillingClient billingClient;

    public GooglePlayBilling(Context cnt) {
        this.context = cnt;

        purchasesUpdatedListener = new PurchasesUpdatedListener() {
            @Override
            public void onPurchasesUpdated(BillingResult billingResult, List<Purchase> purchases) {
                debugMessage("onPurchasesUpdated called with response code: " + billingResult.getResponseCode());
                if (billingResult.getResponseCode() == BillingResponseCode.OK && purchases != null) {
                    debugMessage("Purchase successful");
                    for (Purchase purchase : purchases) {
                        debugMessage("Processing purchase: " + purchase.getOriginalJson());
                        purchaseSucceeded(purchase.getOriginalJson());
                    }
                } else if (billingResult.getResponseCode() == BillingResponseCode.USER_CANCELED) {
                    debugMessage("Purchase canceled by user");
                    purchaseFailed(billingResult.getResponseCode());
                } else {
                    debugMessage("Purchase failed with response code: " + billingResult.getResponseCode());
                    purchaseFailed(billingResult.getResponseCode());
                }
            }
        };

        billingClient = BillingClient.newBuilder(context)
                .setListener(purchasesUpdatedListener)
                .enablePendingPurchases()
                .build();
    }

    public void startConnection() {
        debugMessage("Starting connection to Google Play Store");
        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(BillingResult billingResult) {
                debugMessage("onBillingSetupFinished called with response code: " + billingResult.getResponseCode());
                billingResponseReceived(billingResult.getResponseCode());
                if (billingResult.getResponseCode() == BillingResponseCode.OK) {
                    debugMessage("Billing client setup finished successfully");
                    connectedChangedHelper(true);
                } else {
                    debugMessage("Billing client setup failed");
                    connectedChangedHelper(false);
                }
            }

            @Override
            public void onBillingServiceDisconnected() {
                debugMessage("onBillingServiceDisconnected called");
                connectedChangedHelper(false);
            }
        });
    }

    public void queryPurchases() {
        debugMessage("Querying purchases");


        QueryPurchasesParams queryPurchasesParams = QueryPurchasesParams.newBuilder()
            .setProductType(SkuType.SUBS)
            .build();

            billingClient.queryPurchasesAsync(queryPurchasesParams, new PurchasesResponseListener() {
                @Override
            public void onQueryPurchasesResponse(BillingResult billingResult, List<Purchase> purchases) {
                debugMessage("onQueryPurchasesResponse called with response code: " + billingResult.getResponseCode());
                if (billingResult.getResponseCode() == BillingResponseCode.OK && !purchases.isEmpty()) {
                    debugMessage("Restoring purchases");
                    for (Purchase purchase : purchases) {
                        debugMessage("Restoring purchase: " + purchase.getOriginalJson());
                        purchaseRestored(purchase.getOriginalJson());
                    }
                } else {
                    debugMessage("No purchases to restore or error occurred");
                }
            }
        });
    }

    public void registerProduct(final String productId) {
        debugMessage("Registering product with ID: " + productId);
        List<String> skuList = new ArrayList<>();
        skuList.add(productId);
        SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder();
        params.setSkusList(skuList).setType(SkuType.SUBS);
        billingClient.querySkuDetailsAsync(params.build(), new SkuDetailsResponseListener() {
            @Override
            public void onSkuDetailsResponse(BillingResult billingResult, List<SkuDetails> skuDetailsList) {
                debugMessage("onSkuDetailsResponse called with response code: " + billingResult.getResponseCode());
                if (skuDetailsList == null || skuDetailsList.isEmpty()) {
                    debugMessage("skuDetailsList is empty or null");
                    return;
                }

                SkuDetails skuDetails = skuDetailsList.get(0);
                debugMessage("Product registered: " + skuDetails.getOriginalJson());
                productRegistered(skuDetails.getOriginalJson());
                queryPurchases();
            }
        });
    }

    public void purchaseProduct(Activity activity, final String jsonSkuDetails) {
        try {
            debugMessage("Initiating purchase for SKU details: " + jsonSkuDetails);
            SkuDetails purchaseThis = new SkuDetails(jsonSkuDetails);

            BillingFlowParams billingFlowParams = BillingFlowParams.newBuilder()
                    .setSkuDetails(purchaseThis)
                    .build();
            billingClient.launchBillingFlow(activity, billingFlowParams);
        } catch (JSONException e) {
            debugMessage("JSONException during purchase: " + e.getMessage());
            throw new RuntimeException(e);
        }
    }

    public void consumePurchase(final String jsonPurchaseString) {
        debugMessage("Consuming purchase: " + jsonPurchaseString);
        try {
            JSONObject obj = new JSONObject(jsonPurchaseString);
            String purchaseToken = obj.getString("purchaseToken");

            ConsumeParams consumeParams = ConsumeParams.newBuilder()
                    .setPurchaseToken(purchaseToken)
                    .build();
            billingClient.consumeAsync(consumeParams, (billingResult, purchaseToken1) -> {
                debugMessage("onConsumeResponse called with response code: " + billingResult.getResponseCode());
                if (billingResult.getResponseCode() == BillingResponseCode.OK) {
                    purchaseConsumed(jsonPurchaseString);
                }
            });
        } catch (JSONException e) {
            debugMessage("JSONException during consumption: " + e.getMessage());
            throw new RuntimeException(e);
        }
    }
}
