import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import 'service_providers.dart';

final documentsListProvider = FutureProvider<List<InsuranceDocument>>((ref) async {
  return ref.read(documentServiceProvider).getDocuments();
});
