/// User-facing strings for the currently migrated CoverWise surfaces.
///
/// The catalog is intentionally incremental: remaining screens still need
/// screen-by-screen extraction before all copy is centralized.
///
/// Naming convention: `{Screen}_{Component}_{StringPurpose}` for static
/// methods, or just a descriptive constant name for simple strings.
/// Plurals use the count parameter approach.
class S {
  S._();

  // ─── Common / Shared ───────────────────────────────────────────────

  static const String commonShowLess = 'Show less';
  static const String commonShowMore = 'Show more';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String remove = 'Remove';
  static const String add = 'Add';
  static const String clear = 'Clear';
  static const String enable = 'Enable';
  static const String disable = 'Disable';
  static const String version = 'Version';
  static const String upgrade = 'Upgrade';
  static const String manage = 'Manage';
  static const String signOut = 'Sign out';
  static const String signIn = 'Sign in';
  static const String createAccount = 'Create account';
  static const String buy = 'Buy';
  static const String startAsking = 'Start asking';
  static const String getMore = 'Get more';
  static const String getPacks = 'Get packs';
  static const String viewPolicy = 'View Policy';

  static String policyCount(int count) =>
      '$count polic${count == 1 ? 'y' : 'ies'}';

  static String resultCount(int count) =>
      '$count result${count == 1 ? '' : 's'}';

  static String dayCount(int count) =>
      '$count day${count == 1 ? '' : 's'}';

  static String expiresInDays(int days) =>
      'Expires in $days day${days == 1 ? '' : 's'}';

  static String daysLeft(int days) => '$days days left';

  static String daysBefore(int days) => '$days days before';

  // ─── QA Screen ─────────────────────────────────────────────────────

  static const String qaScreenTitle = 'Ask CoverWise';
  static const String qaTabSuggested = 'Suggested';
  static const String qaTabYourQuestion = 'Your question';
  static const String qaTabHistory = 'History';

  // QA — Budget Banner
  static const String qaNoQuestionsRemaining = 'No questions remaining';
  static String qaQuestionsLeft(int remaining) => '$remaining questions left';

  static String qaMonthlyPlusPack(int monthly, int pack) =>
      '$monthly monthly + $pack pack';
  static String qaPackQuestions(int count, int packs) =>
      '$count questions in $packs pack(s)';
  static String qaMonthlyPlan(int remaining) =>
      '$remaining questions left this month';

  // QA — Document Selector
  static const String qaAskAbout = 'ASK ABOUT';
  static const String qaQuestionSource = 'Question source';
  static String qaAllDocuments(int count) => 'All Documents ($count)';
  static const String qaSingleDocument = 'Single Document';
  static const String qaNoDocumentSelected = 'No document selected';
  static const String qaSearchAllPolicies = 'Search across all your uploaded policies';

  // QA — Custom Question Tab
  static const String qaAskAboutDescription =
      'Ask about cover, exclusions, dates or wording in your policy.';
  static const String qaHintText = 'e.g., What is the effective date?';
  static const String qaClearQuestion = 'Clear question';

  // QA — History Tab
  static const String qaNoHistoryYet = 'No question history yet';
  static const String qaSearchHistory = 'Search history...';
  static String qaNoMatchesFor(String query) => 'No matches for "$query"';
  static const String qaToday = 'Today';
  static const String qaYesterday = 'Yesterday';
  static const String qaThisWeek = 'This week';
  static const String qaEarlier = 'Earlier';

  // QA — Answer Card
  static const String qaSourcesLabel = 'Sources';
  static const String qaFollowUpLabel = 'You might also ask:';
  static const String qaHelpfulAnswer = 'Helpful answer';
  static const String qaUnhelpfulAnswer = 'Unhelpful answer';
  static const String qaCopyAnswer = 'Copy answer';
  static const String qaAnswerCopied = 'Answer copied';
  static const String qaShareAnswer = 'Share answer';
  static const String qaAnswerCopiedToClipboard = 'Answer copied to clipboard';
  static String qaAnswerReadyFor(String question) => 'Answer ready for $question';

