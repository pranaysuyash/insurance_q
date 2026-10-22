/// Canonical box-name constants. All Hive box opens and accesses must use
/// these constants — never raw string literals.
///
/// Owned by HiveWorkspaceService (lifecycle) and AppStateRepository (reads/writes).
/// See DECISION_LOG.md Decision 11.
library;

abstract final class HiveBoxNames {
  static const String appState = 'app_state_box';
  static const String documents = 'documents_box';
  static const String resolvedGaps = 'resolved_gaps';
  static const String analyticsEvents = 'analytics_events';
  static const String consentLedger = 'consent_ledger';
  static const String qaHistory = 'qa_history';
  static const String fieldOverrides = 'field_overrides_box';
  static const String entitlements = 'entitlements';
  static const String newsletter = 'newsletter';
}
