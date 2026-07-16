import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/policy_summary.dart';
import 'app_state_store.dart';

/// Preventive Health Reminders — smart tips based on policy types.
///
/// Generates actionable reminders like:
/// - "Your health policy covers free annual checkups — use it before Dec 31"
/// - "Time to review your life insurance beneficiaries"
/// - "Your motor policy includes roadside assistance — save the helpline"
///
/// Tips are generated from policy summaries and stored to avoid repeats.
class PreventiveHealthService {
  static Box get _box => Hive.box(AppStateStore.boxName);

  /// Key for storing shown tip timestamps to prevent repeats.
  static const _shownTipsKey = 'preventive_health_shown_tips';

  /// Get all available tips for the given policy summaries.
  /// Only returns tips that haven't been shown in the last 7 days.
  static List<HealthTip> getAvailableTips(List<PolicySummary> summaries) {
    final allTips = _generateTips(summaries);
    final shownTips = _getShownTips();

    return allTips.where((tip) {
      final lastShown = shownTips[tip.id];
      if (lastShown == null) return true;
      // Don't show the same tip more than once every 7 days
      return DateTime.now().difference(lastShown).inDays >= 7;
    }).toList();
  }

  /// Mark a tip as shown so it won't be repeated for 7 days.
  static Future<void> markTipShown(String tipId) async {
    final shownTips = _getShownTips();
    shownTips[tipId] = DateTime.now();
    // Prune entries older than 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    shownTips.removeWhere((_, time) => time.isBefore(cutoff));
    await _box.put(_shownTipsKey, _serializeTimestamps(shownTips));
  }

  /// Mark all currently visible tips as shown.
  static Future<void> markAllShown(List<HealthTip> tips) async {
    for (final tip in tips) {
      await markTipShown(tip.id);
    }
  }

  /// Generate tips based on policy summaries.
  static List<HealthTip> _generateTips(List<PolicySummary> summaries) {
    final tips = <HealthTip>[];
    final seenTypes = <String>{};

    for (final summary in summaries) {
      final type = summary.documentType.toLowerCase();

      // Health insurance tips (once per type, not per policy)
      if (type.contains('health') || type.contains('mediclaim')) {
        if (!seenTypes.add('health')) continue;
        tips.add(HealthTip(
          id: 'health_annual_checkup_${summary.documentId}',
          icon: Icons.medical_services,
          title: 'Free Annual Checkup',
          body: 'Your health policy likely covers a free annual health checkup. '
              'Contact ${summary.insurer ?? "your insurer"} to book before year end.',
          category: 'health',
          priority: 2,
        ));

        tips.add(HealthTip(
          id: 'health_wellness_${summary.documentId}',
          icon: Icons.fitness_center,
          title: 'Wellness Benefits',
          body: 'Many health policies cover gym memberships, yoga classes, or '
              'wellness programs. Check your policy benefits for wellness perks.',
          category: 'health',
          priority: 1,
        ));

        if (summary.deductible != null && summary.deductible! > 0) {
          tips.add(HealthTip(
            id: 'health_deductible_${summary.documentId}',
            icon: Icons.receipt_long,
            title: 'Deductible Reminder',
            body: 'Your ₹${summary.deductible!.toStringAsFixed(0)} deductible '
                'may reset annually. Plan major treatments accordingly.',
            category: 'health',
            priority: 1,
          ));
        }
      }

      // Motor insurance tips (once per type)
      if (type.contains('motor') || type.contains('auto') || type.contains('vehicle')) {
        if (!seenTypes.add('motor')) continue;
        tips.add(HealthTip(
          id: 'motor_puc_${summary.documentId}',
          icon: Icons.car_repair,
          title: 'PUC Certificate',
          body: 'Ensure your vehicle has a valid Pollution Under Control (PUC) '
              "certificate. It's required for insurance claims.",
          category: 'motor',
          priority: 2,
        ));

        tips.add(HealthTip(
          id: 'motor_roadside_${summary.documentId}',
          icon: Icons.directions_car,
          title: 'Roadside Assistance',
          body: 'Save your insurer\'s roadside assistance helpline: '
              '${summary.insurerHelpline ?? "Check your policy document"}.',
          category: 'motor',
          priority: 1,
        ));
      }

      // Life insurance tips (once per type)
      if (type.contains('life') || type.contains('term')) {
        if (!seenTypes.add('life')) continue;
        tips.add(HealthTip(
          id: 'life_beneficiary_${summary.documentId}',
          icon: Icons.people,
          title: 'Review Beneficiaries',
          body: 'Life events like marriage, children, or property purchase '
              'may require updating your policy beneficiaries.',
          category: 'life',
          priority: 2,
        ));

        tips.add(HealthTip(
          id: 'life_nominee_${summary.documentId}',
          icon: Icons.how_to_reg,
          title: 'Verify Nominee Details',
          body: 'Ensure your nominee details are current and correct. '
              'Outdated nominees can complicate claims.',
          category: 'life',
          priority: 1,
        ));
      }

      // General tips for all policies
      if (summary.isExpiringSoon) {
        final daysLeft = summary.daysUntilExpiry;
        tips.add(HealthTip(
          id: 'renewal_reminder_${summary.documentId}',
          icon: Icons.event,
          title: 'Renewal Due in $daysLeft Days',
          body: 'Your ${summary.documentType} policy expires on '
              '${summary.formattedExpiryDate}. Start the renewal process early '
              'to avoid coverage gaps.',
          category: 'general',
          priority: 3,
        ));
      }

      // Family coverage tip
      if (summary.documentType.toLowerCase().contains('health')) {
        tips.add(HealthTip(
          id: 'family_coverage_${summary.documentId}',
          icon: Icons.family_restroom,
          title: 'Family Coverage Check',
          body: 'Verify all family members are covered under your health policy. '
              'Missing dependents could mean unexpected out-of-pocket costs.',
          category: 'family',
          priority: 2,
        ));
      }
    }

    // Sort by priority (highest first)
    tips.sort((a, b) => b.priority.compareTo(a.priority));
    return tips;
  }

  static Map<String, DateTime> _getShownTips() {
    final raw = _box.get(_shownTipsKey);
    if (raw == null) return {};
    try {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(
          k.toString(),
          DateTime.parse(v.toString()),
        ));
      }
    } catch (_) {}
    return {};
  }

  static Map<String, String> _serializeTimestamps(Map<String, DateTime> map) {
    return map.map((k, v) => MapEntry(k, v.toIso8601String()));
  }
}

/// A single preventive health tip.
class HealthTip {
  final String id;
  final IconData icon;
  final String title;
  final String body;
  final String category;
  final int priority; // 1 = low, 2 = medium, 3 = high

  const HealthTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.category,
    this.priority = 1,
  });
}
