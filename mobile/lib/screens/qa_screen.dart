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
import '../theme/coverwise_theme.dart';
import '../theme/coverwise_motion.dart';
import 'document_selection_dialog.dart';

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
    if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
      return;
    }

    final selectedDoc = _currentDocumentId();
    ref.read(isLoadingProvider.notifier).state = true;
    ref.read(currentAnswerProvider.notifier).state = null;

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['error']}')),
        );
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
        ref.read(qaHistoryProvider.notifier).addItem(question, answer);
        try {
          await AppStateRepository.addRecentQuestion(question);
        } catch (e) {
          debugPrint('Error saving recent question: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during question: $e');
      final fallbackAnswer = QaAnswer(
        text:
            'Sorry, I encountered an error while processing your question. Please try again later.',
        sources: [],
        timestamp: DateTime.now(),
        documentId: selectedDoc ?? '',
        question: question,
      );

      if (!mounted || !widget.isActive) {
        return;
      }
      if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
        return;
      }
      ref.read(currentAnswerProvider.notifier).state = fallbackAnswer;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
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
        title: const Text('Ask CoverWise'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Suggested'),
            Tab(text: 'Your question'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
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
        label: 'Question source',
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ASK ABOUT',
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
                            ? 'All Documents (${documents.length})'
                            : 'Single Document',
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
                    'Search across all your uploaded policies',
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
            'Ask about cover, exclusions, dates or wording in your policy.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'e.g., What is the effective date?',
              suffixIcon: IconButton(
                tooltip: 'Clear question',
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
            label: const Text('Ask CoverWise'),
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

class _HistoryTab extends StatelessWidget {
  final List<QaPair> qaHistory;
  final void Function(QaAnswer) onSelectAnswer;

  const _HistoryTab({required this.qaHistory, required this.onSelectAnswer});

  @override
  Widget build(BuildContext context) {
    if (qaHistory.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: 'No question history yet',
        color: Color(0xFF6A4BA8),
      );
    }

    return ListView.builder(
      itemCount: qaHistory.length,
      itemBuilder: (context, index) {
        final item = qaHistory[index];
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: ListTile(
            leading: const CoverWiseIconBadge(
              icon: Icons.history_rounded,
              color: CoverWiseColors.blue,
              size: 40,
            ),
            title: Text(item.question,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${item.answer.text.substring(0, item.answer.text.length > 50 ? 50 : item.answer.text.length)}...',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => onSelectAnswer(item.answer),
          ),
        );
      },
    );
  }
}

class _AnswerCard extends StatefulWidget {
  final QaAnswer answer;
  const _AnswerCard({required this.answer});

  @override
  State<_AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<_AnswerCard> {
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
    // Set loading state immediately so the UI shows a spinner
    qaState.ref.read(isLoadingProvider.notifier).state = true;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Answer copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );

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
                      if (answer.sources.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Sources:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        ...answer.sources.map((source) => Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: CoverWiseInfoPanel(
                                icon: Icons.menu_book_outlined,
                                title: source.pageNumber == null
                                    ? 'Policy source'
                                    : 'Page ${source.pageNumber}',
                                body: source.text,
                              ),
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
/// Displays a color-coded chip indicating the backend's confidence level.
/// No badge is shown if confidence is null (backend didn't return it).
class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
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