  // QA — Snackbar / Errors
  static String qaCouldNotGetAnswer(String error) =>
      'Could not get an answer. ${error.isEmpty ? 'Please try again.' : error}';
  static const String qaFallbackAnswer =
      "Sorry, that didn't work. Please try again.";
  static const String qaPolicySource = 'Policy source';

  // QA — Confidence
  static const String confidenceHigh = 'High';
  static const String confidenceMedium = 'Medium';
  static const String confidenceLow = 'Low';
  static String confidenceLabel(String level) => '$level confidence';

  // ─── QA Packs Screen ──────────────────────────────────────────────

  static const String qaPacksTitle = 'Q&A Packs';
  static const String qaPacksBuyHeading = 'Buy a pack';
  static const String qaPacksSubtitle =
      'No subscription needed. Pay once, ask questions.';
  static const String qaPacksYourPacks = 'Your packs';
  static const String qaPacksPurchasedSuccess =
      'Pack purchased! You can now ask more questions.';
  static const String qaPacksHowTheyWork = 'How packs work';

  static const String qaPacksFaqQ1 = 'When are questions deducted?';
  static const String qaPacksFaqA1 =
      'A question is deducted each time you submit one. Monthly subscription questions are used first, then pack questions.';
  static const String qaPacksFaqQ2 = 'Do packs expire?';
  static const String qaPacksFaqA2 =
      'Yes, packs are valid for 90 days from purchase. Unused questions are lost after expiry.';
  static const String qaPacksFaqQ3 = 'Can I have multiple packs?';
  static const String qaPacksFaqA3 =
      'Yes! Multiple packs stack. Questions are consumed from the earliest-expiring pack first (FIFO).';
  static const String qaPacksFaqQ4 = 'What happens if I upgrade to a subscription?';
  static const String qaPacksFaqA4 =
      'Your pack questions remain active and are used after your monthly subscription quota is exhausted.';

  static String qaPacksQuestionsAvailable(int count) =>
      '$count questions available';
  static String qaPacksFromMonthlyPlan(int count) =>
      '$count from monthly plan';
  static String qaPacksFromPacks(int count) => '$count from packs';
  static String qaPacksFromMonthlyAndPacks(int monthly, int packs) =>
      '$monthly from monthly plan · $packs from packs';
  static String qaPacksQuestionsInPacks(int count) => '$count from packs';
  static String qaPacksBestValue = 'Best value';
  static String qaPacksQuestionsEach(int count, String price) =>
      '$count questions · $price each';
  static String qaPacksPackPurchased(String name, int count) =>
      '$name pack purchased! $count questions added.';
  static const String qaPacksPurchaseCancelled = 'Purchase was cancelled.';
  static String qaPacksPackRemaining(String type) => '$type pack';
  static String qaPacksRemaining(int remaining, int total) =>
      '$remaining/$total left';

  // ─── Family Screen ────────────────────────────────────────────────

  static const String familyTitle = 'Family';
  static const String familyNoMembersYet = 'No family members yet';
  static const String familyNoMembersFound = 'No family members found';
  static const String familyEmptySubtitle =
      'Upload insurance documents to auto-detect family members, or add one manually.';
  static const String familyAddMember = 'Add Family Member';
  static const String familyLibraryError = 'Your policy library could not be loaded.';
  static const String familyMembersReadError =
      'Covered family members could not be read from your policies.';
  static const String familyPeopleCovered = 'People covered';
  static const String familyPeopleSubtitle =
      'A clear view of the people found in your policies, plus anyone you add yourself.';
  static const String familySectionLabel = 'Family and insured members';
  static const String familyRemoveTitle = 'Remove family member?';
  static String familyRemoveContent(String name) =>
      'Remove $name from your family list? This does not affect your policy documents.';
  static const String familyAddButton = 'Add family member';
  static const String familyManualBadge = 'Manual';
  static const String familyFromDocumentBadge = 'From document';
  static String familyRemoveTooltip(String name) => 'Remove $name';
  static String familyDateOfBirth(String date) => 'Date of birth: $date';

