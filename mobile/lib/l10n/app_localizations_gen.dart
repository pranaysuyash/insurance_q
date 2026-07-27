import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_gen_en.dart';
import 'app_localizations_gen_gu.dart';
import 'app_localizations_gen_hi.dart';
import 'app_localizations_gen_mr.dart';
import 'app_localizations_gen_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizationsGen
/// returned by `AppLocalizationsGen.of(context)`.
///
/// Applications need to include `AppLocalizationsGen.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations_gen.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
///   supportedLocales: AppLocalizationsGen.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizationsGen.supportedLocales
/// property.
abstract class AppLocalizationsGen {
  AppLocalizationsGen(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizationsGen of(BuildContext context) {
    return Localizations.of<AppLocalizationsGen>(context, AppLocalizationsGen)!;
  }

  static const LocalizationsDelegate<AppLocalizationsGen> delegate =
      _AppLocalizationsGenDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('mr'),
    Locale('ta')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CoverWise'**
  String get appName;

  /// No description provided for @commonShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get commonShowLess;

  /// No description provided for @commonShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get commonShowMore;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @startAsking.
  ///
  /// In en, this message translates to:
  /// **'Start asking'**
  String get startAsking;

  /// No description provided for @getMore.
  ///
  /// In en, this message translates to:
  /// **'Get more'**
  String get getMore;

  /// No description provided for @getPacks.
  ///
  /// In en, this message translates to:
  /// **'Get packs'**
  String get getPacks;

  /// No description provided for @viewPolicy.
  ///
  /// In en, this message translates to:
  /// **'View Policy'**
  String get viewPolicy;

  /// No description provided for @policyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 policy} other{{count} policies}}'**
  String policyCount(num count);

  /// No description provided for @resultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String resultCount(num count);

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String dayCount(num count);

  /// No description provided for @expiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {count} {count, plural, =1{day} other{days}}'**
  String expiresInDays(num count);

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysLeft(Object days);

  /// No description provided for @daysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days} days before'**
  String daysBefore(Object days);

  /// No description provided for @qaScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask CoverWise'**
  String get qaScreenTitle;

  /// No description provided for @qaTabSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get qaTabSuggested;

  /// No description provided for @qaTabYourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your question'**
  String get qaTabYourQuestion;

  /// No description provided for @qaTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get qaTabHistory;

  /// No description provided for @qaNoQuestionsRemaining.
  ///
  /// In en, this message translates to:
  /// **'No questions remaining'**
  String get qaNoQuestionsRemaining;

  /// No description provided for @qaQuestionsLeft.
  ///
  /// In en, this message translates to:
  /// **'{remaining} questions left'**
  String qaQuestionsLeft(Object remaining);

  /// No description provided for @qaMonthlyPlusPack.
  ///
  /// In en, this message translates to:
  /// **'{monthly} monthly + {pack} pack'**
  String qaMonthlyPlusPack(Object monthly, Object pack, Object packs);

  /// No description provided for @qaPackQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count} questions in {packs} pack(s)'**
  String qaPackQuestions(Object count, Object packs);

  /// No description provided for @qaMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'{remaining} questions left this month'**
  String qaMonthlyPlan(Object remaining);

  /// No description provided for @qaAskAbout.
  ///
  /// In en, this message translates to:
  /// **'ASK ABOUT'**
  String get qaAskAbout;

  /// No description provided for @qaQuestionSource.
  ///
  /// In en, this message translates to:
  /// **'Question source'**
  String get qaQuestionSource;

  /// No description provided for @qaAllDocuments.
  ///
  /// In en, this message translates to:
  /// **'All Documents ({count})'**
  String qaAllDocuments(Object count);

  /// No description provided for @qaSingleDocument.
  ///
  /// In en, this message translates to:
  /// **'Single Document'**
  String get qaSingleDocument;

  /// No description provided for @qaNoDocumentSelected.
  ///
  /// In en, this message translates to:
  /// **'No document selected'**
  String get qaNoDocumentSelected;

  /// No description provided for @qaSearchAllPolicies.
  ///
  /// In en, this message translates to:
  /// **'Search across all your uploaded policies'**
  String get qaSearchAllPolicies;

  /// No description provided for @qaAskAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask about cover, exclusions, dates or wording in your policy.'**
  String get qaAskAboutDescription;

  /// No description provided for @qaHintText.
  ///
  /// In en, this message translates to:
  /// **'e.g., What is the effective date?'**
  String get qaHintText;

  /// No description provided for @qaClearQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear question'**
  String get qaClearQuestion;

  /// No description provided for @qaNoHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No question history yet'**
  String get qaNoHistoryYet;

  /// No description provided for @qaSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history...'**
  String get qaSearchHistory;

  /// No description provided for @qaNoMatchesFor.
  ///
  /// In en, this message translates to:
  /// **'No matches for \"{query}\"'**
  String qaNoMatchesFor(Object query);

  /// No description provided for @qaToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get qaToday;

  /// No description provided for @qaYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get qaYesterday;

  /// No description provided for @qaThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get qaThisWeek;

  /// No description provided for @qaEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get qaEarlier;

  /// No description provided for @qaSourcesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get qaSourcesLabel;

  /// No description provided for @qaFollowUpLabel.
  ///
  /// In en, this message translates to:
  /// **'You might also ask:'**
  String get qaFollowUpLabel;

  /// No description provided for @qaHelpfulAnswer.
  ///
  /// In en, this message translates to:
  /// **'Helpful answer'**
  String get qaHelpfulAnswer;

  /// No description provided for @qaUnhelpfulAnswer.
  ///
  /// In en, this message translates to:
  /// **'Unhelpful answer'**
  String get qaUnhelpfulAnswer;

  /// No description provided for @qaCopyAnswer.
  ///
  /// In en, this message translates to:
  /// **'Copy answer'**
  String get qaCopyAnswer;

  /// No description provided for @qaAnswerCopied.
  ///
  /// In en, this message translates to:
  /// **'Answer copied'**
  String get qaAnswerCopied;

  /// No description provided for @qaShareAnswer.
  ///
  /// In en, this message translates to:
  /// **'Share answer'**
  String get qaShareAnswer;

  /// No description provided for @qaAnswerCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Answer copied to clipboard'**
  String get qaAnswerCopiedToClipboard;

  /// No description provided for @qaEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get qaEvidence;

  /// No description provided for @qaCitationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get qaCitationUnknown;

  /// No description provided for @qaCitationSource.
  ///
  /// In en, this message translates to:
  /// **'Source {index}'**
  String qaCitationSource(Object index);

  /// No description provided for @qaCitationSourcePage.
  ///
  /// In en, this message translates to:
  /// **'Source {index} • page {page}'**
  String qaCitationSourcePage(Object index, Object page);

  /// No description provided for @qaPolicyDoesNotEstablish.
  ///
  /// In en, this message translates to:
  /// **'What the policy does not establish'**
  String get qaPolicyDoesNotEstablish;

  /// No description provided for @qaAnswerReadyFor.
  ///
  /// In en, this message translates to:
  /// **'Answer ready for {question}'**
  String qaAnswerReadyFor(Object question);

  /// No description provided for @qaCouldNotGetAnswer.
  ///
  /// In en, this message translates to:
  /// **'Could not get an answer. {error}'**
  String qaCouldNotGetAnswer(Object error);

  /// No description provided for @qaFallbackAnswer.
  ///
  /// In en, this message translates to:
  /// **'Sorry, that didn\'t work. Please try again.'**
  String get qaFallbackAnswer;

  /// No description provided for @qaPolicySource.
  ///
  /// In en, this message translates to:
  /// **'Policy source'**
  String get qaPolicySource;

  /// No description provided for @qaViewSource.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get qaViewSource;

  /// No description provided for @qaViewSourcePage.
  ///
  /// In en, this message translates to:
  /// **'View on page'**
  String get qaViewSourcePage;

  /// No description provided for @qaNoSourceDocument.
  ///
  /// In en, this message translates to:
  /// **'Source document unavailable'**
  String get qaNoSourceDocument;

  /// No description provided for @qaSourcePageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String qaSourcePageLabel(Object page);

  /// No description provided for @qaRelevanceTooltip.
  ///
  /// In en, this message translates to:
  /// **'How closely this source matches your question'**
  String get qaRelevanceTooltip;

  /// No description provided for @qaOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Please check your connection and try again.'**
  String get qaOfflineMessage;

  /// No description provided for @confidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get confidenceHigh;

  /// No description provided for @confidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get confidenceLow;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'{level} confidence'**
  String confidenceLabel(Object level);

  /// No description provided for @qaPacksTitle.
  ///
  /// In en, this message translates to:
  /// **'Q&A Packs'**
  String get qaPacksTitle;

  /// No description provided for @qaPacksBuyHeading.
  ///
  /// In en, this message translates to:
  /// **'Buy a pack'**
  String get qaPacksBuyHeading;

  /// No description provided for @qaPacksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No subscription needed. Pay once, ask questions.'**
  String get qaPacksSubtitle;

  /// No description provided for @qaPacksYourPacks.
  ///
  /// In en, this message translates to:
  /// **'Your packs'**
  String get qaPacksYourPacks;

  /// No description provided for @qaPacksPurchasedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase received. Questions appear after server confirmation.'**
  String get qaPacksPurchasedSuccess;

  /// No description provided for @qaPacksHowTheyWork.
  ///
  /// In en, this message translates to:
  /// **'How packs work'**
  String get qaPacksHowTheyWork;

  /// No description provided for @qaPacksFaqQ1.
  ///
  /// In en, this message translates to:
  /// **'When are questions deducted?'**
  String get qaPacksFaqQ1;

  /// No description provided for @qaPacksFaqA1.
  ///
  /// In en, this message translates to:
  /// **'A question is deducted each time you submit one. Monthly subscription questions are used first, then pack questions.'**
  String get qaPacksFaqA1;

  /// No description provided for @qaPacksFaqQ2.
  ///
  /// In en, this message translates to:
  /// **'Do packs expire?'**
  String get qaPacksFaqQ2;

  /// No description provided for @qaPacksFaqA2.
  ///
  /// In en, this message translates to:
  /// **'Yes, packs are valid for 90 days from purchase. Unused questions are lost after expiry.'**
  String get qaPacksFaqA2;

  /// No description provided for @qaPacksFaqQ3.
  ///
  /// In en, this message translates to:
  /// **'Can I have multiple packs?'**
  String get qaPacksFaqQ3;

  /// No description provided for @qaPacksFaqA3.
  ///
  /// In en, this message translates to:
  /// **'Yes! Multiple packs stack. Questions are consumed from the earliest-expiring pack first (FIFO).'**
  String get qaPacksFaqA3;

  /// No description provided for @qaPacksFaqQ4.
  ///
  /// In en, this message translates to:
  /// **'What happens if I upgrade to a subscription?'**
  String get qaPacksFaqQ4;

  /// No description provided for @qaPacksFaqA4.
  ///
  /// In en, this message translates to:
  /// **'Your pack questions remain active and are used after your monthly subscription quota is exhausted.'**
  String get qaPacksFaqA4;

  /// No description provided for @qaPacksQuestionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} questions available'**
  String qaPacksQuestionsAvailable(Object count);

  /// No description provided for @qaPacksFromMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'{count} from monthly plan'**
  String qaPacksFromMonthlyPlan(Object count);

  /// No description provided for @qaPacksFromPacks.
  ///
  /// In en, this message translates to:
  /// **'{count} from packs'**
  String qaPacksFromPacks(Object count);

  /// No description provided for @qaPacksFromMonthlyAndPacks.
  ///
  /// In en, this message translates to:
  /// **'{monthly} from monthly plan · {packs} from packs'**
  String qaPacksFromMonthlyAndPacks(Object monthly, Object packs);

  /// No description provided for @qaPacksQuestionsInPacks.
  ///
  /// In en, this message translates to:
  /// **'{count} from packs'**
  String qaPacksQuestionsInPacks(Object count);

  /// No description provided for @qaPacksBestValue.
  ///
  /// In en, this message translates to:
  /// **'More monthly questions'**
  String get qaPacksBestValue;

  /// No description provided for @qaPacksQuestionsEach.
  ///
  /// In en, this message translates to:
  /// **'{count} questions · {price} each'**
  String qaPacksQuestionsEach(Object count, Object price);

  /// No description provided for @qaPacksPackPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchase received. Your {name} questions will appear after server confirmation.'**
  String qaPacksPackPurchased(Object name);

  /// No description provided for @qaPacksPurchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase was cancelled.'**
  String get qaPacksPurchaseCancelled;

  /// No description provided for @qaPacksPurchaseNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Purchase was not completed. No questions were added.'**
  String get qaPacksPurchaseNotCompleted;

  /// No description provided for @qaPacksPackRemaining.
  ///
  /// In en, this message translates to:
  /// **'{type} pack'**
  String qaPacksPackRemaining(Object type);

  /// No description provided for @qaPacksRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining}/{total} left'**
  String qaPacksRemaining(Object remaining, Object total);

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyTitle;

  /// No description provided for @familyNoMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No family members yet'**
  String get familyNoMembersYet;

  /// No description provided for @familyNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No family members found'**
  String get familyNoMembersFound;

  /// No description provided for @familyEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload insurance documents to auto-detect family members, or add one manually.'**
  String get familyEmptySubtitle;

  /// No description provided for @familyAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add Family Member'**
  String get familyAddMember;

  /// No description provided for @familyLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Your policy library could not be loaded.'**
  String get familyLibraryError;

  /// No description provided for @familyMembersReadError.
  ///
  /// In en, this message translates to:
  /// **'Covered family members could not be read from your policies.'**
  String get familyMembersReadError;

  /// No description provided for @familyPeopleCovered.
  ///
  /// In en, this message translates to:
  /// **'People covered'**
  String get familyPeopleCovered;

  /// No description provided for @familyPeopleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A clear view of the people found in your policies, plus anyone you add yourself.'**
  String get familyPeopleSubtitle;

  /// No description provided for @familySectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Family and insured members'**
  String get familySectionLabel;

  /// No description provided for @familyRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove family member?'**
  String get familyRemoveTitle;

  /// No description provided for @familyRemoveContent.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your family list? This does not affect your policy documents.'**
  String familyRemoveContent(Object name);

  /// No description provided for @familyAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add family member'**
  String get familyAddButton;

  /// No description provided for @familyManualBadge.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get familyManualBadge;

  /// No description provided for @familyFromDocumentBadge.
  ///
  /// In en, this message translates to:
  /// **'From document'**
  String get familyFromDocumentBadge;

  /// No description provided for @familyRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String familyRemoveTooltip(Object name);

  /// No description provided for @familyDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth: {date}'**
  String familyDateOfBirth(Object date);

  /// No description provided for @familyDetailEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit member'**
  String get familyDetailEditTooltip;

  /// No description provided for @familyDetailHintName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get familyDetailHintName;

  /// No description provided for @familyDetailMemberUpdated.
  ///
  /// In en, this message translates to:
  /// **'Member updated'**
  String get familyDetailMemberUpdated;

  /// No description provided for @familyDetailUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update member: {error}'**
  String familyDetailUpdateError(Object error);

  /// No description provided for @familyDetailDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get familyDetailDobLabel;

  /// No description provided for @familyDetailSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get familyDetailSourceLabel;

  /// No description provided for @familyDetailCoveringPolicies.
  ///
  /// In en, this message translates to:
  /// **'Covering policies'**
  String get familyDetailCoveringPolicies;

  /// No description provided for @familyDetailManualSource.
  ///
  /// In en, this message translates to:
  /// **'Added manually'**
  String get familyDetailManualSource;

  /// No description provided for @familyDetailAutoSource.
  ///
  /// In en, this message translates to:
  /// **'Detected from policy'**
  String get familyDetailAutoSource;

  /// No description provided for @familyDetailNoPolicies.
  ///
  /// In en, this message translates to:
  /// **'No policies listing {name} were found. Upload a policy that includes them, or add them manually.'**
  String familyDetailNoPolicies(Object name);

  /// No description provided for @relationshipDependent.
  ///
  /// In en, this message translates to:
  /// **'Dependent'**
  String get relationshipDependent;

  /// No description provided for @relationshipSpouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get relationshipSpouse;

  /// No description provided for @relationshipChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get relationshipChild;

  /// No description provided for @relationshipParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get relationshipParent;

  /// No description provided for @relationshipSibling.
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get relationshipSibling;

  /// No description provided for @relationshipPrimaryInsured.
  ///
  /// In en, this message translates to:
  /// **'Primary Insured'**
  String get relationshipPrimaryInsured;

  /// No description provided for @relationshipOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get relationshipOther;

  /// No description provided for @insuranceCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurance Cards'**
  String get insuranceCardsTitle;

  /// No description provided for @insuranceCardsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No insurance cards yet'**
  String get insuranceCardsEmptyTitle;

  /// No description provided for @insuranceCardsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a policy file to keep its key details ready on your phone.'**
  String get insuranceCardsEmptySubtitle;

  /// No description provided for @insuranceCardsChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose policy file'**
  String get insuranceCardsChooseFile;

  /// No description provided for @insuranceCardsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your policy details, ready to carry'**
  String get insuranceCardsHeaderTitle;

  /// No description provided for @insuranceCardsHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick reference for policy and insurer details. Verify proof requirements with your insurer.'**
  String get insuranceCardsHeaderSubtitle;

  /// No description provided for @insuranceCardsPolicyNumber.
  ///
  /// In en, this message translates to:
  /// **'Policy Number'**
  String get insuranceCardsPolicyNumber;

  /// No description provided for @insuranceCardsCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get insuranceCardsCoverage;

  /// No description provided for @insuranceCardsPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get insuranceCardsPremium;

  /// No description provided for @insuranceCardsValidFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get insuranceCardsValidFrom;

  /// No description provided for @insuranceCardsValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get insuranceCardsValidUntil;

  /// No description provided for @insuranceCardsCallInsurer.
  ///
  /// In en, this message translates to:
  /// **'Call insurer'**
  String get insuranceCardsCallInsurer;

  /// No description provided for @insuranceCardsShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get insuranceCardsShareCard;

  /// No description provided for @insuranceCardsExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get insuranceCardsExpired;

  /// No description provided for @insuranceCardsShareTitle.
  ///
  /// In en, this message translates to:
  /// **'CoverWise policy reference'**
  String get insuranceCardsShareTitle;

  /// No description provided for @insuranceCardsInsurerPrefix.
  ///
  /// In en, this message translates to:
  /// **'Insurer: '**
  String get insuranceCardsInsurerPrefix;

  /// No description provided for @insuranceCardsPolicyNumberPrefix.
  ///
  /// In en, this message translates to:
  /// **'Policy number: '**
  String get insuranceCardsPolicyNumberPrefix;

  /// No description provided for @insuranceCardsCoveragePrefix.
  ///
  /// In en, this message translates to:
  /// **'Coverage: '**
  String get insuranceCardsCoveragePrefix;

  /// No description provided for @insuranceCardsValidUntilPrefix.
  ///
  /// In en, this message translates to:
  /// **'Valid until: '**
  String get insuranceCardsValidUntilPrefix;

  /// No description provided for @insuranceCardsHelplinePrefix.
  ///
  /// In en, this message translates to:
  /// **'Insurer helpline: '**
  String get insuranceCardsHelplinePrefix;

  /// No description provided for @insuranceCardsShareFooter.
  ///
  /// In en, this message translates to:
  /// **'Verify current details with the insurer and the source policy document.'**
  String get insuranceCardsShareFooter;

  /// No description provided for @insuranceCardsPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone app'**
  String get insuranceCardsPhoneError;

  /// No description provided for @insuranceCardsShareError.
  ///
  /// In en, this message translates to:
  /// **'Could not open sharing options'**
  String get insuranceCardsShareError;

  /// No description provided for @renewalTitle.
  ///
  /// In en, this message translates to:
  /// **'Renewal Calendar'**
  String get renewalTitle;

  /// No description provided for @renewalEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No policies tracked'**
  String get renewalEmptyTitle;

  /// No description provided for @renewalEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a policy file to track renewal dates.'**
  String get renewalEmptySubtitle;

  /// No description provided for @renewalHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep renewals in view'**
  String get renewalHeaderTitle;

  /// No description provided for @renewalHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See what needs attention first and keep insurer contact details close.'**
  String get renewalHeaderSubtitle;

  /// No description provided for @renewalReminderText.
  ///
  /// In en, this message translates to:
  /// **'Set reminders for 30, 15, 7 and 1 day before a policy expires.'**
  String get renewalReminderText;

  /// No description provided for @renewalRemindersOn.
  ///
  /// In en, this message translates to:
  /// **'Renewal reminders are on.'**
  String get renewalRemindersOn;

  /// No description provided for @renewalNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. You can enable them in Settings.'**
  String get renewalNotificationsOff;

  /// No description provided for @renewalSectionExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get renewalSectionExpired;

  /// No description provided for @renewalSectionExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get renewalSectionExpiringSoon;

  /// No description provided for @renewalSectionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get renewalSectionActive;

  /// No description provided for @renewalSectionNoDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date Not Found'**
  String get renewalSectionNoDate;

  /// No description provided for @renewalNoDateInfo.
  ///
  /// In en, this message translates to:
  /// **'Expiry date not found in your policy — check your policy document'**
  String get renewalNoDateInfo;

  /// No description provided for @renewalInsurerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Insurer not found'**
  String get renewalInsurerNotFound;

  /// No description provided for @renewalExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String renewalExpires(Object date);

  /// No description provided for @renewalContactToRenew.
  ///
  /// In en, this message translates to:
  /// **'Contact insurer to renew'**
  String get renewalContactToRenew;

  /// No description provided for @renewalStartRenewal.
  ///
  /// In en, this message translates to:
  /// **'Start renewal'**
  String get renewalStartRenewal;

  /// No description provided for @renewalRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew {type}'**
  String renewalRenewTitle(Object type);

  /// No description provided for @renewalContactInsurer.
  ///
  /// In en, this message translates to:
  /// **'Contact {insurer} to start the renewal process.'**
  String renewalContactInsurer(Object insurer);

  /// No description provided for @renewalCallHelpline.
  ///
  /// In en, this message translates to:
  /// **'Call helpline'**
  String get renewalCallHelpline;

  /// No description provided for @renewalSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send email'**
  String get renewalSendEmail;

  /// No description provided for @renewalContactInfoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Contact info not found for {insurer}. Check your policy document or call the insurer directly.'**
  String renewalContactInfoNotFound(Object insurer);

  /// No description provided for @renewalPhoneDialerError.
  ///
  /// In en, this message translates to:
  /// **'Could not open phone dialer'**
  String get renewalPhoneDialerError;

  /// No description provided for @renewalEmailClientError.
  ///
  /// In en, this message translates to:
  /// **'Could not open email client'**
  String get renewalEmailClientError;

  /// No description provided for @renewalExpiringPolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies expiring on {date}'**
  String renewalExpiringPolicies(Object date);

  /// No description provided for @renewalExpiringCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 policy expiring} other{{count} policies expiring}} on this date'**
  String renewalExpiringCount(num count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your app, your preferences'**
  String get settingsHeaderTitle;

  /// No description provided for @settingsHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage access, reminders and what stays on this device.'**
  String get settingsHeaderSubtitle;

  /// No description provided for @settingsSectionPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get settingsSectionPlan;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get settingsSectionExperience;

  /// No description provided for @settingsSectionAppDetails.
  ///
  /// In en, this message translates to:
  /// **'App details'**
  String get settingsSectionAppDetails;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & consent'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionDeviceData.
  ///
  /// In en, this message translates to:
  /// **'Device data'**
  String get settingsSectionDeviceData;

  /// No description provided for @settingsCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan: {plan}'**
  String settingsCurrentPlan(Object plan);

  /// No description provided for @settingsQaPacks.
  ///
  /// In en, this message translates to:
  /// **'Q&A Packs'**
  String get settingsQaPacks;

  /// No description provided for @settingsQuestionsInPacks.
  ///
  /// In en, this message translates to:
  /// **'{count} questions in packs'**
  String settingsQuestionsInPacks(Object count);

  /// No description provided for @settingsBuyQuestions.
  ///
  /// In en, this message translates to:
  /// **'Buy questions without a subscription'**
  String get settingsBuyQuestions;

  /// No description provided for @settingsRenews.
  ///
  /// In en, this message translates to:
  /// **'Renews'**
  String get settingsRenews;

  /// No description provided for @settingsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsSignedIn;

  /// No description provided for @settingsSupabaseAccount.
  ///
  /// In en, this message translates to:
  /// **'Supabase account'**
  String get settingsSupabaseAccount;

  /// No description provided for @settingsAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'Account linked'**
  String get settingsAccountLinked;

  /// No description provided for @settingsLinkYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Link your phone'**
  String get settingsLinkYourPhone;

  /// No description provided for @settingsConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {phone}'**
  String settingsConnectedAs(Object phone);

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up policies and use them on another device'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'{mode}'**
  String settingsThemeMode(Object mode);

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Renewal reminders and quiet hours'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsSmartSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Coverage insights'**
  String get settingsSmartSuggestions;

  /// No description provided for @settingsSmartSuggestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon: coverage guidance based on your policy details'**
  String get settingsSmartSuggestionsSubtitle;

  /// No description provided for @settingsServiceEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Service endpoint'**
  String get settingsServiceEndpoint;

  /// No description provided for @settingsClearDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all local data?'**
  String get settingsClearDataTitle;

  /// No description provided for @settingsClearDataAction.
  ///
  /// In en, this message translates to:
  /// **'Clear local data'**
  String get settingsClearDataAction;

  /// No description provided for @settingsClearDataContent.
  ///
  /// In en, this message translates to:
  /// **'This removes all locally stored documents, policy summaries, Q&A history, family members, and session data from this device. Uploaded documents on the server are not affected. This action cannot be undone from this device.'**
  String get settingsClearDataContent;

  /// No description provided for @settingsClearDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'All local data cleared from this device.'**
  String get settingsClearDataSuccess;

  /// No description provided for @settingsClearDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove documents, summaries, history and family members'**
  String get settingsClearDataSubtitle;

  /// No description provided for @settingsNoConsentRecords.
  ///
  /// In en, this message translates to:
  /// **'No consent records'**
  String get settingsNoConsentRecords;

  /// No description provided for @settingsConsentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Consent is recorded when you upload your first policy'**
  String get settingsConsentRecorded;

  /// No description provided for @settingsConsentPolicyProcessing.
  ///
  /// In en, this message translates to:
  /// **'Policy processing'**
  String get settingsConsentPolicyProcessing;

  /// No description provided for @settingsConsentAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics'**
  String get settingsConsentAnalytics;

  /// No description provided for @settingsConsentLeadCapture.
  ///
  /// In en, this message translates to:
  /// **'Contact capture'**
  String get settingsConsentLeadCapture;

  /// No description provided for @settingsConsentTermsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Terms accepted'**
  String get settingsConsentTermsAccepted;

  /// No description provided for @settingsConsentGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted {date} • v{version}'**
  String settingsConsentGranted(Object date, Object version);

  /// No description provided for @settingsConsentRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked {date}'**
  String settingsConsentRevoked(Object date);

  /// No description provided for @settingsConsentActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsConsentActive;

  /// No description provided for @settingsConsentRevokedLabel.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get settingsConsentRevokedLabel;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileDefaultHeader.
  ///
  /// In en, this message translates to:
  /// **'Your CoverWise profile'**
  String get profileDefaultHeader;

  /// No description provided for @profileLinkedHeader.
  ///
  /// In en, this message translates to:
  /// **'Linked and ready across your devices.'**
  String get profileLinkedHeader;

  /// No description provided for @profileUnlinkedHeader.
  ///
  /// In en, this message translates to:
  /// **'Your policy workspace currently stays on this device.'**
  String get profileUnlinkedHeader;

  /// No description provided for @profileCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a secure account'**
  String get profileCreateAccount;

  /// No description provided for @profileRestoreWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Restore this policy workspace across devices'**
  String get profileRestoreWorkspace;

  /// No description provided for @profileSignedInAccount.
  ///
  /// In en, this message translates to:
  /// **'Signed-in account'**
  String get profileSignedInAccount;

  /// No description provided for @profileWorkspaceLinked.
  ///
  /// In en, this message translates to:
  /// **'Workspace is linked to your account'**
  String get profileWorkspaceLinked;

  /// No description provided for @profilePhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profilePhoneNumber;

  /// No description provided for @profileNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get profileNotLinked;

  /// No description provided for @profileSecureSession.
  ///
  /// In en, this message translates to:
  /// **'Secure session'**
  String get profileSecureSession;

  /// No description provided for @profileAccountSessionActive.
  ///
  /// In en, this message translates to:
  /// **'Account session active on this device'**
  String get profileAccountSessionActive;

  /// No description provided for @profileAnonymousSessionActive.
  ///
  /// In en, this message translates to:
  /// **'Anonymous session active on this device'**
  String get profileAnonymousSessionActive;

  /// No description provided for @profileAppSection.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get profileAppSection;

  /// No description provided for @profileFamilySection.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get profileFamilySection;

  /// No description provided for @profilePrivacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacySection;

  /// No description provided for @profileDeviceFirstStorage.
  ///
  /// In en, this message translates to:
  /// **'Device-first storage'**
  String get profileDeviceFirstStorage;

  /// No description provided for @profileDeviceFirstSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This device keeps a protected local cache; account data may also be stored securely for sync.'**
  String get profileDeviceFirstSubtitle;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove account and all server data'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileCreateAccountFirst.
  ///
  /// In en, this message translates to:
  /// **'Create an account first to delete it'**
  String get profileCreateAccountFirst;

  /// No description provided for @profileFooter.
  ///
  /// In en, this message translates to:
  /// **'CoverWise helps you understand your policies. It does not sell insurance.'**
  String get profileFooter;

  /// No description provided for @profileDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently?'**
  String get profileDeleteConfirmTitle;

  /// No description provided for @profileDeleteConfirmHeader.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:'**
  String get profileDeleteConfirmHeader;

  /// No description provided for @profileDeleteItemAccount.
  ///
  /// In en, this message translates to:
  /// **'• Your CoverWise account'**
  String get profileDeleteItemAccount;

  /// No description provided for @profileDeleteItemDocs.
  ///
  /// In en, this message translates to:
  /// **'• All uploaded policy documents on our servers'**
  String get profileDeleteItemDocs;

  /// No description provided for @profileDeleteItemSummaries.
  ///
  /// In en, this message translates to:
  /// **'• All policy summaries and embeddings'**
  String get profileDeleteItemSummaries;

  /// No description provided for @profileDeleteItemHistory.
  ///
  /// In en, this message translates to:
  /// **'• Your Q&A history on the server'**
  String get profileDeleteItemHistory;

  /// No description provided for @profileDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone from this device. Local data on this device will be cleared separately via Settings → Clear local data.'**
  String get profileDeleteWarning;

  /// No description provided for @profileDeleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get profileDeleteEverything;

  /// No description provided for @profileDeleteTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get profileDeleteTypeTitle;

  /// No description provided for @profileDeleteTypeWarning.
  ///
  /// In en, this message translates to:
  /// **'This is your last chance. All data will be permanently erased.'**
  String get profileDeleteTypeWarning;

  /// No description provided for @profileDeleteTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE'**
  String get profileDeleteTypeHint;

  /// No description provided for @profileDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get profileDeletePermanently;

  /// No description provided for @profileDeletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get profileDeletingAccount;

  /// No description provided for @profileDeleteComplete.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. {docs} document(s) and {files} storage file(s) removed.'**
  String profileDeleteComplete(Object docs, Object files);

  /// No description provided for @profileDeletePartial.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is partially complete. Failed stages: {failed}. Do not assume server deletion is complete.'**
  String profileDeletePartial(Object failed);

  /// No description provided for @profileDeleteRequested.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requested. Status: {status}.'**
  String profileDeleteRequested(Object status);

  /// No description provided for @profileDeletionStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deletion status'**
  String get profileDeletionStatusTitle;

  /// No description provided for @profileDeletionStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Deletion is queued. Your account remains active until server erasure is verified.'**
  String get profileDeletionStatusPending;

  /// No description provided for @profileDeletionStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Deletion is being processed. New account writes are paused while erasure runs.'**
  String get profileDeletionStatusRunning;

  /// No description provided for @profileDeletionStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'The last deletion attempt needs attention.'**
  String get profileDeletionStatusFailed;

  /// No description provided for @profileDeletionStatusRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get profileDeletionStatusRefresh;

  /// No description provided for @profileDeletionStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Deletion status is temporarily unavailable.'**
  String get profileDeletionStatusUnavailable;

  /// No description provided for @profileInFlightWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} document(s) still processing. Please wait for processing to complete before deleting your account.'**
  String profileInFlightWarning(Object count);

  /// No description provided for @upgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your plan'**
  String get upgradeTitle;

  /// No description provided for @upgradeBillingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Billing is not available yet. Please try again later.'**
  String get upgradeBillingUnavailable;

  /// No description provided for @upgradeCouldNotOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription settings'**
  String get upgradeCouldNotOpenSettings;

  /// No description provided for @upgradeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upgraded to {plan}! Enjoy your new features.'**
  String upgradeSuccess(Object plan);

  /// No description provided for @upgradePurchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase was cancelled.'**
  String get upgradePurchaseCancelled;

  /// No description provided for @upgradeMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get upgradeMonthly;

  /// No description provided for @upgradeAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get upgradeAnnual;

  /// No description provided for @upgradeSaveUpTo.
  ///
  /// In en, this message translates to:
  /// **'Save up to 44%'**
  String get upgradeSaveUpTo;

  /// No description provided for @upgradeCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get upgradeCurrentPlan;

  /// No description provided for @upgradeFreeForever.
  ///
  /// In en, this message translates to:
  /// **'Free forever'**
  String get upgradeFreeForever;

  /// No description provided for @upgradeTo.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to {plan}'**
  String upgradeTo(Object plan);

  /// No description provided for @upgradeComparePlans.
  ///
  /// In en, this message translates to:
  /// **'Compare plans'**
  String get upgradeComparePlans;

  /// No description provided for @upgradeQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get upgradeQuestions;

  /// No description provided for @upgradeFaqSwitch.
  ///
  /// In en, this message translates to:
  /// **'Can I switch plans?'**
  String get upgradeFaqSwitch;

  /// No description provided for @upgradeFaqSwitchAnswer.
  ///
  /// In en, this message translates to:
  /// **'You can manage plan changes through your App Store or Play Store subscription settings.'**
  String get upgradeFaqSwitchAnswer;

  /// No description provided for @upgradeFaqPacks.
  ///
  /// In en, this message translates to:
  /// **'What about my Q&A packs?'**
  String get upgradeFaqPacks;

  /// No description provided for @upgradeFaqPacksAnswer.
  ///
  /// In en, this message translates to:
  /// **'Pack questions remain active and are used after your monthly subscription quota is exhausted.'**
  String get upgradeFaqPacksAnswer;

  /// No description provided for @upgradeFaqCancel.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel?'**
  String get upgradeFaqCancel;

  /// No description provided for @upgradeFaqCancelAnswer.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime from your App Store or Play Store subscription settings.'**
  String get upgradeFaqCancelAnswer;

  /// No description provided for @upgradeAccessUntil.
  ///
  /// In en, this message translates to:
  /// **'Access until'**
  String get upgradeAccessUntil;

  /// No description provided for @upgradePolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get upgradePolicies;

  /// No description provided for @upgradeQaPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Q&A per month'**
  String get upgradeQaPerMonth;

  /// No description provided for @upgradeComparePolicies.
  ///
  /// In en, this message translates to:
  /// **'Compare policies'**
  String get upgradeComparePolicies;

  /// No description provided for @upgradeFamilyView.
  ///
  /// In en, this message translates to:
  /// **'Family view'**
  String get upgradeFamilyView;

  /// No description provided for @upgradeCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get upgradeCloudSync;

  /// No description provided for @upgradeEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get upgradeEmergency;

  /// No description provided for @upgradeAnnualReview.
  ///
  /// In en, this message translates to:
  /// **'Annual review'**
  String get upgradeAnnualReview;

  /// No description provided for @upgradeAdvancedSearch.
  ///
  /// In en, this message translates to:
  /// **'Advanced search'**
  String get upgradeAdvancedSearch;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'{isSignUp, select, true{Create account} other{Sign in}}'**
  String accountTitle(String isSignUp);

  /// No description provided for @accountHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your policy workspace'**
  String get accountHeaderTitle;

  /// No description provided for @accountHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An account lets you restore your CoverWise workspace on another device.'**
  String get accountHeaderSubtitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get accountNameLabel;

  /// No description provided for @accountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmailLabel;

  /// No description provided for @accountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPasswordLabel;

  /// No description provided for @accountResendBanner.
  ///
  /// In en, this message translates to:
  /// **'Your email has not been confirmed yet. Check your inbox or resend.'**
  String get accountResendBanner;

  /// No description provided for @accountResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get accountResend;

  /// No description provided for @accountForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get accountForgotPassword;

  /// No description provided for @accountResendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get accountResendVerification;

  /// No description provided for @accountSwitchToSignIn.
  ///
  /// In en, this message translates to:
  /// **'{isSignUp, select, true{Already have an account? Sign in} other{New to CoverWise? Create an account}}'**
  String accountSwitchToSignIn(String isSignUp);

  /// No description provided for @accountGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get accountGoogleSignIn;

  /// No description provided for @accountAuthNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Account auth is not configured for this build.'**
  String get accountAuthNotConfigured;

  /// No description provided for @accountEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get accountEnterEmail;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get accountPasswordTooShort;

  /// No description provided for @accountInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get accountInvalidEmail;

  /// No description provided for @accountCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm the account, then sign in.'**
  String get accountCheckEmail;

  /// No description provided for @accountIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password. Please try again.'**
  String get accountIncorrectCredentials;

  /// No description provided for @accountAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Try signing in.'**
  String get accountAlreadyRegistered;

  /// No description provided for @accountPasswordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Password does not meet requirements. Use at least 8 characters.'**
  String get accountPasswordRequirements;

  /// No description provided for @accountCouldNotAction.
  ///
  /// In en, this message translates to:
  /// **'Could not {action, select, true{create} other{sign in to}} the account.'**
  String accountCouldNotAction(String action);

  /// No description provided for @accountEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above first, then tap Forgot password.'**
  String get accountEnterEmailFirst;

  /// No description provided for @accountResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get accountResetEmailSent;

  /// No description provided for @accountCouldNotReset.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset email. Check your email and try again.'**
  String get accountCouldNotReset;

  /// No description provided for @accountEnterEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above first, then tap Resend verification.'**
  String get accountEnterEmailResend;

  /// No description provided for @accountVerificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Check your inbox.'**
  String get accountVerificationSent;

  /// No description provided for @accountCouldNotVerify.
  ///
  /// In en, this message translates to:
  /// **'Could not send verification email. Try again later.'**
  String get accountCouldNotVerify;

  /// No description provided for @accountCouldNotGoogle.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google. Please try again.'**
  String get accountCouldNotGoogle;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Renewal reminders'**
  String get notifTitle;

  /// No description provided for @notifHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay ahead of renewals'**
  String get notifHeaderTitle;

  /// No description provided for @notifHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose when this device should remind you. Notifications are reminders, not insurer renewal notices.'**
  String get notifHeaderSubtitle;

  /// No description provided for @notifMasterToggle.
  ///
  /// In en, this message translates to:
  /// **'Renewal reminders'**
  String get notifMasterToggle;

  /// No description provided for @notifEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enabled on this device'**
  String get notifEnabledSubtitle;

  /// No description provided for @notifDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get notifDisabledSubtitle;

  /// No description provided for @notifSectionRemindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me before expiry'**
  String get notifSectionRemindMe;

  /// No description provided for @notifSectionRemindMeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how many days before your policy expires to receive a reminder.'**
  String get notifSectionRemindMeDescription;

  /// No description provided for @notifNoReminderTimes.
  ///
  /// In en, this message translates to:
  /// **'No reminder times are selected.'**
  String get notifNoReminderTimes;

  /// No description provided for @notifSectionQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notifSectionQuietHours;

  /// No description provided for @notifSectionQuietHoursDescription.
  ///
  /// In en, this message translates to:
  /// **'No notifications during these hours.'**
  String get notifSectionQuietHoursDescription;

  /// No description provided for @notifStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get notifStartTime;

  /// No description provided for @notifEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get notifEndTime;

  /// No description provided for @notifSectionPerPolicy.
  ///
  /// In en, this message translates to:
  /// **'Per-policy reminders'**
  String get notifSectionPerPolicy;

  /// No description provided for @notifSectionPerPolicyDescription.
  ///
  /// In en, this message translates to:
  /// **'Toggle reminders for individual policies.'**
  String get notifSectionPerPolicyDescription;

  /// No description provided for @notifPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get notifPreferencesSaved;

  /// No description provided for @docsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get docsTitle;

  /// No description provided for @docsSlotsUsed.
  ///
  /// In en, this message translates to:
  /// **'{count} of 5 free policy slots used'**
  String docsSlotsUsed(Object count);

  /// No description provided for @docsTypeChanged.
  ///
  /// In en, this message translates to:
  /// **'Type changed to'**
  String get docsTypeChanged;

  /// No description provided for @docsRemovedLocal.
  ///
  /// In en, this message translates to:
  /// **'Removed from this device. The server copy was not affected.'**
  String get docsRemovedLocal;

  /// No description provided for @docsReplaceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Document replaced successfully'**
  String get docsReplaceSuccess;

  /// No description provided for @docsPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get docsPreview;

  /// No description provided for @docsDownloadSource.
  ///
  /// In en, this message translates to:
  /// **'Download source'**
  String get docsDownloadSource;

  /// No description provided for @docsChangeType.
  ///
  /// In en, this message translates to:
  /// **'Change type'**
  String get docsChangeType;

  /// No description provided for @docsAskQuestions.
  ///
  /// In en, this message translates to:
  /// **'Ask Questions'**
  String get docsAskQuestions;

  /// No description provided for @docsReadingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Reading policy'**
  String get docsReadingPolicy;

  /// No description provided for @docsUploadRequired.
  ///
  /// In en, this message translates to:
  /// **'Server upload required'**
  String get docsUploadRequired;

  /// No description provided for @docsRetryUpload.
  ///
  /// In en, this message translates to:
  /// **'Retry upload'**
  String get docsRetryUpload;

  /// No description provided for @docsNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get docsNeedsAttention;

  /// No description provided for @docsReadyForQuestions.
  ///
  /// In en, this message translates to:
  /// **'Ready for questions'**
  String get docsReadyForQuestions;

  /// No description provided for @docsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get docsSaved;

  /// No description provided for @docsRefreshingTypes.
  ///
  /// In en, this message translates to:
  /// **'Refreshing document types...'**
  String get docsRefreshingTypes;

  /// No description provided for @docsTypesRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Document types refreshed successfully!'**
  String get docsTypesRefreshed;

  /// No description provided for @docsReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get docsReplace;

  /// No description provided for @docsRemoveFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get docsRemoveFromDevice;

  /// No description provided for @docsRemoveFromDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device?'**
  String get docsRemoveFromDeviceTitle;

  /// No description provided for @docsDeletePolicy.
  ///
  /// In en, this message translates to:
  /// **'Delete policy'**
  String get docsDeletePolicy;

  /// No description provided for @docsDeletePolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete policy?'**
  String get docsDeletePolicyTitle;

  /// No description provided for @docsDeletePolicyContent.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes \"{filename}\" from CoverWise and this device.'**
  String docsDeletePolicyContent(Object filename);

  /// No description provided for @docsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Policy deleted'**
  String get docsDeleted;

  /// No description provided for @docsReplaceDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace Document?'**
  String get docsReplaceDocumentTitle;

  /// No description provided for @docsReplaceDocument.
  ///
  /// In en, this message translates to:
  /// **'Replace Document'**
  String get docsReplaceDocument;

  /// No description provided for @docsCurrentDocument.
  ///
  /// In en, this message translates to:
  /// **'Current Document'**
  String get docsCurrentDocument;

  /// No description provided for @docsSelectReplacement.
  ///
  /// In en, this message translates to:
  /// **'Select Replacement File'**
  String get docsSelectReplacement;

  /// No description provided for @docsReplaceWillDelete.
  ///
  /// In en, this message translates to:
  /// **'This will delete \"{filename}\" and replace it with the new file.'**
  String docsReplaceWillDelete(Object filename);

  /// No description provided for @docsReplaceAnalysisLost.
  ///
  /// In en, this message translates to:
  /// **'The old document\'s analysis will be lost. The new document will be processed fresh.'**
  String get docsReplaceAnalysisLost;

  /// No description provided for @docsUploadedDate.
  ///
  /// In en, this message translates to:
  /// **'Uploaded: {date}'**
  String docsUploadedDate(Object date);

  /// No description provided for @docsClearReplacement.
  ///
  /// In en, this message translates to:
  /// **'Clear replacement file'**
  String get docsClearReplacement;

  /// No description provided for @docsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get docsArchive;

  /// No description provided for @docsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get docsArchived;

  /// No description provided for @docsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get docsRestore;

  /// No description provided for @docsRestored.
  ///
  /// In en, this message translates to:
  /// **'Policy restored'**
  String get docsRestored;

  /// No description provided for @docsArchivedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Policy archived'**
  String get docsArchivedSuccess;

  /// No description provided for @docsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get docsShowArchived;

  /// No description provided for @docsHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get docsHideArchived;

  /// No description provided for @docsArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive policy?'**
  String get docsArchiveConfirmTitle;

  /// No description provided for @docsArchiveConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'\"{filename}\" will be hidden from your active policy list. You can restore it any time from the archive.'**
  String docsArchiveConfirmContent(Object filename);

  /// No description provided for @docsDeletePermanentWarning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the policy from both CoverWise and this device. Consider archiving instead.'**
  String get docsDeletePermanentWarning;

  /// No description provided for @docsLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'You are nearing your free storage limit. Archive old policies to free up space.'**
  String get docsLimitWarning;

  /// No description provided for @docsLimitCountdown.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} slots used — {remaining} remaining'**
  String docsLimitCountdown(Object limit, Object remaining, Object used);

  /// No description provided for @docsLimitRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} free slot(s) remaining'**
  String docsLimitRemaining(Object remaining);

  /// No description provided for @docsSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get docsSortLabel;

  /// No description provided for @docsFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get docsFilterLabel;

  /// No description provided for @docsSortDateNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get docsSortDateNewest;

  /// No description provided for @docsSortDateOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get docsSortDateOldest;

  /// No description provided for @docsSortNameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get docsSortNameAZ;

  /// No description provided for @docsSortNameZA.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get docsSortNameZA;

  /// No description provided for @docsSortType.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get docsSortType;

  /// No description provided for @docsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get docsFilterAll;

  /// No description provided for @docsFilterResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} policies'**
  String docsFilterResultCount(Object count, Object total);

  /// No description provided for @docsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename policy'**
  String get docsRenameTitle;

  /// No description provided for @docsRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new name'**
  String get docsRenameHint;

  /// No description provided for @docsRenameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get docsRenameSave;

  /// No description provided for @docsRenameSuccess.
  ///
  /// In en, this message translates to:
  /// **'Policy renamed'**
  String get docsRenameSuccess;

  /// No description provided for @docsRenameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get docsRenameEmpty;

  /// No description provided for @tosTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get tosTitle;

  /// No description provided for @tosCopySuccess.
  ///
  /// In en, this message translates to:
  /// **'Terms of service copied to clipboard'**
  String get tosCopySuccess;

  /// No description provided for @tosLoadError.
  ///
  /// In en, this message translates to:
  /// **'The terms of service could not be loaded.'**
  String get tosLoadError;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacyCopySuccess.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy copied to clipboard'**
  String get privacyCopySuccess;

  /// No description provided for @privacyLoadError.
  ///
  /// In en, this message translates to:
  /// **'The privacy policy could not be loaded.'**
  String get privacyLoadError;

  /// No description provided for @processingReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get processingReceived;

  /// No description provided for @processingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processingProcessing;

  /// No description provided for @processingCategorising.
  ///
  /// In en, this message translates to:
  /// **'Categorising'**
  String get processingCategorising;

  /// No description provided for @processingFinishingUp.
  ///
  /// In en, this message translates to:
  /// **'Finishing up'**
  String get processingFinishingUp;

  /// No description provided for @processingReceivedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your policy has been received'**
  String get processingReceivedDesc;

  /// No description provided for @processingProcessingDesc.
  ///
  /// In en, this message translates to:
  /// **'Reading and extracting text'**
  String get processingProcessingDesc;

  /// No description provided for @processingCategorisingDesc.
  ///
  /// In en, this message translates to:
  /// **'Determining policy type and insurer'**
  String get processingCategorisingDesc;

  /// No description provided for @processingFinishingUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Making your policy searchable'**
  String get processingFinishingUpDesc;

  /// No description provided for @onboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get clear answers based on your actual policy — not generic advice from the internet.'**
  String get onboardSubtitle;

  /// No description provided for @onboardNoDataStored.
  ///
  /// In en, this message translates to:
  /// **'No policy data will be stored or shared without your consent.'**
  String get onboardNoDataStored;

  /// No description provided for @onboardTermsAcceptance.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the Privacy Policy and Terms of Service.'**
  String get onboardTermsAcceptance;

  /// No description provided for @emergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyTitle;

  /// No description provided for @emergencyHelpAtGlance.
  ///
  /// In en, this message translates to:
  /// **'Help at a glance'**
  String get emergencyHelpAtGlance;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get dashboardEmergency;

  /// No description provided for @dashboardAddPolicy.
  ///
  /// In en, this message translates to:
  /// **'Add policy file'**
  String get dashboardAddPolicy;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search across all policies...'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @coverageGapTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage Review'**
  String get coverageGapTitle;

  /// No description provided for @coverageGapEmpty.
  ///
  /// In en, this message translates to:
  /// **'No potential coverage questions flagged from the available policy text yet'**
  String get coverageGapEmpty;

  /// No description provided for @literacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurance Glossary'**
  String get literacyTitle;

  /// No description provided for @literacySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search terms...'**
  String get literacySearchHint;

  /// No description provided for @docTypePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select document type'**
  String get docTypePickerTitle;

  /// No description provided for @fileTypeSupported.
  ///
  /// In en, this message translates to:
  /// **'Supported file types'**
  String get fileTypeSupported;

  /// No description provided for @fileTypePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF documents'**
  String get fileTypePdf;

  /// No description provided for @fileTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Images (JPEG, PNG)'**
  String get fileTypeImage;

  /// No description provided for @fileTypeMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Maximum file size: 20 MB'**
  String get fileTypeMaxSize;

  /// No description provided for @fileTypeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported. Please choose a PDF or image.'**
  String get fileTypeUnsupported;

  /// No description provided for @whatIfTitle.
  ///
  /// In en, this message translates to:
  /// **'What-If Calculator'**
  String get whatIfTitle;

  /// No description provided for @whatIfDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore how different coverage options affect your estimated costs.'**
  String get whatIfDescription;

  /// No description provided for @batchPickMultiple.
  ///
  /// In en, this message translates to:
  /// **'Select multiple files'**
  String get batchPickMultiple;

  /// No description provided for @batchUploadingPendingCount.
  ///
  /// In en, this message translates to:
  /// **'Uploading {count} files…'**
  String batchUploadingPendingCount(Object count);

  /// No description provided for @batchUploadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {done} of {total}'**
  String batchUploadingProgress(Object done, Object total);

  /// No description provided for @batchCompleted.
  ///
  /// In en, this message translates to:
  /// **'All files uploaded'**
  String get batchCompleted;

  /// No description provided for @batchCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files uploaded successfully'**
  String batchCompletedCount(Object count);

  /// No description provided for @batchSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Some uploads failed'**
  String get batchSomeFailed;

  /// No description provided for @batchFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{failed} of {total} files failed'**
  String batchFailedCount(Object failed, Object total);

  /// No description provided for @batchFileTooLargeMB.
  ///
  /// In en, this message translates to:
  /// **'This file exceeds the {maxMB} MB limit and will be skipped'**
  String batchFileTooLargeMB(Object maxMB);

  /// No description provided for @batchFileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type — skipped'**
  String get batchFileUnsupported;

  /// No description provided for @batchDuplicateSkipped.
  ///
  /// In en, this message translates to:
  /// **'Duplicate — skipped'**
  String get batchDuplicateSkipped;

  /// No description provided for @batchRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed uploads'**
  String get batchRetryFailed;

  /// No description provided for @batchDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get batchDone;

  /// No description provided for @batchAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more files'**
  String get batchAddMore;

  /// No description provided for @batchSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get batchSelectAll;

  /// No description provided for @familyVisTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage map'**
  String get familyVisTitle;

  /// No description provided for @familyVisHeader.
  ///
  /// In en, this message translates to:
  /// **'Policy-listed family members'**
  String get familyVisHeader;

  /// No description provided for @familyVisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare family members listed in each policy; verify coverage with your insurer.'**
  String get familyVisSubtitle;

  /// No description provided for @familyVisMembers.
  ///
  /// In en, this message translates to:
  /// **'Family members'**
  String get familyVisMembers;

  /// No description provided for @familyVisPolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get familyVisPolicies;

  /// No description provided for @familyVisEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No coverage data yet'**
  String get familyVisEmptyTitle;

  /// No description provided for @familyVisEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload policies and add family members to compare names listed in your policy documents.'**
  String get familyVisEmptySubtitle;

  /// No description provided for @familyVisNoPolicies.
  ///
  /// In en, this message translates to:
  /// **'No policies listing {name} yet.'**
  String familyVisNoPolicies(Object name);

  /// No description provided for @familyVisSeeMap.
  ///
  /// In en, this message translates to:
  /// **'View policy member map'**
  String get familyVisSeeMap;

  /// No description provided for @coverageShareSummary.
  ///
  /// In en, this message translates to:
  /// **'Share summary'**
  String get coverageShareSummary;

  /// No description provided for @coverageShareSubject.
  ///
  /// In en, this message translates to:
  /// **'CoverWise policy coverage summary'**
  String get coverageShareSubject;

  /// No description provided for @coverageShareError.
  ///
  /// In en, this message translates to:
  /// **'Could not open sharing options'**
  String get coverageShareError;
}

class _AppLocalizationsGenDelegate
    extends LocalizationsDelegate<AppLocalizationsGen> {
  const _AppLocalizationsGenDelegate();

  @override
  Future<AppLocalizationsGen> load(Locale locale) {
    return SynchronousFuture<AppLocalizationsGen>(
        lookupAppLocalizationsGen(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi', 'mr', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsGenDelegate old) => false;
}

AppLocalizationsGen lookupAppLocalizationsGen(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsGenEn();
    case 'gu':
      return AppLocalizationsGenGu();
    case 'hi':
      return AppLocalizationsGenHi();
    case 'mr':
      return AppLocalizationsGenMr();
    case 'ta':
      return AppLocalizationsGenTa();
  }

  throw FlutterError(
      'AppLocalizationsGen.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
