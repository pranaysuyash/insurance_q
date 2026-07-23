import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../widgets/shared/coverwise_snackbar.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _showResendVerification =
      false; // Show inline resend when email not confirmed

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!AppConfig.hasSupabaseAuthConfig) {
      _message('Account auth is not configured for this build.');
      return;
    }
    if (_email.text.trim().isEmpty) {
      _message('Please enter your email address.');
      return;
    }
    if (_password.text.length < 8) {
      _message('Password must be at least 8 characters.');
      return;
    }
    // Basic email format check
    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      _message('Please enter a valid email address.');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await AuthService.prepareAnonymousWorkspaceClaim();
      final response = _signUp
          ? await AuthService.signUp(_email.text, _password.text, _name.text)
          : await AuthService.signIn(_email.text, _password.text);
      if (!context.mounted) return;
      if (response.session == null) {
        _message('Check your email to confirm the account, then sign in.',
            isError: false);
        return;
      }
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      // Provide more specific error messages
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('invalid login credentials')) {
        _message('Incorrect email or password. Please try again.');
      } else if (errorStr.contains('email not confirmed')) {
        setState(() => _showResendVerification = true);
      } else if (errorStr.contains('user already registered')) {
        _message('An account with this email already exists. Try signing in.');
      } else if (errorStr.contains('password')) {
        _message(
            'Password does not meet requirements. Use at least 8 characters.');
      } else {
        _message(
            'Could not ${_signUp ? 'create' : 'sign in'} the account. Check your details and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      _message('Enter your email above first, then tap Forgot password.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.resetPassword(_email.text);
      if (!mounted) return;
      _message('Password reset email sent. Check your inbox.', isError: false);
    } catch (error) {
      if (!mounted) return;
      _message('Could not send reset email. Check your email and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message, {bool isError = true}) {
    if (isError) {
      CoverWiseSnackBar.error(context, message);
    } else {
      CoverWiseSnackBar.info(context, message);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!AppConfig.hasSupabaseAuthConfig) {
      _message('Account auth is not configured for this build.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.prepareAnonymousWorkspaceClaim();
      // Opens browser for Google OAuth. Session is established via
      // deep link callback → authStateProvider triggers workspace + claim path.
      await AuthService.signInWithGoogle();
      if (!mounted) return;
      // Pop back — authStateProvider will rebuild ProfileScreen with the new user.
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _message('Could not sign in with Google. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      _message('Enter your email above first, then tap Resend verification.');
      return;
    }
    setState(() {
      _busy = true;
      _showResendVerification = false; // Hide banner after successful resend
    });
    try {
      await AuthService.resendEmailVerification(_email.text);
      if (!mounted) return;
      _message('Verification email sent. Check your inbox.', isError: false);
    } catch (error) {
      if (!mounted) return;
      _message('Could not send verification email. Try again later.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_signUp ? 'Create account' : 'Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Protect your policy workspace',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'An account lets you restore your CoverWise workspace on another device. Your account does not make policy explanations binding insurance advice.'),
          const SizedBox(height: 24),
          if (_signUp)
            TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Name (optional)')),
          if (_signUp) const SizedBox(height: 12),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(
              controller: _password,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Password')),
          // Inline resend verification banner — shown after 'email not confirmed' error
          if (_showResendVerification) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your email has not been confirmed yet. Check your inbox or resend.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _resendVerification,
                    child: const Text('Resend'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_signUp ? 'Create account' : 'Sign in')),
          const SizedBox(height: 12),
          // Google Sign-In button
          if (AppConfig.hasSupabaseAuthConfig)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                label: const Text('Continue with Google'),
              ),
            ),
          const SizedBox(height: 16),
          if (!_signUp) ...[
            TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: const Text('Forgot password?'),
            ),
            TextButton(
              onPressed: _busy ? null : _resendVerification,
              child: const Text('Resend verification email'),
            ),
          ],
          TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _signUp = !_signUp),
              child: Text(_signUp
                  ? 'Already have an account? Sign in'
                  : 'New to CoverWise? Create an account')),
        ],
      ),
    );
  }
}
