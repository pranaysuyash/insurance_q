import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('HomePolicyFields — parsing and serialization', () {
    test('fromJson parses all fields correctly', () {
      final fields = HomePolicyFields.fromJson({
        'property_address': '42, MG Road, Bangalore 560001',
        'building_sum_insured': 5000000,
        'contents_sum_insured': 2000000,
        'rebuild_cost': 5500000,
        'perils_covered': ['Fire', 'Flood', 'Earthquake', 'Burglary', 'Storm'],
        'perils_excluded': ['War', 'Nuclear risk'],
        'add_on_covers': ['Jewellery Cover', 'Domestic Help Cover'],
        'deductible': 5000,
        'structure_type': 'Apartment',
        'policy_type': 'Home Comprehensive',
        'occupancy_type': 'Owner occupied',
        'construction_type': 'RCC framed',
        'underinsurance_clause': 'Average clause applies — if underinsured, claim reduced proportionately',
        'year_built': 2018,
        'escalation_clause': '10% annual automatic increase in SI',
      });

      expect(fields.propertyAddress, '42, MG Road, Bangalore 560001');
      expect(fields.buildingSumInsured, 5000000);
      expect(fields.contentsSumInsured, 2000000);
      expect(fields.rebuildCost, 5500000);
      expect(fields.perilsCovered, ['Fire', 'Flood', 'Earthquake', 'Burglary', 'Storm']);
      expect(fields.perilsExcluded, ['War', 'Nuclear risk']);
      expect(fields.addOnCovers, ['Jewellery Cover', 'Domestic Help Cover']);
      expect(fields.deductible, 5000);
      expect(fields.structureType, 'Apartment');
      expect(fields.policyType, 'Home Comprehensive');
      expect(fields.occupancyType, 'Owner occupied');
      expect(fields.constructionType, 'RCC framed');
      expect(fields.underinsuranceClause, 'Average clause applies — if underinsured, claim reduced proportionately');
      expect(fields.yearBuilt, 2018);
      expect(fields.escalationClause, '10% annual automatic increase in SI');
    });

    test('fromJson handles null fields', () {
      final fields = HomePolicyFields.fromJson({});

      expect(fields.propertyAddress, isNull);
      expect(fields.buildingSumInsured, isNull);
      expect(fields.contentsSumInsured, isNull);
      expect(fields.rebuildCost, isNull);
      expect(fields.perilsCovered, isEmpty);
      expect(fields.perilsExcluded, isEmpty);
      expect(fields.addOnCovers, isEmpty);
      expect(fields.deductible, isNull);
      expect(fields.structureType, isNull);
      expect(fields.policyType, isNull);
      expect(fields.occupancyType, isNull);
      expect(fields.constructionType, isNull);
      expect(fields.underinsuranceClause, isNull);
      expect(fields.yearBuilt, isNull);
      expect(fields.escalationClause, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = HomePolicyFields(
        propertyAddress: '42, MG Road, Bangalore 560001',
        buildingSumInsured: 5000000,
        contentsSumInsured: 2000000,
        rebuildCost: 5500000,
        perilsCovered: ['Fire', 'Flood'],
        perilsExcluded: ['War'],
        addOnCovers: ['Jewellery Cover'],
        deductible: 5000,
        structureType: 'Apartment',
        policyType: 'Home Comprehensive',
        occupancyType: 'Owner occupied',
        constructionType: 'RCC framed',
        underinsuranceClause: 'Average clause applies',
      );

      final json = original.toJson();
      final restored = HomePolicyFields.fromJson(json);

      expect(restored.propertyAddress, original.propertyAddress);
      expect(restored.buildingSumInsured, original.buildingSumInsured);
      expect(restored.contentsSumInsured, original.contentsSumInsured);
      expect(restored.rebuildCost, original.rebuildCost);
      expect(restored.perilsCovered, original.perilsCovered);
      expect(restored.perilsExcluded, original.perilsExcluded);
      expect(restored.addOnCovers, original.addOnCovers);
      expect(restored.deductible, original.deductible);
      expect(restored.structureType, original.structureType);
      expect(restored.policyType, original.policyType);
      expect(restored.occupancyType, original.occupancyType);
      expect(restored.constructionType, original.constructionType);
      expect(restored.underinsuranceClause, original.underinsuranceClause);
      expect(restored.yearBuilt, original.yearBuilt);
      expect(restored.escalationClause, original.escalationClause);
    });

    test('round-trip preserves yearBuilt and escalationClause', () {
      final original = HomePolicyFields(
        yearBuilt: 2018,
        escalationClause: '10% annual automatic increase',
      );

      final json = original.toJson();
      final restored = HomePolicyFields.fromJson(json);

      expect(restored.yearBuilt, 2018);
      expect(restored.escalationClause, '10% annual automatic increase');
    });

    test('hasAnyFields returns true when any field is populated', () {
      expect(
        HomePolicyFields().hasAnyFields,
        isFalse,
        reason: 'empty should return false',
      );
      expect(
        HomePolicyFields(propertyAddress: 'test').hasAnyFields,
        isTrue,
        reason: 'propertyAddress should return true',
      );
      expect(
        HomePolicyFields(buildingSumInsured: 10000).hasAnyFields,
        isTrue,
        reason: 'buildingSumInsured should return true',
      );
      expect(
        HomePolicyFields(perilsCovered: ['Fire']).hasAnyFields,
        isTrue,
        reason: 'perilsCovered should return true',
      );
      expect(
        HomePolicyFields(occupancyType: 'Rented out').hasAnyFields,
        isTrue,
        reason: 'occupancyType should return true',
      );
      expect(
        HomePolicyFields(constructionType: 'Load bearing').hasAnyFields,
        isTrue,
        reason: 'constructionType should return true',
      );
      expect(
        HomePolicyFields(underinsuranceClause: 'Average clause').hasAnyFields,
        isTrue,
        reason: 'underinsuranceClause should return true',
      );
      expect(
        HomePolicyFields(yearBuilt: 2018).hasAnyFields,
        isTrue,
        reason: 'yearBuilt should return true',
      );
      expect(
        HomePolicyFields(escalationClause: '10% increase').hasAnyFields,
        isTrue,
        reason: 'escalationClause should return true',
      );
    });

    test('hasAnyFields combined gating works with PolicySummary', () {
      final summary = PolicySummary(
        documentId: 'test-doc',
        documentType: 'home',
        extractedAt: DateTime.now(),
        homeFields: HomePolicyFields(
          propertyAddress: '42, MG Road',
          buildingSumInsured: 5000000,
          perilsCovered: ['Fire', 'Flood'],
        ),
      );

      expect(summary.homeFields?.hasAnyFields, isTrue);
      expect(summary.homeFields?.propertyAddress, '42, MG Road');
      expect(summary.homeFields?.buildingSumInsured, 5000000);
    });

    test('PolicySummary round-trip preserves homeFields', () {
      final original = PolicySummary(
        documentId: 'doc-1',
        documentType: 'home',
        extractedAt: DateTime.now(),
        homeFields: HomePolicyFields(
          propertyAddress: '42, MG Road, Bangalore 560001',
          buildingSumInsured: 5000000,
          rebuildCost: 5500000,
        ),
      );

      final json = original.toJson();
      final restored = PolicySummary.fromJson(json);

      expect(restored.documentType, 'home');
      expect(restored.homeFields?.propertyAddress, '42, MG Road, Bangalore 560001');
      expect(restored.homeFields?.buildingSumInsured, 5000000);
      expect(restored.homeFields?.rebuildCost, 5500000);
    });
  });
}
