import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Stores user corrections to extracted policy fields.
///
/// Architecture: a separate Hive box keyed by documentId, with each
/// value being a JSON map of `{field: {value, original, timestamp}}`.
/// This preserves the original extracted value alongside the override
/// so we can show "user corrected" badges and support revert.
///
/// Why a separate box (not inside PolicySummary)?
/// - The extraction pipeline writes PolicySummary from the backend.
///   User overrides are a client-side concern that must NOT be
///   overwritten when the backend re-processes a document.
/// - Keeping them separate avoids merge conflicts in the extraction
///   write path and makes the override layer explicit.
class FieldOverridesStore {
  static const String _boxName = 'field_overrides_box';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Get all overrides for a document.
  /// Returns `{field: OverrideRecord}`.
  Future<Map<String, OverrideRecord>> getOverrides(String documentId) async {
    final box = await _getBox();
    final raw = box.get(documentId);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, OverrideRecord.fromJson(v)));
    } catch (_) {
      return {};
    }
  }

  /// Get the overridden value for a specific field, or null if no override.
  Future<String?> getOverride(String documentId, String field) async {
    final overrides = await getOverrides(documentId);
    return overrides[field]?.value;
  }

  /// Check if a specific field has a user override.
  Future<bool> hasOverride(String documentId, String field) async {
    final overrides = await getOverrides(documentId);
    return overrides.containsKey(field);
  }

  /// Save a user override for a field.
  /// [originalValue] is the extracted value before correction.
  Future<void> setOverride({
    required String documentId,
    required String field,
    required String value,
    String? originalValue,
  }) async {
    final box = await _getBox();
    final existing = await getOverrides(documentId);
    existing[field] = OverrideRecord(
      value: value,
      originalValue: originalValue ?? existing[field]?.originalValue,
      timestamp: DateTime.now(),
    );
    await box.put(documentId, jsonEncode(
      existing.map((k, v) => MapEntry(k, v.toJson())),
    ));
    debugPrint('FieldOverride: $field → "$value" for $documentId');
  }

  /// Remove a user override (revert to extracted value).
  Future<void> removeOverride(String documentId, String field) async {
    final box = await _getBox();
    final existing = await getOverrides(documentId);
    existing.remove(field);
    if (existing.isEmpty) {
      await box.delete(documentId);
    } else {
      await box.put(documentId, jsonEncode(
        existing.map((k, v) => MapEntry(k, v.toJson())),
      ));
    }
    debugPrint('FieldOverride: reverted $field for $documentId');
  }

  /// Clear all overrides for a document.
  Future<void> clearDocument(String documentId) async {
    final box = await _getBox();
    await box.delete(documentId);
  }

  /// Clear all overrides (used in settings → clear data).
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}

/// A single field override record.
class OverrideRecord {
  final String value;
  final String? originalValue;
  final DateTime timestamp;

  const OverrideRecord({
    required this.value,
    this.originalValue,
    required this.timestamp,
  });

  bool get hasOriginal => originalValue != null && originalValue != value;

  Map<String, dynamic> toJson() => {
    'value': value,
    'original': originalValue,
    'timestamp': timestamp.toIso8601String(),
  };

  factory OverrideRecord.fromJson(Map<String, dynamic> json) => OverrideRecord(
    value: json['value'] ?? '',
    originalValue: json['original'],
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'])
        : DateTime.now(),
  );
}
