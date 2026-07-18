import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/field_citation.dart';

/// Reads cited fields from the evidence substrate (Trust Phase 1).
///
/// The policy detail screen calls this once per document load. The
/// server-side route is GET /evidence/{document_id}/field-citations
/// (src/api/evidence.py). The route is owner-scoped: a 404 means
/// the document does not belong to the caller; a 503 means the
/// substrate is not configured on this deployment.
///
/// The 503 case is the expected steady state for new deployments
/// that have not yet applied the substrate migration. The
/// policy detail screen must keep the "Not yet verified" scaffold
/// in that case (the existing Phase 0 P0-0.4 behavior).
class EvidenceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
    receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
  ));

  /// Fetch every cited field for a document. Returns an empty list
  /// on 503 (substrate not configured) or 404 (document not owned
  /// by caller) — both are non-errors from the UI's perspective;
  /// the policy detail screen shows the scaffold.
  ///
  /// Returns null only on transport-level failure (network down,
  /// 500, etc.) — the caller may want to surface that.
  Future<List<FieldCitation>?> getFieldCitations(String documentId) async {
    try {
      final response = await _dio.get(
        '/evidence/$documentId/field-citations',
      );
      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .map((item) => FieldCitation.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ))
            .where((c) => c.isVisible) // hide fields the parser could not verify
            .toList();
        return list;
      }
      return const [];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 503 || status == 404) {
        // Substrate not configured, or document not owned.
        // The scaffold is the honest UI for both cases.
        debugPrint('evidence substrate not available: $status');
        return const [];
      }
      debugPrint('evidence fetch failed: $e');
      return null;
    } catch (e) {
      debugPrint('evidence fetch unexpected error: $e');
      return null;
    }
  }
}
