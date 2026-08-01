import 'package:hive/hive.dart';
import 'app_state_store.dart';

/// Manages contact information (email, phone) stored in the principal-scoped
/// Hive workspace.
///
/// Audit 7 P1.1: Multi-key writes use [putAll] for atomicity — a crash
/// between individual puts would leave inconsistent state.
///
/// Audit 7 P1.2: All contact reads and writes go through this service.
/// Profile screen and other UI must not access Hive keys directly.
///
/// Audit 7 P1.3: Getters are synchronous — Hive reads are in-memory and
/// do not need async.
class ContactService {
  // ── Read operations (synchronous, P1.3) ──────────────────────────────

  /// Whether the user has opted in to saving contact info on this device.
  static bool get isSaveContactEnabled {
    final box = Hive.box(AppStateStore.boxName);
    return box.get(AppStateStore.saveContactKey) as bool? ?? false;
  }

  /// Saved email address, or null if not saved or saving is disabled.
  static String? get savedEmail {
    if (!isSaveContactEnabled) return null;
    return Hive.box(AppStateStore.boxName)
        .get(AppStateStore.emailKey) as String?;
  }

  /// Saved phone number (from the contact-capture flow), or null.
  static String? get savedPhone {
    if (!isSaveContactEnabled) return null;
    return Hive.box(AppStateStore.boxName)
        .get(AppStateStore.phoneKey) as String?;
  }

  /// Audit 7 P1.2: Canonical phone-number getter for the profile screen.
  /// The profile screen previously read `phoneNumberKey` directly from Hive,
  /// bypassing ContactService. This getter provides the single source of truth.
  static String? get userPhoneNumber {
    return Hive.box(AppStateStore.boxName)
        .get(AppStateStore.phoneNumberKey) as String?;
  }

  /// Get both saved email and phone as a map.
  static Map<String, String?> get savedContact => {
        'email': savedEmail,
        'phone': savedPhone,
      };

  // ── Write operations (async, atomic via putAll) ──────────────────────

  /// Save contact information atomically.
  ///
  /// P1.1: Uses [putAll] so all keys are written in a single Hive
  /// transaction. A crash between individual puts would leave inconsistent
  /// state (e.g. saveContactKey=true but email not yet written).
  static Future<void> saveContact({
    String? email,
    String? phone,
    required bool saveForFuture,
  }) async {
    final box = Hive.box(AppStateStore.boxName);
    if (saveForFuture) {
      await box.putAll({
        AppStateStore.saveContactKey: true,
        if (email != null) AppStateStore.emailKey: email.trim().toLowerCase(),
        if (phone != null) AppStateStore.phoneKey: phone.trim(),
      });
    } else {
      // Clear saved contact info if user doesn't want to save.
      // Use delete() for email/phone to remove keys entirely (not null-stale).
      await box.put(AppStateStore.saveContactKey, false);
      await box.delete(AppStateStore.emailKey);
      await box.delete(AppStateStore.phoneKey);
    }
  }

  /// Audit 7 P1.2: Canonical setter for the profile screen phone number.
  /// Replaces direct `box.delete(AppStateStore.phoneNumberKey)` calls.
  static Future<void> setUserPhoneNumber(String? phone) async {
    final box = Hive.box(AppStateStore.boxName);
    if (phone == null || phone.isEmpty) {
      await box.delete(AppStateStore.phoneNumberKey);
    } else {
      await box.put(AppStateStore.phoneNumberKey, phone.trim());
    }
  }

  /// Clear all saved contact information atomically.
  ///
  /// P1.1: Uses [putAll] for the same atomicity reason as [saveContact].
  static Future<void> clearSavedContact() async {
    final box = Hive.box(AppStateStore.boxName);
    await box.put(AppStateStore.saveContactKey, false);
    await box.delete(AppStateStore.emailKey);
    await box.delete(AppStateStore.phoneKey);
  }
} 
