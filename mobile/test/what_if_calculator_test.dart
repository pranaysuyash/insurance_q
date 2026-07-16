import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/utils/what_if_calculator.dart';

void main() {
  group('WhatIfCalculator', () {
    group('estimatePremium', () {
      const basePremium = 30000.0;

      test('returns base premium when all multipliers are default (1.0) and all toggles off', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        final result = calc.estimatePremium(basePremium);
        expect(result, basePremium);
      });

      test('higher coverage increases premium linearly', () {
        final calc2x = WhatIfCalculator(
          coverageMultiplier: 2.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        final calc3x = WhatIfCalculator(
          coverageMultiplier: 3.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        expect(calc2x.estimatePremium(basePremium), 60000);
        expect(calc3x.estimatePremium(basePremium), 90000);
      });

      test('lower coverage reduces premium proportionally', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 0.5,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        expect(calc.estimatePremium(basePremium), 15000);
      });

      test('higher deductible reduces premium by 15%', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 2.0, // > 1 → factor *= 0.85
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        // 30000 * 1.0 * 0.85 = 25500
        expect(calc.estimatePremium(basePremium), 25500);
      });

      test('lower deductible increases premium by 15%', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 0.5, // < 1 → factor *= 1.15
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        // 30000 * 1.0 * 1.15 = 34500
        expect(calc.estimatePremium(basePremium), 34500);
      });

      test('deductible at exactly 1.0 has no multiplier effect', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        expect(calc.estimatePremium(basePremium), basePremium);
      });

      test('maternity toggle adds 8% to premium', () {
        final calcWith = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: true,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        final calcWithout = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        // 30000 * 1.08 = 32400
        expect(calcWith.estimatePremium(basePremium), 32400);
        expect(calcWithout.estimatePremium(basePremium), 30000);
      });

      test('daycare toggle adds 3% to premium', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: true,
          includePrePostHospital: false,
        );
        // 30000 * 1.03 = 30900
        expect(calc.estimatePremium(basePremium), 30900);
      });

      test('pre/post hospitalization toggle adds 5% to premium', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: true,
        );
        // 30000 * 1.05 = 31500
        expect(calc.estimatePremium(basePremium), 31500);
      });

      test('all toggles combined multiply additively', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: true,
          includeDaycare: true,
          includePrePostHospital: true,
        );
        // 30000 * 1.08 * 1.03 * 1.05 = 30000 * 1.16802 = 35040.6 → 35041
        expect(calc.estimatePremium(basePremium), 35041);
      });

      test('coverage + deductible interact correctly', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 2.0,
          deductibleMultiplier: 2.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        // 30000 * 2.0 * 0.85 = 51000
        expect(calc.estimatePremium(basePremium), 51000);
      });

      test('all parameters combined produce reasonable output', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.5,
          deductibleMultiplier: 0.5,
          includeMaternity: true,
          includeDaycare: true,
          includePrePostHospital: true,
        );
        // factor = 1.5 * 1.15 * 1.08 * 1.03 * 1.05 = 1.5 * 1.15 * 1.16982 = 2.018...
        final result = calc.estimatePremium(basePremium);
        // Should be higher than base (30000) due to lower deductible + all toggles + 1.5x coverage
        expect(result, greaterThan(basePremium));
        // Should be less than 3x base (reasonable upper bound for 1.5x coverage)
        expect(result, lessThan(basePremium * 3));
      });

      test('handles zero base premium gracefully', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 2.0,
          includeMaternity: true,
          includeDaycare: true,
          includePrePostHospital: true,
        );
        expect(calc.estimatePremium(0), 0);
      });

      test('handles very large base premium', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 1.0,
          deductibleMultiplier: 1.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        expect(calc.estimatePremium(1000000), 1000000);
      });
    });

    group('estimateCoverage', () {
      const baseCoverage = 2500000.0;

      test('returns base coverage at 1.0x multiplier', () {
        final calc = WhatIfCalculator(coverageMultiplier: 1.0);
        expect(calc.estimateCoverage(baseCoverage), baseCoverage);
      });

      test('doubles coverage at 2.0x multiplier', () {
        final calc = WhatIfCalculator(coverageMultiplier: 2.0);
        expect(calc.estimateCoverage(baseCoverage), 5000000);
      });

      test('halves coverage at 0.5x multiplier', () {
        final calc = WhatIfCalculator(coverageMultiplier: 0.5);
        expect(calc.estimateCoverage(baseCoverage), 1250000);
      });

      test('triples coverage at 3.0x multiplier (max slider)', () {
        final calc = WhatIfCalculator(coverageMultiplier: 3.0);
        expect(calc.estimateCoverage(baseCoverage), 7500000);
      });

      test('handles zero base coverage', () {
        final calc = WhatIfCalculator(coverageMultiplier: 2.0);
        expect(calc.estimateCoverage(0), 0);
      });
    });

    group('estimateDeductible', () {
      const baseDeductible = 10000.0;

      test('returns base deductible at 1.0x multiplier', () {
        final calc = WhatIfCalculator(deductibleMultiplier: 1.0);
        expect(calc.estimateDeductible(baseDeductible), baseDeductible);
      });

      test('doubles deductible at 2.0x multiplier', () {
        final calc = WhatIfCalculator(deductibleMultiplier: 2.0);
        expect(calc.estimateDeductible(baseDeductible), 20000);
      });

      test('halves deductible at 0.5x multiplier', () {
        final calc = WhatIfCalculator(deductibleMultiplier: 0.5);
        expect(calc.estimateDeductible(baseDeductible), 5000);
      });
    });

    group('formatCurrency', () {
      test('formats amounts under 1000 as plain number', () {
        expect(WhatIfCalculator.formatCurrency(500), '₹500');
        expect(WhatIfCalculator.formatCurrency(999), '₹999');
      });

      test('formats amounts in thousands as K', () {
        expect(WhatIfCalculator.formatCurrency(1000), '₹1.0K');
        expect(WhatIfCalculator.formatCurrency(15000), '₹15.0K');
        expect(WhatIfCalculator.formatCurrency(99999), '₹100.0K');
      });

      test('formats amounts in lakhs as L', () {
        expect(WhatIfCalculator.formatCurrency(100000), '₹1.0 L');
        expect(WhatIfCalculator.formatCurrency(317050), '₹3.2 L');
        expect(WhatIfCalculator.formatCurrency(2500000), '₹25.0 L');
      });

      test('formats amounts in crores as Cr', () {
        expect(WhatIfCalculator.formatCurrency(10000000), '₹1.0 Cr');
        expect(WhatIfCalculator.formatCurrency(25000000), '₹2.5 Cr');
      });

      test('formats zero as ₹0', () {
        expect(WhatIfCalculator.formatCurrency(0), '₹0');
      });
    });

    group('edge cases', () {
      test('premium with coverage=0.5x and high deductible', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 0.5,
          deductibleMultiplier: 2.0,
          includeMaternity: false,
          includeDaycare: false,
          includePrePostHospital: false,
        );
        // 30000 * 0.5 * 0.85 = 12750
        expect(calc.estimatePremium(30000), 12750);
      });

      test('premium with coverage=3.0x and low deductible with all toggles', () {
        final calc = WhatIfCalculator(
          coverageMultiplier: 3.0,
          deductibleMultiplier: 0.5,
          includeMaternity: true,
          includeDaycare: true,
          includePrePostHospital: true,
        );
        // 30000 * 3.0 * 1.15 * 1.08 * 1.03 * 1.05
        final result = calc.estimatePremium(30000);
        // Should be significantly higher than base
        expect(result, greaterThan(30000));
        expect(result, greaterThan(100000));
      });

      test('consistency: doubling coverage exactly doubles output (no toggles)', () {
        final calc1x = WhatIfCalculator(coverageMultiplier: 1.0, includeMaternity: false, includeDaycare: false, includePrePostHospital: false);
        final calc2x = WhatIfCalculator(coverageMultiplier: 2.0, includeMaternity: false, includeDaycare: false, includePrePostHospital: false);
        expect(calc2x.estimatePremium(20000), calc1x.estimatePremium(20000) * 2);
      });
    });
  });
}
