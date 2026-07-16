import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + identity
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              phone ?? 'Anonymous User',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              phone != null ? 'Verified' : 'Not linked to a phone number',
              style: TextStyle(
                color: phone != null ? Colors.green : Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Account section
          _SectionHeader('Account'),
          _InfoTile(
            icon: Icons.phone,
            title: 'Phone Number',
            subtitle: phone ?? 'Not linked',
            trailing: phone != null
                ? TextButton(
                    onPressed: () async {
                      await box.delete(AppStateStore.phoneNumberKey);
                      setState(() {});
                    },
                    child: const Text('Remove'),
                  )
                : null,
          ),
          _InfoTile(
            icon: Icons.vpn_key,
            title: 'Auth Token',
            subtitle: _loadingToken
                ? 'Loading...'
                : (_token != null ? '${_token!.substring(0, _token!.length.clamp(0, 20))}...' : 'Not available'),
            trailing: _token != null
                ? IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _token!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Token copied to clipboard')),
                      );
                    },
                  )
                : null,
          ),

          const SizedBox(height: 16),

          // App section
          _SectionHeader('App'),
          _InfoTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '${AppConfig.appName} ${AppConfig.appVersion}',
          ),
          _InfoTile(
            icon: Icons.brightness_auto,
            title: 'Appearance',
            subtitle: themeMode == 'light' ? 'Light' : themeMode == 'dark' ? 'Dark' : 'System default',
          ),
          _InfoTile(
            icon: Icons.storage,
            title: 'Local Storage',
            subtitle: 'Hive box: ${AppStateStore.boxName}',
          ),

          const SizedBox(height: 16),

          // Privacy section
          _SectionHeader('Privacy'),
          _InfoTile(
            icon: Icons.lock_outline,
            title: 'Data Storage',
            subtitle: 'All data is stored locally on your device. No PII is sent to the server.',
          ),
          _InfoTile(
            icon: Icons.cloud_off,
            title: 'Anonymous Identity',
            subtitle: 'Your identity is a temporary token, not linked to any personal information.',
          ),
          _InfoTile(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            subtitle: 'Clear all local data and revoke your token',
            trailing: Icon(Icons.chevron_right, color: Colors.red.shade700),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use Settings → Clear local data to reset')),
              );
            },
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'CoverWise is an information broker.\nWe help you understand your policies — we don\'t sell insurance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
