/// A section of an Indian insurance policy document whose content
/// type has been identified by [DocumentSectionClassifier].
///
/// Sections are numbered sequentially as they appear in the document
/// so that the extraction service can ask the LLM focused questions
/// about a specific page range.
class ClassifiedSection {
  /// Descriptive name, e.g. "Policy Schedule", "Nominee Details".
  final String name;

  /// The type of section identified.
  final SectionType type;

  /// Estimated page range (1-indexed) where this section lives.
  final int startPage;
  final int endPage;

  /// Keywords that triggered the classification, for debugging.
  final List<String> matchedKeywords;

  const ClassifiedSection({
    required this.name,
    required this.type,
    required this.startPage,
    required this.endPage,
    this.matchedKeywords = const [],
  });

  int get pageCount => endPage - startPage + 1;
}

/// Types of sections found in Indian insurance policy documents.
enum SectionType {
  /// The front page or policy schedule with policy number, dates, names.
  policySchedule,

  /// Details of who is insured under this policy.
  insuredPersons,

  /// Nominee or beneficiary designation.
  nominee,

  /// Coverage amounts, sum insured, deductibles.
  coverageDetails,

  /// Premium payment details (amount, frequency, due dates).
  premiumAndPayment,

  /// Policy benefits and what is covered.
  benefits,

  /// Exclusions and what is NOT covered.
  exclusions,

  /// Waiting periods.
  waitingPeriods,

  /// Claim process and contact information.
  claimsProcess,

  /// General terms and conditions / fine print.
  termsAndConditions,

  /// A section we couldn't classify.
  unknown,
}

/// Classifies sections of Indian insurance policy documents using
/// keyword and regex patterns common to Indian insurers.
///
/// This is a fast, local classifier that works on plain text extracted
/// from OCR. It does NOT call the LLM — it uses keyword matching to
/// identify likely section boundaries so the LLM can be asked targeted
/// questions about specific parts of the document.
class DocumentSectionClassifier {
  /// Ordered list of section matchers. Each matcher is tried in order
  /// and the first match wins. Matchers at the top have higher priority
  /// (more specific patterns).
  static final List<_SectionMatcher> _matchers = [
    // Policy schedule / front matter (most specific first)
    _SectionMatcher(
      type: SectionType.policySchedule,
      keywords: [
        'policy schedule',
        'policy certificate',
        'schedule of insurance',
        'policy particulars',
        'policy number',
        'certificate of insurance',
      ],
      name: 'Policy schedule',
    ),
    // Nominee details
    _SectionMatcher(
      type: SectionType.nominee,
      keywords: [
        'nominee',
        'nomination',
        'beneficiary',
        'assignee',
        'section 39',
      ],
      name: 'Nominee details',
    ),
    // Insured persons
    _SectionMatcher(
      type: SectionType.insuredPersons,
      keywords: [
        'insured person',
        'insured persons',
        'insured member',
        'insured members',
        'person insured',
        'persons insured',
        'life assured',
        'lives assured',
        'cover to',
        'covered person',
        'covered persons',
        'family definition',
        'family members covered',
        'dependent parent',
        'dependent children',
        'spouse coverage',
      ],
      name: 'Insured persons',
    ),
    // Coverage details
    _SectionMatcher(
      type: SectionType.coverageDetails,
      keywords: [
        'sum insured',
        'sum assured',
        'cover amount',
        'coverage amount',
        'total sum insured',
        'sum insured per',
        'deductible',
        'co-pay',
        'co-payment',
        'limit per illness',
      ],
      name: 'Coverage details',
    ),
    // Premium & payment
    _SectionMatcher(
      type: SectionType.premiumAndPayment,
      keywords: [
        'premium amount',
        'premium due',
        'premium payable',
        'mode of payment',
        'payment frequency',
        'gst on premium',
        'total premium',
        'installment premium',
      ],
      name: 'Premium & payment',
    ),
    // Benefits
    _SectionMatcher(
      type: SectionType.benefits,
      keywords: [
        'key benefits',
        'coverages',
        'what is covered',
        'in-patient',
        'hospitalization',
        'room rent',
        'day care',
        'maternity',
        'critical illness',
        'accidental',
      ],
      name: 'Benefits',
    ),
    // Exclusions
    _SectionMatcher(
      type: SectionType.exclusions,
      keywords: [
        'exclusion',
        'what is not covered',
        'general exclusion',
        'specific exclusion',
        'not covered',
        'this policy does not cover',
        'shall not be liable',
      ],
      name: 'Exclusions',
    ),
    // Waiting periods
    _SectionMatcher(
      type: SectionType.waitingPeriods,
      keywords: [
        'waiting period',
        'cooling period',
        'initial waiting',
        'pre-existing',
        'survival period',
      ],
      name: 'Waiting periods',
    ),
    // Claims process
    _SectionMatcher(
      type: SectionType.claimsProcess,
      keywords: [
        'claim process',
        'claim intimation',
        'how to claim',
        'notification of claim',
        'claim procedure',
        'claim settlement',
        'cashless',
        'reimbursement',
      ],
      name: 'Claims process',
    ),
    // Terms & conditions (always last — very broad)
    _SectionMatcher(
      type: SectionType.termsAndConditions,
      keywords: [
        'terms and conditions',
        'general conditions',
        'policy conditions',
        'fine print',
        'definitions',
        'interpretation',
      ],
      name: 'Terms & conditions',
    ),
  ];

