// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsGenHi extends AppLocalizationsGen {
  AppLocalizationsGenHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'CoverWise';

  @override
  String get commonShowLess => 'कम दिखाएँ';

  @override
  String get commonShowMore => 'और दिखाएँ';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सहेजें';

  @override
  String get remove => 'हटाएँ';

  @override
  String get add => 'जोड़ें';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get enable => 'सक्षम करें';

  @override
  String get disable => 'अक्षम करें';

  @override
  String get version => 'संस्करण';

  @override
  String get upgrade => 'अपग्रेड करें';

  @override
  String get manage => 'प्रबंधित करें';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get signIn => 'साइन इन';

  @override
  String get createAccount => 'खाता बनाएँ';

  @override
  String get buy => 'खरीदें';

  @override
  String get startAsking => 'पूछना शुरू करें';

  @override
  String get getMore => 'और पाएँ';

  @override
  String get getPacks => 'पैक पाएँ';

  @override
  String get viewPolicy => 'पॉलिसी देखें';

  @override
  String policyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पॉलिसियाँ',
      one: '1 पॉलिसी',
    );
    return '$_temp0';
  }

  @override
  String resultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count परिणाम',
      one: '1 परिणाम',
    );
    return '$_temp0';
  }

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String expiresInDays(num count) {
    return '$count दिन में समाप्त हो रही है';
  }

  @override
  String daysLeft(Object days) {
    return '$days दिन शेष';
  }

  @override
  String daysBefore(Object days) {
    return '$days दिन पहले';
  }

  @override
  String get qaScreenTitle => 'CoverWise से पूछें';

  @override
  String get qaTabSuggested => 'सुझाव';

  @override
  String get qaTabYourQuestion => 'आपका प्रश्न';

  @override
  String get qaTabHistory => 'इतिहास';

  @override
  String get qaNoQuestionsRemaining => 'कोई प्रश्न शेष नहीं';

  @override
  String qaQuestionsLeft(Object remaining) {
    return '$remaining प्रश्न शेष';
  }

  @override
  String qaMonthlyPlusPack(Object monthly, Object pack) {
    return '$monthly मासिक + $pack पैक';
  }

  @override
  String qaPackQuestions(Object count, Object packs) {
    return '$count प्रश्न $packs पैक में';
  }

  @override
  String qaMonthlyPlan(Object remaining) {
    return 'इस महीने $remaining प्रश्न शेष';
  }

  @override
  String get qaAskAbout => 'के बारे में पूछें';

  @override
  String get qaQuestionSource => 'प्रश्न स्रोत';

  @override
  String qaAllDocuments(Object count) {
    return 'सभी दस्तावेज़ ($count)';
  }

  @override
  String get qaSingleDocument => 'एकल दस्तावेज़';

  @override
  String get qaNoDocumentSelected => 'कोई दस्तावेज़ चयनित नहीं';

  @override
  String get qaSearchAllPolicies => 'अपनी सभी अपलोड की गई पॉलिसियों में खोजें';

  @override
  String get qaAskAboutDescription =>
      'अपनी पॉलिसी में कवर, बहिष्करण, तिथियाँ या शब्दों के बारे में पूछें।';

  @override
  String get qaHintText => 'जैसे, प्रभावी तिथि क्या है?';

  @override
  String get qaClearQuestion => 'प्रश्न साफ़ करें';

  @override
  String get qaNoHistoryYet => 'अभी तक कोई प्रश्न इतिहास नहीं';

  @override
  String get qaSearchHistory => 'इतिहास खोजें...';

  @override
  String qaNoMatchesFor(Object query) {
    return '\"$query\" के लिए कोई मेल नहीं';
  }

  @override
  String get qaToday => 'आज';

  @override
  String get qaYesterday => 'कल';

  @override
  String get qaThisWeek => 'इस सप्ताह';

  @override
  String get qaEarlier => 'पहले';

  @override
  String get qaSourcesLabel => 'स्रोत';

  @override
  String get qaFollowUpLabel => 'आप यह भी पूछ सकते हैं:';

  @override
  String get qaHelpfulAnswer => 'उपयोगी उत्तर';

  @override
  String get qaUnhelpfulAnswer => 'अनुपयोगी उत्तर';

  @override
  String get qaCopyAnswer => 'उत्तर कॉपी करें';

  @override
  String get qaAnswerCopied => 'उत्तर कॉपी किया गया';

  @override
  String get qaShareAnswer => 'उत्तर साझा करें';

  @override
  String get qaAnswerCopiedToClipboard => 'उत्तर क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get qaEvidence => 'साक्ष्य';

  @override
  String get qaCitationUnknown => 'अज्ञात';

  @override
  String qaCitationSource(Object index) {
    return 'स्रोत $index';
  }

  @override
  String qaCitationSourcePage(Object index, Object page) {
    return 'स्रोत $index • पृष्ठ $page';
  }

  @override
  String get qaPolicyDoesNotEstablish => 'पॉलिसी क्या स्थापित नहीं करती';

  @override
  String qaAnswerReadyFor(Object question) {
    return '$question के लिए उत्तर तैयार';
  }

  @override
  String qaCouldNotGetAnswer(Object error) {
    return 'उत्तर नहीं मिल सका। $error';
  }

  @override
  String get qaFallbackAnswer =>
      'क्षमा करें, यह काम नहीं किया। कृपया पुनः प्रयास करें।';

  @override
  String get qaPolicySource => 'पॉलिसी स्रोत';

  @override
  String get qaViewSource => 'स्रोत देखें';

  @override
  String get qaViewSourcePage => 'पृष्ठ पर देखें';

  @override
  String get qaNoSourceDocument => 'स्रोत दस्तावेज़ उपलब्ध नहीं';

  @override
  String qaSourcePageLabel(Object page) {
    return 'पृष्ठ $page';
  }

  @override
  String get qaRelevanceTooltip => 'यह स्रोत आपके प्रश्न से कितना मेल खाता है';

  @override
  String get confidenceHigh => 'उच्च';

  @override
  String get confidenceMedium => 'मध्यम';

  @override
  String get confidenceLow => 'निम्न';

  @override
  String confidenceLabel(Object level) {
    return '$level विश्वसनीयता';
  }

  @override
  String get qaPacksTitle => 'Q&A पैक';

  @override
  String get qaPacksBuyHeading => 'पैक खरीदें';

  @override
  String get qaPacksSubtitle =>
      'कोई सब्सक्रिप्शन ज़रूरी नहीं। एक बार भुगतान करें, प्रश्न पूछें।';

  @override
  String get qaPacksYourPacks => 'आपके पैक';

  @override
  String get qaPacksPurchasedSuccess =>
      'खरीदारी प्राप्त हुई। सर्वर पुष्टि के बाद प्रश्न दिखाई देंगे।';

  @override
  String get qaPacksHowTheyWork => 'पैक कैसे काम करते हैं';

  @override
  String get qaPacksFaqQ1 => 'प्रश्न कब काटे जाते हैं?';

  @override
  String get qaPacksFaqA1 =>
      'हर बार जब आप प्रश्न सबमिट करते हैं तो एक प्रश्न काटा जाता है। मासिक सब्सक्रिप्शन के प्रश्न पहले उपयोग होते हैं, फिर पैक के प्रश्न।';

  @override
  String get qaPacksFaqQ2 => 'क्या पैक की समय सीमा होती है?';

  @override
  String get qaPacksFaqA2 =>
      'हाँ, पैक खरीदारी से 90 दिनों के लिए वैध होते हैं। समय सीमा के बाद अप्रयुक्त प्रश्न समाप्त हो जाते हैं।';

  @override
  String get qaPacksFaqQ3 => 'क्या मेरे पास कई पैक हो सकते हैं?';

  @override
  String get qaPacksFaqA3 =>
      'हाँ! कई पैक जमा हो सकते हैं। प्रश्न सबसे पहले समाप्त होने वाले पैक से उपयोग होते हैं (FIFO)।';

  @override
  String get qaPacksFaqQ4 =>
      'यदि मैं सब्सक्रिप्शन में अपग्रेड करूँ तो क्या होगा?';

  @override
  String get qaPacksFaqA4 =>
      'आपके पैक के प्रश्न सक्रिय रहते हैं और मासिक सब्सक्रिप्शन कोटा समाप्त होने के बाद उपयोग होते हैं।';

  @override
  String qaPacksQuestionsAvailable(Object count) {
    return '$count प्रश्न उपलब्ध';
  }

  @override
  String qaPacksFromMonthlyPlan(Object count) {
    return '$count मासिक योजना से';
  }

  @override
  String qaPacksFromPacks(Object count) {
    return '$count पैक से';
  }

  @override
  String qaPacksFromMonthlyAndPacks(Object monthly, Object packs) {
    return '$monthly मासिक योजना से · $packs पैक से';
  }

  @override
  String qaPacksQuestionsInPacks(Object count) {
    return '$count पैक से प्रश्न';
  }

  @override
  String get qaPacksBestValue => 'अधिक मासिक प्रश्न';

  @override
  String qaPacksQuestionsEach(Object count, Object price) {
    return '$count प्रश्न · $price प्रत्येक';
  }

  @override
  String qaPacksPackPurchased(Object name) {
    return 'खरीदारी प्राप्त हुई। आपके $name प्रश्न सर्वर पुष्टि के बाद दिखाई देंगे।';
  }

  @override
  String get qaPacksPurchaseCancelled => 'खरीदारी रद्द कर दी गई।';

  @override
  String get qaPacksPurchaseNotCompleted =>
      'खरीदारी पूरी नहीं हुई। कोई प्रश्न नहीं जोड़े गए।';

  @override
  String qaPacksPackRemaining(Object type) {
    return '$type पैक';
  }

  @override
  String qaPacksRemaining(Object remaining, Object total) {
    return '$remaining/$total शेष';
  }

  @override
  String get familyTitle => 'परिवार';

  @override
  String get familyNoMembersYet => 'अभी तक कोई परिवार सदस्य नहीं';

  @override
  String get familyNoMembersFound => 'कोई परिवार सदस्य नहीं मिला';

  @override
  String get familyEmptySubtitle =>
      'परिवार के सदस्यों का स्वतः पता लगाने के लिए बीमा दस्तावेज़ अपलोड करें, या मैन्युअल रूप से जोड़ें।';

  @override
  String get familyAddMember => 'परिवार सदस्य जोड़ें';

  @override
  String get familyLibraryError => 'आपकी पॉलिसी लाइब्रेरी लोड नहीं हो सकी।';

  @override
  String get familyMembersReadError =>
      'आपकी पॉलिसियों से कवर किए गए परिवार के सदस्यों को पढ़ा नहीं जा सका।';

  @override
  String get familyPeopleCovered => 'कवर किए गए लोग';

  @override
  String get familyPeopleSubtitle =>
      'आपकी पॉलिसियों में पाए गए लोगों का स्पष्ट दृश्य, साथ ही आपके द्वारा स्वयं जोड़े गए लोग।';

  @override
  String get familySectionLabel => 'परिवार और बीमित सदस्य';

  @override
  String get familyRemoveTitle => 'परिवार सदस्य हटाएँ?';

  @override
  String familyRemoveContent(Object name) {
    return '$name को परिवार सूची से हटाएँ? इससे आपके पॉलिसी दस्तावेज़ प्रभावित नहीं होंगे।';
  }

  @override
  String get familyAddButton => 'परिवार सदस्य जोड़ें';

  @override
  String get familyManualBadge => 'मैन्युअल';

  @override
  String get familyFromDocumentBadge => 'दस्तावेज़ से';

  @override
  String familyRemoveTooltip(Object name) {
    return '$name हटाएँ';
  }

  @override
  String familyDateOfBirth(Object date) {
    return 'जन्म तिथि: $date';
  }

  @override
  String get familyDetailEditTooltip => 'सदस्य संपादित करें';

  @override
  String get familyDetailHintName => 'पूरा नाम';

  @override
  String get familyDetailMemberUpdated => 'सदस्य अपडेट किया गया';

  @override
  String familyDetailUpdateError(Object error) {
    return 'सदस्य अपडेट नहीं कर सका: $error';
  }

  @override
  String get familyDetailDobLabel => 'जन्म तिथि';

  @override
  String get familyDetailSourceLabel => 'स्रोत';

  @override
  String get familyDetailCoveringPolicies => 'कवर करने वाली पॉलिसियाँ';

  @override
  String get familyDetailManualSource => 'मैन्युअल रूप से जोड़ा गया';

  @override
  String get familyDetailAutoSource => 'पॉलिसी से पता चला';

  @override
  String familyDetailNoPolicies(Object name) {
    return '$name को सूचीबद्ध करने वाली कोई पॉलिसी नहीं मिली। उन्हें शामिल करने वाली पॉलिसी अपलोड करें, या मैन्युअल रूप से जोड़ें।';
  }

  @override
  String get relationshipDependent => 'आश्रित';

  @override
  String get relationshipSpouse => 'पति/पत्नी';

  @override
  String get relationshipChild => 'बच्चा';

  @override
  String get relationshipParent => 'माता-पिता';

  @override
  String get relationshipSibling => 'भाई-बहन';

  @override
  String get relationshipPrimaryInsured => 'प्राथमिक बीमित';

  @override
  String get relationshipOther => 'अन्य';

  @override
  String get insuranceCardsTitle => 'बीमा कार्ड';

  @override
  String get insuranceCardsEmptyTitle => 'अभी तक कोई बीमा कार्ड नहीं';

  @override
  String get insuranceCardsEmptySubtitle =>
      'अपने फ़ोन पर मुख्य विवरण रखने के लिए एक पॉलिसी फ़ाइल चुनें।';

  @override
  String get insuranceCardsChooseFile => 'पॉलिसी फ़ाइल चुनें';

  @override
  String get insuranceCardsHeaderTitle =>
      'आपकी पॉलिसी जानकारी, साथ रखने के लिए तैयार';

  @override
  String get insuranceCardsHeaderSubtitle =>
      'पॉलिसी और बीमाकर्ता विवरण के लिए त्वरित संदर्भ। अपने बीमाकर्ता से प्रमाण आवश्यकताओं की पुष्टि करें।';

  @override
  String get insuranceCardsPolicyNumber => 'पॉलिसी नंबर';

  @override
  String get insuranceCardsCoverage => 'कवरेज';

  @override
  String get insuranceCardsPremium => 'प्रीमियम';

  @override
  String get insuranceCardsValidFrom => 'मान्य तिथि से';

  @override
  String get insuranceCardsValidUntil => 'मान्य तिथि तक';

  @override
  String get insuranceCardsCallInsurer => 'बीमाकर्ता को कॉल करें';

  @override
  String get insuranceCardsShareCard => 'कार्ड साझा करें';

  @override
  String get insuranceCardsExpired => 'समाप्त';

  @override
  String get insuranceCardsShareTitle => 'CoverWise पॉलिसी संदर्भ';

  @override
  String get insuranceCardsInsurerPrefix => 'बीमाकर्ता: ';

  @override
  String get insuranceCardsPolicyNumberPrefix => 'पॉलिसी नंबर: ';

  @override
  String get insuranceCardsCoveragePrefix => 'कवरेज: ';

  @override
  String get insuranceCardsValidUntilPrefix => 'मान्य तिथि तक: ';

  @override
  String get insuranceCardsHelplinePrefix => 'बीमाकर्ता हेल्पलाइन: ';

  @override
  String get insuranceCardsShareFooter =>
      'बीमाकर्ता और स्रोत पॉलिसी दस्तावेज़ के साथ वर्तमान विवरण सत्यापित करें।';

  @override
  String get insuranceCardsPhoneError => 'फ़ोन ऐप नहीं खोल सका';

  @override
  String get insuranceCardsShareError => 'साझाकरण विकल्प नहीं खोल सका';

  @override
  String get renewalTitle => 'नवीकरण कैलेंडर';

  @override
  String get renewalEmptyTitle => 'कोई पॉलिसी ट्रैक नहीं की गई';

  @override
  String get renewalEmptySubtitle =>
      'नवीकरण तिथियों को ट्रैक करने के लिए एक पॉलिसी फ़ाइल चुनें।';

  @override
  String get renewalHeaderTitle => 'नवीकरण पर नज़र रखें';

  @override
  String get renewalHeaderSubtitle =>
      'देखें कि पहले किस पर ध्यान देने की आवश्यकता है और बीमाकर्ता के संपर्क विवरण पास रखें।';

  @override
  String get renewalReminderText =>
      'पॉलिसी समाप्त होने से 30, 15, 7 और 1 दिन पहले अनुस्मारक सेट करें।';

  @override
  String get renewalRemindersOn => 'नवीकरण अनुस्मारक चालू हैं।';

  @override
  String get renewalNotificationsOff =>
      'सूचनाएँ बंद हैं। आप सेटिंग में इन्हें सक्षम कर सकते हैं।';

  @override
  String get renewalSectionExpired => 'समाप्त';

  @override
  String get renewalSectionExpiringSoon => 'जल्द समाप्त हो रही है';

  @override
  String get renewalSectionActive => 'सक्रिय';

  @override
  String get renewalSectionNoDate => 'समाप्ति तिथि नहीं मिली';

  @override
  String get renewalNoDateInfo =>
      'आपकी पॉलिसी में समाप्ति तिथि नहीं मिली — अपना पॉलिसी दस्तावेज़ जाँचें';

  @override
  String get renewalInsurerNotFound => 'बीमाकर्ता नहीं मिला';

  @override
  String renewalExpires(Object date) {
    return '$date को समाप्त हो रही है';
  }

  @override
  String get renewalContactToRenew => 'नवीकरण के लिए बीमाकर्ता से संपर्क करें';

  @override
  String get renewalStartRenewal => 'नवीकरण शुरू करें';

  @override
  String renewalRenewTitle(Object type) {
    return '$type नवीनीकृत करें';
  }

  @override
  String renewalContactInsurer(Object insurer) {
    return 'नवीकरण प्रक्रिया शुरू करने के लिए $insurer से संपर्क करें।';
  }

  @override
  String get renewalCallHelpline => 'हेल्पलाइन पर कॉल करें';

  @override
  String get renewalSendEmail => 'ईमेल भेजें';

  @override
  String renewalContactInfoNotFound(Object insurer) {
    return '$insurer के लिए संपर्क जानकारी नहीं मिली। अपना पॉलिसी दस्तावेज़ जाँचें या सीधे बीमाकर्ता को कॉल करें।';
  }

  @override
  String get renewalPhoneDialerError => 'फ़ोन डायलर नहीं खोल सका';

  @override
  String get renewalEmailClientError => 'ईमेल क्लाइंट नहीं खोल सका';

  @override
  String renewalExpiringPolicies(Object date) {
    return '$date को समाप्त होने वाली पॉलिसियाँ';
  }

  @override
  String renewalExpiringCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस तिथि पर $count पॉलिसियाँ समाप्त हो रही हैं',
      one: 'इस तिथि पर 1 पॉलिसी समाप्त हो रही है',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'सेटिंग';

  @override
  String get settingsHeaderTitle => 'आपका ऐप, आपकी प्राथमिकताएँ';

  @override
  String get settingsHeaderSubtitle =>
      'पहुँच, अनुस्मारक और इस डिवाइस पर क्या रहता है प्रबंधित करें।';

  @override
  String get settingsSectionPlan => 'योजना';

  @override
  String get settingsSectionAccount => 'खाता';

  @override
  String get settingsSectionExperience => 'अनुभव';

  @override
  String get settingsSectionAppDetails => 'ऐप विवरण';

  @override
  String get settingsSectionPrivacy => 'गोपनीयता और सहमति';

  @override
  String get settingsSectionDeviceData => 'डिवाइस डेटा';

  @override
  String settingsCurrentPlan(Object plan) {
    return 'वर्तमान योजना: $plan';
  }

  @override
  String get settingsQaPacks => 'Q&A पैक';

  @override
  String settingsQuestionsInPacks(Object count) {
    return '$count प्रश्न पैक में';
  }

  @override
  String get settingsBuyQuestions => 'बिना सब्सक्रिप्शन के प्रश्न खरीदें';

  @override
  String get settingsRenews => 'नवीनीकरण';

  @override
  String get settingsSignedIn => 'साइन इन किया';

  @override
  String get settingsSupabaseAccount => 'Supabase खाता';

  @override
  String get settingsAccountLinked => 'खाता लिंक किया गया';

  @override
  String get settingsLinkYourPhone => 'अपना फ़ोन लिंक करें';

  @override
  String settingsConnectedAs(Object phone) {
    return '$phone के रूप में कनेक्टेड';
  }

  @override
  String get settingsBackupSubtitle =>
      'पॉलिसियों का बैकअप लें और दूसरे डिवाइस पर उपयोग करें';

  @override
  String get settingsAppearance => 'दिखावट';

  @override
  String settingsThemeMode(Object mode) {
    return '$mode';
  }

  @override
  String get settingsNotifications => 'सूचनाएँ';

  @override
  String get settingsNotificationsSubtitle => 'नवीकरण अनुस्मारक और शांत घंटे';

  @override
  String get settingsSmartSuggestions => 'कवरेज अंतर्दृष्टि';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'जल्द आ रहा है: आपके पॉलिसी विवरण के आधार पर कवरेज मार्गदर्शन';

  @override
  String get settingsServiceEndpoint => 'सेवा एंडपॉइंट';

  @override
  String get settingsClearDataTitle => 'सभी स्थानीय डेटा साफ़ करें?';

  @override
  String get settingsClearDataAction => 'स्थानीय डेटा साफ़ करें';

  @override
  String get settingsClearDataContent =>
      'यह इस डिवाइस से सभी स्थानीय रूप से संग्रहीत दस्तावेज़, पॉलिसी सारांश, Q&A इतिहास, परिवार सदस्य और सत्र डेटा हटाता है। सर्वर पर अपलोड किए गए दस्तावेज़ प्रभावित नहीं होते। इस कार्रवाई को इस डिवाइस से वापस नहीं किया जा सकता।';

  @override
  String get settingsClearDataSuccess => 'सभी स्थानीय डेटा साफ़ हो गया।';

  @override
  String get settingsClearDataSubtitle =>
      'दस्तावेज़, सारांश, इतिहास और परिवार सदस्य हटाएँ';

  @override
  String get settingsNoConsentRecords => 'कोई सहमति रिकॉर्ड नहीं';

  @override
  String get settingsConsentRecorded =>
      'जब आप अपनी पहली पॉलिसी अपलोड करते हैं तब सहमति दर्ज की जाती है';

  @override
  String get settingsConsentPolicyProcessing => 'पॉलिसी प्रसंस्करण';

  @override
  String get settingsConsentAnalytics => 'उपयोग विश्लेषण';

  @override
  String get settingsConsentLeadCapture => 'संपर्क कैप्चर';

  @override
  String get settingsConsentTermsAccepted => 'शर्तें स्वीकार की गईं';

  @override
  String settingsConsentGranted(Object date, Object version) {
    return '$date को दी गई • संस्करण $version';
  }

  @override
  String settingsConsentRevoked(Object date) {
    return '$date को रद्द की गई';
  }

  @override
  String get settingsConsentActive => 'सक्रिय';

  @override
  String get settingsConsentRevokedLabel => 'रद्द';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsLanguageSubtitle => 'अपनी पसंदीदा ऐप भाषा चुनें';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get profileDefaultHeader => 'आपकी CoverWise प्रोफ़ाइल';

  @override
  String get profileLinkedHeader => 'आपके डिवाइसों पर लिंक और तैयार।';

  @override
  String get profileUnlinkedHeader =>
      'आपका पॉलिसी वर्कस्पेस फिलहाल इसी डिवाइस पर रहता है।';

  @override
  String get profileCreateAccount => 'सुरक्षित खाता बनाएँ';

  @override
  String get profileRestoreWorkspace =>
      'इस पॉलिसी वर्कस्पेस को डिवाइसों में पुनर्स्थापित करें';

  @override
  String get profileSignedInAccount => 'साइन इन किया गया खाता';

  @override
  String get profileWorkspaceLinked => 'वर्कस्पेस आपके खाते से लिंक है';

  @override
  String get profilePhoneNumber => 'फ़ोन नंबर';

  @override
  String get profileNotLinked => 'लिंक नहीं किया गया';

  @override
  String get profileSecureSession => 'सुरक्षित सत्र';

  @override
  String get profileAccountSessionActive => 'इस डिवाइस पर खाता सत्र सक्रिय';

  @override
  String get profileAnonymousSessionActive => 'इस डिवाइस पर अनाम सत्र सक्रिय';

  @override
  String get profileAppSection => 'ऐप';

  @override
  String get profileFamilySection => 'परिवार';

  @override
  String get profilePrivacySection => 'गोपनीयता';

  @override
  String get profileDeviceFirstStorage => 'डिवाइस-प्रथम भंडारण';

  @override
  String get profileDeviceFirstSubtitle =>
      'यह डिवाइस एक सुरक्षित स्थानीय कैश रखता है; सिंक के लिए खाता डेटा भी सुरक्षित रूप से संग्रहीत किया जा सकता है।';

  @override
  String get profileDeleteAccount => 'खाता हटाएँ';

  @override
  String get profileDeleteAccountSubtitle =>
      'खाता और सभी सर्वर डेटा स्थायी रूप से हटाएँ';

  @override
  String get profileCreateAccountFirst => 'इसे हटाने के लिए पहले एक खाता बनाएँ';

  @override
  String get profileFooter =>
      'CoverWise आपकी पॉलिसियों को समझने में मदद करता है। यह बीमा नहीं बेचता।';

  @override
  String get profileDeleteConfirmTitle => 'खाता स्थायी रूप से हटाएँ?';

  @override
  String get profileDeleteConfirmHeader => 'यह स्थायी रूप से हटाएगा:';

  @override
  String get profileDeleteItemAccount => '• आपका CoverWise खाता';

  @override
  String get profileDeleteItemDocs =>
      '• हमारे सर्वर पर सभी अपलोड किए गए पॉलिसी दस्तावेज़';

  @override
  String get profileDeleteItemSummaries => '• सभी पॉलिसी सारांश और एम्बेडिंग';

  @override
  String get profileDeleteItemHistory => '• सर्वर पर आपका Q&A इतिहास';

  @override
  String get profileDeleteWarning =>
      'यह क्रिया इस डिवाइस से पूर्ववत नहीं की जा सकती। इस डिवाइस पर स्थानीय डेटा अलग से सेटिंग → स्थानीय डेटा साफ़ करें से हटाया जाएगा।';

  @override
  String get profileDeleteEverything => 'सब कुछ हटाएँ';

  @override
  String get profileDeleteTypeTitle => 'पुष्टि करने के लिए DELETE टाइप करें';

  @override
  String get profileDeleteTypeWarning =>
      'यह आपका अंतिम मौका है। सभी डेटा स्थायी रूप से मिटा दिया जाएगा।';

  @override
  String get profileDeleteTypeHint => 'DELETE टाइप करें';

  @override
  String get profileDeletePermanently => 'स्थायी रूप से हटाएँ';

  @override
  String get profileDeletingAccount => 'खाता हटाया जा रहा है...';

  @override
  String profileDeleteComplete(Object docs, Object files) {
    return 'खाता हटा दिया गया। $docs दस्तावेज़ और $files स्टोरेज फ़ाइलें हटा दी गईं।';
  }

  @override
  String profileDeletePartial(Object failed) {
    return 'खाता हटाना आंशिक रूप से पूरा हुआ। असफल चरण: $failed। सर्वर हटाने को पूर्ण न मानें।';
  }

  @override
  String profileDeleteRequested(Object status) {
    return 'खाता हटाने का अनुरोध किया गया। स्थिति: $status।';
  }

  @override
  String get profileDeletionStatusTitle => 'खाता हटाने की स्थिति';

  @override
  String get profileDeletionStatusPending =>
      'हटाना कतार में है। सर्वर मिटाने की पुष्टि होने तक आपका खाता सक्रिय रहेगा।';

  @override
  String get profileDeletionStatusRunning =>
      'हटाने की प्रक्रिया चल रही है। मिटाने के दौरान नए खाता लेखन रोक दिए गए हैं।';

  @override
  String get profileDeletionStatusFailed =>
      'पिछले हटाने के प्रयास पर ध्यान देने की आवश्यकता है।';

  @override
  String get profileDeletionStatusRefresh => 'स्थिति ताज़ा करें';

  @override
  String get profileDeletionStatusUnavailable =>
      'हटाने की स्थिति अस्थायी रूप से अनुपलब्ध है।';

  @override
  String profileInFlightWarning(Object count) {
    return '$count दस्तावेज़ अभी भी प्रसंस्करण में हैं। खाता हटाने से पहले प्रसंस्करण पूरा होने तक प्रतीक्षा करें।';
  }

  @override
  String get upgradeTitle => 'अपनी योजना चुनें';

  @override
  String get upgradeBillingUnavailable =>
      'बिलिंग अभी उपलब्ध नहीं है। कृपया बाद में पुनः प्रयास करें।';

  @override
  String get upgradeCouldNotOpenSettings => 'सब्सक्रिप्शन सेटिंग नहीं खोल सका';

  @override
  String upgradeSuccess(Object plan) {
    return '$plan में अपग्रेड किया गया! अपनी नई सुविधाओं का आनंद लें।';
  }

  @override
  String get upgradePurchaseCancelled => 'खरीदारी रद्द कर दी गई।';

  @override
  String get upgradeMonthly => 'मासिक';

  @override
  String get upgradeAnnual => 'वार्षिक';

  @override
  String get upgradeSaveUpTo => '44% तक बचाएँ';

  @override
  String get upgradeCurrentPlan => 'वर्तमान योजना';

  @override
  String get upgradeFreeForever => 'हमेशा मुफ़्त';

  @override
  String upgradeTo(Object plan) {
    return '$plan में अपग्रेड करें';
  }

  @override
  String get upgradeComparePlans => 'योजनाओं की तुलना करें';

  @override
  String get upgradeQuestions => 'प्रश्न';

  @override
  String get upgradeFaqSwitch => 'क्या मैं योजना बदल सकता हूँ?';

  @override
  String get upgradeFaqSwitchAnswer =>
      'आप अपने App Store या Play Store सब्सक्रिप्शन सेटिंग से योजना परिवर्तन प्रबंधित कर सकते हैं।';

  @override
  String get upgradeFaqPacks => 'मेरे Q&A पैक का क्या होगा?';

  @override
  String get upgradeFaqPacksAnswer =>
      'पैक के प्रश्न सक्रिय रहते हैं और मासिक सब्सक्रिप्शन कोटा समाप्त होने के बाद उपयोग होते हैं।';

  @override
  String get upgradeFaqCancel => 'मैं कैसे रद्द करूँ?';

  @override
  String get upgradeFaqCancelAnswer =>
      'अपने App Store या Play Store सब्सक्रिप्शन सेटिंग से कभी भी रद्द करें।';

  @override
  String get upgradeAccessUntil => 'पहुँच तिथि तक';

  @override
  String get upgradePolicies => 'पॉलिसियाँ';

  @override
  String get upgradeQaPerMonth => 'प्रति माह Q&A';

  @override
  String get upgradeComparePolicies => 'पॉलिसियों की तुलना करें';

  @override
  String get upgradeFamilyView => 'परिवार दृश्य';

  @override
  String get upgradeCloudSync => 'क्लाउड सिंक';

  @override
  String get upgradeEmergency => 'आपातकालीन';

  @override
  String get upgradeAnnualReview => 'वार्षिक समीक्षा';

  @override
  String get upgradeAdvancedSearch => 'उन्नत खोज';

  @override
  String accountTitle(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'खाता बनाएँ',
        'other': 'साइन इन करें',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountHeaderTitle => 'अपने पॉलिसी वर्कस्पेस की सुरक्षा करें';

  @override
  String get accountHeaderSubtitle =>
      'एक खाता आपको दूसरे डिवाइस पर अपना CoverWise वर्कस्पेस पुनर्स्थापित करने देता है।';

  @override
  String get accountNameLabel => 'नाम (वैकल्पिक)';

  @override
  String get accountEmailLabel => 'ईमेल';

  @override
  String get accountPasswordLabel => 'पासवर्ड';

  @override
  String get accountResendBanner =>
      'आपका ईमेल अभी तक पुष्टि नहीं हुआ है। अपना इनबॉक्स जाँचें या पुनः भेजें।';

  @override
  String get accountResend => 'पुनः भेजें';

  @override
  String get accountForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get accountResendVerification => 'पुष्टिकरण ईमेल पुनः भेजें';

  @override
  String accountSwitchToSignIn(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'पहले से खाता है? साइन इन करें',
        'other': 'CoverWise में नए हैं? खाता बनाएँ',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountGoogleSignIn => 'Google के साथ जारी रखें';

  @override
  String get accountAuthNotConfigured =>
      'इस बिल्ड के लिए खाता प्रमाणीकरण कॉन्फ़िगर नहीं किया गया है।';

  @override
  String get accountEnterEmail => 'कृपया अपना ईमेल पता दर्ज करें।';

  @override
  String get accountPasswordTooShort =>
      'पासवर्ड कम से कम 8 अक्षर का होना चाहिए।';

  @override
  String get accountInvalidEmail => 'कृपया एक मान्य ईमेल पता दर्ज करें।';

  @override
  String get accountCheckEmail =>
      'खाते की पुष्टि के लिए अपना ईमेल जाँचें, फिर साइन इन करें।';

  @override
  String get accountIncorrectCredentials =>
      'गलत ईमेल या पासवर्ड। कृपया पुनः प्रयास करें।';

  @override
  String get accountAlreadyRegistered =>
      'इस ईमेल के साथ एक खाता पहले से मौजूद है। साइन इन करने का प्रयास करें।';

  @override
  String get accountPasswordRequirements =>
      'पासवर्ड आवश्यकताओं को पूरा नहीं करता। कम से कम 8 अक्षर का उपयोग करें।';

  @override
  String accountCouldNotAction(String action) {
    String _temp0 = intl.Intl.selectLogic(
      action,
      {
        'true': 'खाता बनाया',
        'other': 'खाता साइन इन किया',
      },
    );
    return '$_temp0 नहीं जा सका।';
  }

  @override
  String get accountEnterEmailFirst =>
      'पहले ऊपर अपना ईमेल दर्ज करें, फिर पासवर्ड भूल गए पर टैप करें।';

  @override
  String get accountResetEmailSent =>
      'पासवर्ड रीसेट ईमेल भेज दिया गया। अपना इनबॉक्स जाँचें।';

  @override
  String get accountCouldNotReset =>
      'रीसेट ईमेल नहीं भेज सका। अपना ईमेल जाँचें और पुनः प्रयास करें।';

  @override
  String get accountEnterEmailResend =>
      'पहले ऊपर अपना ईमेल दर्ज करें, फिर पुनः भेजें पर टैप करें।';

  @override
  String get accountVerificationSent =>
      'पुष्टिकरण ईमेल भेज दिया गया। अपना इनबॉक्स जाँचें।';

  @override
  String get accountCouldNotVerify =>
      'पुष्टिकरण ईमेल नहीं भेज सका। बाद में पुनः प्रयास करें।';

  @override
  String get accountCouldNotGoogle =>
      'Google से साइन इन नहीं कर सका। कृपया पुनः प्रयास करें।';

  @override
  String get notifTitle => 'नवीकरण अनुस्मारक';

  @override
  String get notifHeaderTitle => 'नवीकरण से आगे रहें';

  @override
  String get notifHeaderSubtitle =>
      'चुनें कि यह डिवाइस आपको कब याद दिलाए। सूचनाएँ अनुस्मारक हैं, बीमाकर्ता के नवीकरण नोटिस नहीं।';

  @override
  String get notifMasterToggle => 'नवीकरण अनुस्मारक';

  @override
  String get notifEnabledSubtitle => 'इस डिवाइस पर सक्षम';

  @override
  String get notifDisabledSubtitle => 'अक्षम';

  @override
  String get notifSectionRemindMe => 'समाप्ति से पहले मुझे याद दिलाएँ';

  @override
  String get notifSectionRemindMeDescription =>
      'चुनें कि आपकी पॉलिसी समाप्त होने से कितने दिन पहले अनुस्मारक प्राप्त करना चाहते हैं।';

  @override
  String get notifNoReminderTimes => 'कोई अनुस्मारक समय चयनित नहीं है।';

  @override
  String get notifSectionQuietHours => 'शांत घंटे';

  @override
  String get notifSectionQuietHoursDescription =>
      'इन घंटों के दौरान कोई सूचना नहीं।';

  @override
  String get notifStartTime => 'प्रारंभ समय';

  @override
  String get notifEndTime => 'समाप्ति समय';

  @override
  String get notifSectionPerPolicy => 'प्रति-पॉलिसी अनुस्मारक';

  @override
  String get notifSectionPerPolicyDescription =>
      'व्यक्तिगत पॉलिसियों के लिए अनुस्मारक चालू/बंद करें।';

  @override
  String get notifPreferencesSaved => 'प्राथमिकताएँ सहेज ली गईं';

  @override
  String get docsTitle => 'दस्तावेज़';

  @override
  String docsSlotsUsed(Object count) {
    return '$count में से 5 मुफ़्त पॉलिसी स्लॉट उपयोग में';
  }

  @override
  String get docsTypeChanged => 'प्रकार बदलकर';

  @override
  String get docsRemovedLocal =>
      'इस डिवाइस से हटा दिया गया। सर्वर कॉपी प्रभावित नहीं हुई।';

  @override
  String get docsReplaceSuccess => 'दस्तावेज़ सफलतापूर्वक बदला गया';

  @override
  String get docsPreview => 'पूर्वावलोकन';

  @override
  String get docsDownloadSource => 'स्रोत डाउनलोड करें';

  @override
  String get docsChangeType => 'प्रकार बदलें';

  @override
  String get docsAskQuestions => 'प्रश्न पूछें';

  @override
  String get docsReadingPolicy => 'पॉलिसी पढ़ रहे हैं';

  @override
  String get docsUploadRequired => 'सर्वर अपलोड आवश्यक';

  @override
  String get docsRetryUpload => 'अपलोड पुनः प्रयास करें';

  @override
  String get docsNeedsAttention => 'ध्यान देने की आवश्यकता';

  @override
  String get docsReadyForQuestions => 'प्रश्नों के लिए तैयार';

  @override
  String get docsSaved => 'सहेजा गया';

  @override
  String get docsRefreshingTypes => 'दस्तावेज़ प्रकार ताज़ा हो रहे हैं...';

  @override
  String get docsTypesRefreshed => 'दस्तावेज़ प्रकार सफलतापूर्वक ताज़ा हो गए!';

  @override
  String get docsReplace => 'बदलें';

  @override
  String get docsRemoveFromDevice => 'इस डिवाइस से हटाएँ';

  @override
  String get docsRemoveFromDeviceTitle => 'इस डिवाइस से हटाएँ?';

  @override
  String get docsDeletePolicy => 'पॉलिसी हटाएँ';

  @override
  String get docsDeletePolicyTitle => 'पॉलिसी हटाएँ?';

  @override
  String docsDeletePolicyContent(Object filename) {
    return 'यह \"$filename\" को CoverWise और इस डिवाइस से स्थायी रूप से हटा देता है।';
  }

  @override
  String get docsDeleted => 'पॉलिसी हटा दी गई';

  @override
  String get docsReplaceDocumentTitle => 'दस्तावेज़ बदलें?';

  @override
  String get docsReplaceDocument => 'दस्तावेज़ बदलें';

  @override
  String get docsCurrentDocument => 'वर्तमान दस्तावेज़';

  @override
  String get docsSelectReplacement => 'प्रतिस्थापन फ़ाइल चुनें';

  @override
  String docsReplaceWillDelete(Object filename) {
    return 'यह \"$filename\" को हटाकर नई फ़ाइल से बदल देगा।';
  }

  @override
  String get docsReplaceAnalysisLost =>
      'पुराने दस्तावेज़ का विश्लेषण खो जाएगा। नए दस्तावेज़ को फिर से प्रसंस्कृत किया जाएगा।';

  @override
  String docsUploadedDate(Object date) {
    return 'अपलोड किया गया: $date';
  }

  @override
  String get docsClearReplacement => 'प्रतिस्थापन फ़ाइल साफ़ करें';

  @override
  String get docsArchive => 'संग्रहित करें';

  @override
  String get docsArchived => 'संग्रहित';

  @override
  String get docsRestore => 'पुनर्स्थापित करें';

  @override
  String get docsRestored => 'पॉलिसी पुनर्स्थापित हो गई';

  @override
  String get docsArchivedSuccess => 'पॉलिसी संग्रहित हो गई';

  @override
  String get docsShowArchived => 'संग्रहित दिखाएँ';

  @override
  String get docsHideArchived => 'संग्रहित छुपाएँ';

  @override
  String get docsArchiveConfirmTitle => 'पॉलिसी संग्रहित करें?';

  @override
  String docsArchiveConfirmContent(Object filename) {
    return '\"$filename\" आपकी सक्रिय पॉलिसी सूची से छिपा दिया जाएगा। आप इसे कभी भी संग्रह से पुनर्स्थापित कर सकते हैं।';
  }

  @override
  String get docsDeletePermanentWarning =>
      'यह पॉलिसी को CoverWise और इस डिवाइस दोनों से स्थायी रूप से हटा देता है। संग्रहित करने पर विचार करें।';

  @override
  String get docsLimitWarning =>
      'आप अपनी मुफ़्त भंडारण सीमा के करीब हैं। जगह खाली करने के लिए पुरानी पॉलिसियाँ संग्रहित करें।';

  @override
  String docsLimitCountdown(Object limit, Object remaining, Object used) {
    return '$used में से $limit स्लॉट उपयोग में — $remaining शेष';
  }

  @override
  String docsLimitRemaining(Object remaining) {
    return '$remaining मुफ़्त स्लॉट शेष';
  }

  @override
  String get docsSortLabel => 'क्रमबद्ध करें';

  @override
  String get docsFilterLabel => 'फ़िल्टर';

  @override
  String get docsSortDateNewest => 'नई पहले';

  @override
  String get docsSortDateOldest => 'पुरानी पहले';

  @override
  String get docsSortNameAZ => 'नाम A–Z';

  @override
  String get docsSortNameZA => 'नाम Z–A';

  @override
  String get docsSortType => 'प्रकार के अनुसार';

  @override
  String get docsFilterAll => 'सभी प्रकार';

  @override
  String docsFilterResultCount(Object count, Object total) {
    return '$count में से $total पॉलिसियाँ';
  }

  @override
  String get docsRenameTitle => 'पॉलिसी का नाम बदलें';

  @override
  String get docsRenameHint => 'नया नाम दर्ज करें';

  @override
  String get docsRenameSave => 'सहेजें';

  @override
  String get docsRenameSuccess => 'पॉलिसी का नाम बदल दिया गया';

  @override
  String get docsRenameEmpty => 'नाम खाली नहीं हो सकता';

  @override
  String get tosTitle => 'सेवा की शर्तें';

  @override
  String get tosCopySuccess => 'सेवा की शर्तें क्लिपबोर्ड पर कॉपी हो गईं';

  @override
  String get tosLoadError => 'सेवा की शर्तें लोड नहीं हो सकीं।';

  @override
  String get privacyTitle => 'गोपनीयता नीति';

  @override
  String get privacyCopySuccess => 'गोपनीयता नीति क्लिपबोर्ड पर कॉपी हो गई';

  @override
  String get privacyLoadError => 'गोपनीयता नीति लोड नहीं हो सकी।';

  @override
  String get processingReceived => 'प्राप्त हुआ';

  @override
  String get processingProcessing => 'प्रसंस्करण';

  @override
  String get processingCategorising => 'वर्गीकरण';

  @override
  String get processingFinishingUp => 'अंतिम रूप दिया जा रहा है';

  @override
  String get processingReceivedDesc => 'आपकी पॉलिसी प्राप्त हो गई है';

  @override
  String get processingProcessingDesc => 'पाठ पढ़ा और निकाला जा रहा है';

  @override
  String get processingCategorisingDesc =>
      'पॉलिसी प्रकार और बीमाकर्ता निर्धारित किया जा रहा है';

  @override
  String get processingFinishingUpDesc =>
      'आपकी पॉलिसी खोजने योग्य बनाई जा रही है';

  @override
  String get onboardSubtitle =>
      'अपनी वास्तविक पॉलिसी के आधार पर स्पष्ट उत्तर प्राप्त करें — इंटरनेट से सामान्य सलाह नहीं।';

  @override
  String get onboardNoDataStored =>
      'आपकी सहमति के बिना कोई पॉलिसी डेटा संग्रहीत या साझा नहीं किया जाएगा।';

  @override
  String get onboardTermsAcceptance =>
      'मैंने गोपनीयता नीति और सेवा की शर्तें पढ़ और स्वीकार कर ली हैं।';

  @override
  String get emergencyTitle => 'आपातकालीन';

  @override
  String get emergencyHelpAtGlance => 'एक नज़र में मदद';

  @override
  String get dashboardQuickActions => 'त्वरित कार्रवाइयाँ';

  @override
  String get dashboardEmergency => 'आपातकालीन';

  @override
  String get dashboardAddPolicy => 'पॉलिसी फ़ाइल जोड़ें';

  @override
  String get searchTitle => 'खोज';

  @override
  String get searchHint => 'सभी पॉलिसियों में खोजें...';

  @override
  String get searchNoResults => 'कोई परिणाम नहीं मिला';

  @override
  String get coverageGapTitle => 'कवरेज समीक्षा';

  @override
  String get coverageGapEmpty =>
      'उपलब्ध पॉलिसी पाठ से अभी तक कोई संभावित कवरेज प्रश्न नहीं मिला';

  @override
  String get literacyTitle => 'बीमा शब्दकोश';

  @override
  String get literacySearchHint => 'शर्तें खोजें...';

  @override
  String get docTypePickerTitle => 'दस्तावेज़ प्रकार चुनें';

  @override
  String get fileTypeSupported => 'समर्थित फ़ाइल प्रकार';

  @override
  String get fileTypePdf => 'PDF दस्तावेज़';

  @override
  String get fileTypeImage => 'चित्र (JPEG, PNG)';

  @override
  String get fileTypeMaxSize => 'अधिकतम फ़ाइल आकार: 20 MB';

  @override
  String get fileTypeUnsupported =>
      'यह फ़ाइल प्रकार समर्थित नहीं है। कृपया PDF या चित्र चुनें।';

  @override
  String get whatIfTitle => 'क्या-अगर कैलकुलेटर';

  @override
  String get whatIfDescription =>
      'जानें कि विभिन्न कवरेज विकल्प आपके अनुमानित खर्चों को कैसे प्रभावित करते हैं।';

  @override
  String get batchPickMultiple => 'एकाधिक फ़ाइलें चुनें';

  @override
  String batchUploadingPendingCount(Object count) {
    return '$count फ़ाइलें अपलोड हो रही हैं…';
  }

  @override
  String batchUploadingProgress(Object done, Object total) {
    return '$done में से $total अपलोड हो गए';
  }

  @override
  String get batchCompleted => 'सभी फ़ाइलें अपलोड हो गईं';

  @override
  String batchCompletedCount(Object count) {
    return '$count फ़ाइलें सफलतापूर्वक अपलोड हुईं';
  }

  @override
  String get batchSomeFailed => 'कुछ अपलोड विफल रहे';

  @override
  String batchFailedCount(Object failed, Object total) {
    return '$failed में से $total फ़ाइलें विफल रहीं';
  }

  @override
  String batchFileTooLargeMB(Object maxMB) {
    return 'यह फ़ाइल $maxMB MB की सीमा से अधिक है और इसे छोड़ दिया जाएगा';
  }

  @override
  String get batchFileUnsupported => 'असमर्थित फ़ाइल प्रकार — छोड़ दिया गया';

  @override
  String get batchDuplicateSkipped => 'डुप्लिकेट — छोड़ दिया गया';

  @override
  String get batchRetryFailed => 'असफल अपलोड पुनः प्रयास करें';

  @override
  String get batchDone => 'हो गया';

  @override
  String get batchAddMore => 'और फ़ाइलें जोड़ें';

  @override
  String get batchSelectAll => 'सभी चुनें';

  @override
  String get familyVisTitle => 'कवरेज मानचित्र';

  @override
  String get familyVisHeader => 'पॉलिसी में सूचीबद्ध परिवार के सदस्य';

  @override
  String get familyVisSubtitle =>
      'हर पॉलिसी में सूचीबद्ध परिवार के सदस्यों की तुलना करें; अपने बीमाकर्ता से कवरेज की पुष्टि करें।';

  @override
  String get familyVisMembers => 'परिवार सदस्य';

  @override
  String get familyVisPolicies => 'पॉलिसियाँ';

  @override
  String get familyVisEmptyTitle => 'अभी तक कोई कवरेज डेटा नहीं';

  @override
  String get familyVisEmptySubtitle =>
      'अपनी पॉलिसी में सूचीबद्ध नामों की तुलना करने के लिए पॉलिसियाँ अपलोड करें और परिवार के सदस्यों को जोड़ें।';

  @override
  String familyVisNoPolicies(Object name) {
    return '$name को सूचीबद्ध करने वाली कोई पॉलिसी अभी तक नहीं।';
  }

  @override
  String get familyVisSeeMap => 'पॉलिसी सदस्य मानचित्र देखें';
}
