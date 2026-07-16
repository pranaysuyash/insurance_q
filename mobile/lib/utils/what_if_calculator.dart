/// Pure calculation logic for the What-If Calculator.
///
/// Extracted from WhatIfCalculatorScreen for testability and reuse.
class WhatIfCalculator {
  final double coverageMultiplier;
  final double deductibleMultiplier;
  final bool includeMaternity;
  final bool includeDaycare;
  final bool includePrePostHospital;

  const WhatIfCalculator({
    this.coverageMultiplier = 1.0,
    this.deductibleMultiplier = 1.0,
    this.includeMaternity = true,
    this.includeDaycare = true,
    this.includePrePostHospital = true,
  });

  /// Estimate premium based on multipliers and coverage toggles.
  ///
  /// Formula:
  ///   factor = coverageMultiplier
  ///   if deductibleMultiplier > 1: factor *= 0.85  (higher deductible = lower premium)
  ///   if deductibleMultiplier < 1: factor *= 1.15  (lower deductible = higher premium)
  ///   if maternity: factor *= 1.08
  ///   if daycare: factor *= 1.03
  ///   if pre/post hospitalization: factor *= 1.05
  ///   estimated = basePremium * factor (rounded to nearest integer)
  double estimatePremium(double basePremium) {
    double factor = coverageMultiplier;
    if (deductibleMultiplier > 1) {
      factor *= 0.85;
    } else if (deductibleMultiplier < 1) {
      factor *= 1.15;
    }
    if (includeMaternity) factor *= 1.08;
    if (includeDaycare) factor *= 1.03;
    if (includePrePostHospital) factor *= 1.05;
    return (basePremium * factor).roundToDouble();
  }

  /// Estimate coverage amount based on multiplier.
  double estimateCoverage(double baseCoverage) {
    return (baseCoverage * coverageMultiplier).roundToDouble();
  }

  /// Estimate deductible based on multiplier.
  double estimateDeductible(double baseDeductible) {
    return (baseDeductible * deductibleMultiplier).roundToDouble();
  }

  /// Format a currency amount to a human-readable string.
  static String formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)} L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}
