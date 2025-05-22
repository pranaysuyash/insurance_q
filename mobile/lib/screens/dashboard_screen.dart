import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/storage_provider.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';
import 'qa_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _localStorageService = LocalStorageService();
  final _apiService = ApiService();
  List<InsuranceDocument> _documents = [];
  List<String> _recentQuestions = [];
  bool _isLoading = true;
  final Map<String, int> _documentTypeCount = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Load documents
    try {
      final documents = await _localStorageService.getDocuments();
      setState(() {
        _documents = documents;
        
        // Calculate document type counts
        _documentTypeCount.clear();
        for (var doc in documents) {
          final type = doc.documentType?.toLowerCase() ?? 'unknown';
          _documentTypeCount[type] = (_documentTypeCount[type] ?? 0) + 1;
        }
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
    }
    
    // Load recent questions
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        final questions = prefs.getStringList(StorageKeys.recentQuestions) ?? [];
        setState(() {
          _recentQuestions = questions;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent questions: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        _buildWelcomeCard(),
                        const SizedBox(height: 20),
                        _buildDocumentSummary(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildRecentActivities(),
                        const SizedBox(height: 20),
                        _buildInsuranceTerminology(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Your Insurance Hub',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have ${_documents.length} documents in your library',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            if (_documents.isEmpty)
              const Text(
                'Upload your first document to get started!',
                style: TextStyle(
                  color: Colors.blue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents by Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_documents.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No documents yet. Add your first document!'),
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDocumentTypeCard('Health Insurance', Icons.health_and_safety, Colors.green),
                _buildDocumentTypeCard('Auto Insurance', Icons.directions_car, Colors.blue),
                _buildDocumentTypeCard('Home Insurance', Icons.home, Colors.brown),
                _buildDocumentTypeCard('Life Insurance', Icons.favorite, Colors.red),
                _buildDocumentTypeCard('Other', Icons.description, Colors.grey),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentTypeCard(String type, IconData icon, Color color) {
    final count = _documentTypeCount[type.toLowerCase()] ?? 0;
    final hasDocuments = count > 0;
    
    return Card(
      elevation: 2,
      color: hasDocuments ? null : Colors.grey.shade100,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: hasDocuments ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              type,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hasDocuments ? '$count document${count > 1 ? "s" : ""}' : 'No documents',
              style: TextStyle(
                color: hasDocuments ? Colors.black87 : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.upload_file,
                label: 'Upload Document',
                color: Colors.blue,
                onTap: () {
                  print("Upload Document tapped");
                  // Navigate to upload document
                  Navigator.pushNamed(context, '/');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.question_answer,
                label: 'Ask a Question',
                color: Colors.purple,
                onTap: () {
                  print("Ask a Question tapped");
                  // Navigate to QA Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QaScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.compare_arrows,
                label: 'Compare Policies',
                color: Colors.orange,
                onTap: () {
                  // Show coming soon snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Policy comparison coming soon!'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.help_outline,
                label: 'Insurance Terms',
                color: Colors.teal,
                onTap: () {
                  // Show terminology dialog
                  _showInsuranceTerminologyDialog(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    // Sort documents by upload date
    final recentDocuments = [..._documents]
      ..sort((a, b) => b.uploadedOn.compareTo(a.uploadedOn));
    
    // Take only the last 3
    final documents = recentDocuments.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activities',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Recent documents
        if (documents.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Recently uploaded documents',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ...documents.map((doc) => _buildActivityItem(
            icon: Icons.upload_file,
            title: doc.filename,
            subtitle: 'Uploaded on ${_formatDate(doc.uploadedOn)}',
            color: Colors.blue,
          )),
          const SizedBox(height: 8),
        ],
        
        // Recent questions
        if (_recentQuestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Recent questions',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ..._recentQuestions.take(3).map((question) => _buildActivityItem(
            icon: Icons.question_answer,
            title: question,
            subtitle: 'Asked recently',
            color: Colors.purple,
          )),
        ],
        
        // No activities
        if (documents.isEmpty && _recentQuestions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No recent activities'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildInsuranceTerminology() {
    print("Building _buildInsuranceTerminology");
    // Common insurance terms for quick reference
    const terms = [
      {'term': 'Premium', 'definition': 'The amount paid for an insurance policy'},
      {'term': 'Deductible', 'definition': 'The amount you pay before insurance covers costs'},
      {'term': 'Copay', 'definition': 'A fixed amount you pay for a covered service'},
      {'term': 'Coverage Limit', 'definition': 'Maximum amount insurer will pay for a covered loss'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Insurance Terminology',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _showInsuranceTerminologyDialog(context),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: terms.map((item) {
                print("Mapping term: ${item['term']}");
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['term']}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(item['definition']!),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _showInsuranceTerminologyDialog(BuildContext context) {
    print("Showing terminology dialog");
    // Full insurance terminology glossary
    const terminology = [
      {'letter': 'A', 'terms': [
        {'term': 'Actual Cash Value (ACV)', 'definition': 'The cost to replace damaged property minus depreciation'},
        {'term': 'Adjuster', 'definition': 'A person who investigates and settles insurance claims'},
      ]},
      {'letter': 'C', 'terms': [
        {'term': 'Claim', 'definition': 'A formal request to an insurance company for payment'},
        {'term': 'Coinsurance', 'definition': 'The percentage of costs you pay after paying your deductible'},
        {'term': 'Copay', 'definition': 'A fixed amount you pay for a covered health care service'},
      ]},
      {'letter': 'D', 'terms': [
        {'term': 'Deductible', 'definition': 'Amount you pay before your insurance plan starts to pay'},
        {'term': 'Depreciation', 'definition': 'Decrease in property value over time due to wear and tear'},
      ]},
      {'letter': 'P', 'terms': [
        {'term': 'Premium', 'definition': 'The amount paid for an insurance policy'},
        {'term': 'Pre-Existing Condition', 'definition': 'Health problem you had before new coverage starts'},
      ]},
    ];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            AppBar(
              title: const Text('Insurance Terminology'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: terminology.length,
                itemBuilder: (context, index) {
                  final section = terminology[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          section['letter']! as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...(section['terms'] as List).map((term) => ListTile(
                        title: Text(
                          term['term']!,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(term['definition']!),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      )).toList(),
                      const Divider(),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  // In a real app, this would navigate to a full glossary screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full glossary documentation available in the app!'),
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('View Complete Glossary'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 