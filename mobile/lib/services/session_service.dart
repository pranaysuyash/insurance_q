import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'app_state_store.dart';

class SessionService {
  static const Uuid _uuid = Uuid();
  
  static String? _currentSessionId;
  
  /// Get or create a session ID
  static Future<String> getSessionId() async {
    if (_currentSessionId != null) {
      return _currentSessionId!;
    }

    final box = Hive.box(AppStateStore.boxName);
    
    // Check if we have an existing session
    final existingSessionId = box.get(AppStateStore.sessionIdKey) as String?;
    final sessionCreated = box.get(AppStateStore.sessionCreatedKey) as int?;
    
    // Session expires after 24 hours
    const sessionDurationMs = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (existingSessionId != null && 
        sessionCreated != null && 
        (now - sessionCreated) < sessionDurationMs) {
      // Use existing session
      _currentSessionId = existingSessionId;
      return existingSessionId;
    }
    
    // Create new session
    final newSessionId = _uuid.v4();
    await box.put(AppStateStore.sessionIdKey, newSessionId);
    await box.put(AppStateStore.sessionCreatedKey, now);
    
    _currentSessionId = newSessionId;
    return newSessionId;
  }
  
  /// Force create a new session (useful for testing or reset)
  static Future<String> createNewSession() async {
    final box = Hive.box(AppStateStore.boxName);
    final newSessionId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await box.put(AppStateStore.sessionIdKey, newSessionId);
    await box.put(AppStateStore.sessionCreatedKey, now);
    
    _currentSessionId = newSessionId;
    return newSessionId;
  }
  
  /// Get session creation time
  static Future<DateTime?> getSessionCreatedTime() async {
    final box = Hive.box(AppStateStore.boxName);
    final sessionCreated = box.get(AppStateStore.sessionCreatedKey) as int?;
    
    if (sessionCreated != null) {
      return DateTime.fromMillisecondsSinceEpoch(sessionCreated);
    }
    
    return null;
  }
  
  /// Check if session is expired
  static Future<bool> isSessionExpired() async {
    final box = Hive.box(AppStateStore.boxName);
    final sessionCreated = box.get(AppStateStore.sessionCreatedKey) as int?;
    
    if (sessionCreated == null) {
      return true;
    }
    
    const sessionDurationMs = 24 * 60 * 60 * 1000; // 24 hours
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return (now - sessionCreated) >= sessionDurationMs;
  }
  
  /// Clear session (logout)
  static Future<void> clearSession() async {
    final box = Hive.box(AppStateStore.boxName);
    await box.delete(AppStateStore.sessionIdKey);
    await box.delete(AppStateStore.sessionCreatedKey);
    _currentSessionId = null;
  }
}
