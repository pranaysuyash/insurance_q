import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'services/api_service.dart';
import 'screens/qa_screen.dart';
import 'screens/documents_list.dart';
import 'providers/questions_provider.dart';
import 'providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Dashboard/Home'));
  }
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  File? _selectedFile;
  bool _isUploading = false;
  String? _uploadError;
  Map<String, dynamic>? _ocrResult;
  final ApiService _apiService = ApiService();
  final GlobalKey<DocumentsListState> _documentsListKey = GlobalKey<DocumentsListState>();
  bool _showUploadDetails = false;

  Future<void> _pickFile() async {
    setState(() {
      _uploadError = null;
      _ocrResult = null;
    });
    
    final typeGroup = XTypeGroup(
      label: 'Documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    
    if (file != null) {
      setState(() {
        _selectedFile = File(file.path);
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;
    
    // Check for duplicate documents first
    final duplicate = await _apiService.checkForDuplicateDocument(_selectedFile!);
    
    if (duplicate != null) {
      // Show confirmation dialog for duplicate
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A similar document already exists:'),
              const SizedBox(height: 8),
              Text(
                duplicate.filename,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Uploaded on: ${duplicate.formattedUploadDate}'),
              const SizedBox(height: 16),
              const Text(
                'Uploading this document will count against your storage limit. Do you want to replace the existing document or keep both?',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Keep Both'),
            ),
          ],
        ),
      );
      
      // If cancel was selected, stop the upload
      if (shouldReplace == false) {
        return;
      }
      
      // If replace was selected, delete the existing document first
      if (shouldReplace == true) {
        setState(() {
          _isUploading = true;
        });
        
        final deleted = await _apiService.deleteDocument(duplicate.id);
        if (!deleted) {
          setState(() {
            _isUploading = false;
            _uploadError = 'Failed to delete existing document';
          });
          return;
        }
      }
      // If "Keep Both" was selected (shouldReplace is null), continue with upload
    }
    
    setState(() {
      _isUploading = true;
      _uploadError = null;
      _ocrResult = null;
    });
    
    try {
      final result = await _apiService.uploadDocumentWithLimitCheck(_selectedFile!);
      setState(() {
        _ocrResult = result;
      });
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _refreshDocumentsList() {
    if (_documentsListKey.currentState != null) {
      _documentsListKey.currentState!.loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload card
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Document',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedFile != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showUploadDetails = !_showUploadDetails;
                          });
                        },
                        child: Text(_showUploadDetails ? 'Hide Details' : 'Show Details'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Select Document'),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Text('Selected: ${_selectedFile!.path.split('/').last}'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : () async {
                      await _uploadFile();
                      setState(() {
                        _selectedFile = null;
                        _showUploadDetails = false;
                      });
                      _refreshDocumentsList();
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: _isUploading 
                        ? const Text('Uploading...') 
                        : const Text('Upload & OCR'),
                  ),
                ],
                if (_isUploading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
                if (_uploadError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_uploadError', 
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                if (_ocrResult != null && _showUploadDetails) ...[
                  const SizedBox(height: 16),
                  const Text('OCR Result:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_ocrResult!['text'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        height: 200, // Fixed height container
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(_ocrResult!['text'].toString().substring(0, 
                              _ocrResult!['text'].toString().length > 500 ? 500 : _ocrResult!['text'].toString().length) + 
                              (_ocrResult!['text'].toString().length > 500 ? '...' : '')
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        
        // Document list view
        Expanded(
          child: DocumentsList(key: _documentsListKey),
        ),
      ],
    );
  }
}

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
    return const Center(child: Text('Family Management'));
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('More Menu'));
  }
}
