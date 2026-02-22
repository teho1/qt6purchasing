package com.climbsmart.crimptronic;

import android.app.Activity;
import android.content.Context;
import com.revenuecat.purchases.Purchases;
import com.revenuecat.purchases.PurchasesConfiguration;
import com.revenuecat.purchases.Offerings;
import com.revenuecat.purchases.Offering;
import com.revenuecat.purchases.Package;
import com.revenuecat.purchases.StoreProduct;
import com.revenuecat.purchases.interfaces.GetOfferingsCallback;
import com.revenuecat.purchases.interfaces.PurchaseCallback;
import com.revenuecat.purchases.models.StoreTransaction;
import com.revenuecat.purchases.models.CustomerInfo;
import com.revenuecat.purchases.PurchasesError;
import org.json.JSONObject;
import org.json.JSONException;

public class RevenueCatBilling {
    private static native void connectedChangedHelper(boolean connected);
    private static native void productRegistered(String productJson);
    private static native void purchaseSucceeded(String transactionJson);
    private static native void purchaseRestored(String transactionJson);
    private static native void purchaseFailed(int errorCode);
    private static native void purchaseConsumed(String transactionJson);

    private Activity activity;
    private boolean configured = false;

    public RevenueCatBilling(Activity activity) {
        this.activity = activity;
    }

    public void configure(String apiKey, String appUserID) {
        PurchasesConfiguration.Builder configBuilder = new PurchasesConfiguration.Builder(activity, apiKey);

        if (appUserID != null && !appUserID.isEmpty()) {
            configBuilder.appUserID(appUserID);
        }

        Purchases.configure(configBuilder.build());
        configured = true;

        // Test connection by fetching offerings
        Purchases.getSharedInstance().getOfferings(new GetOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                connectedChangedHelper(true);
            }

            @Override
            public void onError(PurchasesError error) {
                connectedChangedHelper(false);
            }
        });
    }

    public void startConnection() {
        if (!configured) {
            return;
        }

        Purchases.getSharedInstance().getOfferings(new GetOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                connectedChangedHelper(true);
            }

            @Override
            public void onError(PurchasesError error) {
                connectedChangedHelper(false);
            }
        });
    }

    public void registerProduct(String productIdentifier) {
        if (!configured) {
            return;
        }

        Purchases.getSharedInstance().getOfferings(new GetOfferingsCallback() {
            @Override
            public void onReceived(Offerings offerings) {
                Package foundPackage = null;

                // Search through all offerings
                for (Offering offering : offerings.getAll().values()) {
                    for (Package pkg : offering.getAvailablePackages()) {
                        if (pkg.getStoreProduct().getId().equals(productIdentifier)) {
                            foundPackage = pkg;
                            break;
                        }
                    }
                    if (foundPackage != null) break;
                }

                if (foundPackage != null) {
                    StoreProduct product = foundPackage.getStoreProduct();
                    try {
                        JSONObject json = new JSONObject();
                        json.put("productId", product.getId());
                        json.put("title", product.getTitle());
                        json.put("description", product.getDescription());
                        json.put("price", product.getPrice().getFormatted());
                        json.put("packageIdentifier", foundPackage.getIdentifier());
                        productRegistered(json.toString());
                    } catch (JSONException e) {
                        // Error creating JSON
                    }
                }
            }

            @Override
            public void onError(PurchasesError error) {
                // Product not found or error
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

        Purchases.getSharedInstance().getOfferings(new GetOfferingsCallback() {
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
                            if (pkg.getStoreProduct().getId().equals(productIdentifier)) {
                                packageToPurchase = pkg;
                                break;
                            }
                        }
                        if (packageToPurchase != null) break;
                    }
                }

                if (packageToPurchase == null) {
                    purchaseFailed(-2);
                    return;
                }

                Purchases.getSharedInstance().purchase(
                    new com.revenuecat.purchases.PurchaseParams.Builder(activity, packageToPurchase).build(),
                    new PurchaseCallback() {
                        @Override
                        public void onCompleted(StoreTransaction storeTransaction, CustomerInfo customerInfo) {
                            try {
                                JSONObject json = new JSONObject();
                                json.put("orderId", storeTransaction.getTransactionIdentifier());
                                json.put("productId", storeTransaction.getProductIdentifier());
                                purchaseSucceeded(json.toString());
                            } catch (JSONException e) {
                                purchaseFailed(-3);
                            }
                        }

                        @Override
                        public void onError(PurchasesError error, boolean userCancelled) {
                            if (userCancelled) {
                                purchaseFailed(1); // User cancelled
                            } else {
                                purchaseFailed(error.getCode());
                            }
                        }
                    }
                );
            }

            @Override
            public void onError(PurchasesError error) {
                purchaseFailed(error.getCode());
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
                for (String productId : customerInfo.getAllPurchasedProductIdentifiers()) {
                    try {
                        JSONObject json = new JSONObject();
                        json.put("orderId", "restored_" + productId);
                        json.put("productId", productId);
                        purchaseRestored(json.toString());
                    } catch (JSONException e) {
                        // Error creating JSON
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
