import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/entitlement.dart';
import '../models/qa_pack.dart';
import 'analytics_service.dart';
import 'document_service.dart';
import 'entitlement_service.dart';

/// Billing adapter backed by RevenueCat.
///
/// Maps RevenueCat offerings/entitlements to our PlanTier / QaPackType enums.
/// The adapter's job is to:
/// 1. Initiate purchases and restore previous purchases
/// 2. Sync entitlement state from RevenueCat to our EntitlementService
/// 3. Map provider-specific product IDs to our PlanTier / QaPackType enums
///
/// RevenueCat handles store receipt validation and subscription management.
/// The server ledger verifies consumable grants and is authoritative for Q&A;
/// EntitlementService is only a local mirror for responsive UI.
class BillingAdapter {
  final EntitlementService _entitlementService;
  static bool _initialized = false;

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
    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = Supabase.instance.client.auth.currentUser?.id;
    await Purchases.configure(configuration);
    _initialized = true;
    debugPrint('BillingAdapter: RevenueCat initialized');
  }

  /// Associate RevenueCat with the durable CoverWise account after a guest
  /// converts. RevenueCat aliases the prior store customer where possible,
  /// preserving purchases while the backend uses the Supabase account UID.
  Future<void> identifyAccount(String accountId) async {
    if (!_initialized || accountId.isEmpty) return;
    try {
      final currentId = await Purchases.appUserID;
      if (currentId != accountId) {
        final result = await Purchases.logIn(accountId);
        await _applyCustomerInfo(result.customerInfo);
      }
      await syncEntitlement();
    } catch (e) {
      debugPrint('BillingAdapter: account identity sync deferred: $e');
    }
  }

  /// Detach the store customer from the signed-out account.
  ///
  /// RevenueCat maintains its own customer identity independently of Hive;
  /// resetting local entitlement state without logging out here could carry
  /// account A's purchases into a guest or account B session.
  Future<void> clearAccountIdentity() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
      debugPrint('BillingAdapter: RevenueCat identity reset after sign-out');
    } catch (e) {
      // Do not block local workspace isolation, but leave an observable
      // diagnostic for the operator/runtime review.
      debugPrint('BillingAdapter: RevenueCat identity reset deferred: $e');
    }
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
      await _syncServerEntitlement(customerInfo);
      await _syncServerPackBalance();
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
        // expirationDate is String? in this SDK version; parse safely.
        final rawExpiry = revenueCatEntitlement.expirationDate;
        final expiresAt =
            rawExpiry != null ? DateTime.tryParse(rawExpiry.toString()) : null;
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

  Future<void> _syncServerEntitlement(CustomerInfo customerInfo) async {
    final entitlement = _entitlementService.current();
    final productId = customerInfo.activeSubscriptions.isNotEmpty
        ? customerInfo.activeSubscriptions.first
        : null;
    final active = entitlement.planTier != PlanTier.free;
    try {
      final appUserId = await Purchases.appUserID;
      await DocumentService.authenticatedDio.post(
        AppConfig.subscriptionSyncEndpoint.replaceFirst(AppConfig.baseUrl, ''),
        data: {
          'plan_tier': entitlement.planTier.name,
          'product_id': productId,
          'expires_at': customerInfo.latestExpirationDate,
          'is_active': active,
          'revenuecat_app_user_id': appUserId,
        },
      );
      AnalyticsService.track('subscription_state_synced', {
        'plan_tier': entitlement.planTier.name,
        'is_active': active,
      });
    } catch (e) {
      // Billing remains usable offline, but the server must retry the next
      // startup/purchase so operator and entitlement records converge.
      debugPrint('BillingAdapter: server entitlement sync deferred: $e');
    }
  }

  /// Reconcile consumable packs from the server-owned ledger.
  ///
  /// A successful empty response is meaningful and clears stale local packs.
  /// A failed or unverified response leaves the mirror untouched so a
  /// temporary outage cannot erase a user's locally visible history.
  Future<bool> _syncServerPackBalance() async {
    try {
      final response = await DocumentService.authenticatedDio.get(
        AppConfig.qaPackBalanceEndpoint.replaceFirst(AppConfig.baseUrl, ''),
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map || data['verified'] != true) {
        debugPrint('BillingAdapter: server pack balance is not verified');
        return false;
      }

      final rawPacks = data['packs'];
      if (rawPacks is! List) return false;
      final packs = <QaPack>[];
      for (final raw in rawPacks) {
        if (raw is! Map) continue;
        final productId = raw['product_id']?.toString();
        final type = productId == null ? null : _packProductMap[productId];
        final remaining = raw['questions_remaining'];
        final purchasedAt = DateTime.tryParse(raw['purchased_at']?.toString() ?? '');
        final expiresAt = DateTime.tryParse(raw['expires_at']?.toString() ?? '');
        if (type == null || remaining is! num || purchasedAt == null || expiresAt == null) {
          debugPrint('BillingAdapter: skipped malformed server pack grant');
          continue;
        }
        final boundedRemaining = remaining.toInt().clamp(0, type.questionCount);
        if (boundedRemaining == 0 || !expiresAt.isAfter(DateTime.now())) continue;
        packs.add(QaPack(
          type: type,
          questionsRemaining: boundedRemaining,
          purchasedAt: purchasedAt,
          expiresAt: expiresAt,
        ));
      }
      await _entitlementService.replacePacks(packs);
      AnalyticsService.track('qa_pack_balance_reconciled', {
        'pack_count': packs.length,
        'questions_remaining': packs.fold<int>(
          0,
          (sum, pack) => sum + pack.questionsRemaining,
        ),
      });
      return true;
    } catch (e) {
      debugPrint('BillingAdapter: server pack balance sync deferred: $e');
      return false;
    }
  }

  // ── Subscription purchases ────────────────────────────────────────

  /// Attempt to purchase a plan upgrade.
  ///
  /// Returns the updated Entitlement on success, or null if the user
  /// cancelled or the purchase failed.
  Future<Entitlement?> purchasePlan(PlanTier tier,
      {bool annual = false}) async {
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
      final result = await Purchases.purchase(PurchaseParams.package(package));
      await _applyCustomerInfo(result.customerInfo);
      await _syncServerEntitlement(result.customerInfo);

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

      await Purchases.purchase(PurchaseParams.package(package));

      // Store completion is not a server grant. The webhook may still be
      // queued, so only a verified readback may add the local mirror.
      final reconciled = await _syncServerPackBalance();
      debugPrint(
        'BillingAdapter: purchased ${pack.name} pack; '
        'server_reconciled=$reconciled',
      );
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
      await _syncServerPackBalance();
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
      // Platform-specific subscription management URLs.
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final uri = Uri.parse(
        isIOS
            ? 'https://apps.apple.com/account/subscriptions'
            : 'https://play.google.com/store/account/subscriptions',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('BillingAdapter: opened subscription management');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('BillingAdapter: manageSubscription failed: $e');
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
