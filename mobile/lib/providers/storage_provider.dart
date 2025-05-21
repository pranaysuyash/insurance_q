import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider for accessing SharedPreferences instance
final sharedPreferencesProvider = StateProvider<SharedPreferences?>((ref) {
  return null; // Initially null, will be initialized in the app
});

/// A provider for initializing SharedPreferences
final sharedPreferencesInitializerProvider = FutureProvider<SharedPreferences>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.read(sharedPreferencesProvider.notifier).state = prefs;
  return prefs;
});

/// Keys for SharedPreferences storage
class StorageKeys {
  static const String selectedDocumentId = 'selected_document_id';
  static const String recentQuestions = 'recent_questions';
  static const String lastUploadedDocumentId = 'last_uploaded_document_id';
  static const String lastQueryDate = 'last_query_date';
  static const String tutorialShown = 'tutorial_shown';
  static const String lastViewedDocumentId = 'last_viewed_document_id';
  
  // Prevent instantiation
  StorageKeys._();
} 