import 'package:flutter/material.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _groups = [
    _MoreGroup('Find and carry', [
      _MoreItem(Icons.search_rounded, CoverWiseColors.blue, 'Search policies',
          'Find details across every policy', '/search'),
      _MoreItem(Icons.emergency_outlined, Color(0xFFE64A4A), 'Emergency card',
          'Policy numbers and helplines at a glance', '/emergency'),
      _MoreItem(Icons.wallet_outlined, Color(0xFF5B67D6), 'Insurance cards',
          'Keep digital proof of cover close', '/insurance-cards'),
    ]),
    _MoreGroup('Plan your cover', [
      _MoreItem(Icons.family_restroom_rounded, Color(0xFF16866B), 'Family',
          'People covered across your policies', '/family'),
      _MoreItem(Icons.account_tree_outlined, Color(0xFF0B8F7D),
          'Coverage map', 'See which members are covered by which policies',
          '/family/visualization'),
      _MoreItem(Icons.event_available_outlined, Color(0xFF0B8F7D),
          'Renewal calendar', 'Track expiry dates and reminders', '/renewals'),
      _MoreItem(Icons.shield_outlined, Color(0xFF7C5CE7), 'Coverage gaps',
          'Review areas that may need attention', '/coverage-gaps'),
      _MoreItem(Icons.compare_arrows_rounded, Color(0xFF2686A3),
          'Compare policies', 'See policy details side by side', '/compare'),
      _MoreItem(Icons.tune_rounded, Color(0xFFB66A16), 'What-if calculator',
          'Explore possible cover changes', '/what-if'),
    ]),
    _MoreGroup('Claims and learning', [
      _MoreItem(Icons.route_outlined, Color(0xFFE07A28), 'Claims info guide',
          'Understand the usual steps after an incident', '/claims',
          comingSoon: true),
      _MoreItem(Icons.fact_check_outlined, Color(0xFFC85B3A), 'My claims log',
          'Keep a personal record of filed claims', '/claim-tracker',
          comingSoon: true),
      _MoreItem(Icons.menu_book_outlined, Color(0xFF079A86), 'Insurance basics',
          'Learn useful terms without the jargon', '/literacy'),
    ]),
    _MoreGroup('Account and support', [
      _MoreItem(Icons.person_outline_rounded, Color(0xFF53657A), 'Profile',
          'Account information and identity', '/profile'),
      _MoreItem(Icons.support_agent_rounded, Color(0xFF087F75),
          'Advisor requests',
          'View submitted advisor callback requests', '/agent-requests'),
      _MoreItem(Icons.settings_outlined, Color(0xFF53657A), 'Settings',
          'Appearance, reminders and local data', '/settings'),
      _MoreItem(Icons.notifications_outlined, Color(0xFF53657A), 'Notifications',
          'Renewal reminders and quiet hours', '/notifications'),
      _MoreItem(Icons.help_outline_rounded, Color(0xFF53657A), 'Help & support',
          'FAQs and ways to get help', '/help'),
      _MoreItem(Icons.lock_outline_rounded, Color(0xFF53657A),
          'Privacy & security', 'How CoverWise handles your data', '/privacy'),
      _MoreItem(Icons.info_outline_rounded, Color(0xFF53657A), 'About',
          'Version, product role and legal information', '/about'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const CoverWisePageHeader(
            title: 'Everything else, clearly organised.',
            subtitle:
                'Tools for understanding, planning and carrying your cover.',
          ),
          for (final group in _groups) ...[
            CoverWiseSectionLabel(group.title),
            CoverWiseSurface(
              child: Column(
                children: [
                  for (var index = 0; index < group.items.length; index++) ...[
                    CoverWiseActionRow(
                      icon: group.items[index].icon,
                      color: group.items[index].color,
                      title: group.items[index].title,
                      subtitle: group.items[index].subtitle,
                      trailing: group.items[index].comingSoon
                          ? const CoverWiseSoonBadge()
                          : null,
                      onTap: group.items[index].comingSoon
                          ? null
                          : () => Navigator.pushNamed(
                                context,
                                group.items[index].route,
                              ),
                    ),
                    if (index != group.items.length - 1)
                      const Divider(height: 1, indent: 74),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoreGroup {
  final String title;
  final List<_MoreItem> items;
  const _MoreGroup(this.title, this.items);
}

class _MoreItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;
  final bool comingSoon;
  const _MoreItem(this.icon, this.color, this.title, this.subtitle, this.route,
      {this.comingSoon = false});
}