  // ─── Family Member Detail Screen ──────────────────────────────────

  static const String familyDetailEditTooltip = 'Edit member';
  static const String familyDetailHintName = 'Full name';
  static const String familyDetailMemberUpdated = 'Member updated';
  static String familyDetailUpdateError(String error) =>
      'Could not update member: $error';
  static const String familyDetailDobLabel = 'Date of Birth';
  static const String familyDetailSourceLabel = 'Source';
  static const String familyDetailCoveringPolicies = 'Covering policies';
  static const String familyDetailManualSource = 'Added manually';
  static const String familyDetailAutoSource = 'Detected from policy';
  static String familyDetailNoPolicies(String name) =>
      'No policies listing $name were found. Upload a policy that includes them, or add them manually.';

  // Relationship options
  static const String relationshipDependent = 'Dependent';
  static const String relationshipSpouse = 'Spouse';
  static const String relationshipChild = 'Child';
  static const String relationshipParent = 'Parent';
  static const String relationshipSibling = 'Sibling';
  static const String relationshipPrimaryInsured = 'Primary Insured';
  static const String relationshipOther = 'Other';

  // ─── Insurance Card Screen ────────────────────────────────────────

  static const String insuranceCardsTitle = 'Insurance Cards';
  static const String insuranceCardsEmptyTitle = 'No insurance cards yet';
  static const String insuranceCardsEmptySubtitle =
      'Choose a policy file to keep its key details ready on your phone.';
  static const String insuranceCardsChooseFile = 'Choose policy file';
  static const String insuranceCardsHeaderTitle = 'Your cover, ready to carry';
  static const String insuranceCardsHeaderSubtitle =
      'A quick reference for policy and insurer details. Verify proof requirements with your insurer.';
  static const String insuranceCardsPolicyNumber = 'Policy Number';
  static const String insuranceCardsCoverage = 'Coverage';
  static const String insuranceCardsPremium = 'Premium';
  static const String insuranceCardsValidFrom = 'Valid from';
  static const String insuranceCardsValidUntil = 'Valid until';
  static const String insuranceCardsCallInsurer = 'Call insurer';
  static const String insuranceCardsShareCard = 'Share card';
  static const String insuranceCardsExpired = 'Expired';
  static const String insuranceCardsShareTitle = 'CoverWise policy card';
  static const String insuranceCardsInsurerPrefix = 'Insurer: ';
  static const String insuranceCardsPolicyNumberPrefix = 'Policy number: ';
  static const String insuranceCardsCoveragePrefix = 'Coverage: ';
  static const String insuranceCardsValidUntilPrefix = 'Valid until: ';
  static const String insuranceCardsHelplinePrefix = 'Insurer helpline: ';
  static const String insuranceCardsShareFooter =
      'Verify current details with the insurer and the source policy document.';
  static const String insuranceCardsPhoneError = 'Could not open the phone app';
  static const String insuranceCardsShareError = 'Could not open sharing options';

  // ─── Renewal Calendar Screen ──────────────────────────────────────

  static const String renewalTitle = 'Renewal Calendar';
  static const String renewalEmptyTitle = 'No policies tracked';
  static const String renewalEmptySubtitle = 'Choose a policy file to track renewal dates.';
  static const String renewalHeaderTitle = 'Never miss a renewal';
  static const String renewalHeaderSubtitle =
      'See what needs attention first and keep insurer contact details close.';
  static const String renewalReminderText =
      'Get reminders 30, 15, 7 and 1 day before a policy expires.';
  static const String renewalRemindersOn = 'Renewal reminders are on.';
  static const String renewalNotificationsOff =
      'Notifications are off. You can enable them in Settings.';
  static const String renewalSectionExpired = 'Expired';
  static const String renewalSectionExpiringSoon = 'Expiring Soon';
  static const String renewalSectionActive = 'Active';
  static const String renewalSectionNoDate = 'Expiry Date Not Found';
  static const String renewalNoDateInfo =
      'Expiry date not found in your policy — check your policy document';
  static const String renewalInsurerNotFound = 'Insurer not found';
  static String renewalExpires(String date) => 'Expires $date';
  static const String renewalContactToRenew = 'Contact insurer to renew';
  static const String renewalStartRenewal = 'Start renewal';
  static String renewalRenewTitle(String type) => 'Renew $type';
  static String renewalContactInsurer(String insurer) =>
      'Contact $insurer to start the renewal process.';
  static const String renewalCallHelpline = 'Call helpline';
  static const String renewalSendEmail = 'Send email';
  static String renewalContactInfoNotFound(String insurer) =>
      'Contact info not found for $insurer. Check your policy document or call the insurer directly.';
  static const String renewalPhoneDialerError = 'Could not open phone dialer';
  static const String renewalEmailClientError = 'Could not open email client';

