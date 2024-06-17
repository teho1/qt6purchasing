package com.climbsmart.crimptronic;

import android.app.Activity;
import android.content.Context;

import com.android.billingclient.api.*;
import com.android.billingclient.api.BillingClient.BillingResponseCode;
import com.android.billingclient.api.SkuDetailsParams.Builder;
import com.android.billingclient.api.BillingClient.SkuType;

import java.util.ArrayList;
import java.util.List;

import org.json.JSONException;
import org.json.JSONObject;

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
    private PurchasesResponseListener purchasesResponseListener;
    private BillingClient billingClient;

    public GooglePlayBilling(Context cnt) {
        this.context = cnt;

        purchasesUpdatedListener = new PurchasesUpdatedListener() {
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

        purchasesResponseListener = new PurchasesResponseListener() {
            @Override
            public void onQueryPurchasesResponse(BillingResult billingResult, List<Purchase> purchases) {
                debugMessage("onQueryPurchasesResponse called with response code: " + billingResult.getResponseCode());
                if (!purchases.isEmpty()) {
                    debugMessage("Restoring purchases");
                    for (Purchase purchase : purchases) {
                        debugMessage("Restoring purchase: " + purchase.getOriginalJson());
                        purchaseRestored(purchase.getOriginalJson());
                    }
                } else {
                    debugMessage("No purchases to restore");
                }
            }
        };

        billingClient = BillingClient.newBuilder(this.context)
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
        billingClient.queryPurchasesAsync(SkuType.SUBS, purchasesResponseListener);
    }

    public void registerProduct(final String productId) {
        debugMessage("Registering product with ID: " + productId);
        List<String> skuList = new ArrayList<>();
        skuList.add(productId);
        SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder();
        params.setSkusList(skuList).setType(SkuType.SUBS);
        debugMessage("SkuDetailsParams: " + params.build().toString());
        billingClient.querySkuDetailsAsync(params.build(),
            new SkuDetailsResponseListener() {
                @Override
                public void onSkuDetailsResponse(BillingResult billingResult, List<SkuDetails> skuDetailsList) {
                  debugMessage("onSkuDetailsResponse called with response code: " + billingResult.getResponseCode());
                  if (skuDetailsList == null) {
                      debugMessage("skuDetailsList is null");
                      return;
                  }
                  if (skuDetailsList.isEmpty()) {
                      debugMessage("skuDetailsList is empty");
                      return;
                  }

                  debugMessage("skuDetailsList size: " + skuDetailsList.size());
                  for (SkuDetails skuDetails : skuDetailsList) {
                      debugMessage("SKU Details: " + skuDetails.getOriginalJson());
                  }

                  billingResponseReceived(billingResult.getResponseCode());
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
            int responseCode = billingClient.launchBillingFlow(activity, billingFlowParams).getResponseCode();
            debugMessage("Billing flow launched with response code: " + responseCode);
        } catch (JSONException e) {
            debugMessage("JSONException during purchase: " + e.getMessage());
            throw new RuntimeException(e);
        }
    }

    public void consumePurchase(final String jsonPurchaseString) {
        debugMessage("Consuming purchase: " + jsonPurchaseString);
        ConsumeResponseListener listener = new ConsumeResponseListener() {
            @Override
            public void onConsumeResponse (BillingResult billingResult, String purchaseToken) {
                debugMessage("onConsumeResponse called with response code: " + billingResult.getResponseCode());
                if (billingResult.getResponseCode() == BillingResponseCode.OK) {
                    purchaseConsumed(jsonPurchaseString);
                }
            }
        };

        try {
            JSONObject obj = new JSONObject(jsonPurchaseString);
            String purchaseToken = obj.getString("purchaseToken");

            ConsumeParams consumeParams = ConsumeParams.newBuilder()
                .setPurchaseToken(purchaseToken)
                .build();

            billingClient.consumeAsync(consumeParams, listener);

        } catch (JSONException e) {
            debugMessage("JSONException during consumption: " + e.getMessage());
            throw new RuntimeException(e);
        }
    }
}
