import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Options'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search, color: Colors.indigo),
            title: const Text('Search Policies'),
            subtitle: const Text('Find anything across all your policies'),
            onTap: () => Navigator.pushNamed(context, '/search'),
          ),
          ListTile(
            leading: const Icon(Icons.emergency, color: Colors.red),
            title: const Text('Emergency Card'),
            subtitle: const Text('Policy numbers, helplines, coverage — quick access'),
            onTap: () => Navigator.pushNamed(context, '/emergency'),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in, color: Colors.orange),
            title: const Text('Claims Assistant'),
            subtitle: const Text('Step-by-step claim guidance for any incident'),
            onTap: () => Navigator.pushNamed(context, '/claims'),
          ),
          ListTile(
            leading: const Icon(Icons.track_changes, color: Colors.deepOrange),
            title: const Text('Claim Tracker'),
            subtitle: const Text('Log and track your filed insurance claims'),
            onTap: () => Navigator.pushNamed(context, '/claim-tracker'),
          ),
          ListTile(
            leading: const Icon(Icons.event, color: Colors.blue),
            title: const Text('Renewal Calendar'),
            subtitle: const Text('Track policy expiry dates with reminders'),
            onTap: () => Navigator.pushNamed(context, '/renewals'),
          ),
          ListTile(
            leading: const Icon(Icons.shield, color: Colors.purple),
            title: const Text('Coverage Gaps'),
            subtitle: const Text('Find missing coverage across your policies'),
            onTap: () => Navigator.pushNamed(context, '/coverage-gaps'),
          ),
          ListTile(
            leading: const Icon(Icons.compare_arrows, color: Colors.teal),
            title: const Text('Compare Policies'),
            subtitle: const Text('Side-by-side comparison of your policies'),
            onTap: () => Navigator.pushNamed(context, '/compare'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            subtitle: const Text('App preferences and account settings'),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            subtitle: const Text('FAQs and contact information'),
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy & Security'),
            subtitle: const Text('Manage your data and privacy settings'),
            onTap: () => Navigator.pushNamed(context, '/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('App version and legal information'),
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
        ],
      ),
    );
  }
}