  // ─── Settings Screen ──────────────────────────────────────────────

  static const String settingsTitle = 'Settings';
  static const String settingsHeaderTitle = 'Your app, your preferences';
  static const String settingsHeaderSubtitle =
      'Manage access, reminders and what stays on this device.';
  static const String settingsSectionPlan = 'Plan';
  static const String settingsSectionAccount = 'Account';
  static const String settingsSectionExperience = 'Experience';
  static const String settingsSectionAppDetails = 'App details';
  static const String settingsSectionPrivacy = 'Privacy & consent';
  static const String settingsSectionDeviceData = 'Device data';

  static String settingsCurrentPlan(String plan) => 'Current plan: $plan';
  static const String settingsQaPacks = 'Q&A Packs';
  static String settingsQuestionsInPacks(int count) => '$count questions in packs';
  static const String settingsBuyQuestions =
      'Buy questions without a subscription';
  static const String settingsRenews = 'Renews';
  static const String settingsSignedIn = 'Signed in';
  static const String settingsSupabaseAccount = 'Supabase account';
  static const String settingsAccountLinked = 'Account linked';
  static const String settingsLinkYourPhone = 'Link your phone';
  static String settingsConnectedAs(String phone) => 'Connected as $phone';
  static const String settingsBackupSubtitle =
      'Back up policies and use them on another device';
  static const String settingsAppearance = 'Appearance';
  static String settingsThemeMode(String mode) => mode;
  static const String settingsNotifications = 'Notifications';
  static const String settingsNotificationsSubtitle =
      'Renewal reminders and quiet hours';
  static const String settingsSmartSuggestions = 'Smart Suggestions';
  static const String settingsSmartSuggestionsSubtitle =
      'AI-powered coverage recommendations';
  static const String settingsServiceEndpoint = 'Service endpoint';
  static const String settingsClearDataTitle = 'Clear all local data?';
  static const String settingsClearDataContent =
      'This permanently removes all locally stored documents, policy summaries, Q&A history, family members, and session data from this device. Uploaded documents on the server are not affected. This cannot be undone.';
  static const String settingsClearDataSuccess = 'All local data cleared.';
  static const String settingsClearDataSubtitle =
      'Remove documents, summaries, history and family members';

  // Consent ledger
  static const String settingsNoConsentRecords = 'No consent records';
  static const String settingsConsentRecorded =
      'Consent is recorded when you upload your first policy';
  static const String settingsConsentPolicyProcessing = 'Policy processing';
  static const String settingsConsentAnalytics = 'Usage analytics';
  static const String settingsConsentLeadCapture = 'Contact capture';
  static const String settingsConsentTermsAccepted = 'Terms accepted';
  static String settingsConsentGranted(String date, String version) =>
      'Granted $date • v$version';
  static String settingsConsentRevoked(String date) => 'Revoked $date';
  static const String settingsConsentActive = 'Active';
  static const String settingsConsentRevokedLabel = 'Revoked';

  // ─── Profile Screen ───────────────────────────────────────────────

