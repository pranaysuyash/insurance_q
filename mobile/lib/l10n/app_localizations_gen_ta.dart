// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsGenTa extends AppLocalizationsGen {
  AppLocalizationsGenTa([String locale = 'ta']) : super(locale);

  @override
  String get appName => 'CoverWise';

  @override
  String get commonShowLess => 'குறைவாகக் காட்டு';

  @override
  String get commonShowMore => 'மேலும் காட்டு';

  @override
  String get cancel => 'ரத்துசெய்';

  @override
  String get save => 'சேமி';

  @override
  String get remove => 'அகற்று';

  @override
  String get add => 'சேர்';

  @override
  String get clear => 'அழி';

  @override
  String get enable => 'இயக்கு';

  @override
  String get disable => 'முடக்கு';

  @override
  String get version => 'பதிப்பு';

  @override
  String get upgrade => 'மேம்படுத்து';

  @override
  String get manage => 'நிர்வகி';

  @override
  String get signOut => 'வெளியேறு';

  @override
  String get signIn => 'உள்நுழை';

  @override
  String get createAccount => 'கணக்கை உருவாக்கு';

  @override
  String get buy => 'வாங்கு';

  @override
  String get startAsking => 'கேள்வி கேட்கத் தொடங்கு';

  @override
  String get getMore => 'மேலும் பெறு';

  @override
  String get getPacks => 'தொகுப்புகளைப் பெறு';

  @override
  String get viewPolicy => 'காப்பீட்டு ஆவணத்தைப் பார்';

  @override
  String policyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count காப்பீடுகள்',
      one: '1 காப்பீடு',
    );
    return '$_temp0';
  }

  @override
  String resultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count முடிவுகள்',
      one: '1 முடிவு',
    );
    return '$_temp0';
  }

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நாட்கள்',
      one: '1 நாள்',
    );
    return '$_temp0';
  }

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'நாட்களில்',
      one: 'நாளில்',
    );
    return '$count $_temp0 காலாவதியாகிறது';
  }

  @override
  String daysLeft(Object days) {
    return '$days நாட்கள் மீதம்';
  }

  @override
  String daysBefore(Object days) {
    return '$days நாட்களுக்கு முன்';
  }

  @override
  String get qaScreenTitle => 'CoverWise ஐக் கேளுங்கள்';

  @override
  String get qaTabSuggested => 'பரிந்துரைக்கப்பட்டவை';

  @override
  String get qaTabYourQuestion => 'உங்கள் கேள்வி';

  @override
  String get qaTabHistory => 'வரலாறு';

  @override
  String get qaNoQuestionsRemaining => 'மீதமுள்ள கேள்விகள் எதுவும் இல்லை';

  @override
  String qaQuestionsLeft(Object remaining) {
    return '$remaining கேள்விகள் மீதம்';
  }

  @override
  String qaMonthlyPlusPack(Object monthly, Object pack, Object packs) {
    return '$monthly மாதாந்திர + $pack தொகுப்பு';
  }

  @override
  String qaPackQuestions(Object count, Object packs) {
    return '$packs தொகுப்பு(களில்) $count கேள்விகள்';
  }

  @override
  String qaMonthlyPlan(Object remaining) {
    return 'இந்த மாதம் $remaining கேள்விகள் மீதம்';
  }

  @override
  String get qaAskAbout => 'பற்றிக் கேளுங்கள்';

  @override
  String get qaQuestionSource => 'கேள்வி மூலம்';

  @override
  String qaAllDocuments(Object count) {
    return 'அனைத்து ஆவணங்களும் ($count)';
  }

  @override
  String get qaSingleDocument => 'ஒற்றை ஆவணம்';

  @override
  String get qaNoDocumentSelected => 'எந்த ஆவணமும் தேர்ந்தெடுக்கப்படவில்லை';

  @override
  String get qaSearchAllPolicies =>
      'உங்கள் பதிவேற்றிய அனைத்து காப்பீடுகளிலும் தேடுங்கள்';

  @override
  String get qaAskAboutDescription =>
      'உங்கள் காப்பீட்டில் உள்ள கவரேஜ், விலக்குகள், தேதிகள் அல்லது வார்த்தைகள் பற்றிக் கேளுங்கள்.';

  @override
  String get qaHintText => 'எ.கா., பயனுள்ள தேதி எது?';

  @override
  String get qaClearQuestion => 'கேள்வியை அழி';

  @override
  String get qaNoHistoryYet => 'இதுவரை கேள்வி வரலாறு இல்லை';

  @override
  String get qaSearchHistory => 'வரலாற்றில் தேடு...';

  @override
  String qaNoMatchesFor(Object query) {
    return '\"$query\" க்கு பொருந்தும் முடிவுகள் இல்லை';
  }

  @override
  String get qaToday => 'இன்று';

  @override
  String get qaYesterday => 'நேற்று';

  @override
  String get qaThisWeek => 'இந்த வாரம்';

  @override
  String get qaEarlier => 'முந்தைய';

  @override
  String get qaSourcesLabel => 'மூலங்கள்';

  @override
  String get qaFollowUpLabel => 'நீங்கள் இவற்றையும் கேட்கலாம்:';

  @override
  String get qaHelpfulAnswer => 'பயனுள்ள பதில்';

  @override
  String get qaUnhelpfulAnswer => 'பயனற்ற பதில்';

  @override
  String get qaCopyAnswer => 'பதிலை நகலெடு';

  @override
  String get qaAnswerCopied => 'பதில் நகலெடுக்கப்பட்டது';

  @override
  String get qaShareAnswer => 'பதிலைப் பகிர்';

  @override
  String get qaAnswerCopiedToClipboard =>
      'பதில் கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது';

  @override
  String get qaEvidence => 'ஆதாரம்';

  @override
  String get qaCitationUnknown => 'தெரியவில்லை';

  @override
  String qaCitationSource(Object index) {
    return 'மூலம் $index';
  }

  @override
  String qaCitationSourcePage(Object index, Object page) {
    return 'மூலம் $index • பக்கம் $page';
  }

  @override
  String get qaPolicyDoesNotEstablish => 'காப்பீடு நிறுவாதவை';

  @override
  String qaAnswerReadyFor(Object question) {
    return '$question க்கான பதில் தயார்';
  }

  @override
  String qaCouldNotGetAnswer(Object error) {
    return 'பதிலைப் பெற முடியவில்லை. $error';
  }

  @override
  String get qaFallbackAnswer =>
      'மன்னிக்கவும், அது வேலை செய்யவில்லை. தயவுசெய்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get qaPolicySource => 'காப்பீட்டு மூலம்';

  @override
  String get qaViewSource => 'மூலத்தைப் பார்';

  @override
  String get qaViewSourcePage => 'பக்கத்தில் பார்';

  @override
  String get qaNoSourceDocument => 'மூல ஆவணம் கிடைக்கவில்லை';

  @override
  String qaSourcePageLabel(Object page) {
    return 'பக்கம் $page';
  }

  @override
  String get qaRelevanceTooltip =>
      'இந்த மூலம் உங்கள் கேள்வியுடன் எவ்வளவு நெருக்கமாக பொருந்துகிறது';

  @override
  String get qaOfflineMessage =>
      'You are offline. Please check your connection and try again.';

  @override
  String get confidenceHigh => 'அதிகம்';

  @override
  String get confidenceMedium => 'நடுத்தரம்';

  @override
  String get confidenceLow => 'குறைவு';

  @override
  String confidenceLabel(Object level) {
    return '$level நம்பிக்கை';
  }

  @override
  String get qaPacksTitle => 'Q&A தொகுப்புகள்';

  @override
  String get qaPacksBuyHeading => 'தொகுப்பு வாங்கு';

  @override
  String get qaPacksSubtitle =>
      'சந்தா தேவையில்லை. ஒருமுறை செலுத்தி, கேள்விகள் கேளுங்கள்.';

  @override
  String get qaPacksYourPacks => 'உங்கள் தொகுப்புகள்';

  @override
  String get qaPacksPurchasedSuccess =>
      'கொள்முதல் பெறப்பட்டது. சர்வர் உறுதிப்படுத்தலுக்குப் பின் கேள்விகள் தோன்றும்.';

  @override
  String get qaPacksHowTheyWork => 'தொகுப்புகள் எவ்வாறு செயல்படுகின்றன';

  @override
  String get qaPacksFaqQ1 => 'கேள்விகள் எப்போது கழிக்கப்படுகின்றன?';

  @override
  String get qaPacksFaqA1 =>
      'நீங்கள் சமர்ப்பிக்கும் ஒவ்வொரு முறையும் ஒரு கேள்வி கழிக்கப்படுகிறது. மாதாந்திர சந்தா கேள்விகள் முதலில் பயன்படுத்தப்படுகின்றன, பின் தொகுப்பு கேள்விகள்.';

  @override
  String get qaPacksFaqQ2 => 'தொகுப்புகள் காலாவதியாகுமா?';

  @override
  String get qaPacksFaqA2 =>
      'ஆம், தொகுப்புகள் வாங்கியதிலிருந்து 90 நாட்களுக்கு செல்லுபடியாகும். பயன்படுத்தப்படாத கேள்விகள் காலாவதிக்குப் பின் இழக்கப்படும்.';

  @override
  String get qaPacksFaqQ3 => 'என்னிடம் பல தொகுப்புகள் இருக்க முடியுமா?';

  @override
  String get qaPacksFaqA3 =>
      'ஆம்! பல தொகுப்புகள் அடுக்கப்படும். கேள்விகள் முதலில் காலாவதியாகும் தொகுப்பிலிருந்து நுகரப்படும் (FIFO).';

  @override
  String get qaPacksFaqQ4 => 'நான் சந்தாவிற்கு மேம்படுத்தினால் என்ன நடக்கும்?';

  @override
  String get qaPacksFaqA4 =>
      'உங்கள் தொகுப்பு கேள்விகள் செயலில் இருக்கும் மற்றும் உங்கள் மாதாந்திர ஒதுக்கீடு தீர்ந்தபின் பயன்படுத்தப்படும்.';

  @override
  String qaPacksQuestionsAvailable(Object count) {
    return '$count கேள்விகள் உள்ளன';
  }

  @override
  String qaPacksFromMonthlyPlan(Object count) {
    return '$count மாதத் திட்டத்திலிருந்து';
  }

  @override
  String qaPacksFromPacks(Object count) {
    return '$count தொகுப்புகளிலிருந்து';
  }

  @override
  String qaPacksFromMonthlyAndPacks(Object monthly, Object packs) {
    return '$monthly மாதத் திட்டத்திலிருந்து · $packs தொகுப்புகளிலிருந்து';
  }

  @override
  String qaPacksQuestionsInPacks(Object count) {
    return '$count தொகுப்புகளிலிருந்து';
  }

  @override
  String get qaPacksBestValue => 'அதிக மாதாந்திர கேள்விகள்';

  @override
  String qaPacksQuestionsEach(Object count, Object price) {
    return '$count கேள்விகள் · $price ஒவ்வொன்றும்';
  }

  @override
  String qaPacksPackPurchased(Object name) {
    return 'கொள்முதல் பெறப்பட்டது. உங்கள் $name கேள்விகள் சர்வர் உறுதிப்படுத்தலுக்குப் பின் தோன்றும்.';
  }

  @override
  String get qaPacksPurchaseCancelled => 'கொள்முதல் ரத்துசெய்யப்பட்டது.';

  @override
  String get qaPacksPurchaseNotCompleted =>
      'கொள்முதல் முடிக்கப்படவில்லை. கேள்விகள் எதுவும் சேர்க்கப்படவில்லை.';

  @override
  String qaPacksPackRemaining(Object type) {
    return '$type தொகுப்பு';
  }

  @override
  String qaPacksRemaining(Object remaining, Object total) {
    return '$remaining/$total மீதம்';
  }

  @override
  String get familyTitle => 'குடும்பம்';

  @override
  String get familyNoMembersYet => 'இதுவரை குடும்ப உறுப்பினர்கள் இல்லை';

  @override
  String get familyNoMembersFound =>
      'குடும்ப உறுப்பினர்கள் யாரும் காணப்படவில்லை';

  @override
  String get familyEmptySubtitle =>
      'குடும்ப உறுப்பினர்களைத் தானாகக் கண்டறிய காப்பீட்டு ஆவணங்களைப் பதிவேற்றவும், அல்லது கைமுறையாக சேர்க்கவும்.';

  @override
  String get familyAddMember => 'குடும்ப உறுப்பினரைச் சேர்க்கவும்';

  @override
  String get familyLibraryError =>
      'உங்கள் காப்பீட்டு நூலகத்தை ஏற்ற முடியவில்லை.';

  @override
  String get familyMembersReadError =>
      'உங்கள் காப்பீடுகளிலிருந்து பாதுகாக்கப்பட்ட குடும்ப உறுப்பினர்களைப் படிக்க முடியவில்லை.';

  @override
  String get familyPeopleCovered => 'பாதுகாக்கப்பட்ட நபர்கள்';

  @override
  String get familyPeopleSubtitle =>
      'உங்கள் காப்பீடுகளில் காணப்படும் நபர்களின் தெளிவான காட்சி, நீங்களே சேர்த்தவர்களும் அடங்கும்.';

  @override
  String get familySectionLabel =>
      'குடும்பம் மற்றும் காப்பீடு செய்யப்பட்ட உறுப்பினர்கள்';

  @override
  String get familyRemoveTitle => 'குடும்ப உறுப்பினரை அகற்றவா?';

  @override
  String familyRemoveContent(Object name) {
    return '$name ஐ உங்கள் குடும்பப் பட்டியலிலிருந்து அகற்றவா? இது உங்கள் காப்பீட்டு ஆவணங்களைப் பாதிக்காது.';
  }

  @override
  String get familyAddButton => 'குடும்ப உறுப்பினரைச் சேர்';

  @override
  String get familyManualBadge => 'கைமுறை';

  @override
  String get familyFromDocumentBadge => 'ஆவணத்திலிருந்து';

  @override
  String familyRemoveTooltip(Object name) {
    return '$name ஐ அகற்று';
  }

  @override
  String familyDateOfBirth(Object date) {
    return 'பிறந்த தேதி: $date';
  }

  @override
  String get familyDetailEditTooltip => 'உறுப்பினரைத் திருத்து';

  @override
  String get familyDetailHintName => 'முழுப் பெயர்';

  @override
  String get familyDetailMemberUpdated => 'உறுப்பினர் புதுப்பிக்கப்பட்டார்';

  @override
  String familyDetailUpdateError(Object error) {
    return 'உறுப்பினரைப் புதுப்பிக்க முடியவில்லை: $error';
  }

  @override
  String get familyDetailDobLabel => 'பிறந்த தேதி';

  @override
  String get familyDetailSourceLabel => 'மூலம்';

  @override
  String get familyDetailCoveringPolicies => 'பாதுகாக்கும் காப்பீடுகள்';

  @override
  String get familyDetailManualSource => 'கைமுறையாகச் சேர்க்கப்பட்டது';

  @override
  String get familyDetailAutoSource => 'காப்பீட்டிலிருந்து கண்டறியப்பட்டது';

  @override
  String familyDetailNoPolicies(Object name) {
    return '$name ஐ பட்டியலிடும் காப்பீடுகள் எதுவும் காணப்படவில்லை.';
  }

  @override
  String get relationshipDependent => 'சார்ந்திருப்பவர்';

  @override
  String get relationshipSpouse => 'வாழ்க்கைத் துணை';

  @override
  String get relationshipChild => 'குழந்தை';

  @override
  String get relationshipParent => 'பெற்றோர்';

  @override
  String get relationshipSibling => 'உடன்பிறந்தோர்';

  @override
  String get relationshipPrimaryInsured => 'முதன்மை காப்பீட்டாளர்';

  @override
  String get relationshipOther => 'மற்றவை';

  @override
  String get insuranceCardsTitle => 'காப்பீட்டு அட்டைகள்';

  @override
  String get insuranceCardsEmptyTitle => 'இதுவரை காப்பீட்டு அட்டைகள் இல்லை';

  @override
  String get insuranceCardsEmptySubtitle =>
      'உங்கள் தொலைபேசியில் முக்கிய விவரங்களைத் தயாராக வைத்திருக்க காப்பீட்டுக் கோப்பைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get insuranceCardsChooseFile => 'காப்பீட்டுக் கோப்பைத் தேர்ந்தெடு';

  @override
  String get insuranceCardsHeaderTitle =>
      'உங்கள் காப்பீட்டு விவரங்கள், எடுத்துச் செல்லத் தயார்';

  @override
  String get insuranceCardsHeaderSubtitle =>
      'காப்பீட்டு மற்றும் நிறுவன விவரங்களுக்கான விரைவுக் குறிப்பு. உங்கள் காப்பீட்டு நிறுவனத்துடன் ஆதாரத் தேவைகளை சரிபார்க்கவும்.';

  @override
  String get insuranceCardsPolicyNumber => 'காப்பீட்டு எண்';

  @override
  String get insuranceCardsCoverage => 'கவரேஜ்';

  @override
  String get insuranceCardsPremium => 'பிரீமியம்';

  @override
  String get insuranceCardsValidFrom => 'இதிலிருந்து செல்லுபடியாகும்';

  @override
  String get insuranceCardsValidUntil => 'இது வரை செல்லுபடியாகும்';

  @override
  String get insuranceCardsCallInsurer => 'காப்பீட்டு நிறுவனத்தை அழைக்கவும்';

  @override
  String get insuranceCardsShareCard => 'அட்டையைப் பகிர்';

  @override
  String get insuranceCardsExpired => 'காலாவதியானது';

  @override
  String get insuranceCardsShareTitle => 'CoverWise காப்பீட்டுக் குறிப்பு';

  @override
  String get insuranceCardsInsurerPrefix => 'காப்பீட்டு நிறுவனம்: ';

  @override
  String get insuranceCardsPolicyNumberPrefix => 'காப்பீட்டு எண்: ';

  @override
  String get insuranceCardsCoveragePrefix => 'கவரேஜ்: ';

  @override
  String get insuranceCardsValidUntilPrefix => 'இது வரை செல்லுபடியாகும்: ';

  @override
  String get insuranceCardsHelplinePrefix => 'காப்பீட்டு நிறுவன உதவி எண்: ';

  @override
  String get insuranceCardsShareFooter =>
      'காப்பீட்டு நிறுவனம் மற்றும் மூலக் காப்பீட்டு ஆவணத்துடன் தற்போதைய விவரங்களைச் சரிபார்க்கவும்.';

  @override
  String get insuranceCardsPhoneError =>
      'தொலைபேசி பயன்பாட்டைத் திறக்க முடியவில்லை';

  @override
  String get insuranceCardsShareError =>
      'பகிர்வு விருப்பங்களைத் திறக்க முடியவில்லை';

  @override
  String get renewalTitle => 'புதுப்பிப்பு நாட்காட்டி';

  @override
  String get renewalEmptyTitle => 'காப்பீடுகள் எதுவும் கண்காணிக்கப்படவில்லை';

  @override
  String get renewalEmptySubtitle =>
      'புதுப்பிப்பு தேதிகளைக் கண்காணிக்க காப்பீட்டுக் கோப்பைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get renewalHeaderTitle => 'புதுப்பிப்புகளைக் கண்காணியுங்கள்';

  @override
  String get renewalHeaderSubtitle =>
      'எதற்கு முதலில் கவனம் தேவை என்பதைப் பார்த்து, காப்பீட்டு நிறுவன தொடர்பு விவரங்களை நெருக்கமாக வைத்திருங்கள்.';

  @override
  String get renewalReminderText =>
      'காப்பீடு காலாவதியாவதற்கு 30, 15, 7 மற்றும் 1 நாளுக்கு முன் நினைவூட்டல்களை அமைக்கவும்.';

  @override
  String get renewalRemindersOn =>
      'புதுப்பிப்பு நினைவூட்டல்கள் இயக்கத்தில் உள்ளன.';

  @override
  String get renewalNotificationsOff =>
      'அறிவிப்புகள் முடக்கப்பட்டுள்ளன. அமைப்புகளில் அவற்றை இயக்கலாம்.';

  @override
  String get renewalSectionExpired => 'காலாவதியானது';

  @override
  String get renewalSectionExpiringSoon => 'விரைவில் காலாவதியாகும்';

  @override
  String get renewalSectionActive => 'செயலில் உள்ளது';

  @override
  String get renewalSectionNoDate => 'காலாவதி தேதி கிடைக்கவில்லை';

  @override
  String get renewalNoDateInfo =>
      'உங்கள் காப்பீட்டில் காலாவதி தேதி கிடைக்கவில்லை — உங்கள் காப்பீட்டு ஆவணத்தைச் சரிபார்க்கவும்';

  @override
  String get renewalInsurerNotFound => 'காப்பீட்டு நிறுவனம் கிடைக்கவில்லை';

  @override
  String renewalExpires(Object date) {
    return '$date அன்று காலாவதியாகிறது';
  }

  @override
  String get renewalContactToRenew =>
      'புதுப்பிக்க காப்பீட்டு நிறுவனத்தைத் தொடர்பு கொள்ளவும்';

  @override
  String get renewalStartRenewal => 'புதுப்பிப்பைத் தொடங்கு';

  @override
  String renewalRenewTitle(Object type) {
    return '$type புதுப்பி';
  }

  @override
  String renewalContactInsurer(Object insurer) {
    return 'புதுப்பிப்பு செயல்முறையைத் தொடங்க $insurer ஐ தொடர்பு கொள்ளவும்.';
  }

  @override
  String get renewalCallHelpline => 'உதவி எண்ணை அழைக்கவும்';

  @override
  String get renewalSendEmail => 'மின்னஞ்சல் அனுப்பவும்';

  @override
  String renewalContactInfoNotFound(Object insurer) {
    return '$insurer க்கான தொடர்புத் தகவல் கிடைக்கவில்லை. உங்கள் காப்பீட்டு ஆவணத்தைச் சரிபார்க்கவும் அல்லது நேரடியாக காப்பீட்டு நிறுவனத்தை அழைக்கவும்.';
  }

  @override
  String get renewalPhoneDialerError => 'தொலைபேசி டயலரைத் திறக்க முடியவில்லை';

  @override
  String get renewalEmailClientError =>
      'மின்னஞ்சல் கிளையண்டைத் திறக்க முடியவில்லை';

  @override
  String renewalExpiringPolicies(Object date) {
    return '$date அன்று காலாவதியாகும் காப்பீடுகள்';
  }

  @override
  String renewalExpiringCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count காப்பீடுகள்',
      one: '1 காப்பீடு',
    );
    return '$_temp0 இந்த தேதியில் காலாவதியாகின்றன';
  }

  @override
  String get settingsTitle => 'அமைப்புகள்';

  @override
  String get settingsHeaderTitle =>
      'உங்கள் பயன்பாடு, உங்கள் விருப்பத்தேர்வுகள்';

  @override
  String get settingsHeaderSubtitle =>
      'அணுகல், நினைவூட்டல்கள் மற்றும் இந்தச் சாதனத்தில் என்ன இருக்கும் என்பதை நிர்வகிக்கவும்.';

  @override
  String get settingsSectionPlan => 'திட்டம்';

  @override
  String get settingsSectionAccount => 'கணக்கு';

  @override
  String get settingsSectionExperience => 'அனுபவம்';

  @override
  String get settingsSectionAppDetails => 'பயன்பாட்டு விவரங்கள்';

  @override
  String get settingsSectionPrivacy => 'தனியுரிமை மற்றும் ஒப்புதல்';

  @override
  String get settingsSectionDeviceData => 'சாதனத் தரவு';

  @override
  String settingsCurrentPlan(Object plan) {
    return 'தற்போதைய திட்டம்: $plan';
  }

  @override
  String get settingsQaPacks => 'Q&A தொகுப்புகள்';

  @override
  String settingsQuestionsInPacks(Object count) {
    return '$count கேள்விகள் தொகுப்புகளில்';
  }

  @override
  String get settingsBuyQuestions => 'சந்தா இல்லாமல் கேள்விகள் வாங்கவும்';

  @override
  String get settingsRenews => 'புதுப்பிக்கப்படுகிறது';

  @override
  String get settingsSignedIn => 'உள்நுழைந்துள்ளீர்கள்';

  @override
  String get settingsSupabaseAccount => 'Supabase கணக்கு';

  @override
  String get settingsAccountLinked => 'கணக்கு இணைக்கப்பட்டது';

  @override
  String get settingsLinkYourPhone => 'உங்கள் தொலைபேசியை இணைக்கவும்';

  @override
  String settingsConnectedAs(Object phone) {
    return '$phone ஆக இணைக்கப்பட்டுள்ளது';
  }

  @override
  String get settingsBackupSubtitle =>
      'காப்பீடுகளை காப்புப் பிரதி எடுத்து மற்றொரு சாதனத்தில் பயன்படுத்தவும்';

  @override
  String get settingsAppearance => 'தோற்றம்';

  @override
  String settingsThemeMode(Object mode) {
    return '$mode';
  }

  @override
  String get settingsNotifications => 'அறிவிப்புகள்';

  @override
  String get settingsNotificationsSubtitle =>
      'புதுப்பிப்பு நினைவூட்டல்கள் மற்றும் அமைதி நேரம்';

  @override
  String get settingsSmartSuggestions => 'கவரேஜ் நுண்ணறிவுகள்';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'விரைவில்: உங்கள் காப்பீட்டு விவரங்களின் அடிப்படையில் கவரேஜ் வழிகாட்டுதல்';

  @override
  String get settingsServiceEndpoint => 'சேவை முனை';

  @override
  String get settingsClearDataTitle => 'அனைத்து உள்ளூர் தரவையும் அழிக்கவா?';

  @override
  String get settingsClearDataAction => 'உள்ளூர் தரவை அழி';

  @override
  String get settingsClearDataContent =>
      'இது இந்தச் சாதனத்திலிருந்து அனைத்து உள்ளூரில் சேமிக்கப்பட்ட ஆவணங்கள், காப்பீட்டு சுருக்கங்கள், Q&A வரலாறு, குடும்ப உறுப்பினர்கள் மற்றும் அமர்வுத் தரவை நீக்குகிறது. சர்வரில் பதிவேற்றப்பட்ட ஆவணங்கள் பாதிக்கப்படாது. இந்த செயலை இந்தச் சாதனத்திலிருந்து மீளமைக்க முடியாது.';

  @override
  String get settingsClearDataSuccess =>
      'இந்தச் சாதனத்திலிருந்து அனைத்து உள்ளூர் தரவும் அழிக்கப்பட்டது.';

  @override
  String get settingsClearDataSubtitle =>
      'ஆவணங்கள், சுருக்கங்கள், வரலாறு மற்றும் குடும்ப உறுப்பினர்களை அகற்றவும்';

  @override
  String get settingsNoConsentRecords => 'ஒப்புதல் பதிவுகள் எதுவும் இல்லை';

  @override
  String get settingsConsentRecorded =>
      'உங்கள் முதல் காப்பீட்டைப் பதிவேற்றும்போது ஒப்புதல் பதிவு செய்யப்படுகிறது';

  @override
  String get settingsConsentPolicyProcessing => 'காப்பீட்டு செயலாக்கம்';

  @override
  String get settingsConsentAnalytics => 'பயன்பாட்டு பகுப்பாய்வு';

  @override
  String get settingsConsentLeadCapture => 'தொடர்பு பதிவு';

  @override
  String get settingsConsentTermsAccepted => 'விதிமுறைகள் ஏற்கப்பட்டன';

  @override
  String settingsConsentGranted(Object date, Object version) {
    return '$date அன்று வழங்கப்பட்டது • v$version';
  }

  @override
  String settingsConsentRevoked(Object date) {
    return '$date அன்று ரத்துசெய்யப்பட்டது';
  }

  @override
  String get settingsConsentActive => 'செயலில் உள்ளது';

  @override
  String get settingsConsentRevokedLabel => 'ரத்துசெய்யப்பட்டது';

  @override
  String get settingsLanguage => 'மொழி';

  @override
  String get settingsLanguageSubtitle =>
      'உங்கள் விருப்பமான பயன்பாட்டு மொழியைத் தேர்வுசெய்க';

  @override
  String get profileTitle => 'சுயவிவரம்';

  @override
  String get profileDefaultHeader => 'உங்கள் CoverWise சுயவிவரம்';

  @override
  String get profileLinkedHeader => 'உங்கள் சாதனங்களில் இணைக்கப்பட்டு தயார்.';

  @override
  String get profileUnlinkedHeader =>
      'உங்கள் காப்பீட்டு பணியிடம் தற்போது இந்தச் சாதனத்தில் மட்டுமே உள்ளது.';

  @override
  String get profileCreateAccount => 'பாதுகாப்பான கணக்கை உருவாக்கு';

  @override
  String get profileRestoreWorkspace =>
      'இந்த காப்பீட்டு பணியிடத்தை சாதனங்களுக்கிடையே மீட்டெடு';

  @override
  String get profileSignedInAccount => 'உள்நுழைந்த கணக்கு';

  @override
  String get profileWorkspaceLinked =>
      'பணியிடம் உங்கள் கணக்குடன் இணைக்கப்பட்டுள்ளது';

  @override
  String get profilePhoneNumber => 'தொலைபேசி எண்';

  @override
  String get profileNotLinked => 'இணைக்கப்படவில்லை';

  @override
  String get profileSecureSession => 'பாதுகாப்பான அமர்வு';

  @override
  String get profileAccountSessionActive =>
      'இந்தச் சாதனத்தில் கணக்கு அமர்வு செயலில் உள்ளது';

  @override
  String get profileAnonymousSessionActive =>
      'இந்தச் சாதனத்தில் அநாமதேய அமர்வு செயலில் உள்ளது';

  @override
  String get profileAppSection => 'பயன்பாடு';

  @override
  String get profileFamilySection => 'குடும்பம்';

  @override
  String get profilePrivacySection => 'தனியுரிமை';

  @override
  String get profileDeviceFirstStorage => 'சாதன-முதல் சேமிப்பு';

  @override
  String get profileDeviceFirstSubtitle =>
      'இந்தச் சாதனம் பாதுகாக்கப்பட்ட உள்ளூர் இடைநிலை சேமிப்பை வைத்திருக்கிறது; ஒத்திசைவுக்காக கணக்குத் தரவும் பாதுகாப்பாக சேமிக்கப்படலாம்.';

  @override
  String get profileDeleteAccount => 'கணக்கை நீக்கு';

  @override
  String get profileDeleteAccountSubtitle =>
      'கணக்கு மற்றும் அனைத்து சர்வர் தரவையும் நிரந்தரமாக அகற்று';

  @override
  String get profileCreateAccountFirst =>
      'அதை நீக்க முதலில் ஒரு கணக்கை உருவாக்கவும்';

  @override
  String get profileFooter =>
      'CoverWise உங்கள் காப்பீடுகளைப் புரிந்துகொள்ள உதவுகிறது. இது காப்பீட்டை விற்பதில்லை.';

  @override
  String get profileDeleteConfirmTitle => 'கணக்கை நிரந்தரமாக நீக்கவா?';

  @override
  String get profileDeleteConfirmHeader => 'இது நிரந்தரமாக நீக்கும்:';

  @override
  String get profileDeleteItemAccount => '• உங்கள் CoverWise கணக்கு';

  @override
  String get profileDeleteItemDocs =>
      '• எங்கள் சர்வர்களில் பதிவேற்றப்பட்ட அனைத்து காப்பீட்டு ஆவணங்கள்';

  @override
  String get profileDeleteItemSummaries =>
      '• அனைத்து காப்பீட்டு சுருக்கங்கள் மற்றும் உட்பொதிப்புகள்';

  @override
  String get profileDeleteItemHistory => '• சர்வரில் உங்கள் Q&A வரலாறு';

  @override
  String get profileDeleteWarning =>
      'இந்தச் செயலை இந்தச் சாதனத்திலிருந்து மீளமைக்க முடியாது. இந்தச் சாதனத்தில் உள்ள உள்ளூர் தரவு அமைப்புகள் → உள்ளூர் தரவை அழி வழியாக தனித்தனியாக அழிக்கப்படும்.';

  @override
  String get profileDeleteEverything => 'அனைத்தையும் நீக்கு';

  @override
  String get profileDeleteTypeTitle => 'உறுதிப்படுத்த DELETE என தட்டச்சு செய்க';

  @override
  String get profileDeleteTypeWarning =>
      'இதுதான் உங்கள் கடைசி வாய்ப்பு. அனைத்து தரவும் நிரந்தரமாக அழிக்கப்படும்.';

  @override
  String get profileDeleteTypeHint => 'DELETE என தட்டச்சு செய்க';

  @override
  String get profileDeletePermanently => 'நிரந்தரமாக நீக்கு';

  @override
  String get profileDeletingAccount => 'கணக்கை நீக்குகிறது...';

  @override
  String profileDeleteComplete(Object docs, Object files) {
    return 'கணக்கு நீக்கப்பட்டது. $docs ஆவண(ங்கள்) மற்றும் $files சேமிப்புக் கோப்பு(கள்) அகற்றப்பட்டன.';
  }

  @override
  String profileDeletePartial(Object failed) {
    return 'கணக்கு நீக்கம் பகுதியளவு முடிந்தது. தோல்வியடைந்த நிலைகள்: $failed. சர்வர் நீக்கம் முழுமையடைந்ததாகக் கருத வேண்டாம்.';
  }

  @override
  String profileDeleteRequested(Object status) {
    return 'கணக்கு நீக்கம் கோரப்பட்டது. நிலை: $status.';
  }

  @override
  String get profileDeletionStatusTitle => 'கணக்கு நீக்க நிலை';

  @override
  String get profileDeletionStatusPending =>
      'நீக்கம் வரிசையில் உள்ளது. சர்வர் அழிப்பு சரிபார்க்கப்படும் வரை உங்கள் கணக்கு செயலில் இருக்கும்.';

  @override
  String get profileDeletionStatusRunning =>
      'நீக்கம் செயலாக்கப்படுகிறது. அழிப்பு இயங்கும்போது புதிய கணக்கு எழுத்துகள் இடைநிறுத்தப்படும்.';

  @override
  String get profileDeletionStatusFailed =>
      'கடைசி நீக்க முயற்சிக்கு கவனம் தேவை.';

  @override
  String get profileDeletionStatusRefresh => 'நிலையைப் புதுப்பி';

  @override
  String get profileDeletionStatusUnavailable =>
      'நீக்க நிலை தற்காலிகமாக கிடைக்கவில்லை.';

  @override
  String profileInFlightWarning(Object count) {
    return '$count ஆவண(ங்கள்) இன்னும் செயலாக்கத்தில் உள்ளன. உங்கள் கணக்கை நீக்குவதற்கு முன் செயலாக்கம் முடியும் வரை காத்திருக்கவும்.';
  }

  @override
  String get upgradeTitle => 'உங்கள் திட்டத்தைத் தேர்வுசெய்க';

  @override
  String get upgradeBillingUnavailable =>
      'பில்லிங் இன்னும் கிடைக்கவில்லை. தயவுசெய்து பின்னர் மீண்டும் முயற்சிக்கவும்.';

  @override
  String get upgradeCouldNotOpenSettings =>
      'சந்தா அமைப்புகளைத் திறக்க முடியவில்லை';

  @override
  String upgradeSuccess(Object plan) {
    return '$plan க்கு மேம்படுத்தப்பட்டது! உங்கள் புதிய அம்சங்களை அனுபவிக்கவும்.';
  }

  @override
  String get upgradePurchaseCancelled => 'கொள்முதல் ரத்துசெய்யப்பட்டது.';

  @override
  String get upgradeMonthly => 'மாதாந்திர';

  @override
  String get upgradeAnnual => 'ஆண்டு';

  @override
  String get upgradeSaveUpTo => '44% வரை சேமிக்கவும்';

  @override
  String get upgradeCurrentPlan => 'தற்போதைய திட்டம்';

  @override
  String get upgradeFreeForever => 'என்றும் இலவசம்';

  @override
  String upgradeTo(Object plan) {
    return '$plan திட்டத்திற்கு மேம்படுத்து';
  }

  @override
  String get upgradeComparePlans => 'திட்டங்களை ஒப்பிடு';

  @override
  String get upgradeQuestions => 'கேள்விகள்';

  @override
  String get upgradeFaqSwitch => 'நான் திட்டங்களை மாற்ற முடியுமா?';

  @override
  String get upgradeFaqSwitchAnswer =>
      'உங்கள் ஆப் ஸ்டோர் அல்லது பிளே ஸ்டோர் சந்தா அமைப்புகள் மூலம் திட்ட மாற்றங்களை நிர்வகிக்கலாம்.';

  @override
  String get upgradeFaqPacks => 'எனது Q&A தொகுப்புகள் என்னாகும்?';

  @override
  String get upgradeFaqPacksAnswer =>
      'தொகுப்பு கேள்விகள் செயலில் இருக்கும் மற்றும் உங்கள் மாதாந்திர ஒதுக்கீடு தீர்ந்தபின் பயன்படுத்தப்படும்.';

  @override
  String get upgradeFaqCancel => 'நான் எப்படி ரத்துசெய்வது?';

  @override
  String get upgradeFaqCancelAnswer =>
      'உங்கள் ஆப் ஸ்டோர் அல்லது பிளே ஸ்டோர் சந்தா அமைப்புகளிலிருந்து எப்போது வேண்டுமானாலும் ரத்துசெய்யவும்.';

  @override
  String get upgradeAccessUntil => 'இது வரை அணுகல்';

  @override
  String get upgradePolicies => 'காப்பீடுகள்';

  @override
  String get upgradeQaPerMonth => 'மாதத்திற்கு Q&A';

  @override
  String get upgradeComparePolicies => 'காப்பீடுகளை ஒப்பிடு';

  @override
  String get upgradeFamilyView => 'குடும்பக் காட்சி';

  @override
  String get upgradeCloudSync => 'கிளவுட் ஒத்திசைவு';

  @override
  String get upgradeEmergency => 'அவசரம்';

  @override
  String get upgradeAnnualReview => 'ஆண்டு மதிப்பாய்வு';

  @override
  String get upgradeAdvancedSearch => 'மேம்பட்ட தேடல்';

  @override
  String accountTitle(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'கணக்கை உருவாக்கு',
        'other': 'உள்நுழைக',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountHeaderTitle =>
      'உங்கள் காப்பீட்டு பணியிடத்தைப் பாதுகாக்கவும்';

  @override
  String get accountHeaderSubtitle =>
      'ஒரு கணக்கு மற்றொரு சாதனத்தில் உங்கள் CoverWise பணியிடத்தை மீட்டெடுக்க அனுமதிக்கிறது.';

  @override
  String get accountNameLabel => 'பெயர் (விருப்ப)';

  @override
  String get accountEmailLabel => 'மின்னஞ்சல்';

  @override
  String get accountPasswordLabel => 'கடவுச்சொல்';

  @override
  String get accountResendBanner =>
      'உங்கள் மின்னஞ்சல் இன்னும் உறுதிப்படுத்தப்படவில்லை. உங்கள் இன்பாக்ஸைச் சரிபார்க்கவும் அல்லது மீண்டும் அனுப்பவும்.';

  @override
  String get accountResend => 'மீண்டும் அனுப்பு';

  @override
  String get accountForgotPassword => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get accountResendVerification =>
      'சரிபார்ப்பு மின்னஞ்சலை மீண்டும் அனுப்பு';

  @override
  String accountSwitchToSignIn(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழைக',
        'other': 'CoverWise க்கு புதியவரா? கணக்கை உருவாக்கு',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountGoogleSignIn => 'Google உடன் தொடரவும்';

  @override
  String get accountAuthNotConfigured =>
      'இந்த பில்டிற்கு கணக்கு அங்கீகாரம் கட்டமைக்கப்படவில்லை.';

  @override
  String get accountEnterEmail => 'உங்கள் மின்னஞ்சல் முகவரியை உள்ளிடவும்.';

  @override
  String get accountPasswordTooShort =>
      'கடவுச்சொல் குறைந்தது 8 எழுத்துகளைக் கொண்டிருக்க வேண்டும்.';

  @override
  String get accountInvalidEmail => 'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்.';

  @override
  String get accountCheckEmail =>
      'கணக்கை உறுதிப்படுத்த உங்கள் மின்னஞ்சலைச் சரிபார்த்து, பின் உள்நுழைக.';

  @override
  String get accountIncorrectCredentials =>
      'தவறான மின்னஞ்சல் அல்லது கடவுச்சொல். தயவுசெய்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get accountAlreadyRegistered =>
      'இந்த மின்னஞ்சலுடன் கணக்கு ஏற்கனவே உள்ளது. உள்நுழைய முயற்சிக்கவும்.';

  @override
  String get accountPasswordRequirements =>
      'கடவுச்சொல் தேவைகளைப் பூர்த்தி செய்யவில்லை. குறைந்தது 8 எழுத்துகளைப் பயன்படுத்தவும்.';

  @override
  String accountCouldNotAction(String action) {
    String _temp0 = intl.Intl.selectLogic(
      action,
      {
        'true': 'உருவாக்க',
        'other': 'உள்நுழைய',
      },
    );
    return 'கணக்கை $_temp0 முடியவில்லை.';
  }

  @override
  String get accountEnterEmailFirst =>
      'முதலில் மேலே உங்கள் மின்னஞ்சலை உள்ளிட்டு, பின் கடவுச்சொல் மறந்துவிட்டதா என்பதைத் தட்டவும்.';

  @override
  String get accountResetEmailSent =>
      'கடவுச்சொல் மீட்டமைப்பு மின்னஞ்சல் அனுப்பப்பட்டது. உங்கள் இன்பாக்ஸைச் சரிபார்க்கவும்.';

  @override
  String get accountCouldNotReset =>
      'மீட்டமைப்பு மின்னஞ்சலை அனுப்ப முடியவில்லை. உங்கள் மின்னஞ்சலைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get accountEnterEmailResend =>
      'முதலில் மேலே உங்கள் மின்னஞ்சலை உள்ளிட்டு, பின் சரிபார்ப்பை மீண்டும் அனுப்பு என்பதைத் தட்டவும்.';

  @override
  String get accountVerificationSent =>
      'சரிபார்ப்பு மின்னஞ்சல் அனுப்பப்பட்டது. உங்கள் இன்பாக்ஸைச் சரிபார்க்கவும்.';

  @override
  String get accountCouldNotVerify =>
      'சரிபார்ப்பு மின்னஞ்சலை அனுப்ப முடியவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.';

  @override
  String get accountCouldNotGoogle =>
      'Google மூலம் உள்நுழைய முடியவில்லை. தயவுசெய்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get notifTitle => 'புதுப்பிப்பு நினைவூட்டல்கள்';

  @override
  String get notifHeaderTitle => 'புதுப்பிப்புகளுக்கு முன்னதாக இருங்கள்';

  @override
  String get notifHeaderSubtitle =>
      'இந்தச் சாதனம் உங்களுக்கு நினைவூட்ட வேண்டிய நேரத்தைத் தேர்வுசெய்க. அறிவிப்புகள் நினைவூட்டல்கள் மட்டுமே, காப்பீட்டு நிறுவன புதுப்பிப்பு அறிவிப்புகள் அல்ல.';

  @override
  String get notifMasterToggle => 'புதுப்பிப்பு நினைவூட்டல்கள்';

  @override
  String get notifEnabledSubtitle => 'இந்தச் சாதனத்தில் இயக்கப்பட்டது';

  @override
  String get notifDisabledSubtitle => 'முடக்கப்பட்டது';

  @override
  String get notifSectionRemindMe => 'காலாவதிக்கு முன் நினைவூட்டு';

  @override
  String get notifSectionRemindMeDescription =>
      'உங்கள் காப்பீடு காலாவதியாவதற்கு எத்தனை நாட்களுக்கு முன் நினைவூட்டலைப் பெற விரும்புகிறீர்கள் என்பதைத் தேர்வுசெய்க.';

  @override
  String get notifNoReminderTimes =>
      'நினைவூட்டல் நேரங்கள் எதுவும் தேர்ந்தெடுக்கப்படவில்லை.';

  @override
  String get notifSectionQuietHours => 'அமைதி நேரம்';

  @override
  String get notifSectionQuietHoursDescription =>
      'இந்த நேரங்களில் அறிவிப்புகள் எதுவும் இல்லை.';

  @override
  String get notifStartTime => 'தொடக்க நேரம்';

  @override
  String get notifEndTime => 'முடிவு நேரம்';

  @override
  String get notifSectionPerPolicy => 'தனித்தனி காப்பீட்டு நினைவூட்டல்கள்';

  @override
  String get notifSectionPerPolicyDescription =>
      'தனிப்பட்ட காப்பீடுகளுக்கான நினைவூட்டல்களை இயக்கு/முடக்கு.';

  @override
  String get notifPreferencesSaved => 'விருப்பத்தேர்வுகள் சேமிக்கப்பட்டன';

  @override
  String get docsTitle => 'ஆவணங்கள்';

  @override
  String docsSlotsUsed(Object count) {
    return '$count இலவச காப்பீட்டு இடங்களில் பயன்படுத்தப்பட்டது';
  }

  @override
  String get docsTypeChanged => 'வகை மாற்றப்பட்டது';

  @override
  String get docsRemovedLocal =>
      'இந்தச் சாதனத்திலிருந்து அகற்றப்பட்டது. சர்வர் நகல் பாதிக்கப்படவில்லை.';

  @override
  String get docsReplaceSuccess => 'ஆவணம் வெற்றிகரமாக மாற்றப்பட்டது';

  @override
  String get docsPreview => 'முன்னோட்டம்';

  @override
  String get docsDownloadSource => 'மூலத்தைப் பதிவிறக்கு';

  @override
  String get docsChangeType => 'வகையை மாற்று';

  @override
  String get docsAskQuestions => 'கேள்விகள் கேளுங்கள்';

  @override
  String get docsReadingPolicy => 'காப்பீட்டைப் படிக்கிறது';

  @override
  String get docsUploadRequired => 'சர்வரில் பதிவேற்றம் தேவை';

  @override
  String get docsRetryUpload => 'மீண்டும் பதிவேற்ற முயற்சி';

  @override
  String get docsNeedsAttention => 'கவனம் தேவை';

  @override
  String get docsReadyForQuestions => 'கேள்விகளுக்குத் தயார்';

  @override
  String get docsSaved => 'சேமிக்கப்பட்டது';

  @override
  String get docsRefreshingTypes => 'ஆவண வகைகள் புதுப்பிக்கப்படுகின்றன...';

  @override
  String get docsTypesRefreshed =>
      'ஆவண வகைகள் வெற்றிகரமாகப் புதுப்பிக்கப்பட்டன!';

  @override
  String get docsReplace => 'மாற்று';

  @override
  String get docsRemoveFromDevice => 'இந்தச் சாதனத்திலிருந்து அகற்று';

  @override
  String get docsRemoveFromDeviceTitle => 'இந்தச் சாதனத்திலிருந்து அகற்றவா?';

  @override
  String get docsDeletePolicy => 'காப்பீட்டை நீக்கு';

  @override
  String get docsDeletePolicyTitle => 'காப்பீட்டை நீக்கவா?';

  @override
  String docsDeletePolicyContent(Object filename) {
    return 'இது \"$filename\" ஐ CoverWise மற்றும் இந்தச் சாதனத்திலிருந்து நிரந்தரமாக நீக்கும்.';
  }

  @override
  String get docsDeleted => 'காப்பீடு நீக்கப்பட்டது';

  @override
  String get docsReplaceDocumentTitle => 'ஆவணத்தை மாற்றவா?';

  @override
  String get docsReplaceDocument => 'ஆவணத்தை மாற்று';

  @override
  String get docsCurrentDocument => 'தற்போதைய ஆவணம்';

  @override
  String get docsSelectReplacement => 'மாற்றுக் கோப்பைத் தேர்ந்தெடு';

  @override
  String docsReplaceWillDelete(Object filename) {
    return 'இது \"$filename\" ஐ நீக்கிவிட்டு புதிய கோப்புடன் மாற்றும்.';
  }

  @override
  String get docsReplaceAnalysisLost =>
      'பழைய ஆவணத்தின் பகுப்பாய்வு இழக்கப்படும். புதிய ஆவணம் புதிதாக செயலாக்கப்படும்.';

  @override
  String docsUploadedDate(Object date) {
    return 'பதிவேற்றம்: $date';
  }

  @override
  String get docsClearReplacement => 'மாற்றுக் கோப்பை அழி';

  @override
  String get docsArchive => 'காப்பகம்';

  @override
  String get docsArchived => 'காப்பகப்படுத்தப்பட்டது';

  @override
  String get docsRestore => 'மீட்டெடு';

  @override
  String get docsRestored => 'காப்பீடு மீட்டெடுக்கப்பட்டது';

  @override
  String get docsArchivedSuccess => 'காப்பீடு காப்பகப்படுத்தப்பட்டது';

  @override
  String get docsShowArchived => 'காப்பகப்படுத்தப்பட்டவற்றைக் காண்பி';

  @override
  String get docsHideArchived => 'காப்பகப்படுத்தப்பட்டவற்றை மறை';

  @override
  String get docsArchiveConfirmTitle => 'காப்பீட்டை காப்பகப்படுத்தவா?';

  @override
  String docsArchiveConfirmContent(Object filename) {
    return '\"$filename\" உங்கள் செயலில் உள்ள காப்பீட்டுப் பட்டியலிலிருந்து மறைக்கப்படும். எப்போது வேண்டுமானாலும் காப்பகத்திலிருந்து மீட்டெடுக்கலாம்.';
  }

  @override
  String get docsDeletePermanentWarning =>
      'இது காப்பீட்டை CoverWise மற்றும் இந்தச் சாதனம் இரண்டிலிருந்தும் நிரந்தரமாக நீக்குகிறது. அதற்குப் பதிலாக காப்பகப்படுத்துவதைக் கவனியுங்கள்.';

  @override
  String get docsLimitWarning =>
      'உங்கள் இலவச சேமிப்பக வரம்பை நெருங்குகிறீர்கள். இடத்தைக் காலியாக்க பழைய காப்பீடுகளை காப்பகப்படுத்தவும்.';

  @override
  String docsLimitCountdown(Object limit, Object remaining, Object used) {
    return '$limit இல் $used இடங்கள் பயன்படுத்தப்பட்டன — $remaining மீதம்';
  }

  @override
  String docsLimitRemaining(Object remaining) {
    return '$remaining இலவச இடம்(ங்கள்) மீதம்';
  }

  @override
  String get docsSortLabel => 'வரிசைப்படுத்து';

  @override
  String get docsFilterLabel => 'வடிகட்டு';

  @override
  String get docsSortDateNewest => 'புதியது முதலில்';

  @override
  String get docsSortDateOldest => 'பழையது முதலில்';

  @override
  String get docsSortNameAZ => 'பெயர் A–Z';

  @override
  String get docsSortNameZA => 'பெயர் Z–A';

  @override
  String get docsSortType => 'வகை வாரியாக';

  @override
  String get docsFilterAll => 'அனைத்து வகைகள்';

  @override
  String docsFilterResultCount(Object count, Object total) {
    return '$total இல் $count காப்பீடுகள்';
  }

  @override
  String get docsRenameTitle => 'காப்பீட்டை மறுபெயரிடு';

  @override
  String get docsRenameHint => 'புதிய பெயரை உள்ளிடவும்';

  @override
  String get docsRenameSave => 'சேமி';

  @override
  String get docsRenameSuccess => 'காப்பீடு மறுபெயரிடப்பட்டது';

  @override
  String get docsRenameEmpty => 'பெயர் காலியாக இருக்க முடியாது';

  @override
  String get tosTitle => 'சேவை விதிமுறைகள்';

  @override
  String get tosCopySuccess =>
      'சேவை விதிமுறைகள் கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டன';

  @override
  String get tosLoadError => 'சேவை விதிமுறைகளை ஏற்ற முடியவில்லை.';

  @override
  String get privacyTitle => 'தனியுரிமைக் கொள்கை';

  @override
  String get privacyCopySuccess =>
      'தனியுரிமைக் கொள்கை கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது';

  @override
  String get privacyLoadError => 'தனியுரிமைக் கொள்கையை ஏற்ற முடியவில்லை.';

  @override
  String get processingReceived => 'பெறப்பட்டது';

  @override
  String get processingProcessing => 'செயலாக்குகிறது';

  @override
  String get processingCategorising => 'வகைப்படுத்துகிறது';

  @override
  String get processingFinishingUp => 'முடித்து வருகிறது';

  @override
  String get processingReceivedDesc => 'உங்கள் காப்பீடு பெறப்பட்டது';

  @override
  String get processingProcessingDesc => 'உரையைப் படித்து பிரித்தெடுக்கிறது';

  @override
  String get processingCategorisingDesc =>
      'காப்பீட்டு வகை மற்றும் நிறுவனத்தை தீர்மானிக்கிறது';

  @override
  String get processingFinishingUpDesc =>
      'உங்கள் காப்பீட்டைத் தேடக்கூடியதாக மாற்றுகிறது';

  @override
  String get onboardSubtitle =>
      'இணையத்திலிருந்து வரும் பொதுவான ஆலோசனை அல்ல - உங்கள் உண்மையான காப்பீட்டின் அடிப்படையில் தெளிவான பதில்களைப் பெறுங்கள்.';

  @override
  String get onboardNoDataStored =>
      'உங்கள் சம்மதமின்றி எந்த காப்பீட்டுத் தரவும் சேமிக்கப்படாது அல்லது பகிரப்படாது.';

  @override
  String get onboardTermsAcceptance =>
      'நான் தனியுரிமைக் கொள்கை மற்றும் சேவை விதிமுறைகளைப் படித்து ஏற்றுக்கொண்டேன்.';

  @override
  String get emergencyTitle => 'அவசரம்';

  @override
  String get emergencyHelpAtGlance => 'ஒரு பார்வையில் உதவி';

  @override
  String get dashboardQuickActions => 'விரைவுச் செயல்கள்';

  @override
  String get dashboardEmergency => 'அவசரம்';

  @override
  String get dashboardAddPolicy => 'காப்பீட்டுக் கோப்பைச் சேர்';

  @override
  String get searchTitle => 'தேடு';

  @override
  String get searchHint => 'எல்லா காப்பீடுகளிலும் தேடுங்கள்...';

  @override
  String get searchNoResults => 'முடிவுகள் எதுவும் இல்லை';

  @override
  String get coverageGapTitle => 'கவரேஜ் மதிப்பாய்வு';

  @override
  String get coverageGapEmpty =>
      'இதுவரை கிடைக்கக்கூடிய காப்பீட்டு உரையிலிருந்து எந்த சாத்தியமான கவரேஜ் கேள்விகளும் குறிக்கப்படவில்லை';

  @override
  String get literacyTitle => 'காப்பீட்டு சொற்களஞ்சியம்';

  @override
  String get literacySearchHint => 'விதிமுறைகளைத் தேடு...';

  @override
  String get docTypePickerTitle => 'ஆவண வகையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get fileTypeSupported => 'ஆதரிக்கப்படும் கோப்பு வகைகள்';

  @override
  String get fileTypePdf => 'PDF ஆவணங்கள்';

  @override
  String get fileTypeImage => 'படங்கள் (JPEG, PNG)';

  @override
  String get fileTypeMaxSize => 'அதிகபட்ச கோப்பு அளவு: 20 MB';

  @override
  String get fileTypeUnsupported =>
      'இந்த கோப்பு வகை ஆதரிக்கப்படவில்லை. தயவுசெய்து PDF அல்லது படத்தைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get whatIfTitle => 'What-If கால்குலேட்டர்';

  @override
  String get whatIfDescription =>
      'வெவ்வேறு கவரேஜ் விருப்பங்கள் உங்கள் மதிப்பிடப்பட்ட செலவுகளை எவ்வாறு பாதிக்கின்றன என்பதை ஆராயுங்கள்.';

  @override
  String get batchPickMultiple => 'பல கோப்புகளைத் தேர்ந்தெடு';

  @override
  String batchUploadingPendingCount(Object count) {
    return '$count கோப்புகள் பதிவேற்றப்படுகின்றன...';
  }

  @override
  String batchUploadingProgress(Object done, Object total) {
    return '$total இல் $done பதிவேற்றப்பட்டது';
  }

  @override
  String get batchCompleted => 'அனைத்து கோப்புகளும் பதிவேற்றப்பட்டன';

  @override
  String batchCompletedCount(Object count) {
    return '$count கோப்புகள் வெற்றிகரமாகப் பதிவேற்றப்பட்டன';
  }

  @override
  String get batchSomeFailed => 'சில பதிவேற்றங்கள் தோல்வியடைந்தன';

  @override
  String batchFailedCount(Object failed, Object total) {
    return '$total இல் $failed கோப்புகள் தோல்வியடைந்தன';
  }

  @override
  String batchFileTooLargeMB(Object maxMB) {
    return 'இந்த கோப்பு $maxMB MB வரம்பை மீறுகிறது மற்றும் தவிர்க்கப்படும்';
  }

  @override
  String get batchFileUnsupported =>
      'ஆதரிக்கப்படாத கோப்பு வகை — தவிர்க்கப்பட்டது';

  @override
  String get batchDuplicateSkipped => 'நகல் — தவிர்க்கப்பட்டது';

  @override
  String get batchRetryFailed =>
      'தோல்வியடைந்த பதிவேற்றங்களை மீண்டும் முயற்சி செய்';

  @override
  String get batchDone => 'முடிந்தது';

  @override
  String get batchAddMore => 'மேலும் கோப்புகளைச் சேர்';

  @override
  String get batchSelectAll => 'அனைத்தையும் தேர்ந்தெடு';

  @override
  String get familyVisTitle => 'கவரேஜ் வரைபடம்';

  @override
  String get familyVisHeader =>
      'காப்பீட்டில் பட்டியலிடப்பட்ட குடும்ப உறுப்பினர்கள்';

  @override
  String get familyVisSubtitle =>
      'ஒவ்வொரு காப்பீட்டிலும் பட்டியலிடப்பட்ட குடும்ப உறுப்பினர்களை ஒப்பிடுங்கள்; உங்கள் காப்பீட்டு நிறுவனத்துடன் கவரேஜை சரிபார்க்கவும்.';

  @override
  String get familyVisMembers => 'குடும்ப உறுப்பினர்கள்';

  @override
  String get familyVisPolicies => 'காப்பீடுகள்';

  @override
  String get familyVisEmptyTitle => 'இதுவரை கவரேஜ் தரவு இல்லை';

  @override
  String get familyVisEmptySubtitle =>
      'உங்கள் காப்பீட்டு ஆவணங்களில் பட்டியலிடப்பட்ட பெயர்களை ஒப்பிட காப்பீடுகளைப் பதிவேற்றவும் மற்றும் குடும்ப உறுப்பினர்களைச் சேர்க்கவும்.';

  @override
  String familyVisNoPolicies(Object name) {
    return '$name ஐ பட்டியலிடும் காப்பீடுகள் இதுவரை இல்லை.';
  }

  @override
  String get familyVisSeeMap => 'காப்பீட்டு உறுப்பினர் வரைபடத்தைப் பார்';

  @override
  String get coverageShareSummary => 'Share summary';

  @override
  String get coverageShareSubject => 'CoverWise policy coverage summary';

  @override
  String get coverageShareError => 'Could not open sharing options';
}
