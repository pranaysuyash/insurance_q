import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/storage_provider.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';
import 'qa_screen.dart';
import 'documents_screen.dart';

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
  
  // Store family information
  final Map<String, PolicyHolder> _policyHolders = {};
  bool _isLoadingFamilyInfo = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingFamilyInfo = true;
    });
    
    // Load documents
    try {
      final documents = await _apiService.getDocuments();
      setState(() {
        _documents = documents;
        
        // Calculate document type counts
        _documentTypeCount.clear();
        for (var doc in documents) {
          final type = doc.documentType?.toLowerCase() ?? 'unknown';
          _documentTypeCount[type] = (_documentTypeCount[type] ?? 0) + 1;
        }
      });

      // Load family information
      if (documents.isNotEmpty) {
        await _loadFamilyInformation();
      }
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

    // Load deleted documents activity (if available)
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        // Check for recently deleted documents
        final deletedDocs = prefs.getStringList(StorageKeys.recentlyDeletedDocs) ?? [];
        if (deletedDocs.isNotEmpty) {
          setState(() {
            // Add to _recentlyDeletedDocs if we need to track separately
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading deleted documents: $e');
    }

    setState(() {
      _isLoading = false;
      _isLoadingFamilyInfo = false;
    });
  }

  Future<void> _loadFamilyInformation() async {
    // Clear existing data
    _policyHolders.clear();
    
    // Collect all policy holders from all documents
    for (final doc in _documents) {
      try {
        // Check if document already has policy holders
        if (doc.policyHolders != null && doc.policyHolders!.isNotEmpty) {
          // Use stored policy holders
          for (final holder in doc.policyHolders!) {
            _policyHolders[holder.name] = holder;
          }
        } else {
          // Extract policy holders if not already available
          final holders = await _apiService.extractPolicyHolders(doc.id);
          
          // Add to unique holders by name
          for (final holder in holders) {
            _policyHolders[holder.name] = holder;
          }
        }
      } catch (e) {
        debugPrint('Error extracting policy holders: $e');
      }
    }
    
    // Update UI
    setState(() {});
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
                        if (_documents.isNotEmpty) _buildFamilyInformation(),
                        if (_documents.isNotEmpty) const SizedBox(height: 20),
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
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: hasDocuments ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  type,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasDocuments ? '$count document${count > 1 ? "s" : ""}' : 'No documents',
                style: TextStyle(
                  color: hasDocuments ? Colors.black87 : Colors.grey,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
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
                  // Navigate to DocumentsScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DocumentsScreen()),
                  );
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  color: color.withValues(alpha: 0.8),
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
    
    // Get recently deleted documents
    final prefs = ref.read(sharedPreferencesProvider);
    List<String> deletedDocs = [];
    if (prefs != null) {
      deletedDocs = prefs.getStringList(StorageKeys.recentlyDeletedDocs) ?? [];
    }
    
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
        
        // Deleted documents
        if (deletedDocs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Recently deleted documents',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ...deletedDocs.take(2).map((filename) => _buildActivityItem(
            icon: Icons.delete_outline,
            title: filename,
            subtitle: 'Deleted recently',
            color: Colors.red,
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
        if (documents.isEmpty && _recentQuestions.isEmpty && deletedDocs.isEmpty)
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
          backgroundColor: color.withValues(alpha: 0.1),
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
        {'term': 'Agent', 'definition': 'A person who sells and services insurance policies'},
        {'term': 'Amendment', 'definition': 'A change or addition to an insurance policy'},
        {'term': 'Annuity', 'definition': 'A contract that provides a series of payments over time'},
      ]},
      {'letter': 'B', 'terms': [
        {'term': 'Beneficiary', 'definition': 'The person or entity named to receive policy benefits'},
        {'term': 'Binder', 'definition': 'A temporary insurance contract that provides proof of coverage until a permanent policy is issued'},
        {'term': 'Broker', 'definition': 'An insurance professional who represents consumers in their search for coverage'},
      ]},
      {'letter': 'C', 'terms': [
        {'term': 'Claim', 'definition': 'A formal request to an insurance company for payment based on the terms of the policy'},
        {'term': 'Coinsurance', 'definition': 'The percentage of costs of a covered health care service you pay after you\'ve paid your deductible'},
        {'term': 'Copay (Copayment)', 'definition': 'A fixed amount you pay for a covered health care service after you\'ve paid your deductible'},
        {'term': 'Coverage Limit', 'definition': 'The maximum amount an insurer will pay for a covered loss'},
        {'term': 'Certificate of Insurance', 'definition': 'A document issued by an insurance company that verifies the existence of an insurance policy'},
      ]},
      {'letter': 'D', 'terms': [
        {'term': 'Deductible', 'definition': 'The amount you pay for covered health care services before your insurance plan starts to pay'},
        {'term': 'Depreciation', 'definition': 'The decrease in an asset\'s value due to use, wear and tear, or obsolescence'},
        {'term': 'Declarations Page', 'definition': 'The part of your insurance policy that includes your name, address, policy number, coverage details, and premium'},
        {'term': 'Domiciliary Hospitalization', 'definition': 'Medical treatment taken at home which would otherwise require hospitalization'},
      ]},
      {'letter': 'E', 'terms': [
        {'term': 'Endorsement', 'definition': 'An amendment or addition to an existing insurance policy that changes the terms or scope of the original policy'},
        {'term': 'Exclusion', 'definition': 'A provision in an insurance policy that eliminates coverage for certain risks, people, property classes, or locations'},
        {'term': 'Effective Date', 'definition': 'The date on which an insurance policy becomes active'},
        {'term': 'Expiration Date', 'definition': 'The date on which an insurance policy is no longer in effect'},
      ]},
      {'letter': 'G', 'terms': [
        {'term': 'Grace Period', 'definition': 'A set amount of time after the premium due date during which policyholders can make a premium payment without their coverage lapsing'},
        {'term': 'Group Insurance', 'definition': 'Insurance coverage offered to a group of people, such as employees of a company or members of an association'},
      ]},
      {'letter': 'I', 'terms': [
        {'term': 'Indemnity', 'definition': 'A principle of insurance that aims to restore the insured to the same financial position they were in before a loss occurred'},
        {'term': 'Insurable Interest', 'definition': 'A financial interest in the property or person being insured; the policyholder must suffer a financial loss if a covered event occurs'},
        {'term': 'Insured', 'definition': 'The person or entity covered by an insurance policy'},
        {'term': 'Insurer', 'definition': 'The insurance company that provides coverage and pays claims'},
      ]},
      {'letter': 'L', 'terms': [
        {'term': 'Lapse', 'definition': 'The termination of an insurance policy due to non-payment of premiums'},
        {'term': 'Liability Insurance', 'definition': 'Insurance that covers costs associated with legal claims against the insured for bodily injury or property damage'},
        {'term': 'Loss', 'definition': 'The financial damage or injury suffered by an insured person or property'},
      ]},
      {'letter': 'P', 'terms': [
        {'term': 'Policy', 'definition': 'The written contract of insurance between the insurer and the insured'},
        {'term': 'Premium', 'definition': 'The amount paid, often in installments, for an insurance policy'},
        {'term': 'Pre-Existing Condition', 'definition': 'A health problem that existed before the date your new health coverage became effective'},
        {'term': 'Policyholder', 'definition': 'The individual or entity that owns an insurance policy'},
        {'term': 'Peril', 'definition': 'A specific risk or cause of loss covered by an insurance policy, such as a fire, windstorm, or theft'},
      ]},
      {'letter': 'R', 'terms': [
        {'term': 'Rider', 'definition': 'An add-on to an insurance policy that provides additional benefits or amends the terms of the policy'},
        {'term': 'Reinstatement', 'definition': 'The process of putting a lapsed insurance policy back into force'},
        {'term': 'Renewal', 'definition': 'The continuation of an insurance policy beyond its original term'},
      ]},
      {'letter': 'S', 'terms': [
        {'term': 'Subrogation', 'definition': 'The right of an insurer to pursue a third party that caused an insurance loss to the insured'},
        {'term': 'Sum Insured', 'definition': 'The maximum amount an insurance company will pay out for a covered claim'},
      ]},
      {'letter': 'U', 'terms': [
        {'term': 'Underwriting', 'definition': 'The process insurers use to evaluate the risk of insuring a person or asset and to determine policy terms and premiums'},
        {'term': 'UIN (Unique Identification Number)', 'definition': 'A unique number assigned by the insurance regulator to each insurance product'},
      ]},
    ];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important for dialog sizing
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
            Flexible( // Allows the ListView to take available space and scroll
              child: ListView.builder(
                shrinkWrap: true, // Important with Flexible in a Column
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Add some padding
                itemCount: terminology.length,
                itemBuilder: (context, index) {
                  final section = terminology[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          section['letter']! as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue, // Added color for section letter
                          ),
                        ),
                      ),
                      ...(section['terms'] as List).map((term) => ListTile(
                        title: Text(
                          term['term']!,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0), // Add padding to subtitle
                          child: Text(term['definition']!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      )),
                      if (index < terminology.length - 1) // Add divider between sections
                         const Divider(indent: 16, endIndent: 16),
                    ],
                  );
                },
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

  Widget _buildFamilyInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Family Members & Insured',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_isLoadingFamilyInfo)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_policyHolders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No family information detected in your policies'),
              ),
            ),
          )
        else
          ...(_policyHolders.values).map((holder) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                child: Icon(
                  holder.relationship == 'Primary Insured' 
                      ? Icons.person 
                      : Icons.people_alt,
                  color: Colors.blue,
                ),
              ),
              title: Text(holder.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (holder.dob != null)
                    Text('DOB: ${holder.dob}'),
                  Text(holder.relationship),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          )),
        
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Family Member'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Family management coming soon!')),
              );
            },
          ),
        ),
      ],
    );
  }
} 