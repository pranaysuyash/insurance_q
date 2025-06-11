import 'package:flutter/material.dart';

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
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(value)) {
        return 'Please enter a valid email address';
      }
      
      // Check for disposable email domains
      final disposableDomains = [
        '10minutemail.com', 'tempmail.org', 'guerrillamail.com',
        'mailinator.com', 'throwaway.email', 'temp-mail.org',
        'yopmail.com', 'maildrop.cc', 'sharklasers.com',
        'getairmail.com', 'dispostable.com', 'tempail.com',
      ];
      
      final domain = value.split('@').last.toLowerCase();
      if (disposableDomains.contains(domain)) {
        return 'Disposable email addresses are not allowed';
      }
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      // Basic phone validation - adjust regex as needed
      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
      if (!phoneRegex.hasMatch(value)) {
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
                'Optionally provide your contact information to save your results and receive updates.',
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
              title: const Text(
                'Save for future uploads',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'We\'ll remember your contact info for next time',
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
              Navigator.of(context).pop({
                'email': null,
                'phone': null,
                'save': false,
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
              Navigator.of(context).pop({
                'email': _emailController.text.trim().isEmpty 
                    ? null 
                    : _emailController.text.trim(),
                'phone': _phoneController.text.trim().isEmpty 
                    ? null 
                    : _phoneController.text.trim(),
                'save': _saveForFuture,
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
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