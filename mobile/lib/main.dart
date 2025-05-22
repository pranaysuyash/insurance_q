import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'services/api_service.dart';
import 'screens/qa_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dashboard_screen.dart';
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
    return const Center(
      child: Text('Family Screen - Coming Soon'),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('More Screen - Coming Soon'),
    );
  }
}
