import 'package:coverwise/utils/policy_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyPolicyType', () {
    test('keeps Indian policy names in their visual coverage category', () {
      expect(classifyPolicyType('Mediclaim Family Floater'), PolicyType.health);
      expect(classifyPolicyType('Comprehensive Two Wheeler'), PolicyType.auto);
      expect(classifyPolicyType('Term Plan'), PolicyType.life);
    });

    test('recognises canonical document types', () {
      expect(classifyPolicyType('Home Insurance'), PolicyType.home);
      expect(classifyPolicyType('Travel Insurance'), PolicyType.travel);
      expect(classifyPolicyType(null), PolicyType.other);
    });
  });
}
