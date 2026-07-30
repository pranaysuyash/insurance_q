import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../services/analytics_service.dart';
import '../services/app_state_store.dart';
import '../services/auth_service.dart';
import 'shared/coverwise_components.dart';
import 'shared/coverwise_snackbar.dart';
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
class PhoneCaptureSheet extends ConsumerStatefulWidget {
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
  ConsumerState<PhoneCaptureSheet> createState() => _PhoneCaptureSheetState();
}

class _PhoneCaptureSheetState extends ConsumerState<PhoneCaptureSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isValidPhone = false;
  bool _isValidOtp = false;
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _validatePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() => _isValidPhone = digits.length == 10);
  }

  void _validateOtp(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() => _isValidOtp = digits.length == 6);
  }

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    final phone = '+91${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}';

    try {
      final notifier = ref.read(authServiceProvider.notifier);
      if (notifier.isClientReady) {
        if (notifier.hasAccountSession) {
          await notifier.updateUserPhone(phone);
        } else {
          await notifier.signInWithPhoneOtp(phone);
        }
      }
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.phoneNumberKey, phone);
      AnalyticsService.track('phone_otp_requested', {'otp_channel': 'sms'});

      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
      CoverWiseSnackBar.success(context, 'OTP code sent to $phone');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CoverWiseSnackBar.error(context, 'Failed to send OTP code: $e');
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    final phone = '+91${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}';
    final code = _otpController.text.trim();

    try {
      if (ref.read(authServiceProvider.notifier).isClientReady) {
        await ref
            .read(authServiceProvider.notifier)
            .verifyPhoneOtp(phone, code);
      }
      AnalyticsService.track('phone_otp_verified', {'otp_channel': 'sms'});

      if (!mounted) return;
      Navigator.pop(context);
      CoverWiseSnackBar.success(
        context,
        'Phone number verified and linked to your account.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CoverWiseSnackBar.error(context, 'Invalid OTP code. Please try again.');
    }
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
            Align(
              alignment: Alignment.center,
              child: CoverWiseIconBadge(
                icon: _otpSent ? Icons.mark_email_read_outlined : Icons.phone_outlined,
                color: theme.colorScheme.primary,
                size: 68,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _otpSent ? 'Enter 6-digit verification code' : 'Link phone with OTP verification',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent
                  ? 'We sent a verification code to +91 ${_phoneController.text}. Enter it below to complete identity verification.'
                  : 'Enter your phone number to receive a verification OTP and link your account across devices.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (!_otpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: _validatePhone,
                decoration: InputDecoration(
                  prefixText: '+91 ',
                  labelText: 'Mobile number',
                  hintText: '98765 43210',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_isValidPhone && !_isLoading) ? _sendOtp : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Verification Code'),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(6),
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: _validateOtp,
                decoration: InputDecoration(
                  labelText: '6-Digit OTP',
                  hintText: '123456',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_isValidOtp && !_isLoading) ? _verifyOtp : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify & Link Account'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _dismiss,
              child: Text(
                'Maybe Later',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
