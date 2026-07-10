import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/qa_models.dart';
import '../models/document_model.dart';
import '../config/app_config.dart';
import '../providers/questions_provider.dart';
import '../providers/storage_provider.dart';
import '../services/api_service.dart';
import 'document_selection_dialog.dart';

final isLoadingProvider = StateProvider<bool>((ref) => false);
final currentAnswerProvider = StateProvider<QaAnswer?>((ref) => null);

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
  final ApiService _apiService = ApiService();
  List<InsuranceDocument> _documents = [];
  bool _isLoadingDocuments = false;
  bool _demoSequenceStarted = false;
  int _demoSequenceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load documents first, then handle document selection
    _loadDocuments().then((_) {
      _loadSavedDocumentId();

      // Set the initial document ID if provided
      if (widget.initialDocumentId != null) {
        ref.read(selectedDocumentProvider.notifier).state =
            widget.initialDocumentId;
        _saveSelectedDocumentId(widget.initialDocumentId);
      }

      _maybeStartDemoSequence();
    });
  }

  @override
  void didUpdateWidget(covariant QaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive && !widget.isActive) {
      // Stop any remaining scripted demo steps once QA is no longer visible.
      _demoSequenceStarted = false;
      _demoSequenceGeneration++;
    }
  }

  @override
  void deactivate() {
    // Cancel any in-flight demo work the moment this screen leaves the tree.
    _demoSequenceGeneration++;
    _demoSequenceStarted = false;
    super.deactivate();
  }

  Future<void> _maybeStartDemoSequence() async {
    if (!AppConfig.bootstrapPolicyDemo || _demoSequenceStarted) return;
    if (!widget.isActive) return;
    if (_documents.isEmpty) return;

    _demoSequenceStarted = true;
    final demoGeneration = _demoSequenceGeneration;
    final selectedDocument = _documents.first;
    ref.read(selectedDocumentProvider.notifier).state = selectedDocument.id;
    await _saveSelectedDocumentId(selectedDocument.id);

    if (!mounted ||
        !widget.isActive ||
        demoGeneration != _demoSequenceGeneration) {
      return;
    }
    _tabController.animateTo(1);

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

  Future<void> _loadSavedDocumentId() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        // First try to use explicit initial document ID if provided
        if (widget.initialDocumentId != null) {
          ref.read(selectedDocumentProvider.notifier).state =
              widget.initialDocumentId;
          return;
        }

        // Next, try to use the previously selected document ID
        final savedId = prefs.getString(StorageKeys.selectedDocumentId);
        if (savedId != null) {
          ref.read(selectedDocumentProvider.notifier).state = savedId;
          return;
        }

        // Then, try to use the most recently viewed document
        final lastViewedId = prefs.getString(StorageKeys.lastViewedDocumentId);
        if (lastViewedId != null) {
          ref.read(selectedDocumentProvider.notifier).state = lastViewedId;
          return;
        }

        // Finally, try to use the last uploaded document
        final lastUploadedId =
            prefs.getString(StorageKeys.lastUploadedDocumentId);
        if (lastUploadedId != null) {
          ref.read(selectedDocumentProvider.notifier).state = lastUploadedId;
          return;
        }

        // If there's just one document, auto-select it
        if (_documents.length == 1) {
          ref.read(selectedDocumentProvider.notifier).state = _documents[0].id;
        }
      }
    } catch (e) {
      debugPrint('Error loading saved document ID: $e');
    }
  }

  Future<void> _saveSelectedDocumentId(String? documentId) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        if (documentId == null) {
          await prefs.remove(StorageKeys.selectedDocumentId);
        } else {
          await prefs.setString(StorageKeys.selectedDocumentId, documentId);
          // Also save as the most recently viewed document
          await prefs.setString(StorageKeys.lastViewedDocumentId, documentId);
        }
      }
    } catch (e) {
      debugPrint('Error saving document ID: $e');
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoadingDocuments = true;
    });

    try {
      final documents = await _apiService.getDocuments();
      setState(() {
        _documents = documents;
        _isLoadingDocuments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDocuments = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading documents: $e')),
      );
    }
  }

  void _showDocumentSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => DocumentSelectionDialog(
        documents: _documents,
        currentDocumentId: ref.read(selectedDocumentProvider),
        onDocumentSelected: (documentId) {
          ref.read(selectedDocumentProvider.notifier).state = documentId;
          _saveSelectedDocumentId(documentId);
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
    if (!mounted || !widget.isActive) return;
    if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
      return;
    }
    final selectedDoc = ref.read(selectedDocumentProvider);

    ref.read(isLoadingProvider.notifier).state = true;
    ref.read(currentAnswerProvider.notifier).state = null;

    // Add some logs to help debug
    debugPrint('Asking question: $question');
    debugPrint('Selected document: $selectedDoc');

    try {
      // Format the question to be more conversational and specific
      // This often helps LLMs understand the intent better
      String formattedQuestion = question;

      // For standard questions, enhance them slightly to help the model
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

      debugPrint('Formatted question: $formattedQuestion');

      // Query with document filtering to get results from the selected document
      final result = await _apiService.queryDocument(
        formattedQuestion,
        documentId: selectedDoc, // Re-enable document filtering
      );

      if (!mounted || !widget.isActive) return;
      if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
        return;
      }
      debugPrint('API response: $result');

      if (result.containsKey('error')) {
        // Don't immediately show error - try to show answer if available
        if (!result.containsKey('answer')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result['error']}')),
          );
          return;
        }
      }

      // Create answer from result
      debugPrint('Creating QaAnswer from result: $result');
      final answer = QaAnswer.fromJson({
        ...result,
        'query': question, // Keep the original question for the UI
        'document_id': selectedDoc ?? '',
      });
      debugPrint('Created QaAnswer: ${answer.text}');

      if (!mounted) return;
      if (!widget.isActive) return;
      if (demoGeneration != null && demoGeneration != _demoSequenceGeneration) {
        return;
      }

      // Update UI with answer
      ref.read(currentAnswerProvider.notifier).state = answer;

      // Add to history if there's an actual answer
      if (answer.text.isNotEmpty) {
        ref.read(qaHistoryProvider.notifier).addItem(question, answer);

        // Save to recent questions list (up to 5 questions)
        try {
          final prefs = ref.read(sharedPreferencesProvider);
          if (prefs != null) {
            final recentQuestions =
                prefs.getStringList(StorageKeys.recentQuestions) ?? [];
            if (!recentQuestions.contains(question)) {
              recentQuestions.insert(0, question);
              // Keep only the 5 most recent questions
              if (recentQuestions.length > 5) {
                recentQuestions.removeLast();
              }
              await prefs.setStringList(
                  StorageKeys.recentQuestions, recentQuestions);
            }
          }
        } catch (e) {
          debugPrint('Error saving recent question: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during question: $e');

      // Create a fallback answer
      final fallbackAnswer = QaAnswer(
        text:
            'Sorry, I encountered an error while processing your question. This may be due to a network issue or server problem. Please try again later.',
        sources: [],
        timestamp: DateTime.now(),
        documentId: selectedDoc ?? '',
        question: question,
      );

      if (!mounted) return;
      if (!widget.isActive) return;
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

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(questionCategoriesProvider);
    final standardQuestions = ref.watch(standardQuestionsProvider);
    final qaHistory = ref.watch(qaHistoryProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final currentAnswer = ref.watch(currentAnswerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Q&A'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Documents',
            onPressed: _isLoadingDocuments ? null : _loadDocuments,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Standard Questions'),
            Tab(text: 'Custom Question'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Document selector area (enhanced)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ask Questions About',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer(builder: (context, ref, child) {
                      final selectedDocumentId =
                          ref.watch(selectedDocumentProvider);
                      final selectedDoc = _documents.firstWhere(
                          (doc) => doc.id == selectedDocumentId,
                          orElse: () => InsuranceDocument(
                              id: '',
                              filename: 'No document selected',
                              uploadedOn: DateTime.now()));

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              selectedDoc.filename,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Change'),
                            onPressed: _isLoadingDocuments
                                ? null
                                : _showDocumentSelectionDialog,
                            style:
                                TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                        ],
                      );
                    }),
                    if (_isLoadingDocuments)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(),
                      )
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            // Make TabBarView take remaining space
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStandardQuestionsTab(
                    categories, standardQuestions, isLoading, currentAnswer),
                _buildCustomQuestionTab(isLoading, currentAnswer),
                _buildHistoryTab(qaHistory),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardQuestionsTab(
      List<QuestionCategory> categories,
      List<StandardQuestion> questions,
      bool isLoading,
      QaAnswer? currentAnswer) {
    // Group questions by category for the UI
    Map<String, List<StandardQuestion>> groupedQuestions = {};
    for (var question in questions) {
      groupedQuestions.putIfAbsent(question.category, () => []).add(question);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: categories.length + (currentAnswer != null ? 1 : 0),
      itemBuilder: (context, index) {
        // If this is the last item and we have an answer, show it
        if (currentAnswer != null && index == categories.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: _buildAnswerCard(currentAnswer),
          );
        }

        final category = categories[index];
        final categoryQuestions = groupedQuestions[category.id] ?? [];

        if (categoryQuestions.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...categoryQuestions.map((q) => ListTile(
                      title: Text(q.text, style: const TextStyle(fontSize: 15)),
                      trailing: isLoading && currentAnswer?.query == q.text
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.question_answer_outlined,
                              color: Colors.blue),
                      onTap: isLoading ? null : () => _askQuestion(q.text),
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomQuestionTab(bool isLoading, QaAnswer? currentAnswer) {
    return SingleChildScrollView(
      // Make this tab scrollable
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask your own question about the selected document.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customQuestionController,
            decoration: InputDecoration(
                hintText: 'e.g., What is the effective date?',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _customQuestionController.clear(),
                )),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _askQuestion(value.trim());
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Ask Question'),
            onPressed:
                isLoading || _customQuestionController.text.trim().isEmpty
                    ? null
                    : () => _askQuestion(_customQuestionController.text.trim()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (currentAnswer != null &&
              currentAnswer.query == _customQuestionController.text.trim())
            _buildAnswerCard(currentAnswer),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(List<QaPair> qaHistory) {
    return qaHistory.isEmpty
        ? const Center(child: Text('No question history yet'))
        : ListView.builder(
            itemCount: qaHistory.length,
            itemBuilder: (context, index) {
              final item = qaHistory[index];
              return ListTile(
                title: Text(item.question),
                subtitle: Text(
                  '${item.answer.text.substring(0, item.answer.text.length > 50 ? 50 : item.answer.text.length)}...',
                ),
                trailing: Text(
                  '${item.timestamp.hour}:${item.timestamp.minute}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  ref.read(currentAnswerProvider.notifier).state = item.answer;
                },
              );
            },
          );
  }

  Widget _buildAnswerCard(QaAnswer answer) {
    return Container(
      height: MediaQuery.of(context).size.height / 2,
      padding: const EdgeInsets.all(8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q: ${answer.question}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A: ${answer.text}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (answer.sources.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Sources:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        ...answer.sources.map((source) => Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (source.pageNumber != null)
                                      Text(
                                        'Page ${source.pageNumber}',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text(source.text),
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      // TODO: Implement copy to clipboard
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      // TODO: Implement share functionality
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
