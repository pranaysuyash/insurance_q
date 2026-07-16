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
/// - Value exchange framing — "access from any device", not "create account"
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
        content: Text('Phone number linked. Your policies are now backed up.'),
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
                icon: Icons.phonelink_lock_outlined,
                color: theme.colorScheme.primary,
                size: 68,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            const Text(
              'Never lose your policies',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Body
            Text(
              'Your policy is saved on this device. Add your number to access '
              'it from any device and back it up automatically.',
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
            // Save button
            FilledButton(
              onPressed: _isValid ? _save : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Link Number', style: TextStyle(fontSize: 16)),
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
            // Privacy note
            Text(
              'We\'ll use this number only to identify your account. No spam, no sharing.',
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
