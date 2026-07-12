import 'package:flutter/material.dart';

/// Canonical insurance policy types.
///
/// This is the single source of truth for type classification across the app.
/// Every place that needs to know "is this a health policy?" should use
/// [classifyPolicyType] instead of fragile string matching like
/// `.contains('health')`, which misses Indian product names such as
/// "Mediclaim", "Family Floater", "Group Mediclaim", etc.
enum PolicyType {
  health,
  auto,
  life,
  home,
  travel,
  other,
}

/// Classifies a free-form document type string (from the backend LLM extraction,
/// the keyword classifier, or filename inference) into a canonical [PolicyType].
///
/// Handles:
/// - Canonical English: "Health Insurance", "Auto Insurance", etc.
/// - Lowercase tokens: "health", "auto", "life"
/// - Indian product names: "Mediclaim", "Family Floater", "Two Wheeler",
///   "Term Plan", "ULIP", "Endowment", "Critical Illness", "Group Medical"
/// - Snake_case: "health_insurance", "auto_insurance"
PolicyType classifyPolicyType(String? documentType) {
  if (documentType == null || documentType.trim().isEmpty) {
    return PolicyType.other;
  }

  final t = documentType.toLowerCase().replaceAll('_', ' ').trim();

  // Health — covers Mediclaim, Family Floater, Group Medical, Critical Illness
  if (t.contains('health') ||
      t.contains('mediclaim') ||
      t.contains('medical') ||
      t.contains('family floater') ||
      t.contains('group medical') ||
      t.contains('hospital') ||
      t.contains('critical illness') ||
      t.contains('healthguard') ||
      t.contains(' mediclaim')) {
    return PolicyType.health;
  }

  // Auto — covers Motor, Two Wheeler, Bike, Car, Commercial Vehicle
  if (t.contains('auto') ||
      t.contains('motor') ||
      t.contains('car') ||
      t.contains('vehicle') ||
      t.contains('two wheeler') ||
      t.contains('two-wheeler') ||
      t.contains('bike') ||
      t.contains('commercial vehicle')) {
    return PolicyType.auto;
  }

  // Life — covers Term Plan, ULIP, Endowment, Pension
  if (t.contains('life') ||
      t.contains('term') ||
      t.contains('ulip') ||
      t.contains('endowment') ||
      t.contains('pension') ||
      t.contains('annuity')) {
    return PolicyType.life;
  }

  // Home — covers Fire, Burglary, Property
  if (t.contains('home') ||
      t.contains('house') ||
      t.contains('property') ||
      t.contains('fire') ||
      t.contains('burglary')) {
    return PolicyType.home;
  }

  // Travel — covers Overseas, Trip
  if (t.contains('travel') ||
      t.contains('overseas') ||
      t.contains('trip')) {
    return PolicyType.travel;
  }

  return PolicyType.other;
}

/// Human-readable canonical name for display.
String canonicalTypeName(PolicyType type) {
  switch (type) {
    case PolicyType.health:
      return 'Health Insurance';
    case PolicyType.auto:
      return 'Auto Insurance';
    case PolicyType.life:
      return 'Life Insurance';
    case PolicyType.home:
      return 'Home Insurance';
    case PolicyType.travel:
      return 'Travel Insurance';
    case PolicyType.other:
      return 'Other Insurance';
  }
}

/// Icon for a policy type.
IconData iconForPolicyType(PolicyType type) {
  switch (type) {
    case PolicyType.health:
      return Icons.health_and_safety;
    case PolicyType.auto:
      return Icons.directions_car;
    case PolicyType.life:
      return Icons.favorite;
    case PolicyType.home:
      return Icons.home;
    case PolicyType.travel:
      return Icons.flight;
    case PolicyType.other:
      return Icons.shield;
  }
}

/// Color for a policy type.
Color colorForPolicyType(PolicyType type) {
  switch (type) {
    case PolicyType.health:
      return Colors.red;
    case PolicyType.auto:
      return Colors.blue;
    case PolicyType.life:
      return Colors.pink;
    case PolicyType.home:
      return Colors.deepPurple;
    case PolicyType.travel:
      return Colors.orange;
    case PolicyType.other:
      return Colors.indigo;
  }
}

/// Convenience wrappers that accept a raw string (for call sites that haven't
/// been migrated to hold a [PolicyType] directly).
IconData iconForDocumentType(String? documentType) =>
    iconForPolicyType(classifyPolicyType(documentType));

Color colorForDocumentType(String? documentType) =>
    colorForPolicyType(classifyPolicyType(documentType));
