import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/qa_models.dart';
import '../models/document_model.dart';
import '../providers/questions_provider.dart';
import '../providers/storage_provider.dart';
import '../services/api_service.dart';
import 'document_selection_dialog.dart';

final isLoadingProvider = StateProvider<bool>((ref) => false);
final currentAnswerProvider = StateProvider<QaAnswer?>((ref) => null);

class QaScreen extends ConsumerStatefulWidget {
  final String? initialDocumentId;
  
  const QaScreen({Key? key, this.initialDocumentId}) : super(key: key);

  @override
  _QaScreenState createState() => _QaScreenState();
}

class _QaScreenState extends ConsumerState<QaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _customQuestionController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<InsuranceDocument> _documents = [];
  bool _isLoadingDocuments = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDocuments();
    _loadSavedDocumentId();
    
    // Set the initial document ID if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDocumentId != null) {
        ref.read(selectedDocumentProvider.notifier).state = widget.initialDocumentId;
        _saveSelectedDocumentId(widget.initialDocumentId);
      }
    });
  }
  
  Future<void> _loadSavedDocumentId() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        final savedId = prefs.getString(StorageKeys.selectedDocumentId);
        if (savedId != null) {
          ref.read(selectedDocumentProvider.notifier).state = savedId;
        }
      }
    } catch (e) {
      print('Error loading saved document ID: $e');
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
        }
      }
    } catch (e) {
      print('Error saving document ID: $e');
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
  
  Future<void> _askQuestion(String question) async {
    final selectedDoc = ref.read(selectedDocumentProvider);
    
    ref.read(isLoadingProvider.notifier).state = true;
    ref.read(currentAnswerProvider.notifier).state = null;
    
    // Add some logs to help debug
    print('Asking question: $question');
    print('Selected document: $selectedDoc');
    
    try {
      // Format the question to be more conversational and specific
      // This often helps LLMs understand the intent better
      String formattedQuestion = question;
      
      // For standard questions, enhance them slightly to help the model
      if (question == "What is my policy number?") {
        formattedQuestion = "What is the policy number shown in this insurance document?";
      } else if (question.contains("deductible")) {
        formattedQuestion = "What is the deductible amount specified in this insurance policy?";
      } else if (question.contains("premium")) {
        formattedQuestion = "What is the premium amount stated in this insurance document?";
      }
      
      print('Formatted question: $formattedQuestion');
      
      final result = await _apiService.queryDocument(
        formattedQuestion, 
        documentId: selectedDoc,
      );
      
      print('API response: $result');
      
      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['error']}')),
        );
        return;
      }
      
      final answer = QaAnswer.fromJson({
        ...result,
        'query': question, // Keep the original question for the UI
        'document_id': selectedDoc ?? '',
      });
      
      ref.read(currentAnswerProvider.notifier).state = answer;
      ref.read(qaHistoryProvider.notifier).addItem(question, answer);
      
    } catch (e) {
      print('Error during question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _isLoadingDocuments
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _getSelectedDocumentIcon(),
                              size: 24,
                              color: Theme.of(context).primaryColor,
                            ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getSelectedDocumentName(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.change_circle),
                          label: const Text('Change'),
                          onPressed: _isLoadingDocuments ? null : _showDocumentSelectionDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Tabs content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Standard Questions Tab
                ListView(
                  children: [
                    for (final category in categories)
                      ExpansionTile(
                        title: Text(category),
                        children: [
                          ...standardQuestions
                              .where((q) => q.category == category)
                              .map((q) => ListTile(
                                    leading: Icon(q.icon),
                                    title: Text(q.text),
                                    onTap: () => _askQuestion(q.text),
                                  )),
                        ],
                      ),
                  ],
                ),
                
                // Custom Question Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _customQuestionController,
                        decoration: const InputDecoration(
                          labelText: 'Ask a question about your insurance policy',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.help_outline),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Ask Question'),
                        onPressed: () {
                          if (_customQuestionController.text.trim().isNotEmpty) {
                            _askQuestion(_customQuestionController.text.trim());
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                // History Tab
                qaHistory.isEmpty
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
                      ),
              ],
            ),
          ),
          
          // Answer display area
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (currentAnswer != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q: ${currentAnswer.question}',
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
                                  'A: ${currentAnswer.text}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (currentAnswer.sources.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Sources:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  ...currentAnswer.sources.map((source) => Padding(
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
              ),
            ),
        ],
      ),
    );
  }
  
  String _getSelectedDocumentName() {
    final selectedId = ref.watch(selectedDocumentProvider);
    if (selectedId == null) {
      return 'All Documents';
    }
    
    final selectedDoc = _documents.firstWhere(
      (doc) => doc.id == selectedId,
      orElse: () => InsuranceDocument(
        id: '',
        filename: 'Unknown Document',
        uploadedOn: DateTime.now(),
      ),
    );
    
    return selectedDoc.filename;
  }
  
  IconData _getSelectedDocumentIcon() {
    final selectedId = ref.watch(selectedDocumentProvider);
    if (selectedId == null) {
      return Icons.inventory;
    }
    
    final selectedDoc = _documents.firstWhere(
      (doc) => doc.id == selectedId,
      orElse: () => InsuranceDocument(
        id: '',
        filename: 'Unknown Document',
        uploadedOn: DateTime.now(),
        documentType: null,
      ),
    );
    
    if (selectedDoc.documentType == null) {
      return Icons.description;
    }
    
    switch (selectedDoc.documentType!.toLowerCase()) {
      case 'health insurance':
        return Icons.health_and_safety;
      case 'auto insurance':
        return Icons.directions_car;
      case 'life insurance':
        return Icons.favorite;
      case 'home insurance':
        return Icons.home;
      default:
        return Icons.description;
    }
  }
} 