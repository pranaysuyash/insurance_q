import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

final installServiceProvider = NotifierProvider<InstallNotifier, InstallState>(
  InstallNotifier.new,
);

class InstallState {
  final String installId;
  final DateTime installCreatedAt;
  final bool isReinstall;
  final Map<String, String>? referrer;

  const InstallState({
    required this.installId,
    required this.installCreatedAt,
    required this.isReinstall,
    this.referrer,
  });

  InstallState copyWith({
    String? installId,
    DateTime? installCreatedAt,
    bool? isReinstall,
    Map<String, String>? referrer,
    bool clearReferrer = false,
  }) {
    return InstallState(
      installId: installId ?? this.installId,
      installCreatedAt: installCreatedAt ?? this.installCreatedAt,
      isReinstall: isReinstall ?? this.isReinstall,
      referrer: clearReferrer ? null : (referrer ?? this.referrer),
    );
  }
}

class InstallService {
  static const String _kInstallId = 'install_id';
  static const String _kInstallCreatedAtMs = 'install_created_at_ms';
  static const String _kPreviousInstallIds = 'previous_install_ids';
  static const String _kReferrerSource = 'install_referrer_source';
  static const String _kReferrerMedium = 'install_referrer_medium';
  static const String _kReferrerCampaign = 'install_referrer_campaign';
  static const String _kReferrerCapturedAtMs =
      'install_referrer_captured_at_ms';

  static InstallNotifier? _instance;
  static InstallNotifier? get _notifier => _instance;

  static bool _initialized = false;

  static InstallState _fallbackState = InstallState(
    installId: '',
    installCreatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    isReinstall: false,
    referrer: null,
  );

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final persistedId = prefs.getString(_kInstallId)?.trim();
    final installId =
        (persistedId == null || persistedId.isEmpty) ? _uuid.v4() : persistedId;

    final persistedInstallCreatedAtMs = prefs.getInt(_kInstallCreatedAtMs);
    final installCreatedAt = DateTime.fromMillisecondsSinceEpoch(
      persistedInstallCreatedAtMs ??
          (DateTime.now().millisecondsSinceEpoch - 24 * 60 * 60 * 1000),
    );

    if (persistedId == null || persistedId.isEmpty) {
      await prefs.setString(_kInstallId, installId);
    }
    if (persistedInstallCreatedAtMs == null) {
      await prefs.setInt(
          _kInstallCreatedAtMs, installCreatedAt.millisecondsSinceEpoch);
    }

    final isReinstall =
        (prefs.getString(_kPreviousInstallIds)?.isNotEmpty ?? false);
    final referrer = _readReferrerFromPrefs(prefs);

    _fallbackState = InstallState(
      installId: installId,
      installCreatedAt: installCreatedAt,
      isReinstall: isReinstall,
      referrer: referrer,
    );
    _initialized = true;

    final notifier = _notifier;
    if (notifier != null) {
      notifier.syncFromFallback(_fallbackState);
    }
  }

  static InstallState _state() => _fallbackState;

  static String getInstallId() =>
      _state().installId.isNotEmpty ? _state().installId : _uuid.v4();

  static DateTime? getInstallCreatedAt() => _state().installCreatedAt;

  static bool isReinstall() => _state().isReinstall;

  static int daysSinceInstall() {
    final created = _state().installCreatedAt;
    if (created.millisecondsSinceEpoch <= 0) return 0;
    return DateTime.now().difference(created).inDays;
  }

  static String platformTag() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
      return 'other';
    } catch (_) {
      return 'other';
    }
  }

  static Map<String, String>? getInstallReferrerSync() => _state().referrer;

  static Future<void> refreshInstallReferrerCache() async {
    await _notifier?.refreshInstallReferrerCache();
    final notifier = _notifier;
    if (notifier == null) {
      await ensureInitialized();
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _fallbackState = InstallState(
      installId: 'test-install-id',
      installCreatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      isReinstall: false,
      referrer: null,
    );
    final notifier = _notifier;
    if (notifier != null) {
      notifier.syncFromFallback(_fallbackState);
    }
  }

  static Map<String, String>? _readReferrerFromPrefs(SharedPreferences prefs) {
    final source = prefs.getString(_kReferrerSource);
    final medium = prefs.getString(_kReferrerMedium);
    final campaign = prefs.getString(_kReferrerCampaign);
    final capturedAtMs = prefs.getInt(_kReferrerCapturedAtMs);

    if (source == null && medium == null && campaign == null) {
      return null;
    }

    return {
      if (source != null) 'source': source,
      if (medium != null) 'medium': medium,
      if (campaign != null) 'campaign': campaign,
      if (capturedAtMs != null) 'captured_at_ms': capturedAtMs.toString(),
    };
  }
}

class InstallNotifier extends Notifier<InstallState> {
  static InstallNotifier? _instance;
  static InstallNotifier? get instance => _instance;

  @override
  InstallState build() {
    _instance = this;
    ref.onDispose(() => _instance = null);
    return _stateFromService();
  }

  InstallState _stateFromService() {
    return InstallService._fallbackState;
  }

  String get installId {
    final current = state.installId;
    return current.isNotEmpty ? current : _uuid.v4();
  }

  DateTime get installCreatedAt => state.installCreatedAt;
  bool get isReinstall => state.isReinstall;
  Map<String, String>? get referrer => state.referrer;

  Future<void> refreshInstallReferrerCache() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
        referrer: _readReferrerFromPrefs(prefs), clearReferrer: false);
    InstallService._fallbackState = state;
  }

  void resetForTest() {
    state = InstallState(
      installId: 'test-install-id',
      installCreatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      isReinstall: false,
      referrer: null,
    );
    InstallService._fallbackState = state;
  }

  void syncFromFallback(InstallState fallbackState) {
    state = fallbackState;
    InstallService._fallbackState = fallbackState;
  }

  Map<String, String>? _readReferrerFromPrefs(SharedPreferences prefs) {
    final source = prefs.getString(InstallService._kReferrerSource);
    final medium = prefs.getString(InstallService._kReferrerMedium);
    final campaign = prefs.getString(InstallService._kReferrerCampaign);
    final capturedAtMs = prefs.getInt(InstallService._kReferrerCapturedAtMs);

    if (source == null && medium == null && campaign == null) {
      return null;
    }

    return {
      if (source != null) 'source': source,
      if (medium != null) 'medium': medium,
      if (campaign != null) 'campaign': campaign,
      if (capturedAtMs != null) 'captured_at_ms': capturedAtMs.toString(),
    };
  }
}
