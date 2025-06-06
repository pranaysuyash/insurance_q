import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/api_service.dart';
import 'screens/qa_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dashboard_screen.dart';
import 'providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/document_model.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get shared preferences instance
  final sharedPreferences = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        // Override the shared preferences provider with the instance
        sharedPreferencesProvider.overrideWith((ref) => sharedPreferences),
      ],
      child: const InsuranceApp(),
    ),
  );
}

class InsuranceApp extends StatelessWidget {
  const InsuranceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insurance Policy App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
      routes: {
        '/qa': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          
          // Return the screen immediately
          return QAScreen(initialDocumentId: args);
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const DashboardScreen(),
    const DocumentsScreen(),
    const QAScreen(),
    const FamilyScreen(),
    const MoreScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.description), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.question_answer), label: 'QA'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Family'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}

// --- Screen Stubs ---
// DashboardScreen moved to its own file: dashboard_screen.dart

class QAScreen extends StatelessWidget {
  final String? initialDocumentId;

  const QAScreen({super.key, this.initialDocumentId});

  @override
  Widget build(BuildContext context) {
    return QaScreen(initialDocumentId: initialDocumentId);
  }
}

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Members'),
      ),
      body: const FamilyMembersContent(),
    );
  }
}

class FamilyMembersContent extends ConsumerStatefulWidget {
  const FamilyMembersContent({super.key});

  @override
  _FamilyMembersContentState createState() => _FamilyMembersContentState();
}

class _FamilyMembersContentState extends ConsumerState<FamilyMembersContent> {
  final _apiService = ApiService();
  List<InsuranceDocument> _documents = [];
  final Map<String, PolicyHolder> _policyHolders = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load documents
      final documents = await _apiService.getDocuments();
      setState(() {
        _documents = documents;
      });
      
      // Extract policy holders from all documents
      await _loadFamilyInformation();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    
    setState(() {
      _isLoading = false;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_policyHolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No family members found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload insurance documents to automatically detect family members',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Family Member'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Family management coming soon!')),
                );
              },
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Family Members & Insured',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._policyHolders.values.map((holder) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(
                          holder.relationship == 'Primary Insured' 
                              ? Icons.person 
                              : Icons.people_alt,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              holder.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              holder.relationship,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (holder.dob != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.cake, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Date of Birth: ${holder.dob}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Family Member'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Family management coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Options'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            subtitle: const Text('App preferences and account settings'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            subtitle: const Text('FAQs and contact information'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support coming soon!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy & Security'),
            subtitle: const Text('Manage your data and privacy settings'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy & Security coming soon!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('App version and legal information'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('About coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
