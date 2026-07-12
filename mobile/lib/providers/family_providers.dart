import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../services/app_state_repository.dart';
import 'service_providers.dart';

/// Auto-detected family members, derived from uploaded policy documents.
/// This is read-only from the user's perspective — removing a document is the
/// way to remove an auto-detected member.
final autoFamilyMembersProvider = FutureProvider.family<
    Map<String, PolicyHolder>, List<InsuranceDocument>>((ref, documents) async {
  final documentService = ref.read(documentServiceProvider);
  final policyHolders = <String, PolicyHolder>{};

  for (final doc in documents) {
    try {
      if (doc.policyHolders != null && doc.policyHolders!.isNotEmpty) {
        for (final holder in doc.policyHolders!) {
          policyHolders[holder.name] = holder;
        }
      } else {
        final holders = await documentService.extractPolicyHolders(doc.id);
        for (final holder in holders) {
          policyHolders[holder.name] = holder;
        }
      }
    } catch (e) {
      debugPrint('Error extracting policy holders: $e');
    }
  }

  return policyHolders;
});

/// Bump this to force [mergedFamilyMembersProvider] to reload manual members
/// from storage after an add/remove.
final _manualMembersRevisionProvider = StateProvider<int>((ref) => 0);

/// Manually-added family members, loaded from local storage. These are members
/// the user added themselves (e.g. a dependent with their own separate policy
/// who isn't named in any uploaded document).
final manualFamilyMembersProvider =
    Provider<List<PolicyHolder>>((ref) {
  // Watch the revision so adds/removes trigger a reload.
  ref.watch(_manualMembersRevisionProvider);
  return AppStateRepository.getManualFamilyMembers();
});

/// The complete family roster: auto-detected members from documents merged
/// with manually-added members. Manual members that duplicate an auto-detected
/// name are skipped (the document-sourced entry wins).
///
/// Watch this provider in the UI. Call [refreshManualFamilyMembers] after
/// mutating the manual list.
final mergedFamilyMembersProvider = FutureProvider.family<
    Map<String, PolicyHolder>, List<InsuranceDocument>>((ref, documents) async {
  final auto = await ref.watch(autoFamilyMembersProvider(documents).future);
  final manual = ref.watch(manualFamilyMembersProvider);

  final merged = Map<String, PolicyHolder>.from(auto);
  for (final member in manual) {
    if (!merged.containsKey(member.name)) {
      merged[member.name] = member;
    }
  }
  return merged;
});

/// Helpers to mutate the manual member list and refresh listeners.
void refreshManualFamilyMembers(WidgetRef ref) {
  ref.read(_manualMembersRevisionProvider.notifier).state++;
}

Future<void> addManualFamilyMember(WidgetRef ref, PolicyHolder member) async {
  await AppStateRepository.addManualFamilyMember(member);
  refreshManualFamilyMembers(ref);
}

Future<void> removeManualFamilyMember(
    WidgetRef ref, PolicyHolder member) async {
  await AppStateRepository.removeManualFamilyMember(member.name,
      relationship: member.relationship);
  refreshManualFamilyMembers(ref);
}
