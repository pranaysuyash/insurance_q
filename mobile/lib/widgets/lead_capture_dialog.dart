import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

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
      if (!AppConfig.isValidEmail(value)) {
        if (AppConfig.isDisposableEmail(value)) {
          return 'Disposable email addresses are not allowed';
        }
        return 'Please enter a valid email address';
      }
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!AppConfig.isValidPhone(value)) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.contact_mail,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          const Text('Contact Information'),
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
                'CoverWise needs your permission to securely store and analyze this policy. Contact details are optional and stay on this device unless you later choose to share them.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              )
            else
              const Text(
                'Please provide your contact information to continue.',
                style: TextStyle(fontSize: 14, color: Colors.orange),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'your.email@example.com',
                prefixIcon: Icon(Icons.email),
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
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('I agree to secure policy processing'),
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
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            CheckboxListTile(
              title: const Text(
                'Save on this device for future uploads',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Your contact details are not sent with this policy upload',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
            onPressed: () {
              if (!_processingConsent) {
                setState(() => _consentError =
                    'Accept the Privacy Policy to process this policy.');
                return;
              }
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
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (!_processingConsent) {
                setState(() => _consentError =
                    'Accept the Privacy Policy to process this policy.');
                return;
              }
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
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.timer_off,
            color: Colors.orange,
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
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange, size: 20),
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
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
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
