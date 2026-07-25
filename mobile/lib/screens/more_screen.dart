import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../models/policy_summary.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/family_providers.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);
    final policySummaries = ref.watch(policySummariesProvider);
    final familyMembersAsync =
        ref.watch(mergedFamilyMembersProvider(documentsAsync.value ?? []));

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const CoverWisePageHeader(
            title: 'Everything else, clearly organised.',
            subtitle:
                'Tools for understanding, reviewing and carrying your policy records.',
          ),
          _DynamicMoreContent(
            documents: documentsAsync.value ?? [],
            policySummaries: policySummaries,
            familyMembers: familyMembersAsync.value ?? const {},
          ),
        ],
      ),
    );
  }
}

class _DynamicMoreContent extends StatelessWidget {
  final List<InsuranceDocument> documents;
  final List<PolicySummary> policySummaries;
  final Map<String, PolicyHolder> familyMembers;

  const _DynamicMoreContent({
    required this.documents,
    required this.policySummaries,
    required this.familyMembers,
  });

  bool get _hasDocuments => documents.isNotEmpty;
  bool get _hasPolicies => policySummaries.isNotEmpty;
  bool get _hasFamily => familyMembers.length > 1;

  List<_MoreGroup> _buildGroups() {
    final groups = <_MoreGroup>[];

    // Group 1: Find and carry - always show if has documents
    if (_hasDocuments) {
      groups.add(_MoreGroup('Find and carry', [
        _MoreItem(Icons.search_rounded, CoverWiseColors.blue, 'Search policies',
            'Find details across every policy', '/search'),
        _MoreItem(
            Icons.emergency_outlined,
            const Color(0xFFE64A4A),
            'Emergency card',
            'Policy numbers and helplines at a glance',
            '/emergency'),
        _MoreItem(
            Icons.wallet_outlined,
            const Color(0xFF5B67D6),
            'Insurance cards',
            'Keep policy details close for reference',
            '/insurance-cards'),
      ]));
    }

    // Group 2: Review policy records - show if has policies
    if (_hasPolicies) {
      final planItems = <_MoreItem>[];

      if (_hasFamily) {
        planItems.add(_MoreItem(
            Icons.family_restroom_rounded,
            const Color(0xFF16866B),
            'Family',
            'People covered across your policies',
            '/family'));
      }

      planItems.add(_MoreItem(
          Icons.event_available_outlined,
          const Color(0xFF0B8F7D),
          'Renewal calendar',
          'Track expiry dates and reminders',
          '/renewals'));

      planItems.add(_MoreItem(
          Icons.shield_outlined,
          const Color(0xFF7C5CE7),
          'Coverage overview',
          'What your policy covers and what is not yet extracted',
          '/coverage-gaps'));

      if (policySummaries.length > 1) {
        planItems.add(_MoreItem(
            Icons.compare_arrows_rounded,
            const Color(0xFF2686A3),
            'Compare policies',
            'See policy details side by side',
            '/compare'));
      }

      if (planItems.isNotEmpty) {
        groups.add(_MoreGroup('Review policy records', planItems));
      }
    }

    // Group 3: Claims and learning - show if has policies
    if (_hasPolicies) {
      final claimsItems = <_MoreItem>[
        _MoreItem(
            Icons.menu_book_outlined,
            const Color(0xFF079A86),
            'Insurance basics',
            'Learn useful terms without the jargon',
            '/literacy'),
      ];

      claimsItems.addAll([
        _MoreItem(
            Icons.route_outlined,
            const Color(0xFFE07A28),
            'Claim guide',
            'Prepare questions and records; CoverWise does not file or manage a claim',
            '/claims'),
        _MoreItem(
            Icons.fact_check_outlined,
            const Color(0xFFC85B3A),
            'My claims log',
            'Record your own claim details; statuses are not verified by CoverWise',
            '/claim-tracker'),
      ]);

      if (claimsItems.isNotEmpty) {
        groups.add(_MoreGroup('Claims and learning', claimsItems));
      }
    }

    // Group 4: Account and support - always show
    final accountItems = <_MoreItem>[
      _MoreItem(Icons.person_outline_rounded, const Color(0xFF53657A),
          'Profile', 'Account information and identity', '/profile'),
      _MoreItem(Icons.settings_outlined, const Color(0xFF53657A), 'Settings',
          'Appearance, reminders and local data', '/settings'),
      _MoreItem(
          Icons.notifications_outlined,
          const Color(0xFF53657A),
          'Notifications',
          'Renewal reminders and quiet hours',
          '/notifications'),
      _MoreItem(Icons.help_outline_rounded, const Color(0xFF53657A),
          'Help & support', 'FAQs and ways to get help', '/help'),
      _MoreItem(Icons.lock_outline_rounded, const Color(0xFF53657A),
          'Privacy & security', 'How CoverWise handles your data', '/privacy'),
      _MoreItem(Icons.info_outline_rounded, const Color(0xFF53657A), 'About',
          'Version, product role and legal information', '/about'),
    ];
    groups.add(_MoreGroup('Account and support', accountItems));

    // Group 5: Get started - show if no documents yet
    if (!_hasDocuments) {
      groups.add(_MoreGroup('Get started', [
        _MoreItem(
            Icons.upload_file_rounded,
            CoverWiseColors.blue,
            'Add your first policy',
            'Scan or upload a policy document to begin',
            '/documents'),
        _MoreItem(Icons.help_outline_rounded, const Color(0xFF53657A),
            'How it works', 'Learn what CoverWise does for you', '/help'),
      ]));
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    // Empty state: nothing to show
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Add a policy to unlock more tools',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Add policy'),
                onPressed: () => Navigator.pushNamed(context, '/documents'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final group in groups) ...[
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
                    onTap: () => Navigator.pushNamed(
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
  const _MoreItem(this.icon, this.color, this.title, this.subtitle, this.route);
}