  /// Classify a list of page text blocks.
  ///
  /// [pages] is a list of text content per page, indexed 0.
  /// Returns a list of identified sections with estimated page ranges.
  List<ClassifiedSection> classifyPages(List<String> pages) {
    if (pages.isEmpty) return [];

    final sections = <ClassifiedSection>[];
    SectionType currentType = SectionType.unknown;
    int sectionStart = 1;

    for (var i = 0; i < pages.length; i++) {
      final pageContent = pages[i].toLowerCase();
      final matched = _matchSection(pageContent);

      if (matched != null && matched != currentType) {
        // Close previous section
        if (currentType != SectionType.unknown) {
          sections.add(ClassifiedSection(
            name: _nameForType(currentType),
            type: currentType,
            startPage: sectionStart,
            endPage: i, // Previous page ends before current
          ));
        }
        currentType = matched;
        sectionStart = i + 1;
      }
    }

    // Close the last section
    sections.add(ClassifiedSection(
      name: _nameForType(currentType),
      type: currentType,
      startPage: sectionStart,
      endPage: pages.length,
    ));

    return sections;
  }

  /// Classify a single text blob (non-page-broken content).
  /// Returns the most likely section type for the entire blob.
  SectionType classifyText(String text) {
    final lower = text.toLowerCase();
    final matches = <_SectionMatcher>[];
    for (final matcher in _matchers) {
      final count = matcher.matchCount(lower);
      if (count > 0) {
        matches.add(matcher);
      }
    }
    // Sort by match count descending
    matches.sort((a, b) => b.matchCount(lower).compareTo(a.matchCount(lower)));
    return matches.isNotEmpty ? matches.first.type : SectionType.unknown;
  }

  /// Check if a single page contains keywords for any known section.
  SectionType? _matchSection(String pageContent) {
    for (final matcher in _matchers) {
      if (matcher.matchesAny(pageContent)) {
        return matcher.type;
      }
    }
    return null;
  }

  String _nameForType(SectionType type) {
    for (final matcher in _matchers) {
      if (matcher.type == type) return matcher.name;
    }
    return 'Unknown section';
  }
}

/// Internal matcher with keyword list and count tracking.
class _SectionMatcher {
  final SectionType type;
  final List<String> keywords;
  final String name;

  const _SectionMatcher({
    required this.type,
    required this.keywords,
    required this.name,
  });

  bool matchesAny(String text) {
    return keywords.any((k) => text.contains(k));
  }

  int matchCount(String text) {
    return keywords.where((k) => text.contains(k)).length;
  }
}