  static const String profileTitle = 'Profile';
  static const String profileDefaultHeader = 'Your CoverWise profile';
  static const String profileLinkedHeader = 'Linked and ready across your devices.';
  static const String profileUnlinkedHeader =
      'Your policy workspace currently stays on this device.';
  static const String profileCreateAccount = 'Create a secure account';
  static const String profileRestoreWorkspace =
      'Restore this policy workspace across devices';
  static const String profileSignedInAccount = 'Signed-in account';
  static const String profileWorkspaceLinked = 'Workspace is linked to your account';
  static const String profilePhoneNumber = 'Phone number';
  static const String profileNotLinked = 'Not linked';
  static const String profileSecureSession = 'Secure session';
  static const String profileAccountSessionActive =
      'Account session active on this device';
  static const String profileAnonymousSessionActive =
      'Anonymous session active on this device';
  static const String profileAppSection = 'App';
  static const String profilePrivacySection = 'Privacy';
  static const String profileDeviceFirstStorage = 'Device-first storage';
  static const String profileDeviceFirstSubtitle =
      'Your policy workspace and personal details stay local.';
  static const String profileDeleteAccount = 'Delete account';
  static const String profileDeleteAccountSubtitle =
      'Permanently remove account and all server data';
  static const String profileCreateAccountFirst = 'Create an account first to delete it';
  static const String profileFooter =
      'CoverWise helps you understand your policies. It does not sell insurance.';

  // Delete account dialogs
  static const String profileDeleteConfirmTitle = 'Delete account permanently?';
  static const String profileDeleteConfirmHeader =
      'This will permanently delete:';
  static const String profileDeleteItemAccount = '• Your CoverWise account';
  static const String profileDeleteItemDocs =
      '• All uploaded policy documents on our servers';
  static const String profileDeleteItemSummaries =
      '• All policy summaries and embeddings';
  static const String profileDeleteItemHistory =
      '• Your Q&A history on the server';
  static const String profileDeleteWarning =
      'This action cannot be undone. Local data on this device will be cleared separately via Settings → Clear local data.';
  static const String profileDeleteEverything = 'Delete everything';
  static const String profileDeleteTypeTitle = 'Type DELETE to confirm';
  static const String profileDeleteTypeWarning =
      'This is your last chance. All data will be permanently erased.';
  static const String profileDeleteTypeHint = 'Type DELETE';
  static const String profileDeletePermanently = 'Delete permanently';
  static const String profileDeletingAccount = 'Deleting account...';
  static String profileDeleteComplete(int docs, int files) =>
      'Account deleted. $docs document(s) and $files storage file(s) removed.';
  static String profileDeletePartial(List<String> failed) =>
      'Account deletion is partially complete. Failed stages: ${failed.join(", ")}. '
      'Do not assume server deletion is complete. Local data on this device was not affected and can be cleared from the privacy screen.';
  static String profileDeleteRequested(String status) =>
      'Account deletion requested. Status: $status. Check the privacy screen for details.';
  static String profileInFlightWarning(int count, String names) =>
      '$count document${count == 1 ? ' is' : 's are'} still processing: $names. '
      'Please wait for processing to complete before deleting your account.';

  // ─── Upgrade Screen ───────────────────────────────────────────────

  static const String upgradeTitle = 'Choose your plan';
  static const String upgradeBillingUnavailable =
      'Billing is not available yet. Please try again later.';
  static const String upgradeCouldNotOpenSettings =
      'Could not open subscription settings';
  static String upgradeSuccess(String plan) =>
      'Upgraded to $plan! Enjoy your new features.';
  static const String upgradePurchaseCancelled = 'Purchase was cancelled.';
  static const String upgradeMonthly = 'Monthly';
  static const String upgradeAnnual = 'Annual';
  static const String upgradeSaveUpTo = 'Save up to 44%';
  static const String upgradeCurrentPlan = 'Current plan';
  static const String upgradeFreeForever = 'Free forever';
  static String upgradeTo(String plan) => 'Upgrade to $plan';
  static const String upgradeComparePlans = 'Compare plans';
  static const String upgradeQuestions = 'Questions';
  static const String upgradeFaqSwitch = 'Can I switch plans?';
  static const String upgradeFaqSwitchAnswer =
      'You can manage plan changes through your App Store or Play Store subscription settings. Timing, proration, and refunds follow the store and subscription terms.';
  static const String upgradeFaqPacks = 'What about my Q&A packs?';
  static const String upgradeFaqPacksAnswer =
      'Pack questions remain active and are used after your monthly subscription quota is exhausted.';
  static const String upgradeFaqCancel = 'How do I cancel?';
  static const String upgradeFaqCancelAnswer =
      'Cancel anytime from your App Store or Play Store subscription settings. You keep access until the end of your billing period.';
  static const String upgradeAccessUntil = 'Access until';
  static const String upgradePolicies = 'Policies';
  static const String upgradeQaPerMonth = 'Q&A per month';
  static const String upgradeComparePolicies = 'Compare policies';
  static const String upgradeFamilyView = 'Family view';
  static const String upgradeCloudSync = 'Cloud sync';
  static const String upgradeEmergency = 'Emergency';
  static const String upgradeAnnualReview = 'Annual review';
  static const String upgradeAdvancedSearch = 'Advanced search';

