import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A parsed section of a legal document (title + content).
class LegalSection {
  final String title;
  final String content;

  const LegalSection({required this.title, required this.content});
}

/// Parsed legal document with metadata and sections.
class LegalDocument {
  final String title;
  final String effectiveDate;
  final List<LegalSection> sections;
  final String rawMarkdown;

  const LegalDocument({
    required this.title,
    required this.effectiveDate,
    required this.sections,
    required this.rawMarkdown,
  });

  /// Render the document as plain text for clipboard copy.
  ///
  /// Produces a human-readable string with the title, effective date,
  /// and each section's title + content. Used by both
  /// PrivacyPolicyScreen and TermsOfServiceScreen for their
  /// copy-to-clipboard actions.
  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('$title (Effective $effectiveDate)');
    buffer.writeln();
    for (final section in sections) {
      buffer.writeln(section.title);
      buffer.writeln(section.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}

/// Loads and parses legal markdown files from Flutter assets.
///
/// Content is loaded from `assets/legal/privacy_policy.md` and
/// `assets/legal/terms_of_service.md` — the single source of truth.
/// All UI widgets (PrivacyPolicyScreen, TermsOfServiceScreen) and
/// copy functions read from this loader, eliminating the 3-location
/// DRY violation.
class LegalContentLoader {
  LegalContentLoader._();

  static LegalDocument? _privacyPolicy;
  static LegalDocument? _termsOfService;

  /// Load and parse the privacy policy from assets.
  static Future<LegalDocument> loadPrivacyPolicy({AssetBundle? bundle}) async {
    if (_privacyPolicy != null) return _privacyPolicy!;
    final raw = await (bundle ?? rootBundle)
        .loadString('assets/legal/privacy_policy.md');
    _privacyPolicy = _parseMarkdown(raw, 'CoverWise Privacy Policy');
    return _privacyPolicy!;
  }

  /// Load and parse the terms of service from assets.
  static Future<LegalDocument> loadTermsOfService({AssetBundle? bundle}) async {
    if (_termsOfService != null) return _termsOfService!;
    final raw = await (bundle ?? rootBundle)
        .loadString('assets/legal/terms_of_service.md');
    _termsOfService = _parseMarkdown(raw, 'CoverWise Terms of Service');
    return _termsOfService!;
  }

  /// Clear cached documents
  static void clearCache() {
    _termsOfService = null;
    _privacyPolicy = null;
    rootBundle.evict('assets/legal/terms_of_service.md');
    rootBundle.evict('assets/legal/privacy_policy.md');
  }

  /// Expose _parseMarkdown for unit testing.
  @visibleForTesting
  static LegalDocument parseMarkdownForTest(String markdown, String fallbackTitle) {
    return _parseMarkdown(markdown, fallbackTitle);
  }

  /// Parse a markdown file into a [LegalDocument].
  ///
  /// The parser extracts:
  /// - The H1 title (first `# ` line)
  /// - The effective date from the `**Effective Date:**` line
  /// - H2 sections (`## Section Title`) with their content
  static LegalDocument _parseMarkdown(String markdown, String fallbackTitle) {
    final lines = markdown.split('\n');
    String title = fallbackTitle;
    String effectiveDate = '';
    final sections = <LegalSection>[];
    final buffer = StringBuffer();
    String? currentSectionTitle;

    for (final line in lines) {
      if (line.startsWith('# ') && !line.startsWith('## ')) {
        // H1 — document title
        title = line.substring(2).trim();
        continue;
      }

      if (line.startsWith('**Effective Date:**')) {
        effectiveDate = line
            .replaceFirst('**Effective Date:**', '')
            .trim()
            .replaceAll(RegExp(r'\s+$'), '');
        continue;
      }

      if (line.startsWith('## ')) {
        // Save previous section
        if (currentSectionTitle != null && buffer.isNotEmpty) {
          sections.add(LegalSection(
            title: currentSectionTitle,
            content: buffer.toString().trim(),
          ));
        }
        currentSectionTitle = line.substring(3).trim();
        buffer.clear();
        continue;
      }

      // Skip H3 sub-headers — fold them into the parent section content
      if (line.startsWith('### ')) {
        buffer.writeln();
        buffer.writeln(line.substring(4).trim());
        buffer.writeln();
        continue;
      }

      if (currentSectionTitle != null) {
        buffer.writeln(line);
      }
    }

    // Save last section
    if (currentSectionTitle != null && buffer.isNotEmpty) {
      sections.add(LegalSection(
        title: currentSectionTitle,
        content: buffer.toString().trim(),
      ));
    }

    return LegalDocument(
      title: title,
      effectiveDate: effectiveDate,
      sections: sections,
      rawMarkdown: markdown,
    );
  }
}
