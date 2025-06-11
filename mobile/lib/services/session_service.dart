import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionService {
  static const String _sessionIdKey = 'session_id';
  static const String _sessionCreatedKey = 'session_created';
  static const Uuid _uuid = Uuid();
  
  static String? _currentSessionId;
  
  /// Get or create a session ID
  static Future<String> getSessionId() async {
    if (_currentSessionId != null) {
      return _currentSessionId!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we have an existing session
    final existingSessionId = prefs.getString(_sessionIdKey);
    final sessionCreated = prefs.getInt(_sessionCreatedKey);
    
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
    await prefs.setString(_sessionIdKey, newSessionId);
    await prefs.setInt(_sessionCreatedKey, now);
    
    _currentSessionId = newSessionId;
    return newSessionId;
  }
  
  /// Force create a new session (useful for testing or reset)
  static Future<String> createNewSession() async {
    final prefs = await SharedPreferences.getInstance();
    final newSessionId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await prefs.setString(_sessionIdKey, newSessionId);
    await prefs.setInt(_sessionCreatedKey, now);
    
    _currentSessionId = newSessionId;
    return newSessionId;
  }
  
  /// Get session creation time
  static Future<DateTime?> getSessionCreatedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCreated = prefs.getInt(_sessionCreatedKey);
    
    if (sessionCreated != null) {
      return DateTime.fromMillisecondsSinceEpoch(sessionCreated);
    }
    
    return null;
  }
  
  /// Check if session is expired
  static Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCreated = prefs.getInt(_sessionCreatedKey);
    
    if (sessionCreated == null) {
      return true;
    }
    
    const sessionDurationMs = 24 * 60 * 60 * 1000; // 24 hours
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return (now - sessionCreated) >= sessionDurationMs;
  }
  
  /// Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_sessionCreatedKey);
    _currentSessionId = null;
  }
} 