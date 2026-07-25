import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('MarinePolicyFields — fromJson', () {
    test('parses all fields from a full JSON map', () {
      final json = {
        'policy_type_marine': 'Marine Cargo',
        'vessel_name': 'MV Ocean Queen',
        'voyage_details': 'Mumbai to Singapore via Colombo',
        'cargo_description': 'Electronic components, 50 cartons',
        'cargo_value': 'USD 250,000 FOB',
        'incoterms': 'CIF',
        'institute_clauses': 'Institute Cargo Clauses (A)',
        'voyage_from': 'Mumbai Port, India',
        'voyage_to': 'Singapore Port',
        'transit_start_date': '2026-07-01',
        'transit_end_date': '2026-07-07',
        'conveyance': 'MV Ocean Queen',
        'general_average_clause': 'York Antwerp Rules 2016',
        'war_risk_clause': 'Excluded per standard ICC clauses',
        'strikes_riots_clause': 'Excluded per standard ICC clauses',
        'warehouse_to_warehouse': 'Covered, max 60 days at destination',
        'marine_insurance_certificate_no': 'MIC-2024-001234',
      };

      final fields = MarinePolicyFields.fromJson(json);

      expect(fields.policyTypeMarine, 'Marine Cargo');
      expect(fields.vesselName, 'MV Ocean Queen');
      expect(fields.voyageDetails, 'Mumbai to Singapore via Colombo');
      expect(fields.cargoDescription, 'Electronic components, 50 cartons');
      expect(fields.cargoValue, 'USD 250,000 FOB');
      expect(fields.incoterms, 'CIF');
      expect(fields.instituteClauses, 'Institute Cargo Clauses (A)');
      expect(fields.voyageFrom, 'Mumbai Port, India');
      expect(fields.voyageTo, 'Singapore Port');
      expect(fields.transitStartDate, '2026-07-01');
      expect(fields.transitEndDate, '2026-07-07');
      expect(fields.conveyance, 'MV Ocean Queen');
      expect(fields.generalAverageClause, 'York Antwerp Rules 2016');
      expect(fields.warRiskClause, 'Excluded per standard ICC clauses');
      expect(fields.strikesRiotsClause, 'Excluded per standard ICC clauses');
      expect(fields.warehouseToWarehouse, 'Covered, max 60 days at destination');
      expect(fields.marineInsuranceCertificateNo, 'MIC-2024-001234');
    });

    test('fromJson handles null fields safely', () {
      final fields = MarinePolicyFields.fromJson({});
      expect(fields.policyTypeMarine, isNull);
      expect(fields.vesselName, isNull);
      expect(fields.cargoValue, isNull);
      expect(fields.incoterms, isNull);
      expect(fields.instituteClauses, isNull);
      expect(fields.marineInsuranceCertificateNo, isNull);
    });

    test('fromJson handles null-valued keys safely', () {
      final json = {
        'policy_type_marine': null,
        'vessel_name': null,
        'cargo_value': null,
      };
      final fields = MarinePolicyFields.fromJson(json);
      expect(fields.policyTypeMarine, isNull);
      expect(fields.vesselName, isNull);
      expect(fields.cargoValue, isNull);
    });
  });

  group('MarinePolicyFields — toJson', () {
    test('produces correct JSON keys', () {
      final original = MarinePolicyFields(
        policyTypeMarine: 'Hull',
        vesselName: 'MV Titan',
        cargoValue: 'USD 5,000,000',
        voyageFrom: 'Rotterdam',
        voyageTo: 'Singapore',
      );

      final json = original.toJson();

      expect(json['policy_type_marine'], 'Hull');
      expect(json['vessel_name'], 'MV Titan');
      expect(json['cargo_value'], 'USD 5,000,000');
      expect(json['voyage_from'], 'Rotterdam');
      expect(json['voyage_to'], 'Singapore');
      expect(json['transit_start_date'], isNull);
      expect(json['marine_insurance_certificate_no'], isNull);
    });

    test('toJson round-trips correctly', () {
      final original = MarinePolicyFields(
        policyTypeMarine: 'Marine Cargo',
        vesselName: 'MV Ocean Queen',
        voyageDetails: 'Mumbai to Singapore via Colombo',
        cargoDescription: 'Electronic components, 50 cartons',
        cargoValue: 'USD 250,000 FOB',
        incoterms: 'CIF',
        instituteClauses: 'Institute Cargo Clauses (A)',
        voyageFrom: 'Mumbai Port, India',
        voyageTo: 'Singapore Port',
        transitStartDate: '2026-07-01',
        transitEndDate: '2026-07-07',
        conveyance: 'MV Ocean Queen',
        generalAverageClause: 'York Antwerp Rules 2016',
        warRiskClause: 'Excluded per standard ICC clauses',
        strikesRiotsClause: 'Excluded per standard ICC clauses',
        warehouseToWarehouse: 'Covered, max 60 days at destination',
        marineInsuranceCertificateNo: 'MIC-2024-001234',
      );

      final json = original.toJson();
      final restored = MarinePolicyFields.fromJson(json);

      expect(restored.policyTypeMarine, original.policyTypeMarine);
      expect(restored.vesselName, original.vesselName);
      expect(restored.voyageDetails, original.voyageDetails);
      expect(restored.cargoDescription, original.cargoDescription);
      expect(restored.cargoValue, original.cargoValue);
      expect(restored.incoterms, original.incoterms);
      expect(restored.instituteClauses, original.instituteClauses);
      expect(restored.voyageFrom, original.voyageFrom);
      expect(restored.voyageTo, original.voyageTo);
      expect(restored.transitStartDate, original.transitStartDate);
      expect(restored.transitEndDate, original.transitEndDate);
      expect(restored.conveyance, original.conveyance);
      expect(restored.generalAverageClause, original.generalAverageClause);
      expect(restored.warRiskClause, original.warRiskClause);
      expect(restored.strikesRiotsClause, original.strikesRiotsClause);
      expect(restored.warehouseToWarehouse, original.warehouseToWarehouse);
      expect(restored.marineInsuranceCertificateNo,
          original.marineInsuranceCertificateNo);
    });
  });

  group('MarinePolicyFields — hasAnyFields', () {
    test('returns false when all fields are null or empty', () {
      final fields = MarinePolicyFields();
      expect(fields.hasAnyFields, false);
    });

    test('returns true when policyTypeMarine is set', () {
      final fields = MarinePolicyFields(policyTypeMarine: 'Hull');
      expect(fields.hasAnyFields, true);
    });

    test('returns true when vesselName is set', () {
      final fields = MarinePolicyFields(vesselName: 'MV Ocean Queen');
      expect(fields.hasAnyFields, true);
    });

    test('returns true when cargoValue is set', () {
      final fields = MarinePolicyFields(cargoValue: 'USD 500,000');
      expect(fields.hasAnyFields, true);
    });
  });

  group('PolicySummary — marineFields integration', () {
    test('toJson includes marine_fields key', () {
      final summary = PolicySummary(
        documentId: 'doc1',
        documentType: 'marine',
        extractedAt: DateTime(2026, 7, 25),
        marineFields: MarinePolicyFields(
          policyTypeMarine: 'Marine Cargo',
          vesselName: 'MV Ocean Queen',
        ),
      );

      final json = summary.toJson();
      expect(json['marine_fields'], isNotNull);
      expect(json['marine_fields']['policy_type_marine'], 'Marine Cargo');
      expect(json['marine_fields']['vessel_name'], 'MV Ocean Queen');
    });

    test('fromJson recovers marineFields correctly', () {
      final json = {
        'document_id': 'doc1',
        'document_type': 'marine',
        'marine_fields': {
          'policy_type_marine': 'Hull',
          'vessel_name': 'MV Titan',
          'cargo_value': 'USD 2,000,000',
        },
        'extracted_at': '2026-07-25T00:00:00Z',
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.marineFields, isNotNull);
      expect(summary.marineFields!.policyTypeMarine, 'Hull');
      expect(summary.marineFields!.vesselName, 'MV Titan');
      expect(summary.marineFields!.cargoValue, 'USD 2,000,000');
    });

    test('fromJson handles missing marine_fields key', () {
      final json = {
        'document_id': 'doc1',
        'document_type': 'health',
        'extracted_at': '2026-07-25T00:00:00Z',
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.marineFields, isNull);
    });

    test('hasAnyFields determines marine card visibility', () {
      final empty = PolicySummary(
        documentId: 'doc1',
        documentType: 'marine',
        extractedAt: DateTime(2026, 7, 25),
        marineFields: MarinePolicyFields(),
      );

      expect(empty.marineFields?.hasAnyFields, false);

      final populated = PolicySummary(
        documentId: 'doc2',
        documentType: 'marine',
        extractedAt: DateTime(2026, 7, 25),
        marineFields: MarinePolicyFields(
          vesselName: 'MV Ocean Queen',
          cargoDescription: 'Electronics',
        ),
      );

      expect(populated.marineFields?.hasAnyFields, true);
    });
  });
}
