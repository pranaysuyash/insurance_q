import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('HealthPolicyFields — parsing and serialization', () {
    test('fromJson parses all fields correctly', () {
      final fields = HealthPolicyFields.fromJson({
        'room_rent_cap': '2% of sum insured, max ₹5,000/day',
        'pre_existing_diseases': [
          'Diabetes (24-month waiting period)',
          'Hypertension (24-month waiting period)',
        ],
        'co_pay_percent': 10.0,
        'network_hospitals': '12,000+ hospitals nationwide',
        'maternity_cover': '₹50,000 after 9-month waiting period',
        'deductible_per_claim': 50000,
        'cumulative_bonus': '50% increase, max 100% of sum insured',
        'day_care_procedures': '160+ day care procedures covered',
        'consumables_cover': 'Up to ₹5,000 per claim',
        'ambulance_cover': 2500,
        'health_checkup_cover': 'Once every 3 years, up to ₹5,000',
        'pre_post_hospitalization_days': '30 days pre, 60 days post',
        'restoration_benefit': 'Full SI restored once per year',
        'critical_illness_list': [
          'Cancer',
          'Heart attack — first heart attack',
          'Kidney failure — end stage renal disease',
        ],
        'modern_treatment_cover': 'Robotic surgery, Uterine artery embolization covered',
        'moratorium_period': '5 years as per IRDAI 2026 guidelines',
        'pre_auth_time_limit': '3 hours for cashless approval',
        'domiciliary_hospitalization': 'Covered, max 7 days at home, subject to doctor certification',
        'sub_limits': [
          'Room rent: 2% of sum insured',
          'ICU: 4x room rent',
        ],
        'no_claim_bonus_percent': 50.0,
      });

      expect(fields.roomRentCap, '2% of sum insured, max ₹5,000/day');
      expect(fields.preExistingDiseases, [
        'Diabetes (24-month waiting period)',
        'Hypertension (24-month waiting period)',
      ]);
      expect(fields.coPayPercent, 10.0);
      expect(fields.networkHospitals, '12,000+ hospitals nationwide');
      expect(fields.maternityCover, '₹50,000 after 9-month waiting period');
      expect(fields.deductiblePerClaim, 50000);
      expect(fields.cumulativeBonus, '50% increase, max 100% of sum insured');
      expect(fields.dayCareProcedures, '160+ day care procedures covered');
      expect(fields.consumablesCover, 'Up to ₹5,000 per claim');
      expect(fields.ambulanceCover, 2500);
      expect(fields.healthCheckupCover, 'Once every 3 years, up to ₹5,000');
      expect(fields.prePostHospitalizationDays, '30 days pre, 60 days post');
      expect(fields.restorationBenefit, 'Full SI restored once per year');
      expect(fields.criticalIllnessList, [
        'Cancer',
        'Heart attack — first heart attack',
        'Kidney failure — end stage renal disease',
      ]);
      expect(fields.modernTreatmentCover,
          'Robotic surgery, Uterine artery embolization covered');
      expect(fields.moratoriumPeriod, '5 years as per IRDAI 2026 guidelines');
      expect(fields.preAuthTimeLimit, '3 hours for cashless approval');
      expect(fields.domiciliaryHospitalization,
          'Covered, max 7 days at home, subject to doctor certification');
      expect(fields.subLimits, [
        'Room rent: 2% of sum insured',
        'ICU: 4x room rent',
      ]);
      expect(fields.noClaimBonusPercent, 50.0);
    });

    test('fromJson handles null fields', () {
      final fields = HealthPolicyFields.fromJson({});

      expect(fields.roomRentCap, isNull);
      expect(fields.preExistingDiseases, isEmpty);
      expect(fields.coPayPercent, isNull);
      expect(fields.networkHospitals, isNull);
      expect(fields.maternityCover, isNull);
      expect(fields.deductiblePerClaim, isNull);
      expect(fields.cumulativeBonus, isNull);
      expect(fields.dayCareProcedures, isNull);
      expect(fields.consumablesCover, isNull);
      expect(fields.ambulanceCover, isNull);
      expect(fields.healthCheckupCover, isNull);
      expect(fields.prePostHospitalizationDays, isNull);
      expect(fields.restorationBenefit, isNull);
      expect(fields.criticalIllnessList, isEmpty);
      expect(fields.modernTreatmentCover, isNull);
      expect(fields.moratoriumPeriod, isNull);
      expect(fields.preAuthTimeLimit, isNull);
      expect(fields.domiciliaryHospitalization, isNull);
      expect(fields.subLimits, isEmpty);
      expect(fields.noClaimBonusPercent, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = HealthPolicyFields(
        roomRentCap: '2% of sum insured',
        preExistingDiseases: ['Diabetes (24 months)'],
        coPayPercent: 10.0,
        networkHospitals: '12,000+ hospitals',
        maternityCover: '₹50,000',
        deductiblePerClaim: 50000,
        cumulativeBonus: '50% max 100%',
        dayCareProcedures: '160+ procedures',
        consumablesCover: '₹5,000',
        ambulanceCover: 2500,
        healthCheckupCover: 'Every 3 years',
        prePostHospitalizationDays: '30 days pre, 60 days post',
        restorationBenefit: 'Full SI restored once',
        criticalIllnessList: ['Cancer', 'Heart attack'],
        modernTreatmentCover: 'Robotic surgery covered',
        moratoriumPeriod: '5 years',
        preAuthTimeLimit: '3 hours',
        domiciliaryHospitalization: 'Covered, max 7 days at home',
        subLimits: ['Room rent: 2% of SI', 'ICU: 4x room rent'],
        noClaimBonusPercent: 50.0,
      );

      final json = original.toJson();
      final restored = HealthPolicyFields.fromJson(json);

      expect(restored.roomRentCap, original.roomRentCap);
      expect(restored.preExistingDiseases, original.preExistingDiseases);
      expect(restored.coPayPercent, original.coPayPercent);
      expect(restored.networkHospitals, original.networkHospitals);
      expect(restored.maternityCover, original.maternityCover);
      expect(restored.deductiblePerClaim, original.deductiblePerClaim);
      expect(restored.cumulativeBonus, original.cumulativeBonus);
      expect(restored.dayCareProcedures, original.dayCareProcedures);
      expect(restored.consumablesCover, original.consumablesCover);
      expect(restored.ambulanceCover, original.ambulanceCover);
      expect(restored.healthCheckupCover, original.healthCheckupCover);
      expect(restored.prePostHospitalizationDays,
          original.prePostHospitalizationDays);
      expect(restored.restorationBenefit, original.restorationBenefit);
      expect(restored.criticalIllnessList, original.criticalIllnessList);
      expect(restored.modernTreatmentCover, original.modernTreatmentCover);
      expect(restored.moratoriumPeriod, original.moratoriumPeriod);
      expect(restored.preAuthTimeLimit, original.preAuthTimeLimit);
      expect(restored.domiciliaryHospitalization,
          original.domiciliaryHospitalization);
      expect(restored.subLimits, original.subLimits);
      expect(restored.noClaimBonusPercent, original.noClaimBonusPercent);
    });

    test('hasAnyFields returns true when any field is populated', () {
      expect(
        HealthPolicyFields().hasAnyFields,
        isFalse,
        reason: 'empty should return false',
      );
      expect(
        HealthPolicyFields(roomRentCap: 'test').hasAnyFields,
        isTrue,
        reason: 'roomRentCap should return true',
      );
      expect(
        HealthPolicyFields(coPayPercent: 10.0).hasAnyFields,
        isTrue,
        reason: 'coPayPercent should return true',
      );
      expect(
        HealthPolicyFields(preExistingDiseases: ['Diabetes']).hasAnyFields,
        isTrue,
        reason: 'preExistingDiseases should return true',
      );
      expect(
        HealthPolicyFields(prePostHospitalizationDays: '30/60 days')
            .hasAnyFields,
        isTrue,
        reason: 'prePostHospitalizationDays should return true',
      );
      expect(
        HealthPolicyFields(restorationBenefit: 'Full SI restored').hasAnyFields,
        isTrue,
        reason: 'restorationBenefit should return true',
      );
      expect(
        HealthPolicyFields(criticalIllnessList: ['Cancer']).hasAnyFields,
        isTrue,
        reason: 'criticalIllnessList should return true',
      );
      expect(
        HealthPolicyFields(modernTreatmentCover: 'Robotic surgery')
            .hasAnyFields,
        isTrue,
        reason: 'modernTreatmentCover should return true',
      );
      expect(
        HealthPolicyFields(moratoriumPeriod: '5 years').hasAnyFields,
        isTrue,
        reason: 'moratoriumPeriod should return true',
      );
      expect(
        HealthPolicyFields(preAuthTimeLimit: '3 hours').hasAnyFields,
        isTrue,
        reason: 'preAuthTimeLimit should return true',
      );
      expect(
        HealthPolicyFields(domiciliaryHospitalization: 'Covered').hasAnyFields,
        isTrue,
        reason: 'domiciliaryHospitalization should return true',
      );
      expect(
        HealthPolicyFields(subLimits: ['Room rent: 2%']).hasAnyFields,
        isTrue,
        reason: 'subLimits should return true',
      );
      expect(
        HealthPolicyFields(noClaimBonusPercent: 50.0).hasAnyFields,
        isTrue,
        reason: 'noClaimBonusPercent should return true',
      );
    });

    test('hasAnyFields combined gating works with PolicySummary', () {
      final summary = PolicySummary(
        documentId: 'test-doc',
        documentType: 'health',
        extractedAt: DateTime.now(),
        healthFields: HealthPolicyFields(
          roomRentCap: '2% of sum insured',
          networkHospitals: '12,000+ hospitals',
          coPayPercent: 10.0,
        ),
      );

      expect(summary.healthFields?.hasAnyFields, isTrue);
      expect(summary.healthFields?.roomRentCap, '2% of sum insured');
      expect(summary.healthFields?.networkHospitals, '12,000+ hospitals');
      expect(summary.healthFields?.coPayPercent, 10.0);
    });

    test('PolicySummary round-trip preserves healthFields', () {
      final original = PolicySummary(
        documentId: 'doc-1',
        documentType: 'health',
        extractedAt: DateTime.now(),
        healthFields: HealthPolicyFields(
          roomRentCap: '2% of sum insured',
          preExistingDiseases: ['Diabetes (24 months)'],
          ambulanceCover: 2500,
        ),
      );

      final json = original.toJson();
      final restored = PolicySummary.fromJson(json);

      expect(restored.documentType, 'health');
      expect(restored.healthFields?.roomRentCap, '2% of sum insured');
      expect(restored.healthFields?.preExistingDiseases, ['Diabetes (24 months)']);
      expect(restored.healthFields?.ambulanceCover, 2500);
    });

    test('PolicySummary without healthFields defaults to null', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'health',
        extractedAt: DateTime.now(),
      );

      expect(summary.healthFields, isNull);
    });
  });
}
