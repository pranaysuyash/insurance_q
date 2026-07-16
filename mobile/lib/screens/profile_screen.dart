import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile / Account Screen — shows device identity, token status, and account health.
///
/// For an info broker, this is about transparency: users can see exactly
/// what data the app holds and how their anonymous identity works.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _token;
  bool _loadingToken = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await AuthService.cachedToken();
    if (mounted) {
      setState(() {
        _token = token;
        _loadingToken = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;
    final themeMode = AppStateRepository.getThemeMode();
    final accountUser = AuthService.hasAccountSession
        ? Supabase.instance.client.auth.currentUser
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: phone ?? 'Your CoverWise profile',
            subtitle: phone != null
                ? 'Linked and ready across your devices.'
                : 'Your policy workspace currently stays on this device.',
            trailing: CoverWiseIconBadge(
              icon: phone != null
                  ? Icons.verified_user_rounded
                  : Icons.person_outline_rounded,
              color: phone != null
                  ? const Color(0xFF0F9D84)
                  : CoverWiseColors.blue,
              size: 54,
            ),
          ),
          const CoverWiseSectionLabel('Account'),
          if (accountUser == null)
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Create a secure account'),
                subtitle: const Text('Restore this policy workspace across devices'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final changed = await Navigator.pushNamed(context, '/account');
                  if (changed == true && mounted) setState(() {});
                },
              ),
            )
          else
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.verified_user_rounded),
                title: Text(accountUser.email ?? 'Signed-in account'),
                subtitle: const Text('Workspace is linked to your account'),
                trailing: TextButton(onPressed: () async { await AuthService.signOut(); if (mounted) setState(() {}); }, child: const Text('Sign out')),
              ),
            ),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.phone_iphone_rounded,
                color: const Color(0xFF0F9D84),
                title: 'Phone number',
                subtitle: phone ?? 'Not linked',
                trailing: phone != null
                    ? TextButton(
                        onPressed: () async {
                          await box.delete(AppStateStore.phoneNumberKey);
                          setState(() {});
                        },
                        child: const Text('Remove'),
                      )
                    : const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.key_rounded,
                color: const Color(0xFF7557D3),
                title: 'Secure session',
                subtitle: _loadingToken
                    ? 'Checking session…'
                    : (_token != null
                        ? 'Active on this device'
                        : 'Not available'),
                trailing: _token != null
                    ? IconButton(
                        tooltip: 'Copy session token',
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _token!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Session token copied')),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          const CoverWiseSectionLabel('App'),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.info_outline_rounded,
                color: CoverWiseColors.blue,
                title: 'Version',
                subtitle: '${AppConfig.appName} ${AppConfig.appVersion}',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.brightness_auto_rounded,
                color: const Color(0xFFE58726),
                title: 'Appearance',
                subtitle: themeMode == 'light'
                    ? 'Light'
                    : themeMode == 'dark'
                        ? 'Dark'
                        : 'System default',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          const CoverWiseSectionLabel('Privacy'),
          CoverWiseSurface(
            child: Column(children: [
              const CoverWiseActionRow(
                icon: Icons.phonelink_lock_rounded,
                color: Color(0xFF0F9D84),
                title: 'Device-first storage',
                subtitle:
                    'Your policy workspace and personal details stay local.',
                trailing: SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFC43D4B),
                title: 'Reset account data',
                subtitle: 'Clear local data and revoke this device session',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Use Settings → Clear local data to reset'),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
            child: Text(
              'CoverWise helps you understand your policies. It does not sell insurance.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
