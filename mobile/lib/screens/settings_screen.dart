import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// App settings. Currently exposes the backend environment override (useful for
/// testing staging vs production) and a clear-data action. Kept deliberately
/// small: only settings that actually do something are shown, so users never
/// see dead toggles.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _resolvedBaseUrl;

  @override
  void initState() {
    super.initState();
    _resolvedBaseUrl = AppConfig.baseUrl;
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear local data?'),
        content: const Text(
          'This removes locally stored documents, Q&A history, and session data '
          'from this device. Uploaded documents on the server are not affected. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data cleared.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Backend endpoint'),
            subtitle: Text(_resolvedBaseUrl ?? AppConfig.baseUrl),
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('App version'),
            subtitle: Text('${AppConfig.appName} ${AppConfig.appVersion}'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
            title: Text('Clear local data',
                style: TextStyle(color: Colors.red.shade700)),
            subtitle: const Text(
                'Documents, history, and session stored on this device'),
            onTap: _confirmClearData,
          ),
        ],
      ),
    );
  }
}
