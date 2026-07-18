import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/analytics_service.dart';
import '../services/app_state_store.dart';
import 'shared/coverwise_components.dart';
import '../theme/coverwise_motion.dart';

/// Progressive phone-number capture, shown as a bottom sheet AFTER the user
/// has uploaded their first policy and received value.
///
/// Design principles:
/// - Never blocking — "Maybe Later" is always prominent
/// - Honest framing (security audit P0-13, 2026-07-18): the phone number
///   is stored only on this device. It does NOT enable cross-device
///   access, automatic backup, or account identification until a
///   verified account/restore contract exists. Treating it as such
///   was a false claim that the security audit explicitly flagged.
/// - Smart re-prompt — ask after 1st upload, then 2nd, then stop
/// - Analytics at every step
///
/// Call [maybeShow] after a successful upload. It handles the re-prompt logic.
class PhoneCaptureSheet extends StatefulWidget {
  const PhoneCaptureSheet({super.key});

  /// Shows the phone capture sheet if the re-prompt logic allows.
  /// Call this after a successful document upload.
  static Future<void> maybeShow(BuildContext context) async {
    final box = Hive.box(AppStateStore.boxName);

    // Already linked? Don't show.
    final existingPhone = box.get(AppStateStore.phoneNumberKey) as String?;
    if (existingPhone != null && existingPhone.isNotEmpty) return;

    // Check re-prompt count
    final promptCount = box.get(AppStateStore.phonePromptCountKey) as int? ?? 0;
    if (promptCount >= 2) return; // Stop after 2 asks

    // Increment count
    await box.put(AppStateStore.phonePromptCountKey, promptCount + 1);

    if (!context.mounted) return;

    AnalyticsService.track(
        'phone_capture_shown', {'prompt_number': promptCount + 1});

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PhoneCaptureSheet(),
    );
  }

  @override
  State<PhoneCaptureSheet> createState() => _PhoneCaptureSheetState();
}

class _PhoneCaptureSheetState extends State<PhoneCaptureSheet> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() => _isValid = digits.length == 10);
  }

  Future<void> _save() async {
    final phone = '+91${_controller.text.replaceAll(RegExp(r'[^0-9]'), '')}';
    final box = Hive.box(AppStateStore.boxName);
    await box.put(AppStateStore.phoneNumberKey, phone);
    AnalyticsService.track(
        'phone_capture_completed', {'method': 'manual_entry'});
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        // Security audit P0-13: honest copy. The phone number is
        // stored only on this device and is not used to identify an
        // account, enable cross-device access, or back up policies
        // until a verified account/restore contract exists.
        content: Text('Phone number saved on this device only.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _dismiss() {
    AnalyticsService.track('phone_capture_dismissed');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedPadding(
      duration: CoverWiseMotion.duration(context, CoverWiseMotion.quick),
      curve: CoverWiseMotion.enterCurve,
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Align(
              alignment: Alignment.center,
              child: CoverWiseIconBadge(
                icon: Icons.phone_outlined,
                color: theme.colorScheme.primary,
                size: 68,
              ),
            ),
            const SizedBox(height: 16),
            // Title — security audit P0-13: honest. No "never lose",
            // no "access from any device". This is a local-only
            // preference.
            const Text(
              'Save your number on this device',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Body — security audit P0-13: explicit "stays on this
            // device", no claim about cross-device access or
            // automatic backup.
            Text(
              'CoverWise will store your number locally so you can quickly '
              'check policies you have on this device. It does not enable '
              'cross-device sync, automatic backup, or account recovery. '
              'Those features are not available yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Phone input
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.digitsOnly
              ],
              onChanged: _validate,
              decoration: InputDecoration(
                prefixText: '+91 ',
                labelText: 'Mobile number',
                hintText: '98765 43210',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            // Save button — security audit P0-13: honest label
            FilledButton(
              onPressed: _isValid ? _save : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save on this device',
                  style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            // Maybe Later
            TextButton(
              onPressed: _dismiss,
              child: Text(
                'Maybe later',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            // Privacy note — security audit P0-13: no "we'll use this
            // to identify your account" claim; no "no spam, no sharing"
            // until the underlying contract supports it.
            Text(
              'Stored only on this device. Not shared with servers, '
              'insurers, or third parties. You can clear it from the '
              'privacy screen at any time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
