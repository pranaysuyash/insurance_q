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
  asset,
  liability,
  marine,
  cyber,
  pet,
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
  if (t.contains('travel') || t.contains('overseas') || t.contains('trip')) {
    return PolicyType.travel;
  }

  // Asset — covers asset, property (distinct from home insurance)
  if (t.contains('asset insurance') || t == 'asset') {
    return PolicyType.asset;
  }

  // Liability — covers professional indemnity, public liability
  if (t.contains('liability') || t.contains('indemnity')) {
    return PolicyType.liability;
  }

  // Marine — covers marine, cargo, shipping
  if (t.contains('marine') || t.contains('cargo') || t.contains('shipping') || t.contains('boat')) {
    return PolicyType.marine;
  }

  // Cyber — covers cyber, data breach, ransomware
  if (t.contains('cyber') || t.contains('data breach') || t.contains('ransomware')) {
    return PolicyType.cyber;
  }

  // Pet — covers pet, animal, veterinary
  if (t.contains('pet') || t.contains('animal') || t.contains('veterinary')) {
    return PolicyType.pet;
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
    case PolicyType.asset:
      return 'Asset Insurance';
    case PolicyType.liability:
      return 'Liability Insurance';
    case PolicyType.marine:
      return 'Marine Insurance';
    case PolicyType.cyber:
      return 'Cyber Insurance';
    case PolicyType.pet:
      return 'Pet Insurance';
    case PolicyType.other:
      return 'Other Insurance';
  }
}

/// Icon for a policy type.
IconData iconForPolicyType(PolicyType type) {
  switch (type) {
    case PolicyType.health:
      return Icons.monitor_heart_rounded;
    case PolicyType.auto:
      return Icons.directions_car_filled_rounded;
    case PolicyType.life:
      return Icons.person_rounded;
    case PolicyType.home:
      return Icons.home_rounded;
    case PolicyType.travel:
      return Icons.flight_rounded;
    case PolicyType.asset:
      return Icons.account_balance_rounded;
    case PolicyType.liability:
      return Icons.gavel_rounded;
    case PolicyType.marine:
      return Icons.directions_boat_rounded;
    case PolicyType.cyber:
      return Icons.security_rounded;
    case PolicyType.pet:
      return Icons.pets_rounded;
    case PolicyType.other:
      return Icons.inventory_2_rounded;
  }
}

/// Color for a policy type.
Color colorForPolicyType(
  PolicyType type, {
  Brightness brightness = Brightness.light,
}) {
  final dark = brightness == Brightness.dark;
  switch (type) {
    case PolicyType.health:
      return dark ? const Color(0xFFFF879A) : const Color(0xFFB52F4B);
    case PolicyType.auto:
      return dark ? const Color(0xFF83B6FF) : const Color(0xFF2466B8);
    case PolicyType.life:
      return dark ? const Color(0xFFD7A0F5) : const Color(0xFF7B459C);
    case PolicyType.home:
      return dark ? const Color(0xFFB9A5FF) : const Color(0xFF6046AF);
    case PolicyType.travel:
      return dark ? const Color(0xFFFFB976) : const Color(0xFFA94E00);
    case PolicyType.asset:
      return dark ? const Color(0xFFB9A5FF) : const Color(0xFF5E35B1);
    case PolicyType.liability:
      return dark ? const Color(0xFFFF879A) : const Color(0xFFB52F4B);
    case PolicyType.marine:
      return dark ? const Color(0xFF80CBC4) : const Color(0xFF00695C);
    case PolicyType.cyber:
      return dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32);
    case PolicyType.pet:
      return dark ? const Color(0xFFFFE082) : const Color(0xFFF57F17);
    case PolicyType.other:
      return dark ? const Color(0xFFA8BED8) : const Color(0xFF40556D);
  }
}

/// Convenience wrappers that accept a raw string (for call sites that haven't
/// been migrated to hold a [PolicyType] directly).
IconData iconForDocumentType(String? documentType) =>
    iconForPolicyType(classifyPolicyType(documentType));

Color colorForDocumentType(String? documentType) =>
    colorForPolicyType(classifyPolicyType(documentType));
