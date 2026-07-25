import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('LifePolicyFields', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'life_assured_name': 'Mr. Rajesh Kumar',
        'sum_assured': 5000000.0,
        'policy_term_years': 20,
        'premium_paying_term_years': 10,
        'nominee_name': 'Mrs. Sunita Kumar',
        'nominee_share': '100%',
        'maturity_date': '2044-05-31',
        'maturity_amount': 5000000.0,
        'accidental_death_benefit': 2500000.0,
        'terminal_illness_benefit': 'Advance payout of 50% of sum assured',
        'rider_details': ['Critical Illness Rider', 'Waiver of Premium'],
        'suicide_exclusion': 'First 12 months',
        'free_look_period': '30 days',
        'grace_period': '30 days',
        'surrender_value': 'Available after 3 years',
        'death_benefit_type': 'Level',
        'policy_type_detail': 'Term Life',
      };

      final fields = LifePolicyFields.fromJson(json);

      expect(fields.lifeAssuredName, 'Mr. Rajesh Kumar');
      expect(fields.sumAssured, 5000000.0);
      expect(fields.policyTermYears, 20);
      expect(fields.premiumPayingTermYears, 10);
      expect(fields.nomineeName, 'Mrs. Sunita Kumar');
      expect(fields.nomineeShare, '100%');
      expect(fields.maturityDate, '2044-05-31');
      expect(fields.maturityAmount, 5000000.0);
      expect(fields.accidentalDeathBenefit, 2500000.0);
      expect(fields.terminalIllnessBenefit,
          'Advance payout of 50% of sum assured');
      expect(fields.riderDetails,
          ['Critical Illness Rider', 'Waiver of Premium']);
      expect(fields.suicideExclusion, 'First 12 months');
      expect(fields.freeLookPeriod, '30 days');
      expect(fields.gracePeriod, '30 days');
      expect(fields.surrenderValue, 'Available after 3 years');
      expect(fields.deathBenefitType, 'Level');
      expect(fields.policyTypeDetail, 'Term Life');
    });

    test('fromJson handles null values', () {
      final json = <String, dynamic>{};
      final fields = LifePolicyFields.fromJson(json);

      expect(fields.lifeAssuredName, isNull);
      expect(fields.sumAssured, isNull);
      expect(fields.policyTermYears, isNull);
      expect(fields.premiumPayingTermYears, isNull);
      expect(fields.nomineeName, isNull);
      expect(fields.nomineeShare, isNull);
      expect(fields.maturityDate, isNull);
      expect(fields.maturityAmount, isNull);
      expect(fields.accidentalDeathBenefit, isNull);
      expect(fields.terminalIllnessBenefit, isNull);
      expect(fields.riderDetails, isEmpty);
      expect(fields.suicideExclusion, isNull);
      expect(fields.freeLookPeriod, isNull);
      expect(fields.gracePeriod, isNull);
      expect(fields.surrenderValue, isNull);
      expect(fields.deathBenefitType, isNull);
      expect(fields.policyTypeDetail, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = LifePolicyFields(
        lifeAssuredName: 'Ms. Priya Sharma',
        sumAssured: 10000000.0,
        policyTermYears: 30,
        nomineeName: 'Mr. Vikram Sharma',
        nomineeShare: '100%',
        riderDetails: ['Accidental Death Benefit'],
        policyTypeDetail: 'ULIP',
      );

      final json = original.toJson();
      final reconstructed = LifePolicyFields.fromJson(json);

      expect(reconstructed.lifeAssuredName, 'Ms. Priya Sharma');
      expect(reconstructed.sumAssured, 10000000.0);
      expect(reconstructed.policyTermYears, 30);
      expect(reconstructed.nomineeName, 'Mr. Vikram Sharma');
      expect(reconstructed.nomineeShare, '100%');
      expect(reconstructed.riderDetails, ['Accidental Death Benefit']);
      expect(reconstructed.policyTypeDetail, 'ULIP');
      expect(reconstructed.premiumPayingTermYears, isNull);
      expect(reconstructed.maturityDate, isNull);
    });

    test('hasAnyFields returns false when all fields are null/empty', () {
      final fields = LifePolicyFields();
      expect(fields.hasAnyFields, false);
    });

    test('hasAnyFields returns true when any field is populated', () {
      expect(LifePolicyFields(lifeAssuredName: 'Test').hasAnyFields, true);
      expect(LifePolicyFields(sumAssured: 500000.0).hasAnyFields, true);
      expect(LifePolicyFields(policyTermYears: 20).hasAnyFields, true);
      expect(LifePolicyFields(nomineeName: 'Nominee').hasAnyFields, true);
      expect(LifePolicyFields(riderDetails: ['Rider']).hasAnyFields, true);
      expect(LifePolicyFields(deathBenefitType: 'Level').hasAnyFields, true);
      expect(LifePolicyFields(policyTypeDetail: 'Endowment').hasAnyFields, true);
    });
  });

  group('PolicySummary life fields', () {
    test('toJson includes life_fields key when lifeFields is null', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'Life Insurance',
        extractedAt: DateTime(2024, 1, 1),
      );

      final json = summary.toJson();
      expect(json.containsKey('life_fields'), true);
      expect(json['life_fields'], isNull);
    });

    test('toJson includes life_fields when lifeFields is set', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'Life Insurance',
        extractedAt: DateTime(2024, 1, 1),
        lifeFields: LifePolicyFields(
          lifeAssuredName: 'Test Person',
          sumAssured: 5000000.0,
        ),
      );

      final json = summary.toJson();
      expect(json['life_fields'], isA<Map<String, dynamic>>());
      expect((json['life_fields'] as Map)['life_assured_name'], 'Test Person');
      expect((json['life_fields'] as Map)['sum_assured'], 5000000.0);
    });

    test('fromJson reconstructs life fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Life Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
        'life_fields': {
          'policy_term_years': 25,
          'nominee_name': 'Spouse',
        },
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.lifeFields, isNotNull);
      expect(summary.lifeFields!.policyTermYears, 25);
      expect(summary.lifeFields!.nomineeName, 'Spouse');
    });

    test('fromJson handles missing life_fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Health Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.lifeFields, isNull);
    });
  });
}
