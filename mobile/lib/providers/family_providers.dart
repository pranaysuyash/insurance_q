import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../services/app_state_repository.dart';
import '../services/relationship_extraction_service.dart';
import '../utils/ref_state.dart';
import 'service_providers.dart';

/// Provider for the [RelationshipExtractionService] used to extract
/// person-to-person relationships from uploaded documents.
final relationshipExtractionServiceProvider =
    Provider<RelationshipExtractionService>((ref) {
  return RelationshipExtractionService(ref.read(queryServiceProvider));
});

/// Auto-detected family members, derived from uploaded policy documents.
/// This is read-only from the user's perspective — removing a document is the
/// way to remove an auto-detected member.
///
/// Uses the [RelationshipExtractionService] to extract policyholders, insured
/// persons, nominees, and dependents from document content. Falls back to
/// [InsuranceDocument.policyHolders] if already present on the model.
final autoFamilyMembersProvider = FutureProvider.family<
    Map<String, PolicyHolder>, List<InsuranceDocument>>((ref, documents) async {
  final relationshipService = ref.read(relationshipExtractionServiceProvider);
  final policyHolders = <String, PolicyHolder>{};

  // Build a single relationship graph from all documents
  final docRelationships = <DocumentRelationships>[];

  for (final doc in documents) {
    try {
      if (doc.policyHolders != null && doc.policyHolders!.isNotEmpty) {
        for (final holder in doc.policyHolders!) {
          policyHolders[holder.name] = holder;
        }
      } else if (doc.documentType != null) {
        // Use relationship extraction to find policyholders, insured persons,
        // and nominees from the document text.
        final docRel = await relationshipService.extractRelationships(
          doc.id,
          doc.documentType!,
        );
        docRelationships.add(docRel);
      }
    } catch (e) {
      debugPrint('Error extracting policy holders: $e');
    }
  }

  // If we have relationship graphs, convert them to PolicyHolder objects
  if (docRelationships.isNotEmpty) {
    final familyGraph =
        relationshipService.buildFamilyGraph(docRelationships);
    final holders = relationshipService.graphToPolicyHolders(familyGraph);
    for (final holder in holders) {
      policyHolders[holder.name] = holder;
    }
  }

  return policyHolders;
});

/// Bump this to force [mergedFamilyMembersProvider] to reload manual members
/// from storage after an add/remove.
final _manualMembersRevisionProvider = refStateProvider<int>(0);

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
  final current = ref.read(_manualMembersRevisionProvider);
  ref.read(_manualMembersRevisionProvider.notifier).setState(current + 1);
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
