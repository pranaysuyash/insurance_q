import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('MotorPolicyFields', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'vehicle_registration_number': 'MH-01-AB-1234',
        'vin': 'XYZ123456789ABCDEF',
        'engine_number': 'ENG987654321',
        'ncb_percent': 50.0,
        'idv': 550000.0,
        'vehicle_make_model': 'Maruti Suzuki Swift VXI',
        'vehicle_year': 2023,
        'add_on_covers': ['Zero Depreciation Cover', 'Engine Protector'],
        'own_damage_premium': 8200.0,
        'third_party_premium': 2100.0,
        'policy_type_detail': 'Comprehensive',
        'geographical_limit': 'All India',
        'personal_accident_cover_owner': 1500000.0,
        'cubic_capacity': '1197 cc',
        'seating_capacity': 5,
        'garaging_pincode': '400001',
        'fuel_type': 'Petrol',
        'voluntary_deductible': '₹2,000',
        'hypothecation': 'HDFC Bank',
      };

      final fields = MotorPolicyFields.fromJson(json);

      expect(fields.vehicleRegistrationNumber, 'MH-01-AB-1234');
      expect(fields.vin, 'XYZ123456789ABCDEF');
      expect(fields.engineNumber, 'ENG987654321');
      expect(fields.ncbPercent, 50.0);
      expect(fields.idv, 550000.0);
      expect(fields.vehicleMakeModel, 'Maruti Suzuki Swift VXI');
      expect(fields.vehicleYear, 2023);
      expect(fields.addOnCovers, ['Zero Depreciation Cover', 'Engine Protector']);
      expect(fields.ownDamagePremium, 8200.0);
      expect(fields.thirdPartyPremium, 2100.0);
      expect(fields.policyTypeDetail, 'Comprehensive');
      expect(fields.geographicalLimit, 'All India');
      expect(fields.personalAccidentCoverOwner, 1500000.0);
      expect(fields.cubicCapacity, '1197 cc');
      expect(fields.seatingCapacity, 5);
      expect(fields.garagingPincode, '400001');
      expect(fields.fuelType, 'Petrol');
      expect(fields.voluntaryDeductible, '₹2,000');
      expect(fields.hypothecation, 'HDFC Bank');
    });

    test('fromJson handles null values', () {
      final json = <String, dynamic>{};

      final fields = MotorPolicyFields.fromJson(json);

      expect(fields.vehicleRegistrationNumber, isNull);
      expect(fields.vin, isNull);
      expect(fields.engineNumber, isNull);
      expect(fields.ncbPercent, isNull);
      expect(fields.idv, isNull);
      expect(fields.vehicleMakeModel, isNull);
      expect(fields.vehicleYear, isNull);
      expect(fields.addOnCovers, isEmpty);
      expect(fields.ownDamagePremium, isNull);
      expect(fields.thirdPartyPremium, isNull);
      expect(fields.policyTypeDetail, isNull);
      expect(fields.geographicalLimit, isNull);
      expect(fields.personalAccidentCoverOwner, isNull);
      expect(fields.cubicCapacity, isNull);
      expect(fields.seatingCapacity, isNull);
      expect(fields.garagingPincode, isNull);
      expect(fields.fuelType, isNull);
      expect(fields.voluntaryDeductible, isNull);
      expect(fields.hypothecation, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = MotorPolicyFields(
        vehicleRegistrationNumber: 'MH-02-CD-5678',
        vin: 'VIN999999',
        ncbPercent: 20.0,
        idv: 300000.0,
        addOnCovers: ['Roadside Assistance'],
        policyTypeDetail: 'Third Party Only',
        geographicalLimit: 'Zone A',
      );

      final json = original.toJson();
      final reconstructed = MotorPolicyFields.fromJson(json);

      expect(reconstructed.vehicleRegistrationNumber, 'MH-02-CD-5678');
      expect(reconstructed.vin, 'VIN999999');
      expect(reconstructed.ncbPercent, 20.0);
      expect(reconstructed.idv, 300000.0);
      expect(reconstructed.addOnCovers, ['Roadside Assistance']);
      expect(reconstructed.policyTypeDetail, 'Third Party Only');
      expect(reconstructed.geographicalLimit, 'Zone A');
      expect(reconstructed.engineNumber, isNull);
      expect(reconstructed.vehicleMakeModel, isNull);
      expect(reconstructed.cubicCapacity, isNull);
      expect(reconstructed.seatingCapacity, isNull);
      expect(reconstructed.garagingPincode, isNull);
      expect(reconstructed.fuelType, isNull);
      expect(reconstructed.voluntaryDeductible, isNull);
      expect(reconstructed.hypothecation, isNull);
    });

    test('hasAnyFields returns false when all fields are null/empty', () {
      final fields = MotorPolicyFields();
      expect(fields.hasAnyFields, false);
    });

    test('hasAnyFields returns true when any field is populated', () {
      expect(MotorPolicyFields(ncbPercent: 50.0).hasAnyFields, true);
      expect(MotorPolicyFields(vin: 'ABC').hasAnyFields, true);
      expect(MotorPolicyFields(addOnCovers: ['Zero Dep']).hasAnyFields, true);
      expect(MotorPolicyFields(vehicleYear: 2023).hasAnyFields, true);
      expect(MotorPolicyFields(policyTypeDetail: 'Comprehensive').hasAnyFields, true);
      expect(MotorPolicyFields(geographicalLimit: 'All India').hasAnyFields, true);
      expect(MotorPolicyFields(personalAccidentCoverOwner: 1500000.0).hasAnyFields, true);
      expect(MotorPolicyFields(cubicCapacity: '1197 cc').hasAnyFields, true);
      expect(MotorPolicyFields(seatingCapacity: 5).hasAnyFields, true);
      expect(MotorPolicyFields(garagingPincode: '400001').hasAnyFields, true);
      expect(MotorPolicyFields(fuelType: 'Petrol').hasAnyFields, true);
      expect(MotorPolicyFields(voluntaryDeductible: '₹2,000').hasAnyFields, true);
      expect(MotorPolicyFields(hypothecation: 'HDFC Bank').hasAnyFields, true);
    });
  });

  group('PolicySummary motor fields', () {
    test('toJson includes motor_fields key when motorFields is null', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'Auto Insurance',
        extractedAt: DateTime(2024, 1, 1),
      );

      final json = summary.toJson();
      expect(json.containsKey('motor_fields'), true);
      expect(json['motor_fields'], isNull);
    });

    test('toJson includes motor_fields when motorFields is set', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'Auto Insurance',
        extractedAt: DateTime(2024, 1, 1),
        motorFields: MotorPolicyFields(
          vin: 'CHASSIS123',
          ncbPercent: 50.0,
        ),
      );

      final json = summary.toJson();
      expect(json['motor_fields'], isA<Map<String, dynamic>>());
      expect((json['motor_fields'] as Map)['vin'], 'CHASSIS123');
      expect((json['motor_fields'] as Map)['ncb_percent'], 50.0);
    });

    test('fromJson reconstructs motor fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Auto Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
        'motor_fields': {
          'vehicle_registration_number': 'KA-01-EF-9012',
          'ncb_percent': 50.0,
        },
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.motorFields, isNotNull);
      expect(summary.motorFields!.vehicleRegistrationNumber, 'KA-01-EF-9012');
      expect(summary.motorFields!.ncbPercent, 50.0);
    });

    test('fromJson handles missing motor_fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Health Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.motorFields, isNull);
    });
  });
}
