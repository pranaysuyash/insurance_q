import 'package:hive/hive.dart';
import 'consent_ledger.dart';
import '../config/app_config.dart';

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
  /// Records consent via [ConsentLedger] with `ConsentPurpose.marketingEmails`
  /// and persists the email locally. Returns `true` on success.
  Future<bool> subscribe(String email) async {
    if (!AppConfig.isValidEmail(email)) return false;

    try {
      await _box?.put(_emailKey, email.trim().toLowerCase());
      await _box?.put(_optedInKey, true);

      final ledger = ConsentLedger();
      if (!ledger.hasConsent(ConsentPurpose.marketingEmails)) {
        await ledger.recordConsent(
          purpose: ConsentPurpose.marketingEmails,
          version: AppConfig.privacyPolicyVersion,
          granted: true,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unsubscribe from the newsletter.
  Future<void> unsubscribe() async {
    await _box?.delete(_emailKey);
    await _box?.delete(_optedInKey);

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
