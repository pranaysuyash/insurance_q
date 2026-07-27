#!/usr/bin/env python3
"""Migrate qa_screen.dart from S.xxx to l10n.xxx (ARB-based localization)."""

import re

FILE = "lib/screens/qa_screen.dart"
with open(FILE) as f:
    content = f.read()

# Track which classes need l10n declarations
# We'll add them after the replacement

# ── 1. Change import ──
content = content.replace(
    "import '../localization/app_localizations.dart';",
    "import '../l10n/app_localizations_gen.dart';",
)

# ── 2. Build S.xxx → l10n.xxx mapping ──
# All S.xxx -> l10n.xxx replacements
replacements = {
    "S.qaScreenTitle": "l10n.qaScreenTitle",
    "S.qaTabSuggested": "l10n.qaTabSuggested",
    "S.qaTabYourQuestion": "l10n.qaTabYourQuestion",
    "S.qaTabHistory": "l10n.qaTabHistory",
    "S.qaOfflineMessage": "l10n.qaOfflineMessage",
    "S.getPacks": "l10n.getPacks",
    "S.qaFallbackAnswer": "l10n.qaFallbackAnswer",
    "S.qaNoQuestionsRemaining": "l10n.qaNoQuestionsRemaining",
    "S.qaQuestionsLeft": "l10n.qaQuestionsLeft",
    "S.getMore": "l10n.getMore",
    "S.qaQuestionSource": "l10n.qaQuestionSource",
    "S.qaAskAbout": "l10n.qaAskAbout",
    "S.qaAllDocuments": "l10n.qaAllDocuments",
    "S.qaSingleDocument": "l10n.qaSingleDocument",
    "S.qaSearchAllPolicies": "l10n.qaSearchAllPolicies",
    "S.qaAskAboutDescription": "l10n.qaAskAboutDescription",
    "S.qaHintText": "l10n.qaHintText",
    "S.qaClearQuestion": "l10n.qaClearQuestion",
    "S.qaToday": "l10n.qaToday",
    "S.qaYesterday": "l10n.qaYesterday",
    "S.qaThisWeek": "l10n.qaThisWeek",
    "S.qaEarlier": "l10n.qaEarlier",
    "S.qaNoHistoryYet": "l10n.qaNoHistoryYet",
    "S.qaSearchHistory": "l10n.qaSearchHistory",
    "S.qaNoMatchesFor": "l10n.qaNoMatchesFor",
    "S.commonShowLess": "l10n.commonShowLess",
    "S.commonShowMore": "l10n.commonShowMore",
    "S.qaNoSourceDocument": "l10n.qaNoSourceDocument",
    "S.qaAnswerCopiedToClipboard": "l10n.qaAnswerCopiedToClipboard",
    "S.qaEvidence": "l10n.qaEvidence",
    "S.qaCitationSource": "l10n.qaCitationSource",
    "S.qaCitationSourcePage": "l10n.qaCitationSourcePage",
    "S.qaCitationUnknown": "l10n.qaCitationUnknown",
    "S.qaViewSource": "l10n.qaViewSource",
    "S.qaPolicyDoesNotEstablish": "l10n.qaPolicyDoesNotEstablish",
    "S.qaSourcePageLabel": "l10n.qaSourcePageLabel",
    "S.qaPolicySource": "l10n.qaPolicySource",
    "S.qaRelevanceTooltip": "l10n.qaRelevanceTooltip",
}

for old, new in replacements.items():
    content = content.replace(old, new)

# ── 3. Add l10n declarations ──
# We need to add `final l10n = AppLocalizationsGen.of(context);` at the start
# of each build() method and async method that uses l10n.

# QaScreenState.build() - already has context
# Add after `Widget build(BuildContext context) {`
content = content.replace(
    "  Widget build(BuildContext context) {\n    final categories = ref.watch(questionCategoriesProvider);",
    "  Widget build(BuildContext context) {\n    final l10n = AppLocalizationsGen.of(context);\n    final categories = ref.watch(questionCategoriesProvider);",
)

# _askQuestion - async method on ConsumerState, uses context
content = content.replace(
    "  Future<void> _askQuestion(String question, {int? demoGeneration}) async {\n    if (!mounted || !widget.isActive) {\n      return;\n    }",
    "  Future<void> _askQuestion(String question, {int? demoGeneration}) async {\n    final l10n = AppLocalizationsGen.of(context);\n    if (!mounted || !widget.isActive) {\n      return;\n    }",
)

# _askQuestionStream - async method on ConsumerState
content = content.replace(
    "  Future<void> _askQuestionStream(\n    String question, {\n    int? demoGeneration,\n    String? documentId,\n  }) async {\n    if (!mounted || !widget.isActive) {\n      return;\n    }",
    "  Future<void> _askQuestionStream(\n    String question, {\n    int? demoGeneration,\n    String? documentId,\n  }) async {\n    final l10n = AppLocalizationsGen.of(context);\n    if (!mounted || !widget.isActive) {\n      return;\n    }",
)

# _QuestionBudgetBanner.build() - ConsumerWidget
content = content.replace(
    "class _QuestionBudgetBanner extends ConsumerWidget {\n  final VoidCallback onTapUpgrade;\n\n  const _QuestionBudgetBanner({required this.onTapUpgrade});\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {",
    "class _QuestionBudgetBanner extends ConsumerWidget {\n  final VoidCallback onTapUpgrade;\n\n  const _QuestionBudgetBanner({required this.onTapUpgrade});\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final l10n = AppLocalizationsGen.of(context);",
)

