import 'package:flutter/foundation.dart';
import '../models/entitlement.dart';
import 'entitlement_service.dart';

/// Skeleton billing adapter for future payment integration.
///
/// All methods are stubs that return success states in development.
/// When a real billing provider is integrated (RevenueCat, Stripe, etc.),
/// replace the stub implementations with actual SDK calls.
///
/// The adapter's job is to:
/// 1. Initiate purchases and restore previous purchases
/// 2. Handle webhook/callback confirmations from the payment provider
/// 3. Map provider-specific product IDs to our PlanTier enum
/// 4. Persist the Entitlement after successful verification
class BillingAdapter {
  final EntitlementService _entitlementService;

  BillingAdapter(this._entitlementService);

  /// Map from payment provider product IDs to our plan tiers.
  static const Map<String, PlanTier> _productTierMap = {
    'coverwise_plus_monthly': PlanTier.plus,
    'coverwise_plus_yearly': PlanTier.plus,
    'coverwise_family_monthly': PlanTier.family,
    'coverwise_family_yearly': PlanTier.family,
  };

  /// Initialize the billing SDK. Call once at app startup.
  Future<void> initialize() async {
    // TODO: Initialize RevenueCat / Stripe / Google Play Billing
    debugPrint('BillingAdapter: initialized (stub)');
  }

  /// Attempt to purchase a plan upgrade.
  ///
  /// Returns the upgraded Entitlement on success, or null if the user
  /// cancelled or the purchase failed.
  Future<Entitlement?> purchasePlan(PlanTier tier, {bool annual = false}) async {
    // TODO: Initiate real purchase flow
    // In development, simulate a successful purchase
    final expiresAt = DateTime.now().add(Duration(
      days: annual ? 365 : 30,
    ));

    await _entitlementService.setPlan(tier, expiresAt: expiresAt);
    debugPrint('BillingAdapter: purchased ${tier.name} (annual=$annual)');

    return _entitlementService.current();
  }

  /// Restore previous purchases after app reinstall or device change.
  ///
  /// Checks with the payment provider for any active subscriptions
  /// and updates the local entitlement accordingly.
  Future<Entitlement?> restorePurchases() async {
    // TODO: Call RevenueCat.restorePurchases() or equivalent
    debugPrint('BillingAdapter: restorePurchases (stub)');
    return _entitlementService.current();
  }

  /// Open the platform's subscription management UI.
  ///
  /// On iOS this opens App Store subscriptions; on Android it opens
  /// Google Play subscriptions. Returns true if the user managed their
  /// subscription (they may have cancelled).
  Future<bool> manageSubscription() async {
    // TODO: Launch platform subscription management
    debugPrint('BillingAdapter: manageSubscription (stub)');
    return false;
  }

  /// Handle a webhook or callback confirmation from the payment provider.
  ///
  /// Call this when your backend receives a payment confirmation webhook.
  /// It verifies the receipt and updates the local entitlement.
  Future<Entitlement?> handlePaymentConfirmation({
    required String productId,
    required DateTime expiresAt,
    String? receiptId,
  }) async {
    final tier = _productTierMap[productId];
    if (tier == null) {
      debugPrint('BillingAdapter: unknown product ID: $productId');
      return null;
    }

    await _entitlementService.setPlan(tier, expiresAt: expiresAt);
    debugPrint('BillingAdapter: confirmed $productId, expires: $expiresAt');

    return _entitlementService.current();
  }

  /// Check if a product is available for purchase on this device.
  Future<bool> isProductAvailable(String productId) async {
    // TODO: Check with payment provider if product is available
    return _productTierMap.containsKey(productId);
  }
}
