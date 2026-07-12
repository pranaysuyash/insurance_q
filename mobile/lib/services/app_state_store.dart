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

  AppStateStore._();
}
