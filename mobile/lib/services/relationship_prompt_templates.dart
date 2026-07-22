/// Specialized prompt templates for asking the LLM about relationships
/// during the 13-query extraction pipeline.
///
/// Each template targets a specific relationship aspect of Indian
/// insurance policies — who is the policyholder, who is insured,
/// who is the nominee, and how they relate to each other.
class RelationshipPromptTemplates {
  const RelationshipPromptTemplates._();

  // -------------------------------------------------------------------------
  // Core person extraction
  // -------------------------------------------------------------------------

  /// Extract the primary policyholder name.
  static const String policyholderName =
      'What is the full name of the primary policyholder or policy owner? '
      'Answer with just the name.';

  /// Extract the date of birth of the policyholder.
  static const String policyholderDob =
      'What is the date of birth of the policyholder? '
      'Answer in DD-MM-YYYY format, or say "not found".';

  // -------------------------------------------------------------------------
  // Insured persons
  // -------------------------------------------------------------------------

  /// List all persons insured under this policy.
  static const String insuredPersons =
      'List all persons insured under this policy. '
      'For each person, provide their name and relationship to the '
      'policyholder (e.g., "self", "spouse", "child", "parent", "sibling"). '
      'Format: one per line: "Name - Relationship". '
      'If only the policyholder is insured, say "Policyholder only".';

  /// Ask about the number of insured persons.
  static const String insuredCount =
      'How many persons are covered under this policy (insured persons)? '
      'Answer with just the number.';

  // -------------------------------------------------------------------------
  // Nominee / beneficiary
  // -------------------------------------------------------------------------

  /// List nominees or beneficiaries.
  static const String nomineeDetails =
      'List all nominees or beneficiaries named in this policy. '
      'For each nominee, provide their name, relationship to the '
      'policyholder, and the share percentage if mentioned. '
      'Format: one per line: "Name - Relationship - Share%". '
      'If no nominee is mentioned, say "No nominee listed".';

  // -------------------------------------------------------------------------
  // Family floater details
  // -------------------------------------------------------------------------

  /// For health insurance: ask about family floater coverage.
  static const String familyFloater =
      'Is this a family floater health insurance policy? '
      'If yes, list all family members covered, their ages, and their '
      'relationship to the policyholder. '
      'Format: one per line: "Name - Age - Relationship". '
      'If not a family floater, say "Individual policy".';

  // -------------------------------------------------------------------------
  // Verification
  // -------------------------------------------------------------------------

  /// Verify an extracted person's relationship.
  static String verifyRelationship(String personName, String relationship) =>
      'Is "$personName" the $relationship of the primary policyholder? '
      'Answer with just "Yes" or "No" or "Not mentioned".';

  /// Check if the policy covers dependent parents.
  static const String dependentParents =
      'Does this policy provide coverage for dependent parents? '
      'Answer with just "Yes", "No", or "Not mentioned".';

  /// Check if the policy covers children.
  static const String dependentChildren =
      'Does this policy provide coverage for children? '
      'Answer with just "Yes", "No", or "Not mentioned". '
      'If yes, mention the age limit if specified.';

  // -------------------------------------------------------------------------
  // Age / DOB extraction
  // -------------------------------------------------------------------------

  /// Extract ages of all insured persons.
  static const String insuredAges =
      'What are the ages or dates of birth of each insured person? '
      'Format: one per line: "Name - Age" or "Name - DD-MM-YYYY".';
}
