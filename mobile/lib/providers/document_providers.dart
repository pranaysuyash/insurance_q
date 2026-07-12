import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import 'service_providers.dart';

/// The single source of truth for the user's document list.
///
/// All screens that need the document list should watch this provider — not
/// define their own. Previously `dashboard_screen.dart` and `qa_screen.dart`
/// each had a private duplicate FutureProvider calling the same `getDocuments()`.
/// Invalidating one did not invalidate the others, causing stale UI after
/// delete/clear operations.
///
/// Use [invalidateAllDocuments] to refresh every consumer at once.
final documentsProvider =
    FutureProvider<List<InsuranceDocument>>((ref) async {
  return ref.read(documentServiceProvider).getDocuments();
});

/// Convenience: invalidate the document list so all watching screens rebuild.
void invalidateAllDocuments(WidgetRef ref) {
  ref.invalidate(documentsProvider);
}
