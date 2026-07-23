import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state_store.dart';

const Uuid _uuid = Uuid();

final sessionServiceProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionState {
  final String? sessionId;
  final DateTime? createdAt;

  const SessionState({this.sessionId, this.createdAt});
}

class SessionService {
  static SessionNotifier? _instance;
  static SessionNotifier? get _notifier => _instance;

  static Future<String> getSessionId() async {
    return getSessionIdSync();
  }

  static String getSessionIdSync() {
    return _notifier?.getSessionIdSync() ?? _fallbackSessionIdSync();
  }

  static Future<String> createNewSession() async {
    final notifier = _notifier;
    if (notifier != null) return notifier.createNewSession();
    // Fallback: direct Hive access without Riverpod
    final box = Hive.box(AppStateStore.boxName);
    final newSessionId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await box.put(AppStateStore.sessionIdKey, newSessionId);
    await box.put(AppStateStore.sessionCreatedKey, now);
    return newSessionId;
  }

  static Future<DateTime?> getSessionCreatedTime() async {
    final notifier = _notifier;
    if (notifier != null) {
      return notifier.getSessionCreatedTime();
    }
    return _fallbackCreatedTimeSync();
  }

  static Future<bool> isSessionExpired() async {
    final notifier = _notifier;
    if (notifier != null) {
      return notifier.isSessionExpired();
    }
    return _fallbackExpiredSync();
  }

  static Future<void> clearSession() async {
    final notifier = _notifier;
    if (notifier != null) {
      await notifier.clearSession();
      return;
    }
    final box = Hive.box(AppStateStore.boxName);
    await box.delete(AppStateStore.sessionIdKey);
    await box.delete(AppStateStore.sessionCreatedKey);
  }

  // Fallback implementations for when Notifier isn't initialized yet
  static String _fallbackSessionIdSync() {
    final box = Hive.box(AppStateStore.boxName);
    final existingSessionId = box.get(AppStateStore.sessionIdKey) as String?;
    final sessionCreated = box.get(AppStateStore.sessionCreatedKey) as int?;
    const sessionDurationMs = 24 * 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (existingSessionId != null &&
        sessionCreated != null &&
        (now - sessionCreated) < sessionDurationMs) {
      return existingSessionId;
    }
    final newSessionId = _uuid.v4();
    box.put(AppStateStore.sessionIdKey, newSessionId);
    box.put(AppStateStore.sessionCreatedKey, now);
    return newSessionId;
  }

  static DateTime? _fallbackCreatedTimeSync() {
    final box = Hive.box(AppStateStore.boxName);
    final sessionCreated = box.get(AppStateStore.sessionCreatedKey) as int?;
    if (sessionCreated != null) {
      return DateTime.fromMillisecondsSinceEpoch(sessionCreated);
    }
    return null;
  }

  static bool _fallbackExpiredSync() {
    final box = Hive.box(AppStateStore.boxName);
    final sessionCreated = box.get(AppStateStore.sessionCreatedKey) as int?;
    if (sessionCreated == null) return true;
    const sessionDurationMs = 24 * 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - sessionCreated) >= sessionDurationMs;
  }
}

class SessionNotifier extends Notifier<SessionState> {
  static SessionNotifier? _instance;
  static SessionNotifier? get instance => _instance;

  Box get _box => Hive.box(AppStateStore.boxName);

  @override
  SessionState build() {
    _instance = this;
    ref.onDispose(() => _instance = null);
    final sessionId = _loadSessionId();
    final createdAt = _loadCreatedAt();
    return SessionState(sessionId: sessionId, createdAt: createdAt);
  }

  String? _loadSessionId() {
    final sessionId = _box.get(AppStateStore.sessionIdKey) as String?;
    final sessionCreated = _box.get(AppStateStore.sessionCreatedKey) as int?;
    const sessionDurationMs = 24 * 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (sessionId != null &&
        sessionCreated != null &&
        (now - sessionCreated) < sessionDurationMs) {
      return sessionId;
    }
    return null;
  }

  DateTime? _loadCreatedAt() {
    final sessionCreated = _box.get(AppStateStore.sessionCreatedKey) as int?;
    if (sessionCreated != null) {
      return DateTime.fromMillisecondsSinceEpoch(sessionCreated);
    }
    return null;
  }

  String getSessionIdSync() {
    final id = state.sessionId;
    if (id != null) return id;
    return _createNewSessionSync();
  }

  String _createNewSessionSync() {
    final newSessionId = _uuid.v4();
    final now = DateTime.now();
    _box.put(AppStateStore.sessionIdKey, newSessionId);
    _box.put(AppStateStore.sessionCreatedKey, now.millisecondsSinceEpoch);
    state = SessionState(sessionId: newSessionId, createdAt: now);
    return newSessionId;
  }

  Future<String> createNewSession() async {
    final newSessionId = _uuid.v4();
    final now = DateTime.now();
    await _box.put(AppStateStore.sessionIdKey, newSessionId);
    await _box.put(AppStateStore.sessionCreatedKey, now.millisecondsSinceEpoch);
    state = SessionState(sessionId: newSessionId, createdAt: now);
    return newSessionId;
  }

  Future<DateTime?> getSessionCreatedTime() async {
    return state.createdAt;
  }

  Future<bool> isSessionExpired() async {
    final created = state.createdAt;
    if (created == null) return true;
    const sessionDurationMs = 24 * 60 * 60 * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - created.millisecondsSinceEpoch) >= sessionDurationMs;
  }

  Future<void> clearSession() async {
    await _box.delete(AppStateStore.sessionIdKey);
    await _box.delete(AppStateStore.sessionCreatedKey);
    state = const SessionState();
  }
}