  // ─── Account Screen ───────────────────────────────────────────────

  static String accountTitle(bool isSignUp) =>
      isSignUp ? 'Create account' : 'Sign in';
  static const String accountHeaderTitle = 'Protect your policy workspace';
  static const String accountHeaderSubtitle =
      'An account lets you restore your CoverWise workspace on another device. Your account does not make policy explanations binding insurance advice.';
  static const String accountNameLabel = 'Name (optional)';
  static const String accountEmailLabel = 'Email';
  static const String accountPasswordLabel = 'Password';
  static const String accountResendBanner =
      'Your email has not been confirmed yet. Check your inbox or resend.';
  static const String accountResend = 'Resend';
  static const String accountForgotPassword = 'Forgot password?';
  static const String accountResendVerification = 'Resend verification email';
  static String accountSwitchToSignIn(bool isSignUp) =>
      isSignUp ? 'Already have an account? Sign in' : 'New to CoverWise? Create an account';
  static const String accountGoogleSignIn = 'Continue with Google';
  static const String accountAuthNotConfigured =
      'Account auth is not configured for this build.';
  static const String accountEnterEmail = 'Please enter your email address.';
  static const String accountPasswordTooShort = 'Password must be at least 8 characters.';
  static const String accountInvalidEmail = 'Please enter a valid email address.';
  static const String accountCheckEmail = 'Check your email to confirm the account, then sign in.';
  static const String accountIncorrectCredentials = 'Incorrect email or password. Please try again.';
  static const String accountAlreadyRegistered = 'An account with this email already exists. Try signing in.';
  static const String accountPasswordRequirements =
      'Password does not meet requirements. Use at least 8 characters.';
  static String accountCouldNotAction(bool signUp) =>
      'Could not ${signUp ? 'create' : 'sign in'} the account. Check your details and try again.';
  static const String accountEnterEmailFirst = 'Enter your email above first, then tap Forgot password.';
  static const String accountResetEmailSent = 'Password reset email sent. Check your inbox.';
  static const String accountCouldNotReset = 'Could not send reset email. Check your email and try again.';
  static const String accountEnterEmailResend =
      'Enter your email above first, then tap Resend verification.';
  static const String accountVerificationSent = 'Verification email sent. Check your inbox.';
  static const String accountCouldNotVerify = 'Could not send verification email. Try again later.';
  static const String accountCouldNotGoogle = 'Could not sign in with Google. Please try again.';

  // ─── Notification Preferences Screen ──────────────────────────────

  static const String notifTitle = 'Renewal reminders';
  static const String notifHeaderTitle = 'Stay ahead of renewals';
  static const String notifHeaderSubtitle =
      'Choose when this device should remind you. Notifications are reminders, not insurer renewal notices.';
  static const String notifMasterToggle = 'Renewal reminders';
  static const String notifEnabledSubtitle = 'Enabled on this device';
  static const String notifDisabledSubtitle = 'Disabled';
  static const String notifSectionRemindMe = 'Remind me before expiry';
  static const String notifSectionRemindMeDescription =
      'Choose how many days before your policy expires to receive a reminder.';
  static const String notifNoReminderTimes = 'No reminder times are selected.';
  static const String notifSectionQuietHours = 'Quiet hours';
  static const String notifSectionQuietHoursDescription =
      'No notifications during these hours. Reminders will be delivered when quiet hours end.';
  static const String notifStartTime = 'Start time';
  static const String notifEndTime = 'End time';
  static const String notifSectionPerPolicy = 'Per-policy reminders';
  static const String notifSectionPerPolicyDescription =
      'Toggle reminders for individual policies.';
  static const String notifPreferencesSaved = 'Preferences saved';

