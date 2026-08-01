import 'package:hive/hive.dart';
import 'consent_ledger.dart';
import '../config/app_config.dart';
import '../domain/contact/contact_validator.dart';

/// Manages newsletter subscription state on-device.
///
/// The service stores the subscriber's email in a dedicated Hive box and
/// records consent through [ConsentLedger] with the `marketingEmails`
/// purpose. No network call is made — emails are not sent to any server.
/// A future integration (e.g., a backend email endpoint) can read the
/// stored email and consent status when ready.
class NewsletterService {
  static const String _boxName = 'newsletter';

  Box<dynamic>? get _box {
    try {
      return Hive.box<dynamic>(_boxName);
    } catch (_) {
      return null;
    }
  }

  /// The Hive key used to persist the subscribed email.
  static const String _emailKey = 'subscribed_email';

  /// The Hive key used to track whether the subscriber has explicitly opted in.
  static const String _optedInKey = 'has_opted_in';

  /// Subscribe an email address to the newsletter.
  ///
  /// Audit 7 P0.9: Records consent BEFORE persisting the email. If consent
  /// write fails (e.g. box unavailable), the email is NOT saved — preventing
  /// a state where email exists but no consent trail exists.
  ///
  /// Audit 7 P0.8: The newsletter Hive box is now in
  /// [HiveWorkspaceService.boxNames] so it is properly opened with the
  /// workspace. Previously every write was a silent no-op because the box
  /// was never opened.
  ///
  /// Returns `true` on success, `false` if email is invalid, box is
  /// unavailable, or consent write fails.
  Future<bool> subscribe(String email) async {
    if (!ContactValidator.isValidEmail(email)) return false;

    // Fail fast if the Hive box is not open. Without this check,
    // _box?.put() silently succeeds (returns null) and subscribe()
    // returns true despite nothing being persisted — a false-completion
    // claim that Audit 7 P0.8 flagged.
    if (_box == null) return false;

    try {
      // Audit 7 P0.9: Record consent FIRST. If consent write fails,
      // the email must NOT be persisted — otherwise email exists with
      // no consent trail, which is a privacy violation.
      final ledger = ConsentLedger();
      if (!ledger.hasConsent(ConsentPurpose.marketingEmails)) {
        await ledger.recordConsent(
          purpose: ConsentPurpose.marketingEmails,
          version: AppConfig.privacyPolicyVersion,
          granted: true,
        );
      }

      // Consent recorded successfully — now persist the email and opt-in flag.
      await _box!.put(_emailKey, email.trim().toLowerCase());
      await _box!.put(_optedInKey, true);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unsubscribe from the newsletter.
  ///
  /// Audit 7: Consistent null-box handling with [subscribe].
  Future<void> unsubscribe() async {
    if (_box == null) return;

    await _box!.delete(_emailKey);
    await _box!.delete(_optedInKey);

    final ledger = ConsentLedger();
    if (ledger.hasConsent(ConsentPurpose.marketingEmails)) {
      await ledger.revokeConsent(ConsentPurpose.marketingEmails);
    }
  }

  /// The currently subscribed email, or `null` if not subscribed.
  String? get subscribedEmail {
    final email = _box?.get(_emailKey) as String?;
    if (email == null || email.isEmpty) return null;
    return email;
  }

  /// Whether the user is currently subscribed.
  bool get isSubscribed {
    final optedIn = _box?.get(_optedInKey) as bool? ?? false;
    return optedIn && subscribedEmail != null;
  }
}
