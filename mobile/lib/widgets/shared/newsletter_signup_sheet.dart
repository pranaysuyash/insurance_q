import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/newsletter_service.dart';
import 'coverwise_snackbar.dart';

/// A bottom sheet that lets users subscribe to the CoverWise newsletter.
///
/// Shows an email input, a brief value proposition, and a subscribe button.
/// On success records consent in the consent ledger and shows a confirmation.
/// Already-subscribed users see an unsubscribe option instead.
class NewsletterSignupSheet extends StatefulWidget {
  const NewsletterSignupSheet({super.key});

  /// Show the newsletter signup sheet as a modal bottom sheet.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const NewsletterSignupSheet(),
    );
  }

  @override
  State<NewsletterSignupSheet> createState() => _NewsletterSignupSheetState();
}

class _NewsletterSignupSheetState extends State<NewsletterSignupSheet> {
  final _emailController = TextEditingController();
  final _service = NewsletterService();
  bool _isSubscribed = false;
  bool _isLoading = false;
  bool _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isSubscribed = _service.isSubscribed;
    if (_isSubscribed) {
      _emailController.text = _service.subscribedEmail ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    if (!AppConfig.isValidEmail(email)) {
      setState(() => _error = AppConfig.isDisposableEmail(email)
          ? 'Disposable email addresses are not allowed.'
          : 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await _service.subscribe(email);
    if (!mounted) return;

    if (success) {
      if (!mounted) return;
      CoverWiseSnackBar.success(
        context,
        'Subscribed! You will receive insurance tips and updates.',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Could not subscribe. Please try again.';
      });
    }
  }

  Future<void> _unsubscribe() async {
    setState(() => _isLoading = true);
    await _service.unsubscribe();
    if (!mounted) return;
    CoverWiseSnackBar.info(context, 'Unsubscribed.');
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title + icon
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mail_outline_rounded,
                    color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _isSubscribed
                      ? 'Manage your subscription'
                      : 'Stay informed about insurance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isSubscribed
                ? 'You are subscribed with ${_service.subscribedEmail ?? ""}.'
                : 'Get insurance tips, renewal reminders, and updates delivered to your inbox.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (!_isSubscribed) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'your@email.com',
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _subscribe(),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _confirmed = !_confirmed),
                    child: Text(
                      'I agree to receive emails and understand I can unsubscribe at any time.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_isLoading ? 'Subscribing…' : 'Subscribe'),
                onPressed: _isLoading || !_confirmed ? null : _subscribe,
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Unsubscribe'),
                onPressed: _isLoading ? null : _unsubscribe,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Unsubscribe anytime. Your email is used for this newsletter and handled as described in the Privacy Policy.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