  // ─── Documents Screen / List ──────────────────────────────────────

  static const String docsTitle = 'Documents';
  static const String docsSlotsUsed = 'of 5 free policy slots used';
  static const String docsTypeChanged = 'Type changed to';
  static const String docsRemovedLocal = 'Removed from this device. The server copy was not affected.';
  static const String docsReplaceSuccess = 'Document replaced successfully';

  // ─── Terms of Service Screen ──────────────────────────────────────

  static const String tosTitle = 'Terms of Service';
  static const String tosCopySuccess = 'Terms of service copied to clipboard';
  static const String tosLoadError = 'The terms of service could not be loaded.';

  // ─── Privacy Policy Screen ────────────────────────────────────────

  static const String privacyTitle = 'Privacy Policy';
  static const String privacyCopySuccess = 'Privacy policy copied to clipboard';
  static const String privacyLoadError = 'The privacy policy could not be loaded.';

  // ─── Processing Status Screen ─────────────────────────────────────

  static const String processingReceived = 'Received';
  static const String processingProcessing = 'Processing';
  static const String processingCategorising = 'Categorising';
  static const String processingFinishingUp = 'Finishing up';
  static const String processingReceivedDesc = 'Your policy has been received';
  static const String processingProcessingDesc = 'Reading and extracting text';
  static const String processingCategorisingDesc = 'Determining policy type and insurer';
  static const String processingFinishingUpDesc = 'Making your policy searchable';

  // ─── Onboarding Screen ────────────────────────────────────────────

  static const String onboardSubtitle =
      'Get clear answers based on your actual policy — not generic advice from the internet.';
  static const String onboardNoDataStored =
      'No policy data will be stored or shared without your consent.';
  static const String onboardTermsAcceptance =
      'I have read and accept the Privacy Policy and Terms of Service.';

  // ─── Emergency Screen ─────────────────────────────────────────────

  static const String emergencyTitle = 'Emergency';
  static const String emergencyHelpAtGlance = 'Help at a glance';

  // ─── Dashboard Screen ─────────────────────────────────────────────

  static const String dashboardQuickActions = 'Quick Actions';
  static const String dashboardEmergency = 'Emergency';
  static const String dashboardAddPolicy = 'Add policy file';

  // ─── Search Screen ────────────────────────────────────────────────

  static const String searchTitle = 'Search';
  static const String searchHint = 'Search across all policies...';
  static const String searchNoResults = 'No results found';

  // ─── Coverage Gap Screen ──────────────────────────────────────────

  static const String coverageGapTitle = 'Coverage Gaps';
  static const String coverageGapEmpty = 'No coverage gaps identified yet';

  // ─── Insurance Literacy Screen ────────────────────────────────────

  static const String literacyTitle = 'Insurance Glossary';
  static const String literacySearchHint = 'Search terms...';

  // ─── Document Type Picker ─────────────────────────────────────────

  static const String docTypePickerTitle = 'Select document type';

  // ─── File Type Info (P3-01) ───────────────────────────────────────

  static const String fileTypeSupported = 'Supported file types';
  static const String fileTypePdf = 'PDF documents';
  static const String fileTypeImage = 'Images (JPEG, PNG)';
  static const String fileTypeMaxSize = 'Maximum file size: 20 MB';
  static const String fileTypeUnsupported =
      'This file type is not supported. Please choose a PDF or image.';

  // ─── What-If Calculator ───────────────────────────────────────────

  static const String whatIfTitle = 'What-If Calculator';
  static const String whatIfDescription = 'Explore how different coverage options affect your estimated costs.';
}
