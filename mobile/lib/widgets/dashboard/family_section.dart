import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document_model.dart';
import '../../providers/family_providers.dart';
import '../../services/analytics_service.dart';
import '../../screens/add_family_member_dialog.dart';

class FamilySection extends ConsumerWidget {
  final List<InsuranceDocument> documents;
  
  const FamilySection({super.key, required this.documents});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(mergedFamilyMembersProvider(documents));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Family Members & Insured',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () async {
                final member = await showDialog<PolicyHolder>(
                  context: context,
                  builder: (_) => const AddFamilyMemberDialog(),
                );
                if (member != null) {
                  await addManualFamilyMember(ref, member);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${member.name}.')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        familyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child:
                      Text('No family information detected in your policies')),
            ),
          ),
          data: (policyHolders) {
            if (policyHolders.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: Text(
                          'No family information detected in your policies')),
                ),
              );
            }
            return Column(
              children: [
                ...policyHolders.values.map((holder) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          AnalyticsService.track('dashboard_family_member_tapped', {
                            'is_manual': holder.isManual
                          });
                          Navigator.pushNamed(context, '/family-member-detail', arguments: holder);
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              holder.relationship == 'Primary Insured'
                                  ? Icons.person
                                  : Icons.people_alt,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(holder.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (holder.dob != null) Text('DOB: ${holder.dob}'),
                              Text(holder.relationship),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    )),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Auto-detected from your policies, plus anyone you add manually.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
