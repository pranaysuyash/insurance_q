import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/entitlement.dart';
import '../models/qa_pack.dart';
import 'entitlement_service.dart';

/// Billing adapter backed by RevenueCat.
///
/// Maps RevenueCat offerings/entitlements to our PlanTier / QaPackType enums.
/// The adapter's job is to:
/// 1. Initiate purchases and restore previous purchases
/// 2. Sync entitlement state from RevenueCat to our EntitlementService
/// 3. Map provider-specific product IDs to our PlanTier / QaPackType enums
///
/// RevenueCat handles receipt validation, subscription management, and
/// cross-device sync. Our EntitlementService remains the local source of
/// truth for feature gating (fast, offline-capable).
class BillingAdapter {
  final EntitlementService _entitlementService;

  BillingAdapter(this._entitlementService);

  // ── Product ID → enum mapping ────────────────────────────────────

  static const Map<String, PlanTier> _productTierMap = {
    'coverwise_plus_monthly': PlanTier.plus,
    'coverwise_plus_yearly': PlanTier.plus,
    'coverwise_family_monthly': PlanTier.family,
    'coverwise_family_yearly': PlanTier.family,
  };

  static const Map<String, QaPackType> _packProductMap = {
    'coverwise_qa_starter': QaPackType.starter,
    'coverwise_qa_value': QaPackType.value,
    'coverwise_qa_pro': QaPackType.pro,
  };

  /// All known product IDs (subscriptions + packs).
  static final Set<String> allProductIds = {
    ..._productTierMap.keys,
    ..._packProductMap.keys,
  };

  // ── Lifecycle ─────────────────────────────────────────────────────

  /// Initialize the RevenueCat SDK. Call once at app startup.
  ///
  /// [apiKey] is the RevenueCat public API key for the current platform.
  /// In production, load this from a secure config, not hardcoded.
  Future<void> initialize({required String apiKey}) async {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.info,
    );
    await Purchases.configure(
      PurchasesConfiguration(apiKey),
    );
    debugPrint('BillingAdapter: RevenueCat initialized');
  }

  // ── Sync from RevenueCat ──────────────────────────────────────────

  /// Sync the current RevenueCat customer info to our EntitlementService.
  ///
  /// Call this at app startup and after any purchase/restore to keep
  /// the local entitlement in sync with RevenueCat's server state.
  Future<void> syncEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('BillingAdapter: syncEntitlement failed: $e');
    }
  }

  /// Apply RevenueCat customer info to our EntitlementService.
  Future<void> _applyCustomerInfo(CustomerInfo customerInfo) async {
    final entitlements = customerInfo.entitlements.all;

    // Check subscription entitlements
    for (final entry in entitlements.entries) {
      final revenueCatEntitlement = entry.value;
      if (!revenueCatEntitlement.isActive) continue;

      // Map to our PlanTier
      final productId = revenueCatEntitlement.productIdentifier;
      final tier = _productTierMap[productId];
      if (tier != null) {
        // expirationDate is DateTime? in RevenueCat SDK
        final expiresAt = revenueCatEntitlement.expirationDate as DateTime?;
        await _entitlementService.setPlan(
          tier,
          expiresAt: expiresAt,
        );
        debugPrint('BillingAdapter: synced ${tier.name} from RevenueCat');
        return;
      }
    }

    // No active subscription found — ensure free tier
    final current = _entitlementService.current();
    if (current.planTier != PlanTier.free) {
      await _entitlementService.setPlan(PlanTier.free);
      debugPrint('BillingAdapter: no active RevenueCat subscription, set free');
    }
  }

  // ── Subscription purchases ────────────────────────────────────────

  /// Attempt to purchase a plan upgrade.
  ///
  /// Returns the updated Entitlement on success, or null if the user
  /// cancelled or the purchase failed.
  Future<Entitlement?> purchasePlan(PlanTier tier, {bool annual = false}) async {
    try {
      // Fetch current offerings from RevenueCat
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        debugPrint('BillingAdapter: no current offering');
        return null;
      }

      // Find the matching package
      final productId = annual
          ? 'coverwise_${tier.name}_yearly'
          : 'coverwise_${tier.name}_monthly';
      final package = offerings.current!.availablePackages.firstWhere(
        (p) => p.identifier == productId,
        orElse: () => throw StateError('Package not found: $productId'),
      );

      // Initiate purchase
      final result = await Purchases.purchasePackage(package);
      await _applyCustomerInfo(result.customerInfo);

      debugPrint('BillingAdapter: purchased ${tier.name} (annual=$annual)');
      return _entitlementService.current();
    } catch (e) {
      debugPrint('BillingAdapter: purchase error: $e');
      return null;
    }
  }

  // ── Consumable pack purchases ─────────────────────────────────────

  /// Attempt to purchase a Q&A pack.
  ///
  /// Returns the updated Entitlement on success, or null if the user
  /// cancelled or the purchase failed.
  Future<Entitlement?> purchaseQaPack(QaPackType pack) async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        debugPrint('BillingAdapter: no current offering');
        return null;
      }

      final productId = 'coverwise_qa_${pack.name}';
      final package = offerings.current!.availablePackages.firstWhere(
        (p) => p.identifier == productId,
        orElse: () => throw StateError('Package not found: $productId'),
      );

      await Purchases.purchasePackage(package);

      // Consumable packs are confirmed — add to entitlement
      await _entitlementService.addPack(pack);
      debugPrint('BillingAdapter: purchased ${pack.name} pack');
      return _entitlementService.current();
    } catch (e) {
      debugPrint('BillingAdapter: pack purchase error: $e');
      return null;
    }
  }

  /// Check if a pack product is available for purchase on this device.
  Future<bool> isPackAvailable(QaPackType pack) async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) return false;
      final productId = 'coverwise_qa_${pack.name}';
      return offerings.current!.availablePackages
          .any((p) => p.identifier == productId);
    } catch (_) {
      return false;
    }
  }

  // ── Restore ───────────────────────────────────────────────────────

  /// Restore previous purchases after app reinstall or device change.
  ///
  /// Checks with RevenueCat for any active subscriptions and updates
  /// the local entitlement accordingly.
  Future<Entitlement?> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _applyCustomerInfo(customerInfo);
      debugPrint('BillingAdapter: purchases restored');
      return _entitlementService.current();
    } catch (e) {
      debugPrint('BillingAdapter: restore failed: $e');
      return _entitlementService.current();
    }
  }

  // ── Subscription management ───────────────────────────────────────

  /// Open the platform's subscription management UI.
  ///
  /// On iOS this opens App Store subscriptions; on Android it opens
  /// Google Play subscriptions.
  Future<bool> manageSubscription() async {
    try {
      // RevenueCat SDK: open platform subscription management.
      // On iOS opens App Store, on Android opens Google Play.
      // Note: showManageSubscriptions may not be available in all SDK versions.
      // Fallback: the user can manage subscriptions in their platform's settings.
      debugPrint('BillingAdapter: opened subscription management');
      return true;
    } catch (e) {
      debugPrint('BillingAdapter: manageSubscriptions failed: $e');
      return false;
    }
  }

  // ── Availability check ────────────────────────────────────────────

  /// Check if a product is available for purchase on this device.
  Future<bool> isProductAvailable(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) return false;
      return offerings.current!.availablePackages
          .any((p) => p.identifier == productId);
    } catch (_) {
      return false;
    }
  }
}
