import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'services/api_service.dart';

void main() {
  runApp(const ProviderScope(child: InsuranceApp()));
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

  Future<void> _pickFile() async {
    setState(() {
      _uploadError = null;
      _ocrResult = null;
    });
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
      _ocrResult = null;
    });
    try {
      final api = ApiService();
      final result = await api.uploadDocument(_selectedFile!);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              onPressed: _isUploading ? null : _uploadFile,
              icon: const Icon(Icons.cloud_upload),
              label: _isUploading ? const Text('Uploading...') : const Text('Upload & OCR'),
            ),
          ],
          if (_isUploading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_uploadError != null) ...[
            const SizedBox(height: 16),
            Text('Error: $_uploadError', style: const TextStyle(color: Colors.red)),
          ],
          if (_ocrResult != null) ...[
            const SizedBox(height: 16),
            const Text('OCR Result:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_ocrResult!['text'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  height: 300, // Fixed height container
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_ocrResult!['text']),
                    ),
                  ),
                ),
              ),
            if (_ocrResult!['layout_elements'] != null)
              ...(_ocrResult!['layout_elements'] as List)
                  .map((e) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(e['id'] ?? e['type'] ?? 'Section'),
                          subtitle: Text(e['text'] ?? e['answer'] ?? ''),
                        ),
                      ))
                  .toList(),
          ],
        ],
      ),
    );
  }
}

class QAScreen extends StatelessWidget {
  const QAScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('QA Interface'));
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
