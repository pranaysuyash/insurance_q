// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsGenEn extends AppLocalizationsGen {
  AppLocalizationsGenEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CoverWise';

  @override
  String get commonShowLess => 'Show less';

  @override
  String get commonShowMore => 'Show more';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get remove => 'Remove';

  @override
  String get add => 'Add';

  @override
  String get clear => 'Clear';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String get version => 'Version';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get manage => 'Manage';

  @override
  String get signOut => 'Sign out';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get buy => 'Buy';

  @override
  String get startAsking => 'Start asking';

  @override
  String get getMore => 'Get more';

  @override
  String get getPacks => 'Get packs';

  @override
  String get viewPolicy => 'View Policy';

  @override
  String policyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count policies',
      one: '1 policy',
    );
    return '$_temp0';
  }

  @override
  String resultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return 'Expires in $count $_temp0';
  }

  @override
  String daysLeft(Object days) {
    return '$days days left';
  }

  @override
  String daysBefore(Object days) {
    return '$days days before';
  }

  @override
  String get qaScreenTitle => 'Ask CoverWise';

  @override
  String get qaTabSuggested => 'Suggested';

  @override
  String get qaTabYourQuestion => 'Your question';

  @override
  String get qaTabHistory => 'History';

  @override
  String get qaNoQuestionsRemaining => 'No questions remaining';

  @override
  String qaQuestionsLeft(Object remaining) {
    return '$remaining questions left';
  }

  @override
  String qaMonthlyPlusPack(Object monthly, Object pack, Object packs) {
    return '$monthly monthly + $pack pack';
  }

  @override
  String qaPackQuestions(Object count, Object packs) {
    return '$count questions in $packs pack(s)';
  }

  @override
  String qaMonthlyPlan(Object remaining) {
    return '$remaining questions left this month';
  }

  @override
  String get qaAskAbout => 'ASK ABOUT';

  @override
  String get qaQuestionSource => 'Question source';

  @override
  String qaAllDocuments(Object count) {
    return 'All Documents ($count)';
  }

  @override
  String get qaSingleDocument => 'Single Document';

  @override
  String get qaNoDocumentSelected => 'No document selected';

  @override
  String get qaSearchAllPolicies => 'Search across all your uploaded policies';

  @override
  String get qaAskAboutDescription =>
      'Ask about cover, exclusions, dates or wording in your policy.';

  @override
  String get qaHintText => 'e.g., What is the effective date?';

  @override
  String get qaClearQuestion => 'Clear question';

  @override
  String get qaNoHistoryYet => 'No question history yet';

  @override
  String get qaSearchHistory => 'Search history...';

  @override
  String qaNoMatchesFor(Object query) {
    return 'No matches for \"$query\"';
  }

  @override
  String get qaToday => 'Today';

  @override
  String get qaYesterday => 'Yesterday';

  @override
  String get qaThisWeek => 'This week';

  @override
  String get qaEarlier => 'Earlier';

  @override
  String get qaSourcesLabel => 'Sources';

  @override
  String get qaFollowUpLabel => 'You might also ask:';

  @override
  String get qaHelpfulAnswer => 'Helpful answer';

  @override
  String get qaUnhelpfulAnswer => 'Unhelpful answer';

  @override
  String get qaCopyAnswer => 'Copy answer';

  @override
  String get qaAnswerCopied => 'Answer copied';

  @override
  String get qaShareAnswer => 'Share answer';

  @override
  String get qaAnswerCopiedToClipboard => 'Answer copied to clipboard';

  @override
  String get qaEvidence => 'Evidence';

  @override
  String get qaCitationUnknown => 'Unknown';

  @override
  String qaCitationSource(Object index) {
    return 'Source $index';
  }

  @override
  String qaCitationSourcePage(Object index, Object page) {
    return 'Source $index • page $page';
  }

  @override
  String get qaPolicyDoesNotEstablish => 'What the policy does not establish';

  @override
  String qaAnswerReadyFor(Object question) {
    return 'Answer ready for $question';
  }

  @override
  String qaCouldNotGetAnswer(Object error) {
    return 'Could not get an answer. $error';
  }

  @override
  String get qaFallbackAnswer => 'Sorry, that didn\'t work. Please try again.';

  @override
  String get qaPolicySource => 'Policy source';

  @override
  String get qaViewSource => 'View source';

  @override
  String get qaViewSourcePage => 'View on page';

  @override
  String get qaNoSourceDocument => 'Source document unavailable';

  @override
  String qaSourcePageLabel(Object page) {
    return 'Page $page';
  }

  @override
  String get qaRelevanceTooltip =>
      'How closely this source matches your question';

  @override
  String get qaOfflineMessage =>
      'You are offline. Please check your connection and try again.';

  @override
  String get confidenceHigh => 'High';

  @override
  String get confidenceMedium => 'Medium';

  @override
  String get confidenceLow => 'Low';

  @override
  String confidenceLabel(Object level) {
    return '$level confidence';
  }

  @override
  String get qaPacksTitle => 'Q&A Packs';

  @override
  String get qaPacksBuyHeading => 'Buy a pack';

  @override
  String get qaPacksSubtitle =>
      'No subscription needed. Pay once, ask questions.';

  @override
  String get qaPacksYourPacks => 'Your packs';

  @override
  String get qaPacksPurchasedSuccess =>
      'Purchase received. Questions appear after server confirmation.';

  @override
  String get qaPacksHowTheyWork => 'How packs work';

  @override
  String get qaPacksFaqQ1 => 'When are questions deducted?';

  @override
  String get qaPacksFaqA1 =>
      'A question is deducted each time you submit one. Monthly subscription questions are used first, then pack questions.';

  @override
  String get qaPacksFaqQ2 => 'Do packs expire?';

  @override
  String get qaPacksFaqA2 =>
      'Yes, packs are valid for 90 days from purchase. Unused questions are lost after expiry.';

  @override
  String get qaPacksFaqQ3 => 'Can I have multiple packs?';

  @override
  String get qaPacksFaqA3 =>
      'Yes! Multiple packs stack. Questions are consumed from the earliest-expiring pack first (FIFO).';

  @override
  String get qaPacksFaqQ4 => 'What happens if I upgrade to a subscription?';

  @override
  String get qaPacksFaqA4 =>
      'Your pack questions remain active and are used after your monthly subscription quota is exhausted.';

  @override
  String qaPacksQuestionsAvailable(Object count) {
    return '$count questions available';
  }

  @override
  String qaPacksFromMonthlyPlan(Object count) {
    return '$count from monthly plan';
  }

  @override
  String qaPacksFromPacks(Object count) {
    return '$count from packs';
  }

  @override
  String qaPacksFromMonthlyAndPacks(Object monthly, Object packs) {
    return '$monthly from monthly plan · $packs from packs';
  }

  @override
  String qaPacksQuestionsInPacks(Object count) {
    return '$count from packs';
  }

  @override
  String get qaPacksBestValue => 'More monthly questions';

  @override
  String qaPacksQuestionsEach(Object count, Object price) {
    return '$count questions · $price each';
  }

  @override
  String qaPacksPackPurchased(Object name) {
    return 'Purchase received. Your $name questions will appear after server confirmation.';
  }

  @override
  String get qaPacksPurchaseCancelled => 'Purchase was cancelled.';

  @override
  String get qaPacksPurchaseNotCompleted =>
      'Purchase was not completed. No questions were added.';

  @override
  String qaPacksPackRemaining(Object type) {
    return '$type pack';
  }

  @override
  String qaPacksRemaining(Object remaining, Object total) {
    return '$remaining/$total left';
  }

  @override
  String get familyTitle => 'Family';

  @override
  String get familyNoMembersYet => 'No family members yet';

  @override
  String get familyNoMembersFound => 'No family members found';

  @override
  String get familyEmptySubtitle =>
      'Upload insurance documents to auto-detect family members, or add one manually.';

  @override
  String get familyAddMember => 'Add Family Member';

  @override
  String get familyLibraryError => 'Your policy library could not be loaded.';

  @override
  String get familyMembersReadError =>
      'Covered family members could not be read from your policies.';

  @override
  String get familyPeopleCovered => 'People covered';

  @override
  String get familyPeopleSubtitle =>
      'A clear view of the people found in your policies, plus anyone you add yourself.';

  @override
  String get familySectionLabel => 'Family and insured members';

  @override
  String get familyRemoveTitle => 'Remove family member?';

  @override
  String familyRemoveContent(Object name) {
    return 'Remove $name from your family list? This does not affect your policy documents.';
  }

  @override
  String get familyAddButton => 'Add family member';

  @override
  String get familyManualBadge => 'Manual';

  @override
  String get familyFromDocumentBadge => 'From document';

  @override
  String familyRemoveTooltip(Object name) {
    return 'Remove $name';
  }

  @override
  String familyDateOfBirth(Object date) {
    return 'Date of birth: $date';
  }

  @override
  String get familyDetailEditTooltip => 'Edit member';

  @override
  String get familyDetailHintName => 'Full name';

  @override
  String get familyDetailMemberUpdated => 'Member updated';

  @override
  String familyDetailUpdateError(Object error) {
    return 'Could not update member: $error';
  }

  @override
  String get familyDetailDobLabel => 'Date of Birth';

  @override
  String get familyDetailSourceLabel => 'Source';

  @override
  String get familyDetailCoveringPolicies => 'Covering policies';

  @override
  String get familyDetailManualSource => 'Added manually';

  @override
  String get familyDetailAutoSource => 'Detected from policy';

  @override
  String familyDetailNoPolicies(Object name) {
    return 'No policies listing $name were found. Upload a policy that includes them, or add them manually.';
  }

  @override
  String get relationshipDependent => 'Dependent';

  @override
  String get relationshipSpouse => 'Spouse';

  @override
  String get relationshipChild => 'Child';

  @override
  String get relationshipParent => 'Parent';

  @override
  String get relationshipSibling => 'Sibling';

  @override
  String get relationshipPrimaryInsured => 'Primary Insured';

  @override
  String get relationshipOther => 'Other';

  @override
  String get insuranceCardsTitle => 'Insurance Cards';

  @override
  String get insuranceCardsEmptyTitle => 'No insurance cards yet';

  @override
  String get insuranceCardsEmptySubtitle =>
      'Choose a policy file to keep its key details ready on your phone.';

  @override
  String get insuranceCardsChooseFile => 'Choose policy file';

  @override
  String get insuranceCardsHeaderTitle => 'Your policy details, ready to carry';

  @override
  String get insuranceCardsHeaderSubtitle =>
      'A quick reference for policy and insurer details. Verify proof requirements with your insurer.';

  @override
  String get insuranceCardsPolicyNumber => 'Policy Number';

  @override
  String get insuranceCardsCoverage => 'Coverage';

  @override
  String get insuranceCardsPremium => 'Premium';

  @override
  String get insuranceCardsValidFrom => 'Valid from';

  @override
  String get insuranceCardsValidUntil => 'Valid until';

  @override
  String get insuranceCardsCallInsurer => 'Call insurer';

  @override
  String get insuranceCardsShareCard => 'Share card';

  @override
  String get insuranceCardsExpired => 'Expired';

  @override
  String get insuranceCardsShareTitle => 'CoverWise policy reference';

  @override
  String get insuranceCardsInsurerPrefix => 'Insurer: ';

  @override
  String get insuranceCardsPolicyNumberPrefix => 'Policy number: ';

  @override
  String get insuranceCardsCoveragePrefix => 'Coverage: ';

  @override
  String get insuranceCardsValidUntilPrefix => 'Valid until: ';

  @override
  String get insuranceCardsHelplinePrefix => 'Insurer helpline: ';

  @override
  String get insuranceCardsShareFooter =>
      'Verify current details with the insurer and the source policy document.';

  @override
  String get insuranceCardsPhoneError => 'Could not open the phone app';

  @override
  String get insuranceCardsShareError => 'Could not open sharing options';

  @override
  String get renewalTitle => 'Renewal Calendar';

  @override
  String get renewalEmptyTitle => 'No policies tracked';

  @override
  String get renewalEmptySubtitle =>
      'Choose a policy file to track renewal dates.';

  @override
  String get renewalHeaderTitle => 'Keep renewals in view';

  @override
  String get renewalHeaderSubtitle =>
      'See what needs attention first and keep insurer contact details close.';

  @override
  String get renewalReminderText =>
      'Set reminders for 30, 15, 7 and 1 day before a policy expires.';

  @override
  String get renewalRemindersOn => 'Renewal reminders are on.';

  @override
  String get renewalNotificationsOff =>
      'Notifications are off. You can enable them in Settings.';

  @override
  String get renewalSectionExpired => 'Expired';

  @override
  String get renewalSectionExpiringSoon => 'Expiring Soon';

  @override
  String get renewalSectionActive => 'Active';

  @override
  String get renewalSectionNoDate => 'Expiry Date Not Found';

  @override
  String get renewalNoDateInfo =>
      'Expiry date not found in your policy — check your policy document';

  @override
  String get renewalInsurerNotFound => 'Insurer not found';

  @override
  String renewalExpires(Object date) {
    return 'Expires $date';
  }

  @override
  String get renewalContactToRenew => 'Contact insurer to renew';

  @override
  String get renewalStartRenewal => 'Start renewal';

  @override
  String renewalRenewTitle(Object type) {
    return 'Renew $type';
  }

  @override
  String renewalContactInsurer(Object insurer) {
    return 'Contact $insurer to start the renewal process.';
  }

  @override
  String get renewalCallHelpline => 'Call helpline';

  @override
  String get renewalSendEmail => 'Send email';

  @override
  String renewalContactInfoNotFound(Object insurer) {
    return 'Contact info not found for $insurer. Check your policy document or call the insurer directly.';
  }

  @override
  String get renewalPhoneDialerError => 'Could not open phone dialer';

  @override
  String get renewalEmailClientError => 'Could not open email client';

  @override
  String renewalExpiringPolicies(Object date) {
    return 'Policies expiring on $date';
  }

  @override
  String renewalExpiringCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count policies expiring',
      one: '1 policy expiring',
    );
    return '$_temp0 on this date';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsHeaderTitle => 'Your app, your preferences';

  @override
  String get settingsHeaderSubtitle =>
      'Manage access, reminders and what stays on this device.';

  @override
  String get settingsSectionPlan => 'Plan';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionExperience => 'Experience';

  @override
  String get settingsSectionAppDetails => 'App details';

  @override
  String get settingsSectionPrivacy => 'Privacy & consent';

  @override
  String get settingsSectionDeviceData => 'Device data';

  @override
  String settingsCurrentPlan(Object plan) {
    return 'Current plan: $plan';
  }

  @override
  String get settingsQaPacks => 'Q&A Packs';

  @override
  String settingsQuestionsInPacks(Object count) {
    return '$count questions in packs';
  }

  @override
  String get settingsBuyQuestions => 'Buy questions without a subscription';

  @override
  String get settingsRenews => 'Renews';

  @override
  String get settingsSignedIn => 'Signed in';

  @override
  String get settingsSupabaseAccount => 'Supabase account';

  @override
  String get settingsAccountLinked => 'Account linked';

  @override
  String get settingsLinkYourPhone => 'Link your phone';

  @override
  String settingsConnectedAs(Object phone) {
    return 'Connected as $phone';
  }

  @override
  String get settingsBackupSubtitle =>
      'Back up policies and use them on another device';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String settingsThemeMode(Object mode) {
    return '$mode';
  }

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle =>
      'Renewal reminders and quiet hours';

  @override
  String get settingsSmartSuggestions => 'Coverage insights';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'Coming soon: coverage guidance based on your policy details';

  @override
  String get settingsServiceEndpoint => 'Service endpoint';

  @override
  String get settingsClearDataTitle => 'Clear all local data?';

  @override
  String get settingsClearDataAction => 'Clear local data';

  @override
  String get settingsClearDataContent =>
      'This removes all locally stored documents, policy summaries, Q&A history, family members, and session data from this device. Uploaded documents on the server are not affected. This action cannot be undone from this device.';

  @override
  String get settingsClearDataSuccess =>
      'All local data cleared from this device.';

  @override
  String get settingsClearDataSubtitle =>
      'Remove documents, summaries, history and family members';

  @override
  String get settingsNoConsentRecords => 'No consent records';

  @override
  String get settingsConsentRecorded =>
      'Consent is recorded when you upload your first policy';

  @override
  String get settingsConsentPolicyProcessing => 'Policy processing';

  @override
  String get settingsConsentAnalytics => 'Usage analytics';

  @override
  String get settingsConsentLeadCapture => 'Contact capture';

  @override
  String get settingsConsentTermsAccepted => 'Terms accepted';

  @override
  String settingsConsentGranted(Object date, Object version) {
    return 'Granted $date • v$version';
  }

  @override
  String settingsConsentRevoked(Object date) {
    return 'Revoked $date';
  }

  @override
  String get settingsConsentActive => 'Active';

  @override
  String get settingsConsentRevokedLabel => 'Revoked';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Choose your preferred app language';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileDefaultHeader => 'Your CoverWise profile';

  @override
  String get profileLinkedHeader => 'Linked and ready across your devices.';

  @override
  String get profileUnlinkedHeader =>
      'Your policy workspace currently stays on this device.';

  @override
  String get profileCreateAccount => 'Create a secure account';

  @override
  String get profileRestoreWorkspace =>
      'Restore this policy workspace across devices';

  @override
  String get profileSignedInAccount => 'Signed-in account';

  @override
  String get profileWorkspaceLinked => 'Workspace is linked to your account';

  @override
  String get profilePhoneNumber => 'Phone number';

  @override
  String get profileNotLinked => 'Not linked';

  @override
  String get profileSecureSession => 'Secure session';

  @override
  String get profileAccountSessionActive =>
      'Account session active on this device';

  @override
  String get profileAnonymousSessionActive =>
      'Anonymous session active on this device';

  @override
  String get profileAppSection => 'App';

  @override
  String get profileFamilySection => 'Family';

  @override
  String get profilePrivacySection => 'Privacy';

  @override
  String get profileDeviceFirstStorage => 'Device-first storage';

  @override
  String get profileDeviceFirstSubtitle =>
      'This device keeps a protected local cache; account data may also be stored securely for sync.';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteAccountSubtitle =>
      'Permanently remove account and all server data';

  @override
  String get profileCreateAccountFirst =>
      'Create an account first to delete it';

  @override
  String get profileFooter =>
      'CoverWise helps you understand your policies. It does not sell insurance.';

  @override
  String get profileDeleteConfirmTitle => 'Delete account permanently?';

  @override
  String get profileDeleteConfirmHeader => 'This will permanently delete:';

  @override
  String get profileDeleteItemAccount => '• Your CoverWise account';

  @override
  String get profileDeleteItemDocs =>
      '• All uploaded policy documents on our servers';

  @override
  String get profileDeleteItemSummaries =>
      '• All policy summaries and embeddings';

  @override
  String get profileDeleteItemHistory => '• Your Q&A history on the server';

  @override
  String get profileDeleteWarning =>
      'This action cannot be undone from this device. Local data on this device will be cleared separately via Settings → Clear local data.';

  @override
  String get profileDeleteEverything => 'Delete everything';

  @override
  String get profileDeleteTypeTitle => 'Type DELETE to confirm';

  @override
  String get profileDeleteTypeWarning =>
      'This is your last chance. All data will be permanently erased.';

  @override
  String get profileDeleteTypeHint => 'Type DELETE';

  @override
  String get profileDeletePermanently => 'Delete permanently';

  @override
  String get profileDeletingAccount => 'Deleting account...';

  @override
  String profileDeleteComplete(Object docs, Object files) {
    return 'Account deleted. $docs document(s) and $files storage file(s) removed.';
  }

  @override
  String profileDeletePartial(Object failed) {
    return 'Account deletion is partially complete. Failed stages: $failed. Do not assume server deletion is complete.';
  }

  @override
  String profileDeleteRequested(Object status) {
    return 'Account deletion requested. Status: $status.';
  }

  @override
  String get profileDeletionStatusTitle => 'Account deletion status';

  @override
  String get profileDeletionStatusPending =>
      'Deletion is queued. Your account remains active until server erasure is verified.';

  @override
  String get profileDeletionStatusRunning =>
      'Deletion is being processed. New account writes are paused while erasure runs.';

  @override
  String get profileDeletionStatusFailed =>
      'The last deletion attempt needs attention.';

  @override
  String get profileDeletionStatusRefresh => 'Refresh status';

  @override
  String get profileDeletionStatusUnavailable =>
      'Deletion status is temporarily unavailable.';

  @override
  String profileInFlightWarning(Object count) {
    return '$count document(s) still processing. Please wait for processing to complete before deleting your account.';
  }

  @override
  String get upgradeTitle => 'Choose your plan';

  @override
  String get upgradeBillingUnavailable =>
      'Billing is not available yet. Please try again later.';

  @override
  String get upgradeCouldNotOpenSettings =>
      'Could not open subscription settings';

  @override
  String upgradeSuccess(Object plan) {
    return 'Upgraded to $plan! Enjoy your new features.';
  }

  @override
  String get upgradePurchaseCancelled => 'Purchase was cancelled.';

  @override
  String get upgradeMonthly => 'Monthly';

  @override
  String get upgradeAnnual => 'Annual';

  @override
  String get upgradeSaveUpTo => 'Save up to 44%';

  @override
  String get upgradeCurrentPlan => 'Current plan';

  @override
  String get upgradeFreeForever => 'Free forever';

  @override
  String upgradeTo(Object plan) {
    return 'Upgrade to $plan';
  }

  @override
  String get upgradeComparePlans => 'Compare plans';

  @override
  String get upgradeQuestions => 'Questions';

  @override
  String get upgradeFaqSwitch => 'Can I switch plans?';

  @override
  String get upgradeFaqSwitchAnswer =>
      'You can manage plan changes through your App Store or Play Store subscription settings.';

  @override
  String get upgradeFaqPacks => 'What about my Q&A packs?';

  @override
  String get upgradeFaqPacksAnswer =>
      'Pack questions remain active and are used after your monthly subscription quota is exhausted.';

  @override
  String get upgradeFaqCancel => 'How do I cancel?';

  @override
  String get upgradeFaqCancelAnswer =>
      'Cancel anytime from your App Store or Play Store subscription settings.';

  @override
  String get upgradeAccessUntil => 'Access until';

  @override
  String get upgradePolicies => 'Policies';

  @override
  String get upgradeQaPerMonth => 'Q&A per month';

  @override
  String get upgradeComparePolicies => 'Compare policies';

  @override
  String get upgradeFamilyView => 'Family view';

  @override
  String get upgradeCloudSync => 'Cloud sync';

  @override
  String get upgradeEmergency => 'Emergency';

  @override
  String get upgradeAnnualReview => 'Annual review';

  @override
  String get upgradeAdvancedSearch => 'Advanced search';

  @override
  String accountTitle(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'Create account',
        'other': 'Sign in',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountHeaderTitle => 'Protect your policy workspace';

  @override
  String get accountHeaderSubtitle =>
      'An account lets you restore your CoverWise workspace on another device.';

  @override
  String get accountNameLabel => 'Name (optional)';

  @override
  String get accountEmailLabel => 'Email';

  @override
  String get accountPasswordLabel => 'Password';

  @override
  String get accountResendBanner =>
      'Your email has not been confirmed yet. Check your inbox or resend.';

  @override
  String get accountResend => 'Resend';

  @override
  String get accountForgotPassword => 'Forgot password?';

  @override
  String get accountResendVerification => 'Resend verification email';

  @override
  String accountSwitchToSignIn(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'Already have an account? Sign in',
        'other': 'New to CoverWise? Create an account',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountGoogleSignIn => 'Continue with Google';

  @override
  String get accountAuthNotConfigured =>
      'Account auth is not configured for this build.';

  @override
  String get accountEnterEmail => 'Please enter your email address.';

  @override
  String get accountPasswordTooShort =>
      'Password must be at least 8 characters.';

  @override
  String get accountInvalidEmail => 'Please enter a valid email address.';

  @override
  String get accountCheckEmail =>
      'Check your email to confirm the account, then sign in.';

  @override
  String get accountIncorrectCredentials =>
      'Incorrect email or password. Please try again.';

  @override
  String get accountAlreadyRegistered =>
      'An account with this email already exists. Try signing in.';

  @override
  String get accountPasswordRequirements =>
      'Password does not meet requirements. Use at least 8 characters.';

  @override
  String accountCouldNotAction(String action) {
    String _temp0 = intl.Intl.selectLogic(
      action,
      {
        'true': 'create',
        'other': 'sign in to',
      },
    );
    return 'Could not $_temp0 the account.';
  }

  @override
  String get accountEnterEmailFirst =>
      'Enter your email above first, then tap Forgot password.';

  @override
  String get accountResetEmailSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get accountCouldNotReset =>
      'Could not send reset email. Check your email and try again.';

  @override
  String get accountEnterEmailResend =>
      'Enter your email above first, then tap Resend verification.';

  @override
  String get accountVerificationSent =>
      'Verification email sent. Check your inbox.';

  @override
  String get accountCouldNotVerify =>
      'Could not send verification email. Try again later.';

  @override
  String get accountCouldNotGoogle =>
      'Could not sign in with Google. Please try again.';

  @override
  String get notifTitle => 'Renewal reminders';

  @override
  String get notifHeaderTitle => 'Stay ahead of renewals';

  @override
  String get notifHeaderSubtitle =>
      'Choose when this device should remind you. Notifications are reminders, not insurer renewal notices.';

  @override
  String get notifMasterToggle => 'Renewal reminders';

  @override
  String get notifEnabledSubtitle => 'Enabled on this device';

  @override
  String get notifDisabledSubtitle => 'Disabled';

  @override
  String get notifSectionRemindMe => 'Remind me before expiry';

  @override
  String get notifSectionRemindMeDescription =>
      'Choose how many days before your policy expires to receive a reminder.';

  @override
  String get notifNoReminderTimes => 'No reminder times are selected.';

  @override
  String get notifSectionQuietHours => 'Quiet hours';

  @override
  String get notifSectionQuietHoursDescription =>
      'No notifications during these hours.';

  @override
  String get notifStartTime => 'Start time';

  @override
  String get notifEndTime => 'End time';

  @override
  String get notifSectionPerPolicy => 'Per-policy reminders';

  @override
  String get notifSectionPerPolicyDescription =>
      'Toggle reminders for individual policies.';

  @override
  String get notifPreferencesSaved => 'Preferences saved';

  @override
  String get docsTitle => 'Documents';

  @override
  String docsSlotsUsed(Object count) {
    return '$count of 5 free policy slots used';
  }

  @override
  String get docsTypeChanged => 'Type changed to';

  @override
  String get docsRemovedLocal =>
      'Removed from this device. The server copy was not affected.';

  @override
  String get docsReplaceSuccess => 'Document replaced successfully';

  @override
  String get docsPreview => 'Preview';

  @override
  String get docsDownloadSource => 'Download source';

  @override
  String get docsChangeType => 'Change type';

  @override
  String get docsAskQuestions => 'Ask Questions';

  @override
  String get docsReadingPolicy => 'Reading policy';

  @override
  String get docsUploadRequired => 'Server upload required';

  @override
  String get docsRetryUpload => 'Retry upload';

  @override
  String get docsNeedsAttention => 'Needs attention';

  @override
  String get docsReadyForQuestions => 'Ready for questions';

  @override
  String get docsSaved => 'Saved';

  @override
  String get docsRefreshingTypes => 'Refreshing document types...';

  @override
  String get docsTypesRefreshed => 'Document types refreshed successfully!';

  @override
  String get docsReplace => 'Replace';

  @override
  String get docsRemoveFromDevice => 'Remove from this device';

  @override
  String get docsRemoveFromDeviceTitle => 'Remove from this device?';

  @override
  String get docsDeletePolicy => 'Delete policy';

  @override
  String get docsDeletePolicyTitle => 'Delete policy?';

  @override
  String docsDeletePolicyContent(Object filename) {
    return 'This permanently deletes \"$filename\" from CoverWise and this device.';
  }

  @override
  String get docsDeleted => 'Policy deleted';

  @override
  String get docsReplaceDocumentTitle => 'Replace Document?';

  @override
  String get docsReplaceDocument => 'Replace Document';

  @override
  String get docsCurrentDocument => 'Current Document';

  @override
  String get docsSelectReplacement => 'Select Replacement File';

  @override
  String docsReplaceWillDelete(Object filename) {
    return 'This will delete \"$filename\" and replace it with the new file.';
  }

  @override
  String get docsReplaceAnalysisLost =>
      'The old document\'s analysis will be lost. The new document will be processed fresh.';

  @override
  String docsUploadedDate(Object date) {
    return 'Uploaded: $date';
  }

  @override
  String get docsClearReplacement => 'Clear replacement file';

  @override
  String get docsArchive => 'Archive';

  @override
  String get docsArchived => 'Archived';

  @override
  String get docsRestore => 'Restore';

  @override
  String get docsRestored => 'Policy restored';

  @override
  String get docsArchivedSuccess => 'Policy archived';

  @override
  String get docsShowArchived => 'Show archived';

  @override
  String get docsHideArchived => 'Hide archived';

  @override
  String get docsArchiveConfirmTitle => 'Archive policy?';

  @override
  String docsArchiveConfirmContent(Object filename) {
    return '\"$filename\" will be hidden from your active policy list. You can restore it any time from the archive.';
  }

  @override
  String get docsDeletePermanentWarning =>
      'This permanently deletes the policy from both CoverWise and this device. Consider archiving instead.';

  @override
  String get docsLimitWarning =>
      'You are nearing your free storage limit. Archive old policies to free up space.';

  @override
  String docsLimitCountdown(Object limit, Object remaining, Object used) {
    return '$used of $limit slots used — $remaining remaining';
  }

  @override
  String docsLimitRemaining(Object remaining) {
    return '$remaining free slot(s) remaining';
  }

  @override
  String get docsSortLabel => 'Sort';

  @override
  String get docsFilterLabel => 'Filter';

  @override
  String get docsSortDateNewest => 'Newest first';

  @override
  String get docsSortDateOldest => 'Oldest first';

  @override
  String get docsSortNameAZ => 'Name A–Z';

  @override
  String get docsSortNameZA => 'Name Z–A';

  @override
  String get docsSortType => 'By type';

  @override
  String get docsFilterAll => 'All types';

  @override
  String docsFilterResultCount(Object count, Object total) {
    return '$count of $total policies';
  }

  @override
  String get docsRenameTitle => 'Rename policy';

  @override
  String get docsRenameHint => 'Enter a new name';

  @override
  String get docsRenameSave => 'Save';

  @override
  String get docsRenameSuccess => 'Policy renamed';

  @override
  String get docsRenameEmpty => 'Name cannot be empty';

  @override
  String get tosTitle => 'Terms of Service';

  @override
  String get tosCopySuccess => 'Terms of service copied to clipboard';

  @override
  String get tosLoadError => 'The terms of service could not be loaded.';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get privacyCopySuccess => 'Privacy policy copied to clipboard';

  @override
  String get privacyLoadError => 'The privacy policy could not be loaded.';

  @override
  String get processingReceived => 'Received';

  @override
  String get processingProcessing => 'Processing';

  @override
  String get processingCategorising => 'Categorising';

  @override
  String get processingFinishingUp => 'Finishing up';

  @override
  String get processingReceivedDesc => 'Your policy has been received';

  @override
  String get processingProcessingDesc => 'Reading and extracting text';

  @override
  String get processingCategorisingDesc =>
      'Determining policy type and insurer';

  @override
  String get processingFinishingUpDesc => 'Making your policy searchable';

  @override
  String get onboardSubtitle =>
      'Get clear answers based on your actual policy — not generic advice from the internet.';

  @override
  String get onboardNoDataStored =>
      'No policy data will be stored or shared without your consent.';

  @override
  String get onboardTermsAcceptance =>
      'I have read and accept the Privacy Policy and Terms of Service.';

  @override
  String get emergencyTitle => 'Emergency';

  @override
  String get emergencyHelpAtGlance => 'Help at a glance';

  @override
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get dashboardEmergency => 'Emergency';

  @override
  String get dashboardAddPolicy => 'Add policy file';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search across all policies...';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get coverageGapTitle => 'Coverage Review';

  @override
  String get coverageGapEmpty =>
      'No potential coverage questions flagged from the available policy text yet';

  @override
  String get literacyTitle => 'Insurance Glossary';

  @override
  String get literacySearchHint => 'Search terms...';

  @override
  String get docTypePickerTitle => 'Select document type';

  @override
  String get fileTypeSupported => 'Supported file types';

  @override
  String get fileTypePdf => 'PDF documents';

  @override
  String get fileTypeImage => 'Images (JPEG, PNG)';

  @override
  String get fileTypeMaxSize => 'Maximum file size: 20 MB';

  @override
  String get fileTypeUnsupported =>
      'This file type is not supported. Please choose a PDF or image.';

  @override
  String get whatIfTitle => 'What-If Calculator';

  @override
  String get whatIfDescription =>
      'Explore how different coverage options affect your estimated costs.';

  @override
  String get batchPickMultiple => 'Select multiple files';

  @override
  String batchUploadingPendingCount(Object count) {
    return 'Uploading $count files…';
  }

  @override
  String batchUploadingProgress(Object done, Object total) {
    return 'Uploaded $done of $total';
  }

  @override
  String get batchCompleted => 'All files uploaded';

  @override
  String batchCompletedCount(Object count) {
    return '$count files uploaded successfully';
  }

  @override
  String get batchSomeFailed => 'Some uploads failed';

  @override
  String batchFailedCount(Object failed, Object total) {
    return '$failed of $total files failed';
  }

  @override
  String batchFileTooLargeMB(Object maxMB) {
    return 'This file exceeds the $maxMB MB limit and will be skipped';
  }

  @override
  String get batchFileUnsupported => 'Unsupported file type — skipped';

  @override
  String get batchDuplicateSkipped => 'Duplicate — skipped';

  @override
  String get batchRetryFailed => 'Retry failed uploads';

  @override
  String get batchDone => 'Done';

  @override
  String get batchAddMore => 'Add more files';

  @override
  String get batchSelectAll => 'Select all';

  @override
  String get familyVisTitle => 'Coverage map';

  @override
  String get familyVisHeader => 'Policy-listed family members';

  @override
  String get familyVisSubtitle =>
      'Compare family members listed in each policy; verify coverage with your insurer.';

  @override
  String get familyVisMembers => 'Family members';

  @override
  String get familyVisPolicies => 'Policies';

  @override
  String get familyVisEmptyTitle => 'No coverage data yet';

  @override
  String get familyVisEmptySubtitle =>
      'Upload policies and add family members to compare names listed in your policy documents.';

  @override
  String familyVisNoPolicies(Object name) {
    return 'No policies listing $name yet.';
  }

  @override
  String get familyVisSeeMap => 'View policy member map';

  @override
  String get coverageShareSummary => 'Share summary';

  @override
  String get coverageShareSubject => 'CoverWise policy coverage summary';

  @override
  String get coverageShareError => 'Could not open sharing options';
}
