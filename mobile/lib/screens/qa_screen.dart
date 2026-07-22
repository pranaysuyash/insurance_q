import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import '../models/qa_models.dart';
import '../models/document_model.dart';
import '../config/app_config.dart';
import '../providers/questions_provider.dart';
import '../providers/service_providers.dart';
import '../providers/document_providers.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/analytics_service.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/loading_widget.dart';
import '../widgets/shared/offline_banner.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../localization/app_localizations.dart';
import '../theme/coverwise_theme.dart';
import '../theme/coverwise_motion.dart';
import '../utils/app_error.dart';
import '../providers/entitlement_provider.dart';
import '../models/entitlement.dart';
import 'document_selection_dialog.dart';
import 'document_preview_screen.dart';
import 'qa_packs_screen.dart';

class QaScreen extends ConsumerStatefulWidget {
  final String? initialDocumentId;
  final bool isActive;

  const QaScreen({super.key, this.initialDocumentId, this.isActive = true});

  @override
  QaScreenState createState() => QaScreenState();
}

class QaScreenState extends ConsumerState<QaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _customQuestionController =
      TextEditingController();
  bool _demoSequenceStarted = false;
  int _demoSequenceGeneration = 0;
  bool _questionRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _maybeStartDemoSequence();
  }

  @override
  void didUpdateWidget(covariant QaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive && !widget.isActive) {
      _demoSequenceStarted = false;
      _demoSequenceGeneration++;
    }
  }

  @override
  void deactivate() {
    _demoSequenceGeneration++;
    _demoSequenceStarted = false;
    super.deactivate();
  }

  Future<void> _maybeStartDemoSequence() async {
    if (!AppConfig.bootstrapPolicyDemo || _demoSequenceStarted) return;
    if (!widget.isActive) return;

    final documents = ref.read(documentsProvider).valueOrNull ?? [];
    if (documents.isEmpty) {
      return;
    }

    _demoSequenceStarted = true;
    final demoGeneration = _demoSequenceGeneration;

    if (!mounted ||
        !widget.isActive ||
        demoGeneration != _demoSequenceGeneration) {
      return;
    }
    _tabController.animateTo(
      1,
      duration: CoverWiseMotion.duration(context, CoverWiseMotion.standard),
      curve: CoverWiseMotion.enterCurve,
    );

    const demoQuestions = [
      'What is my policy number?',
      'When does my policy start and end?',
      'Who is the insurer for this policy?',
      'What is my premium amount?',
      'What is the claims process?',
      'Are there any waiting periods?',
    ];

    for (final question in demoQuestions) {
      if (!mounted ||
          !widget.isActive ||
          demoGeneration != _demoSequenceGeneration) {
        return;
      }
      _customQuestionController.text = question;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted ||
          !widget.isActive ||
          demoGeneration != _demoSequenceGeneration) {
        return;
      }
      await _askQuestion(question, demoGeneration: demoGeneration);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _showDocumentSelectionDialog() {
    final documents = ref.read(documentsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (context) => DocumentSelectionDialog(
        documents: documents,
        currentDocumentId: ref.read(selectedDocumentProvider),
        onDocumentSelected: (documentId) {
          Future(() {
            if (!mounted) return;
            ref.read(selectedDocumentProvider.notifier).state = documentId;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customQuestionController.dispose();
    super.dispose();
  }

  Future<void> _askQuestion(String question, {int? demoGeneration}) async {
    if (!mounted || !widget.isActive) {
      return;
    }
    // All entry points (buttons, keyboard submit, follow-ups, and the demo
    // sequence) converge here. Keep the entitlement check and usage write
    // inside one request boundary so rapid submissions cannot race them.
    if (_questionRequestInFlight) {
      return;
    }
    if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
      return;
    }

    // Gate on the canonical entitlement provider. Purchased packs remain
    // usable after a subscription expires; the provider owns that rule.
    final entitlement = ref.read(entitlementProvider);
    final entitlementReason =
        ref.read(entitlementProvider.notifier).checkAction('ask_question');
    if (entitlementReason != null) {
      AnalyticsService.track('qa_question_blocked_no_budget', {
        'plan_tier': entitlement.planTier.name,
        'subscription_remaining': entitlement.subscriptionQuestionsRemaining,
        'pack_remaining': entitlement.packQuestionsRemaining,
      });
      if (!mounted) return;
      CoverWiseSnackBar.warning(
        context,
        entitlementReason,
        actionLabel: S.getPacks,
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QaPacksScreen()),
        ),
      );
      return;
    }

    final selectedDoc = _currentDocumentId();
    _questionRequestInFlight = true;
    ref.read(isLoadingProvider.notifier).state = true;
    // Don't clear currentAnswerProvider here — keep the previous answer
    // visible while the new question loads. The new answer replaces it
    // only on success.

    AnalyticsService.track('question_submitted', {
      'question_length_bucket': question.length < 30
          ? 'short'
          : question.length < 80
              ? 'medium'
              : 'long',
    });

    try {
      String formattedQuestion = question;
      if (question == "What is my policy number?") {
        formattedQuestion =
            "What is the policy number shown in this insurance document?";
      } else if (question.contains("deductible")) {
        formattedQuestion =
            "What is the deductible amount specified in this insurance policy?";
      } else if (question.contains("premium")) {
        formattedQuestion =
            "What is the premium amount stated in this insurance document?";
      }

      final result = await ref.read(queryServiceProvider).queryDocument(
            formattedQuestion,
            documentId: selectedDoc,
          );

      if (!mounted || !widget.isActive) {
        return;
      }
      if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
        return;
      }

      if (result.containsKey('error') && !result.containsKey('answer')) {
        final serverError = result['error']?.toString();
        if (serverError == 'qa_budget_exhausted') {
          if (!mounted) return;
          CoverWiseSnackBar.warning(
            context,
            'No server-verified questions remain. Buy a Q&A pack or renew your plan.',
            actionLabel: S.getPacks,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QaPacksScreen()),
            ),
          );
          return;
        }
        if (serverError == 'qa_usage_unavailable') {
          if (!mounted) return;
          CoverWiseSnackBar.error(
            context,
            'Question usage could not be verified. Please try again.',
            operation: 'verify question usage',
          );
          return;
        }
        if (!mounted) return;
        // The response error is untrusted server data. Route it through the
        // centralized safe mapping instead of rendering raw backend text.
        final safeMessage = AppError.userMessage(
          Exception(result['error']?.toString() ?? 'query failed'),
        );
        CoverWiseSnackBar.error(context, safeMessage,
            operation: 'ask question');
        return;
      }

      final answer = QaAnswer.fromJson({
        ...result,
        'query': question,
        'document_id': selectedDoc ?? '',
      });

      if (!mounted || !widget.isActive) {
        return;
      }
      if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
        return;
      }

      ref.read(currentAnswerProvider.notifier).state = answer;

      AnalyticsService.track('answer_rendered', {
        'confidence_bucket': (answer.confidence ?? 0) < 0.3
            ? 'low'
            : (answer.confidence ?? 0) < 0.7
                ? 'medium'
                : 'high',
        'answer_source_count_bucket': answer.sources.isEmpty
            ? 'none'
            : answer.sources.length <= 2
                ? 'few'
                : 'many',
      });

      if (answer.text.isNotEmpty) {
        // Deduct a question from subscription (first) or pack (FIFO)
        await ref.read(entitlementProvider.notifier).recordQuestionUsed();

        ref.read(qaHistoryProvider.notifier).addItem(question, answer);
        try {
          await AppStateRepository.addRecentQuestion(question);
        } catch (e) {
          debugPrint('Error saving recent question: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during question: $e');
      // Preserve the previous answer if one exists — don't replace it.
      // Only show a fallback card when there's no previous answer at all
      // (first question in the session).
      final previous = ref.read(currentAnswerProvider);
      if (previous == null) {
        final fallbackAnswer = QaAnswer(
          text: S.qaFallbackAnswer,
          sources: [],
          timestamp: DateTime.now(),
          documentId: selectedDoc ?? '',
          question: question,
        );
        if (mounted &&
            widget.isActive &&
            (demoGeneration == null ||
                demoGeneration == _demoSequenceGeneration)) {
          ref.read(currentAnswerProvider.notifier).state = fallbackAnswer;
        }
      }
      if (!mounted || !widget.isActive) {
        return;
      }
      if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
        return;
      }
      CoverWiseSnackBar.error(context, AppError.userMessage(e),
          operation: 'ask question');
    } finally {
      _questionRequestInFlight = false;
      if (mounted && widget.isActive) {
        ref.read(isLoadingProvider.notifier).state = false;
      }
    }
  }

  String? _currentDocumentId() {
    final selectedDoc = ref.read(selectedDocumentProvider);
    if (selectedDoc != null) return selectedDoc;
    if (widget.initialDocumentId != null) return widget.initialDocumentId;
    final documents = ref.read(documentsProvider).valueOrNull ?? [];
    if (documents.isNotEmpty) return documents.first.id;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(questionCategoriesProvider);
    final standardQuestions = ref.watch(standardQuestionsProvider);
    final qaHistory = ref.watch(qaHistoryProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final currentAnswer = ref.watch(currentAnswerProvider);
    final documentsAsync = ref.watch(documentsProvider);
    final selectedDocumentId =
        ref.watch(selectedDocumentProvider) ?? widget.initialDocumentId;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.qaScreenTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: S.qaTabSuggested),
            Tab(text: S.qaTabYourQuestion),
            Tab(text: S.qaTabHistory),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          _QuestionBudgetBanner(
            onTapUpgrade: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QaPacksScreen()),
            ),
          ),
          _DocumentSelector(
            documentsAsync: documentsAsync,
            selectedDocumentId: selectedDocumentId,
            onSelectDocument: _showDocumentSelectionDialog,
            onSelectAllDocuments: () {
              ref.read(selectedDocumentProvider.notifier).state = null;
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StandardQuestionsTab(
                  categories: categories,
                  questions: standardQuestions,
                  isLoading: isLoading,
                  currentAnswer: currentAnswer,
                  onAskQuestion: _askQuestion,
                ),
                _CustomQuestionTab(
                  controller: _customQuestionController,
                  isLoading: isLoading,
                  currentAnswer: currentAnswer,
                  onAskQuestion: _askQuestion,
                ),
                _HistoryTab(
                  qaHistory: qaHistory,
                  onSelectAnswer: (answer) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      ref.read(currentAnswerProvider.notifier).state = answer;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows remaining questions (subscription + packs) with a CTA to buy more.
class _QuestionBudgetBanner extends ConsumerWidget {
  final VoidCallback onTapUpgrade;

  const _QuestionBudgetBanner({required this.onTapUpgrade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packState = ref.watch(qaPackStateProvider);
    final entitlement = ref.watch(entitlementProvider);
    final remaining = packState.totalQuestionsRemaining;
    final isLow = remaining <= 3 && remaining > 0;
    final isZero = remaining == 0;

    // Show banner for free users always, and for paid users when questions are low
    if (entitlement.planTier != PlanTier.free &&
        !packState.hasPackQuestions &&
        remaining > 3) {
      return const SizedBox.shrink();
    }

    final subtitle = packState.hasSubscriptionQuestions &&
            packState.hasPackQuestions
        ? '${packState.subscriptionQuestionsRemaining} monthly + ${packState.packQuestionsRemaining} pack'
        : packState.hasPackQuestions
            ? '${packState.packQuestionsRemaining} questions in ${packState.activePacks.length} pack(s)'
            : '${packState.subscriptionQuestionsRemaining} questions left this month';

    return CoverWiseSurface(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              isZero
                  ? Icons.error_outline_rounded
                  : isLow
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
              size: 20,
              color: isZero
                  ? Theme.of(context).colorScheme.error
                  : isLow
                      ? Colors.orange
                      : Colors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isZero
                        ? S.qaNoQuestionsRemaining
                        : S.qaQuestionsLeft(remaining),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color:
                          isZero ? Theme.of(context).colorScheme.error : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isZero || isLow)
              TextButton(
                onPressed: onTapUpgrade,
                child: Text(S.getMore),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentSelector extends StatelessWidget {
  final AsyncValue<List<InsuranceDocument>> documentsAsync;
  final String? selectedDocumentId;
  final VoidCallback onSelectDocument;
  final VoidCallback onSelectAllDocuments;

  const _DocumentSelector(
      {required this.documentsAsync,
      required this.selectedDocumentId,
      required this.onSelectDocument,
      required this.onSelectAllDocuments});

  @override
  Widget build(BuildContext context) {
    final documents = documentsAsync.valueOrNull ?? [];
    final isAllDocuments = selectedDocumentId == null;

    return CoverWiseSurface(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Semantics(
        container: true,
        label: S.qaQuestionSource,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.qaAskAbout,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: CoverWiseColors.blueDeep,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        isAllDocuments
                            ? S.qaAllDocuments(documents.length)
                            : S.qaSingleDocument,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      selected: isAllDocuments,
                      onSelected: (selected) {
                        if (selected) onSelectAllDocuments();
                      },
                      avatar: Icon(
                        isAllDocuments
                            ? Icons.library_books_rounded
                            : Icons.description_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                  if (!isAllDocuments) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (context) {
                        final selectedDoc = documents.firstWhere(
                          (doc) => doc.id == selectedDocumentId,
                          orElse: () => InsuranceDocument(
                              id: '',
                              filename: 'No document selected',
                              uploadedOn: DateTime.now()),
                        );
                        return TextButton.icon(
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: Text(
                            selectedDoc.filename,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: onSelectDocument,
                        );
                      }),
                    ),
                  ],
                ],
              ),
              if (isAllDocuments)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    S.qaSearchAllPolicies,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (documentsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandardQuestionsTab extends StatelessWidget {
  final List<QuestionCategory> categories;
  final List<StandardQuestion> questions;
  final bool isLoading;
  final QaAnswer? currentAnswer;
  final Future<void> Function(String) onAskQuestion;

  const _StandardQuestionsTab({
    required this.categories,
    required this.questions,
    required this.isLoading,
    required this.currentAnswer,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, List<StandardQuestion>> grouped = {};
    for (var q in questions) {
      grouped.putIfAbsent(q.category, () => []).add(q);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: categories.length + (currentAnswer != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (currentAnswer != null && index == categories.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: _AnswerCard(answer: currentAnswer!),
          );
        }

        final category = categories[index];
        final categoryQuestions = grouped[category.id] ?? [];
        if (categoryQuestions.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 8),
                ...categoryQuestions.map((q) => ListTile(
                      title: Text(q.text, style: const TextStyle(fontSize: 15)),
                      leading: const CoverWiseIconBadge(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: CoverWiseColors.blue,
                        size: 38,
                      ),
                      trailing: isLoading && currentAnswer?.query == q.text
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.arrow_forward_rounded),
                      onTap: isLoading ? null : () => onAskQuestion(q.text),
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomQuestionTab extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final QaAnswer? currentAnswer;
  final Future<void> Function(String) onAskQuestion;

  const _CustomQuestionTab({
    required this.controller,
    required this.isLoading,
    required this.currentAnswer,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.qaAskAboutDescription,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: S.qaHintText,
              suffixIcon: IconButton(
                tooltip: S.qaClearQuestion,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => controller.clear(),
              ),
            ),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) onAskQuestion(value.trim());
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_upward_rounded),
            label: Text(S.qaScreenTitle),
            onPressed: isLoading || controller.text.trim().isEmpty
                ? null
                : () => onAskQuestion(controller.text.trim()),
          ),
          const SizedBox(height: 24),
          if (isLoading) const LoadingWidget(),
          if (currentAnswer != null &&
              currentAnswer!.query == controller.text.trim())
            _AnswerCard(answer: currentAnswer!),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  final List<QaPair> qaHistory;
  final void Function(QaAnswer) onSelectAnswer;

  const _HistoryTab({required this.qaHistory, required this.onSelectAnswer});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedQuestions = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QaPair> get _filteredHistory {
    if (_searchQuery.isEmpty) return widget.qaHistory;
    final q = _searchQuery.toLowerCase();
    return widget.qaHistory.where((item) {
      return item.question.toLowerCase().contains(q) ||
          item.answer.text.toLowerCase().contains(q);
    }).toList();
  }

  Map<String, List<QaPair>> get _groupedByDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<QaPair>>{};
    for (final item in _filteredHistory) {
      final date = DateTime(
          item.timestamp.year, item.timestamp.month, item.timestamp.day);
      String label;
      if (!date.isBefore(today)) {
        label = S.qaToday;
      } else if (!date.isBefore(yesterday)) {
        label = S.qaYesterday;
      } else if (!date.isBefore(weekAgo)) {
        label = S.qaThisWeek;
      } else {
        label = S.qaEarlier;
      }
      groups.putIfAbsent(label, () => []).add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.qaHistory.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: S.qaNoHistoryYet,
        color: Color(0xFF6A4BA8),
      );
    }

    final filtered = _filteredHistory;
    final grouped = _groupedByDate;
    final groupLabels = grouped.keys.toList();

    // Build a flat list of items with section headers
    final List<Object> items = [];
    for (final label in groupLabels) {
      items.add(label); // section header
      for (final pair in grouped[label]!) {
        items.add(pair); // history item
      }
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: S.qaSearchHistory,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        // Results count
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredHistory.length} result${_filteredHistory.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        // History list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          S.qaNoMatchesFor(_searchQuery),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is String) {
                      // Section header
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          item,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      );
                    }
                    final pair = item as QaPair;
                    final isExpanded =
                        _expandedQuestions.contains(pair.question);
                    final answerText = pair.answer.text;
                    final isLong = answerText.length > 120;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onSelectAnswer(pair.answer),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question + time
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CoverWiseIconBadge(
                                    icon: Icons.history_rounded,
                                    color: CoverWiseColors.blue,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      pair.question,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    '${pair.timestamp.hour}:${pair.timestamp.minute.toString().padLeft(2, '0')}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Answer preview (expandable with smooth animation)
                              Padding(
                                padding: const EdgeInsets.only(left: 46),
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  alignment: Alignment.topLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isExpanded || !isLong
                                            ? answerText
                                            : '${answerText.substring(0, 120)}...',
                                        maxLines: isExpanded ? null : 5,
                                        overflow: isExpanded
                                            ? null
                                            : TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                      ),
                                      if (isLong)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedQuestions
                                                    .remove(pair.question);
                                              } else {
                                                _expandedQuestions
                                                    .add(pair.question);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              isExpanded
                                                  ? S.commonShowLess
                                                  : S.commonShowMore,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AnswerCard extends ConsumerStatefulWidget {
  final QaAnswer answer;
  const _AnswerCard({required this.answer});

  @override
  ConsumerState<_AnswerCard> createState() => _AnswerCardState();
}

/// Navigates to the source document at a specific page for citation verification.
Future<void> _navigateToSource(
  BuildContext context,
  WidgetRef ref,
  String documentId,
  int page,
) async {
  final documents = ref.read(documentsProvider).valueOrNull ?? [];
  final doc = documents
      .where((d) => d.id == documentId || d.remoteId == documentId)
      .firstOrNull;
  if (doc == null) {
    if (!context.mounted) return;
    CoverWiseSnackBar.error(context, S.qaNoSourceDocument,
        operation: 'view source');
    return;
  }

  // If the document has a local file, navigate directly to preview
  if (doc.localFilePath != null) {
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          filePath: doc.localFilePath!,
          filename: doc.filename,
          documentId: doc.remoteId,
          initialPage: page,
        ),
      ),
    );
    return;
  }

  // If remote-only, try to cache the source first
  if (doc.remoteId != null) {
    try {
      final cached = await ref
          .read(documentServiceProvider)
          .cacheRemoteSource(doc.id);
      if (!context.mounted) return;
      ref.invalidate(documentsProvider);
      if (cached.localFilePath == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            filePath: cached.localFilePath!,
            filename: cached.filename,
            documentId: cached.remoteId,
            initialPage: page,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      CoverWiseSnackBar.error(
        context,
        S.qaNoSourceDocument,
        operation: 'view source',
      );
    }
  }
}

class _AnswerCardState extends ConsumerState<_AnswerCard> {
  int? _feedback; // 1 = helpful, -1 = not helpful, null = not yet
  bool _copied = false;
  int _copyAcknowledgement = 0;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    final box = Hive.box(AppStateStore.boxName);
    final feedback =
        box.get('${AppStateStore.answerFeedbackKey}:${widget.answer.question}');
    if (mounted && feedback != null) {
      setState(() => _feedback = int.tryParse(feedback.toString()));
    }
  }

  Future<void> _askFollowUp(String question) async {
    // Find the parent QaScreenState and trigger the question
    final qaState = context.findAncestorStateOfType<QaScreenState>();
    if (qaState == null) return;
    try {
      await qaState._askQuestion(question);
    } catch (e) {
      // Ensure loading state is reset even if _askQuestion throws
      if (qaState.mounted) {
        qaState.ref.read(isLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _saveFeedback(int value) async {
    final box = Hive.box(AppStateStore.boxName);
    await box.put(
      '${AppStateStore.answerFeedbackKey}:${widget.answer.question}',
      value.toString(),
    );
    setState(() => _feedback = value);
    AnalyticsService.track('answer_feedback_submitted', {
      'sentiment': value == 1 ? 'positive' : 'negative',
    });
  }

  Future<void> _copyAnswer(QaAnswer answer) async {
    await Clipboard.setData(ClipboardData(
      text: 'Q: ${answer.question}\nA: ${answer.text}',
    ));
    if (!mounted) return;

    final acknowledgement = ++_copyAcknowledgement;
    setState(() => _copied = true);
    CoverWiseSnackBar.success(context, S.qaAnswerCopiedToClipboard,
        duration: const Duration(seconds: 2));

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted && acknowledgement == _copyAcknowledgement) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Answer ready for ${answer.question}',
      child: CoverWiseSurface(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question + confidence badge row
              Row(
                children: [
                  Expanded(
                    child: Text('Q: ${answer.question}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (answer.confidence != null)
                    ConfidenceBadge(confidence: answer.confidence!),
                ],
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A: ${answer.text}',
                          style: const TextStyle(fontSize: 16)),
                      if (answer.citations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(S.qaEvidence,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        ...answer.citations.asMap().entries.map((entry) {
                          final citation = entry.value;
                          final quote = citation['quote']?.toString().trim();
                          final page =
                              citation['page_number'] ?? citation['page'];
                          final status = citation['status']?.toString() ??
                              citation['citation_status']?.toString();
                          final normalizedStatus = status?.toLowerCase();
                          final citationIcon = normalizedStatus == 'verified' ||
                                  normalizedStatus == 'accepted' ||
                                  normalizedStatus == 'grounded'
                              ? Icons.verified_outlined
                              : normalizedStatus == 'failed' ||
                                      normalizedStatus == 'rejected'
                                  ? Icons.error_outline
                                  : Icons.help_outline;
                          final label = page == null
                              ? S.qaCitationSource(entry.key + 1)
                              : S.qaCitationSourcePage(entry.key + 1, page);
                          final displayStatus = status ?? S.qaCitationUnknown;
                          // Navigate to document preview at the cited page
                          final documentId = answer.documentId;
                          final pageInt = page is int
                              ? page
                              : int.tryParse(page?.toString() ?? '');
                          final hasPage = pageInt != null && pageInt > 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: hasPage && documentId.isNotEmpty
                                    ? () => _navigateToSource(
                                        context,
                                        ref,
                                        documentId,
                                        pageInt,
                                      )
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(citationIcon, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(label,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12)),
                                          ),
                                          if (hasPage && documentId.isNotEmpty)
                                            Text(
                                              S.qaViewSource,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          if (hasPage && documentId.isNotEmpty)
                                            const Icon(
                                              Icons.open_in_new,
                                              size: 14,
                                            ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(displayStatus,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                      if (quote != null && quote.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text('“$quote”',
                                            style: const TextStyle(fontSize: 13)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      if (answer.missingInformation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(S.qaPolicyDoesNotEstablish,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        ...answer.missingInformation.map((item) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('• $item',
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      if (answer.sources.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Sources (${answer.sources.length}):',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        ...answer.sources.map((source) => Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _SourceCard(source: source),
                            )),
                      ],
                      // Follow-up questions as tappable chips
                      if (answer.followUpQuestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('You might also ask:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        FollowUpChips(
                          questions: answer.followUpQuestions,
                          onAskQuestion: _askFollowUp,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Helpful answer',
                    icon: CoverWiseStateTransition(
                      durationToken: CoverWiseMotion.quick,
                      child: Icon(
                        _feedback == 1
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        key: ValueKey(_feedback == 1),
                      ),
                    ),
                    color: _feedback == 1
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onPressed: () => _saveFeedback(1),
                  ),
                  IconButton(
                    tooltip: 'Unhelpful answer',
                    icon: CoverWiseStateTransition(
                      durationToken: CoverWiseMotion.quick,
                      child: Icon(
                        _feedback == -1
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
                        key: ValueKey(_feedback == -1),
                      ),
                    ),
                    color: _feedback == -1
                        ? Theme.of(context).colorScheme.error
                        : null,
                    onPressed: () => _saveFeedback(-1),
                  ),
                  IconButton(
                    tooltip: _copied ? 'Answer copied' : 'Copy answer',
                    icon: CoverWiseStateTransition(
                      durationToken: CoverWiseMotion.quick,
                      child: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_outlined,
                        key: ValueKey(_copied),
                      ),
                    ),
                    onPressed: () => _copyAnswer(answer),
                  ),
                  IconButton(
                    tooltip: 'Share answer',
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      SharePlus.instance.share(ShareParams(
                          text: 'Q: ${answer.question}\nA: ${answer.text}'));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays a Q&A source with resolved document name attribution.
///
/// When multiple documents are queried, the source's [documentId] is resolved
/// to a human-readable document name via [documentsProvider]. This lets users
/// verify which policy each fact was extracted from.
///
/// Tap to navigate to the source document at the relevant page.
class _SourceCard extends ConsumerWidget {
  final QaSource source;
  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider).valueOrNull ?? [];
    final doc = source.documentId.isNotEmpty
        ? documents
            .where((d) =>
                d.id == source.documentId || d.remoteId == source.documentId)
            .firstOrNull
        : null;
    final docName = doc?.filename;
    final hasPage =
        source.pageNumber != null && source.pageNumber! > 0;

    final title = <String>[
      if (docName != null) docName,
      if (hasPage) S.qaSourcePageLabel(source.pageNumber!),
    ].join(' · ');

    // Show relevance score as a percentage (score is 0.0–1.0)
    final scorePercent = (source.score * 100).round();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: hasPage && doc != null
            ? () => _navigateToSource(
                context,
                ref,
                source.documentId,
                source.pageNumber!,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : S.qaPolicySource,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Relevance score badge with tooltip
                  Tooltip(
                    message: S.qaRelevanceTooltip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scorePercent >= 80
                            ? Colors.green.withValues(alpha: 0.1)
                            : scorePercent >= 50
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$scorePercent%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scorePercent >= 80
                              ? Colors.green
                              : scorePercent >= 50
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  if (hasPage && doc != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                source.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Follow-up question chips that disable and show a spinner while loading.
class FollowUpChips extends ConsumerWidget {
  final List<String> questions;
  final void Function(String) onAskQuestion;

  const FollowUpChips({
    super.key,
    required this.questions,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isLoadingProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: questions
          .map((q) => ActionChip(
                avatar: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward, size: 16),
                label: Text(q, style: const TextStyle(fontSize: 13)),
                onPressed: isLoading ? null : () => onAskQuestion(q),
              ))
          .toList(),
    );
  }
}

/// Confidence badge shown next to Q&A answers.
///
/// Phase 0 P0-0.3 (trust audit, 2026-07-18): the trust audit returns a
/// NO-GO verdict because confidence is computed as
/// `max(model_confidence, retrieval_confidence)` which inflates weak
/// answers. Until a real benchmark calibrates confidence, the badge  /// must NOT show high/medium/low colours — it must be hidden entirely
/// or show a neutral indicator.
///
/// When [AppConfig.confidenceCalibrated] is false (the default), the
/// badge returns a SizedBox.shrink() so users never see an internal
/// confidence label. When true, it shows the legacy high/medium/low
/// chip behaviour.
class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.confidenceCalibrated) {
      // Hide the badge entirely rather than showing 'uncalibrated' —
      // users have no context for that internal label.
      return const SizedBox.shrink();
    }
    final (label, color) = confidence >= 0.7
        ? ('High', Colors.green)
        : confidence >= 0.4
            ? ('Medium', Colors.orange)
            : ('Low', Colors.red);

    return CoverWiseStatusChip(
      icon: confidence >= 0.7
          ? Icons.check_circle_outline_rounded
          : confidence >= 0.4
              ? Icons.info_outline_rounded
              : Icons.warning_amber_rounded,
      label: '$label confidence',
      color: color,
      compact: true,
    );
  }
}
