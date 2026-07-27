class AppStateStore {
  static const String boxName = 'app_state_box';
  static const String sessionIdKey = 'session_id';
  static const String sessionCreatedKey = 'session_created';
  static const String selectedDocumentIdKey = 'selected_document_id';
  static const String lastUploadedDocumentIdKey = 'last_uploaded_document_id';
  static const String lastViewedDocumentIdKey = 'last_viewed_document_id';
  static const String recentQuestionsKey = 'recent_questions';
  static const String recentlyDeletedDocsKey = 'recently_deleted_docs';
  static const String emailKey = 'saved_email';
  static const String phoneKey = 'saved_phone';
  static const String saveContactKey = 'save_contact_enabled';
  static const String manualFamilyMembersKey = 'manual_family_members';
  static const String answerFeedbackKey = 'answer_feedback';
  static const String claimRecordsKey = 'claim_records';
  static const String phoneNumberKey = 'user_phone_number';
  static const String phonePromptCountKey = 'phone_prompt_count';
  static const String analyticsEventsKey = 'analytics_events';

  // Notification preferences
  static const String notificationEnabledKey = 'notification_enabled';
  static const String reminderDaysKey = 'reminder_days'; // List<int>
  static const String quietHoursStartKey = 'quiet_hours_start'; // int (hour 0-23)
  static const String quietHoursEndKey = 'quiet_hours_end'; // int (hour 0-23)
  static const String disabledPoliciesKey = 'disabled_policies'; // List<String> of documentIds

  // Coverage gap resolution tracking
  static const String resolvedGapsKey = 'resolved_gaps'; // Map<String, Map> of gapId -> resolution info

  // Document sort/filter preferences
  static const String docsSortModeKey = 'docs_sort_mode'; // 'date_desc', 'date_asc', 'name_asc', 'name_desc', 'type'
  static const String docsFilterTypeKey = 'docs_filter_type'; // null = all, or document type string

  // Theme preference
  static const String themeModeKey = 'theme_mode'; // 'light', 'dark', or 'system'

  // Locale preference (M10 multi-language support)
  static const String localeKey = 'app_locale'; // 'en', 'hi', or null (system default)

  AppStateStore._();
}
