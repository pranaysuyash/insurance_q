import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../domain/contact/contact_validator.dart';
import '../services/consent_ledger.dart';
import 'shared/coverwise_components.dart';

class LeadCaptureDialog extends StatefulWidget {
  final String? initialEmail;
  final String? initialPhone;
  final bool isRequired;

  const LeadCaptureDialog({
    super.key,
    this.initialEmail,
    this.initialPhone,
    this.isRequired = false,
  });

  @override
  State<LeadCaptureDialog> createState() => _LeadCaptureDialogState();
}

class _LeadCaptureDialogState extends State<LeadCaptureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saveForFuture = false;
  bool _processingConsent = false;
  String? _consentError;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
    _phoneController.text = widget.initialPhone ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (widget.isRequired && (value == null || value.isEmpty)) {
      return 'Email is required';
    }
    if (value != null && value.isNotEmpty) {
      if (!ContactValidator.isValidEmail(value)) {
        if (ContactValidator.isDisposableEmail(value)) {
          return 'Disposable email addresses are not allowed';
        }
        return 'Please enter a valid email address';
      }
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!ContactValidator.isValidPhone(value)) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      scrollable: true,
      title: Row(
        children: [
          CoverWiseIconBadge(
            icon: Icons.privacy_tip_outlined,
            color: scheme.primary,
            size: 42,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Policy processing permission')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isRequired)
              const Text(
                'CoverWise needs your permission to store and analyze this policy. Contact details are optional; how they are handled is described in the Privacy Policy.',
                style: TextStyle(fontSize: 14),
              )
            else
              const Text(
                'Please provide your contact information to continue.',
                style: TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'your.email@example.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                hintText: '+1 (555) 123-4567',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('I agree to policy processing'),
              subtitle: TextButton(
                onPressed: AppConfig.hasPrivacyPolicy
                    ? () => launchUrl(
                          Uri.parse(AppConfig.privacyPolicyUrl),
                          mode: LaunchMode.externalApplication,
                        )
                    : null,
                child: const Text('Review the current Privacy Policy'),
              ),
              value: _processingConsent,
              onChanged: (value) => setState(() {
                _processingConsent = value ?? false;
                _consentError = null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_consentError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_consentError!,
                    style: TextStyle(color: scheme.error, fontSize: 12)),
              ),
            CheckboxListTile(
              title: const Text(
                'Save on this device for future uploads',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Your contact details are not sent with this policy upload',
                style: TextStyle(fontSize: 12),
              ),
              value: _saveForFuture,
              onChanged: (value) {
                setState(() {
                  _saveForFuture = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        if (!widget.isRequired)
          TextButton(
            onPressed: () async {
              if (!_processingConsent) {
                setState(() => _consentError =
                    'Accept the Privacy Policy to process this policy.');
                return;
              }
              // 7-P0.18: Await consent write before returning.
              final ledger = ConsentLedger();
              await ledger.recordConsent(
                purpose: ConsentPurpose.documentProcessing,
                version: AppConfig.privacyPolicyVersion,
                granted: true,
              );
              if (!mounted) return;
              Navigator.of(context).pop({
                'email': null,
                'phone': null,
                'save': false,
                'processing_consent': true,
                'processing_consent_version': AppConfig.privacyPolicyVersion,
              });
            },
            child: const Text('Skip'),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (!_processingConsent) {
                setState(() => _consentError =
                    'Accept the Privacy Policy to process this policy.');
                return;
              }
              // 7-P0.18: Await consent write before returning success.
              // Unawaited writes can fail silently while the dialog returns
              // success and the upload proceeds without durable authorization.
              final ledger = ConsentLedger();
              await ledger.recordConsent(
                purpose: ConsentPurpose.documentProcessing,
                version: AppConfig.privacyPolicyVersion,
                granted: true,
              );
              if (!mounted) return;
              // 7-P0.19: Do NOT automatically grant marketing consent when
              // contact details are provided. Entering an email is not marketing
              // consent. Saving an email locally is not marketing consent.
              // Marketing opt-in requires a separate unticked control with
              // specific purpose and copy.
              Navigator.of(context).pop({
                'email': _emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim(),
                'phone': _phoneController.text.trim().isEmpty
                    ? null
                    : _phoneController.text.trim(),
                'save': _saveForFuture,
                'processing_consent': true,
                'processing_consent_version': AppConfig.privacyPolicyVersion,
              });
            }
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class RateLimitDialog extends StatelessWidget {
  final String message;
  final int? retryAfter;

  const RateLimitDialog({
    super.key,
    required this.message,
    this.retryAfter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          CoverWiseIconBadge(
            icon: Icons.timer_off_outlined,
            color: scheme.tertiary,
            size: 42,
          ),
          const SizedBox(width: 8),
          const Text('Upload Limit Reached'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (retryAfter != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: scheme.tertiary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: scheme.onTertiaryContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can try again in ${_formatRetryTime(retryAfter!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'To prevent abuse, we limit the number of uploads per day. This helps us provide better service to everyone.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  String _formatRetryTime(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).round();
      return '$minutes minutes';
    } else {
      final hours = (seconds / 3600).round();
      return '$hours hours';
    }
  }
}
