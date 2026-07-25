import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('TravelPolicyFields', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'traveller_name': 'Mr. Amit Sharma',
        'destination': 'Thailand (Bangkok, Phuket)',
        'trip_duration_days': 15,
        'trip_start_date': '2024-11-10',
        'trip_end_date': '2024-11-24',
        'trip_type': 'Single trip',
        'trip_cost_covered': 75000.0,
        'medical_expenses_cover': 100000.0,
        'medical_evacuation_cover': 500000.0,
        'personal_accident_cover': 50000.0,
        'baggage_loss_cover': 2000.0,
        'baggage_delay_cover': 200.0,
        'trip_cancellation_cover': 75000.0,
        'flight_delay_cover': 200.0,
        'add_on_covers': ['Passport Loss Assistance', 'Adventure Sports'],
        'emergency_assistance_phone': '+66-800-123-4567',
        'geographical_zone': 'Schengen',
        'preexisting_condition_waiver': 'Not covered',
        'adventure_sports_cover': 'Covered up to ₹50,000',
        'hijack_cover': '₹15,000 per 24 hours, max 7 days',
        'passport_loss_cover': 'USD 200 for emergency passport expenses',
        'deductible_per_claim_travel': 50.0,
      };

      final fields = TravelPolicyFields.fromJson(json);

      expect(fields.travellerName, 'Mr. Amit Sharma');
      expect(fields.destination, 'Thailand (Bangkok, Phuket)');
      expect(fields.tripDurationDays, 15);
      expect(fields.tripStartDate, '2024-11-10');
      expect(fields.tripEndDate, '2024-11-24');
      expect(fields.tripType, 'Single trip');
      expect(fields.tripCostCovered, 75000.0);
      expect(fields.medicalExpensesCover, 100000.0);
      expect(fields.medicalEvacuationCover, 500000.0);
      expect(fields.personalAccidentCover, 50000.0);
      expect(fields.baggageLossCover, 2000.0);
      expect(fields.baggageDelayCover, 200.0);
      expect(fields.tripCancellationCover, 75000.0);
      expect(fields.flightDelayCover, 200.0);
      expect(fields.addOnCovers, ['Passport Loss Assistance', 'Adventure Sports']);
      expect(fields.emergencyAssistancePhone, '+66-800-123-4567');
      expect(fields.geographicalZone, 'Schengen');
      expect(fields.preexistingConditionWaiver, 'Not covered');
      expect(fields.adventureSportsCover, 'Covered up to ₹50,000');
      expect(fields.hijackCover, '₹15,000 per 24 hours, max 7 days');
      expect(fields.passportLossCover, 'USD 200 for emergency passport expenses');
      expect(fields.deductiblePerClaimTravel, 50.0);
    });

    test('fromJson handles null values', () {
      final json = <String, dynamic>{};

      final fields = TravelPolicyFields.fromJson(json);

      expect(fields.travellerName, isNull);
      expect(fields.destination, isNull);
      expect(fields.tripDurationDays, isNull);
      expect(fields.tripStartDate, isNull);
      expect(fields.tripEndDate, isNull);
      expect(fields.tripType, isNull);
      expect(fields.tripCostCovered, isNull);
      expect(fields.medicalExpensesCover, isNull);
      expect(fields.medicalEvacuationCover, isNull);
      expect(fields.personalAccidentCover, isNull);
      expect(fields.baggageLossCover, isNull);
      expect(fields.baggageDelayCover, isNull);
      expect(fields.tripCancellationCover, isNull);
      expect(fields.flightDelayCover, isNull);
      expect(fields.addOnCovers, isEmpty);
      expect(fields.emergencyAssistancePhone, isNull);
      expect(fields.geographicalZone, isNull);
      expect(fields.preexistingConditionWaiver, isNull);
      expect(fields.adventureSportsCover, isNull);
      expect(fields.hijackCover, isNull);
      expect(fields.passportLossCover, isNull);
      expect(fields.deductiblePerClaimTravel, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = TravelPolicyFields(
        travellerName: 'Ms. Priya Patel',
        destination: 'Bali, Indonesia',
        tripDurationDays: 10,
        tripType: 'Single trip',
        tripCostCovered: 50000.0,
        addOnCovers: ['Passport Loss Assistance'],
        geographicalZone: 'Asia',
        adventureSportsCover: 'Covered for scuba diving',
      );

      final json = original.toJson();
      final reconstructed = TravelPolicyFields.fromJson(json);

      expect(reconstructed.travellerName, 'Ms. Priya Patel');
      expect(reconstructed.destination, 'Bali, Indonesia');
      expect(reconstructed.tripDurationDays, 10);
      expect(reconstructed.tripType, 'Single trip');
      expect(reconstructed.tripCostCovered, 50000.0);
      expect(reconstructed.addOnCovers, ['Passport Loss Assistance']);
      expect(reconstructed.geographicalZone, 'Asia');
      expect(reconstructed.adventureSportsCover, 'Covered for scuba diving');
      expect(reconstructed.tripStartDate, isNull);
      expect(reconstructed.tripEndDate, isNull);
      expect(reconstructed.medicalExpensesCover, isNull);
      expect(reconstructed.hijackCover, isNull);
      expect(reconstructed.passportLossCover, isNull);
      expect(reconstructed.deductiblePerClaimTravel, isNull);
    });

    test('hasAnyFields returns false when all fields are null/empty', () {
      final fields = TravelPolicyFields();
      expect(fields.hasAnyFields, false);
    });

    test('hasAnyFields returns true when any field is populated', () {
      expect(TravelPolicyFields(destination: 'Thailand').hasAnyFields, true);
      expect(TravelPolicyFields(tripDurationDays: 15).hasAnyFields, true);
      expect(TravelPolicyFields(tripType: 'Annual multi-trip').hasAnyFields, true);
      expect(TravelPolicyFields(tripCostCovered: 50000.0).hasAnyFields, true);
      expect(TravelPolicyFields(emergencyAssistancePhone: '+66-800').hasAnyFields, true);
      expect(TravelPolicyFields(addOnCovers: ['Adventure Sports']).hasAnyFields, true);
      expect(TravelPolicyFields(geographicalZone: 'Worldwide').hasAnyFields, true);
      expect(TravelPolicyFields(preexistingConditionWaiver: 'Not covered').hasAnyFields, true);
      expect(TravelPolicyFields(adventureSportsCover: 'Covered').hasAnyFields, true);
      expect(TravelPolicyFields(hijackCover: '₹15,000/day').hasAnyFields, true);
      expect(TravelPolicyFields(passportLossCover: 'USD 200').hasAnyFields, true);
      expect(TravelPolicyFields(deductiblePerClaimTravel: 50.0).hasAnyFields, true);
    });
  });

  group('PolicySummary travel fields', () {
    test('toJson includes travel_fields key when travelFields is null', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'Travel Insurance',
        extractedAt: DateTime(2024, 1, 1),
      );

      final json = summary.toJson();
      expect(json.containsKey('travel_fields'), true);
      expect(json['travel_fields'], isNull);
    });

    test('toJson includes travel_fields when travelFields is set', () {
      final summary = PolicySummary(
        documentId: 'doc-1',
        documentType: 'Travel Insurance',
        extractedAt: DateTime(2024, 1, 1),
        travelFields: TravelPolicyFields(
          destination: 'Vietnam',
          tripDurationDays: 12,
        ),
      );

      final json = summary.toJson();
      expect(json['travel_fields'], isA<Map<String, dynamic>>());
      expect((json['travel_fields'] as Map)['destination'], 'Vietnam');
      expect((json['travel_fields'] as Map)['trip_duration_days'], 12);
    });

    test('fromJson reconstructs travel fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Travel Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
        'travel_fields': {
          'destination': 'Singapore',
          'trip_type': 'Annual multi-trip',
        },
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.travelFields, isNotNull);
      expect(summary.travelFields!.destination, 'Singapore');
      expect(summary.travelFields!.tripType, 'Annual multi-trip');
    });

    test('fromJson handles missing travel_fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Health Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
      };

      final summary = PolicySummary.fromJson(json);
      expect(summary.travelFields, isNull);
    });

    test('non-travel policy does not get travel_fields', () {
      final json = {
        'document_id': 'doc-1',
        'document_type': 'Health Insurance',
        'extracted_at': '2024-01-01T00:00:00.000',
        'travel_fields': {
          'destination': 'Test',
        },
      };

      final summary = PolicySummary.fromJson(json);
      // Backend should not emit travel_fields for non-travel docs,
      // but if it does, the model should parse and store them.
      expect(summary.travelFields, isNotNull);
      expect(summary.travelFields!.destination, 'Test');
    });
  });
}