# _DocumentSelector.build() - StatelessWidget
content = content.replace(
    "  @override\n  Widget build(BuildContext context) {\n    final documents = documentsAsync.asData?.value ?? [];\n    final isAllDocuments = selectedDocumentId == null;",
    "  @override\n  Widget build(BuildContext context) {\n    final l10n = AppLocalizationsGen.of(context);\n    final documents = documentsAsync.asData?.value ?? [];\n    final isAllDocuments = selectedDocumentId == null;",
)

# _CustomQuestionTab.build() - StatelessWidget
content = content.replace(
    "  @override\n  Widget build(BuildContext context) {\n    return SingleChildScrollView(",
    "  @override\n  Widget build(BuildContext context) {\n    final l10n = AppLocalizationsGen.of(context);\n    return SingleChildScrollView(",
)

# _HistoryTabState._groupedByDate - change from getter to method with l10n param
content = content.replace(
    "  Map<String, List<QaPair>> get _groupedByDate {\n    final now = DateTime.now();\n    final today = DateTime(now.year, now.month, now.day);\n    final yesterday = today.subtract(const Duration(days: 1));\n    final weekAgo = today.subtract(const Duration(days: 7));\n\n    final groups = <String, List<QaPair>>{};\n    for (final item in _filteredHistory) {\n      final date = DateTime(\n          item.timestamp.year, item.timestamp.month, item.timestamp.day);\n      String label;\n      if (!date.isBefore(today)) {\n        label = S.qaToday;\n      } else if (!date.isBefore(yesterday)) {\n        label = S.qaYesterday;\n      } else if (!date.isBefore(weekAgo)) {\n        label = S.qaThisWeek;\n      } else {\n        label = S.qaEarlier;\n      }\n      groups.putIfAbsent(label, () => []).add(item);\n    }\n    return groups;\n  }",
    '  Map<String, List<QaPair>> _groupedByDate(AppLocalizationsGen l10n) {\n    final now = DateTime.now();\n    final today = DateTime(now.year, now.month, now.day);\n    final yesterday = today.subtract(const Duration(days: 1));\n    final weekAgo = today.subtract(const Duration(days: 7));\n\n    final groups = <String, List<QaPair>>{};\n    for (final item in _filteredHistory) {\n      final date = DateTime(\n          item.timestamp.year, item.timestamp.month, item.timestamp.day);\n      String label;\n      if (!date.isBefore(today)) {\n        label = l10n.qaToday;\n      } else if (!date.isBefore(yesterday)) {\n        label = l10n.qaYesterday;\n      } else if (!date.isBefore(weekAgo)) {\n        label = l10n.qaThisWeek;\n      } else {\n        label = l10n.qaEarlier;\n      }\n      groups.putIfAbsent(label, () => []).add(item);\n    }\n    return groups;\n  }',
)

# Replace calls to _groupedByDate with parameter
content = content.replace(
    "final grouped = _groupedByDate;",
    "final grouped = _groupedByDate(l10n);",
)

# _HistoryTabState.build() - already has context from State
content = content.replace(
    "  Widget build(BuildContext context) {\n    if (widget.qaHistory.isEmpty) {",
    "  Widget build(BuildContext context) {\n    final l10n = AppLocalizationsGen.of(context);\n    if (widget.qaHistory.isEmpty) {",
)

# _AnswerCardState._copyAnswer - uses S.qaAnswerCopiedToClipboard
content = content.replace(
    "  Future<void> _copyAnswer(QaAnswer answer) async {\n    await Clipboard.setData(ClipboardData(",
    "  Future<void> _copyAnswer(QaAnswer answer) async {\n    final l10n = AppLocalizationsGen.of(context);\n    await Clipboard.setData(ClipboardData(",
)

# _AnswerCardState.build() - ConsumerState
content = content.replace(
    "  Widget build(BuildContext context) {\n    final answer = widget.answer;\n    return Semantics(",
    "  Widget build(BuildContext context) {\n    final l10n = AppLocalizationsGen.of(context);\n    final answer = widget.answer;\n    return Semantics(",
)

# _SourceCard.build() - ConsumerWidget
content = content.replace(
    "  Widget build(BuildContext context, WidgetRef ref) {\n    final documents = ref.watch(documentsProvider).asData?.value ?? [];",
    "  Widget build(BuildContext context, WidgetRef ref) {\n    final l10n = AppLocalizationsGen.of(context);\n    final documents = ref.watch(documentsProvider).asData?.value ?? [];",
)

# _navigateToSource - top-level function
content = content.replace(
    "Future<void> _navigateToSource(\n  BuildContext context,\n  WidgetRef ref,\n  String documentId,\n  int page,\n) async {\n  final documents = ref.read(documentsProvider).asData?.value ?? [];",
    "Future<void> _navigateToSource(\n  BuildContext context,\n  WidgetRef ref,\n  String documentId,\n  int page,\n) async {\n  final l10n = AppLocalizationsGen.of(context);\n  final documents = ref.read(documentsProvider).asData?.value ?? [];",
)

# Write the output
with open(FILE, "w") as f:
    f.write(content)

print("✅ qa_screen.dart migrated successfully.")
print("Next step: run `flutter analyze` to verify.")
