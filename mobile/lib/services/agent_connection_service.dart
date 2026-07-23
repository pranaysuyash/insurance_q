import 'package:hive/hive.dart';

/// A single agent connection request stored locally.
///
/// Collects basic contact info and what the user needs help with,
/// along with the policy context at the time of request.
class AgentRequest {
  final String id;
  final String name;
  final String phone;
  final String description;
  final String? insurer;
  final String? documentType;
  final String? documentId;
  final DateTime createdAt;
  final bool contacted;

  /// Preferred callback date (null means "as soon as possible").
  final DateTime? preferredDate;

  /// Preferred time slot (e.g. "Morning (9-12)", "Afternoon (12-5)", "Evening (5-8)").
  final String? preferredTime;

  const AgentRequest({
    required this.id,
    required this.name,
    required this.phone,
    required this.description,
    this.insurer,
    this.documentType,
    this.documentId,
    required this.createdAt,
    this.contacted = false,
    this.preferredDate,
    this.preferredTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'description': description,
        'insurer': insurer,
        'document_type': documentType,
        'document_id': documentId,
        'created_at': createdAt.toIso8601String(),
        'contacted': contacted,
        if (preferredDate != null) 'preferred_date': preferredDate!.toIso8601String(),
        if (preferredTime != null) 'preferred_time': preferredTime,
      };

  factory AgentRequest.fromJson(Map<String, dynamic> json) => AgentRequest(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        description: json['description'] as String? ?? '',
        insurer: json['insurer'] as String?,
        documentType: json['document_type'] as String?,
        documentId: json['document_id'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        contacted: json['contacted'] as bool? ?? false,
        preferredDate: json['preferred_date'] != null
            ? DateTime.tryParse(json['preferred_date'] as String)
            : null,
        preferredTime: json['preferred_time'] as String?,
      );
}

/// Service for managing agent connection requests.
///
/// Stores requests in a local Hive box (`agent_requests`). In v1,
/// requests stay on-device for the user to review. A future version
/// will sync them to a backend endpoint for lead routing.
class AgentConnectionService {
  static const String _boxName = 'agent_requests';

  Box<dynamic>? get _box {
    try {
      return Hive.box<dynamic>(_boxName);
    } catch (_) {
      return null;
    }
  }

  /// Submit a new agent connection request.
  Future<bool> submitRequest({
    required String name,
    required String phone,
    required String description,
    String? insurer,
    String? documentType,
    String? documentId,
    DateTime? preferredDate,
    String? preferredTime,
  }) async {
    if (name.trim().isEmpty || phone.trim().isEmpty) return false;
    if (!_isValidPhone(phone)) return false;

    final request = AgentRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      phone: phone.trim(),
      description: description.trim(),
      insurer: insurer,
      documentType: documentType,
      documentId: documentId,
      createdAt: DateTime.now(),
      preferredDate: preferredDate,
      preferredTime: preferredTime,
    );

    await _box?.add(request.toJson());
    return true;
  }

  /// Get all stored agent requests, newest first.
  List<AgentRequest> getRequests() {
    if (_box == null) return [];

    final requests = <AgentRequest>[];
    for (final value in _box!.values) {
      try {
        requests.add(
          AgentRequest.fromJson(Map<String, dynamic>.from(value)),
        );
      } catch (_) {
        // Skip malformed records.
      }
    }
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  /// Count how many requests have been submitted.
  int get requestCount => getRequests().length;

  /// Mark a request as contacted (for tracking).
  Future<void> markContacted(String requestId) async {
    if (_box == null) return;

    for (final key in _box!.keys) {
      try {
        final value = _box!.get(key);
        if (value is Map) {
          final request = AgentRequest.fromJson(Map<String, dynamic>.from(value));
          if (request.id == requestId) {
            value['contacted'] = true;
            await _box!.put(key, value);
            return;
          }
        }
      } catch (_) {
        // Skip malformed records.
      }
    }
  }

  /// Delete all requests.
  Future<void> clear() async {
    await _box?.clear();
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.length >= 10;
  }
}
