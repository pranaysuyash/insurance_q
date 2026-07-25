import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('PolicySummary.copyWith', () {
    final baseDate = DateTime(2026, 7, 25);

    PolicySummary base() => PolicySummary(
          documentId: 'doc-1',
          policyNumber: 'POL-001',
          insurer: 'Test Insurer',
          documentType: 'life',
          coverageAmount: 500000,
          startDate: baseDate,
          endDate: baseDate.add(const Duration(days: 365)),
          extractedAt: baseDate,
          keyBenefits: ['Life cover'],
        );

    group('type-specific fields override', () {
      test('motorFields can be overridden', () {
        final original = base();
        expect(original.motorFields, isNull);

        final updated = original.copyWith(
          motorFields: MotorPolicyFields(
            vehicleRegistrationNumber: 'KA-01-AB-1234',
            vehicleMakeModel: 'Toyota Corolla',
            vehicleYear: 2023,
          ),
        );

        expect(updated.motorFields, isNotNull);
        expect(updated.motorFields!.vehicleRegistrationNumber, 'KA-01-AB-1234');
        expect(updated.motorFields!.vehicleMakeModel, 'Toyota Corolla');
        expect(updated.motorFields!.vehicleYear, 2023);

        // Original unchanged
        expect(original.motorFields, isNull);
      });

      test('travelFields can be overridden', () {
        final original = base();
        expect(original.travelFields, isNull);

        final updated = original.copyWith(
          travelFields: TravelPolicyFields(
            travellerName: 'Priya Singh',
            destination: 'Bali',
            tripDurationDays: 14,
          ),
        );

        expect(updated.travelFields, isNotNull);
        expect(updated.travelFields!.travellerName, 'Priya Singh');
        expect(updated.travelFields!.destination, 'Bali');
        expect(updated.travelFields!.tripDurationDays, 14);

        // Original unchanged
        expect(original.travelFields, isNull);
      });

      test('lifeFields can be overridden', () {
        final original = base();
        expect(original.lifeFields, isNull);

        final updated = original.copyWith(
          lifeFields: LifePolicyFields(
            lifeAssuredName: 'Ravi Sharma',
            sumAssured: 10000000,
            policyTermYears: 20,
            nomineeName: 'Anita Sharma',
            riderDetails: ['Accidental death benefit'],
          ),
        );

        expect(updated.lifeFields, isNotNull);
        expect(updated.lifeFields!.lifeAssuredName, 'Ravi Sharma');
        expect(updated.lifeFields!.sumAssured, 10000000);
        expect(updated.lifeFields!.policyTermYears, 20);
        expect(updated.lifeFields!.nomineeName, 'Anita Sharma');
        expect(updated.lifeFields!.riderDetails, ['Accidental death benefit']);

        // Original unchanged
        expect(original.lifeFields, isNull);
      });

      test('homeFields can be overridden', () {
        final original = base();
        expect(original.homeFields, isNull);

        final updated = original.copyWith(
          homeFields: HomePolicyFields(
            propertyAddress: '42 MG Road, Bangalore',
            buildingSumInsured: 5000000,
            contentsSumInsured: 1000000,
            yearBuilt: 2018,
            perilsCovered: ['Fire', 'Theft'],
            perilsExcluded: ['Earthquake'],
          ),
        );

        expect(updated.homeFields, isNotNull);
        expect(updated.homeFields!.propertyAddress, '42 MG Road, Bangalore');
        expect(updated.homeFields!.buildingSumInsured, 5000000);
        expect(updated.homeFields!.contentsSumInsured, 1000000);
        expect(updated.homeFields!.yearBuilt, 2018);
        expect(updated.homeFields!.perilsCovered, ['Fire', 'Theft']);
        expect(updated.homeFields!.perilsExcluded, ['Earthquake']);

        // Original unchanged
        expect(original.homeFields, isNull);
      });

      test('healthFields can be overridden', () {
        final original = base();
        expect(original.healthFields, isNull);

        final updated = original.copyWith(
          healthFields: HealthPolicyFields(
            roomRentCap: 'Single private AC',
            coPayPercent: 10,
            networkHospitals: '7000+',
            ambulanceCover: 2500,
            preExistingDiseases: ['Diabetes'],
            criticalIllnessList: ['Cancer', 'Heart attack'],
          ),
        );

        expect(updated.healthFields, isNotNull);
        expect(updated.healthFields!.roomRentCap, 'Single private AC');
        expect(updated.healthFields!.coPayPercent, 10);
        expect(updated.healthFields!.networkHospitals, '7000+');
        expect(updated.healthFields!.ambulanceCover, 2500);
        expect(updated.healthFields!.preExistingDiseases, ['Diabetes']);
        expect(updated.healthFields!.criticalIllnessList,
            ['Cancer', 'Heart attack']);

        // Original unchanged
        expect(original.healthFields, isNull);
      });

      test('marineFields can be overridden', () {
        final original = base();
        expect(original.marineFields, isNull);

        final updated = original.copyWith(
          marineFields: MarinePolicyFields(
            vesselName: 'MV Ocean Queen',
            voyageDetails: 'Mumbai to Singapore',
            cargoDescription: 'Electronics and textiles',
            cargoValue: 'USD 150,000',
            incoterms: 'CIF',
          ),
        );

        expect(updated.marineFields, isNotNull);
        expect(updated.marineFields!.vesselName, 'MV Ocean Queen');
        expect(updated.marineFields!.voyageDetails, 'Mumbai to Singapore');
        expect(updated.marineFields!.cargoDescription,
            'Electronics and textiles');
        expect(updated.marineFields!.cargoValue, 'USD 150,000');
        expect(updated.marineFields!.incoterms, 'CIF');

        // Original unchanged
        expect(original.marineFields, isNull);
      });
    });

    group('preserves existing type-specific fields when not overridden', () {
      test('passing null keeps existing motorFields', () {
        final existingMotor = MotorPolicyFields(
          vehicleRegistrationNumber: 'KA-01-AB-1234',
        );
        final original = base().copyWith(motorFields: existingMotor);

        // copyWith without motorFields param preserves original
        final unchanged = original.copyWith();
        expect(unchanged.motorFields, same(existingMotor));

        // Explicit null also preserves (?? fallback behavior)
        final explicitNull = original.copyWith(motorFields: null);
        expect(explicitNull.motorFields, same(existingMotor));
      });

      test('passing null preserves existing lifeFields', () {
        final existingLife = LifePolicyFields(lifeAssuredName: 'Ravi');
        final original = base().copyWith(lifeFields: existingLife);

        // With param not passed, original preserved
        final unchanged = original.copyWith();
        expect(unchanged.lifeFields, same(existingLife));

        // Explicit null also preserves (?? fallback behavior)
        final preserved = original.copyWith(lifeFields: null);
        expect(preserved.lifeFields, same(existingLife));
      });
    });

    group('other fields still work with copyWith', () {
      test('scalar fields are overridable', () {
        final original = base();
        expect(original.policyNumber, 'POL-001');
        expect(original.insurer, 'Test Insurer');

        final updated = original.copyWith(
          policyNumber: 'POL-002',
          insurer: 'New Insurer',
          coverageAmount: 1000000,
        );

        expect(updated.policyNumber, 'POL-002');
        expect(updated.insurer, 'New Insurer');
        expect(updated.coverageAmount, 1000000);

        // Original unchanged
        expect(original.policyNumber, 'POL-001');
      });

      test('list fields are overridable', () {
        final original = base();
        expect(original.keyBenefits, ['Life cover']);

        final updated = original.copyWith(
          keyBenefits: ['Life cover', 'AD&D cover'],
          exclusions: ['Pre-existing conditions', 'Suicide first year'],
        );

        expect(updated.keyBenefits, ['Life cover', 'AD&D cover']);
        expect(updated.exclusions,
            ['Pre-existing conditions', 'Suicide first year']);
      });
    });

    group('multiple type-specific fields simultaneously', () {
      test('can override two type-specific fields at once', () {
        final original = base();

        final updated = original.copyWith(
          motorFields: MotorPolicyFields(
            vehicleRegistrationNumber: 'KA-01-AB-1234',
          ),
          healthFields: HealthPolicyFields(
            roomRentCap: 'Private',
            coPayPercent: 10,
          ),
        );

        expect(updated.motorFields, isNotNull);
        expect(updated.motorFields!.vehicleRegistrationNumber,
            'KA-01-AB-1234');
        expect(updated.healthFields, isNotNull);
        expect(updated.healthFields!.roomRentCap, 'Private');
        expect(updated.healthFields!.coPayPercent, 10);

        // Others remain null
        expect(updated.lifeFields, isNull);
        expect(updated.travelFields, isNull);
        expect(updated.homeFields, isNull);
        expect(updated.marineFields, isNull);
      });

      test('can override all 6 type-specific fields at once', () {
        final original = base();

        final updated = original.copyWith(
          motorFields: MotorPolicyFields(vehicleRegistrationNumber: 'M1'),
          travelFields: TravelPolicyFields(travellerName: 'T1'),
          lifeFields: LifePolicyFields(lifeAssuredName: 'L1'),
          homeFields: HomePolicyFields(propertyAddress: 'H1'),
          healthFields: HealthPolicyFields(roomRentCap: 'HL1'),
          marineFields: MarinePolicyFields(vesselName: 'MA1'),
        );

        expect(updated.motorFields!.vehicleRegistrationNumber, 'M1');
        expect(updated.travelFields!.travellerName, 'T1');
        expect(updated.lifeFields!.lifeAssuredName, 'L1');
        expect(updated.homeFields!.propertyAddress, 'H1');
        expect(updated.healthFields!.roomRentCap, 'HL1');
        expect(updated.marineFields!.vesselName, 'MA1');
      });
    });
  });
}
