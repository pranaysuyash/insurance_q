import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

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
    if (_email.text.trim().isEmpty || _password.text.length < 8) {
      _message('Enter an email and a password of at least 8 characters.');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final response = _signUp
          ? await AuthService.signUp(_email.text, _password.text, _name.text)
          : await AuthService.signIn(_email.text, _password.text);
      if (!context.mounted) return;
      if (response.session == null) {
        _message('Check your email to confirm the account, then sign in.');
      } else {
        await AuthService.claimAnonymousData();
        if (!context.mounted) return;
        navigator.pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      _message(
          'Could not ${_signUp ? 'create' : 'sign in'} the account. Check your details and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

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
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const CircularProgressIndicator()
                  : Text(_signUp ? 'Create account' : 'Sign in')),
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
