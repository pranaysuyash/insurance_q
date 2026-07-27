// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsGenMr extends AppLocalizationsGen {
  AppLocalizationsGenMr([String locale = 'mr']) : super(locale);

  @override
  String get appName => 'CoverWise';

  @override
  String get commonShowLess => 'कमी दाखवा';

  @override
  String get commonShowMore => 'अधिक दाखवा';

  @override
  String get cancel => 'रद्द करा';

  @override
  String get save => 'जतन करा';

  @override
  String get remove => 'काढा';

  @override
  String get add => 'जोडा';

  @override
  String get clear => 'साफ करा';

  @override
  String get enable => 'सुरू करा';

  @override
  String get disable => 'बंद करा';

  @override
  String get version => 'आवृत्ती';

  @override
  String get upgrade => 'सुधारणा करा';

  @override
  String get manage => 'व्यवस्थापित करा';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get signIn => 'साइन इन';

  @override
  String get createAccount => 'खाते तयार करा';

  @override
  String get buy => 'खरेदी करा';

  @override
  String get startAsking => 'प्रश्न विचारणे सुरू करा';

  @override
  String get getMore => 'अधिक मिळवा';

  @override
  String get getPacks => 'पॅक मिळवा';

  @override
  String get viewPolicy => 'पॉलिसी पहा';

  @override
  String policyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पॉलिसी',
      one: '1 पॉलिसी',
    );
    return '$_temp0';
  }

  @override
  String resultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count निकाल',
      one: '1 निकाल',
    );
    return '$_temp0';
  }

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिवस',
      one: '1 दिवस',
    );
    return '$_temp0';
  }

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'दिवसांत',
      one: 'दिवसात',
    );
    return '$count $_temp0 समाप्त';
  }

  @override
  String daysLeft(Object days) {
    return '$days दिवस शिल्लक';
  }

  @override
  String daysBefore(Object days) {
    return '$days दिवस आधी';
  }

  @override
  String get qaScreenTitle => 'कवरवाईजला विचारा';

  @override
  String get qaTabSuggested => 'सुचवलेले';

  @override
  String get qaTabYourQuestion => 'तुमचा प्रश्न';

  @override
  String get qaTabHistory => 'इतिहास';

  @override
  String get qaNoQuestionsRemaining => 'प्रश्न शिल्लक नाहीत';

  @override
  String qaQuestionsLeft(Object remaining) {
    return '$remaining प्रश्न शिल्लक';
  }

  @override
  String qaMonthlyPlusPack(Object monthly, Object pack, Object packs) {
    return '$monthly मासिक + $packs पॅक';
  }

  @override
  String qaPackQuestions(Object count, Object packs) {
    return '$packs पॅकमध्ये $count प्रश्न';
  }

  @override
  String qaMonthlyPlan(Object remaining) {
    return 'या महिन्यात $remaining प्रश्न शिल्लक';
  }

  @override
  String get qaAskAbout => 'याबद्दल विचारा';

  @override
  String get qaQuestionSource => 'प्रश्न स्रोत';

  @override
  String qaAllDocuments(Object count) {
    return 'सर्व कागदपत्रे ($count)';
  }

  @override
  String get qaSingleDocument => 'एकच दस्तऐवज';

  @override
  String get qaNoDocumentSelected => 'कोणतेही दस्तऐवज निवडले नाही';

  @override
  String get qaSearchAllPolicies =>
      'तुमच्या सर्व अपलोड केलेल्या पॉलिसीमध्ये शोधा';

  @override
  String get qaAskAboutDescription =>
      'तुमच्या पॉलिसीतील कव्हर, अपवाद, तारखा किंवा मजकुराबद्दल विचारा.';

  @override
  String get qaHintText => 'उदा., प्रभावी तारीख कोणती आहे?';

  @override
  String get qaClearQuestion => 'प्रश्न साफ करा';

  @override
  String get qaNoHistoryYet => 'अद्याप प्रश्न इतिहास नाही';

  @override
  String get qaSearchHistory => 'इतिहास शोधा...';

  @override
  String qaNoMatchesFor(Object query) {
    return '\"$query\" साठी काहीही सापडले नाही';
  }

  @override
  String get qaToday => 'आज';

  @override
  String get qaYesterday => 'काल';

  @override
  String get qaThisWeek => 'या आठवड्यात';

  @override
  String get qaEarlier => 'आधीचे';

  @override
  String get qaSourcesLabel => 'स्रोत';

  @override
  String get qaFollowUpLabel => 'तुम्ही हे देखील विचारू शकता:';

  @override
  String get qaHelpfulAnswer => 'उपयुक्त उत्तर';

  @override
  String get qaUnhelpfulAnswer => 'अनुपयुक्त उत्तर';

  @override
  String get qaCopyAnswer => 'उत्तर कॉपी करा';

  @override
  String get qaAnswerCopied => 'उत्तर कॉपी केले';

  @override
  String get qaShareAnswer => 'उत्तर शेअर करा';

  @override
  String get qaAnswerCopiedToClipboard => 'उत्तर क्लिपबोर्डवर कॉपी केले';

  @override
  String get qaEvidence => 'पुरावा';

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
  String get qaPolicyDoesNotEstablish => 'पॉलिसी काय स्थापित करत नाही';

  @override
  String qaAnswerReadyFor(Object question) {
    return '$question साठी उत्तर तयार आहे';
  }

  @override
  String qaCouldNotGetAnswer(Object error) {
    return 'उत्तर मिळू शकले नाही. $error';
  }

  @override
  String get qaFallbackAnswer =>
      'क्षमस्व, हे कार्य करू शकले नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get qaPolicySource => 'पॉलिसी स्रोत';

  @override
  String get qaViewSource => 'स्रोत पहा';

  @override
  String get qaViewSourcePage => 'पृष्ठावर पहा';

  @override
  String get qaNoSourceDocument => 'स्रोत दस्तऐवज उपलब्ध नाही';

  @override
  String qaSourcePageLabel(Object page) {
    return 'पृष्ठ $page';
  }

  @override
  String get qaRelevanceTooltip =>
      'हा स्रोत तुमच्या प्रश्नाशी किती जवळचा संबंधित आहे';

  @override
  String get qaOfflineMessage =>
      'You are offline. Please check your connection and try again.';

  @override
  String get confidenceHigh => 'उच्च';

  @override
  String get confidenceMedium => 'मध्यम';

  @override
  String get confidenceLow => 'कमी';

  @override
  String confidenceLabel(Object level) {
    return '$level विश्वास';
  }

  @override
  String get qaPacksTitle => 'प्रश्न-उत्तर पॅक';

  @override
  String get qaPacksBuyHeading => 'पॅक खरेदी करा';

  @override
  String get qaPacksSubtitle =>
      'सदस्यत्वाची गरज नाही. एकदा पैसे द्या, प्रश्न विचारा.';

  @override
  String get qaPacksYourPacks => 'तुमचे पॅक';

  @override
  String get qaPacksPurchasedSuccess =>
      'खरेदी प्राप्त झाली. सर्व्हर पुष्टीकरणानंतर प्रश्न दिसतील.';

  @override
  String get qaPacksHowTheyWork => 'पॅक कसे कार्य करतात';

  @override
  String get qaPacksFaqQ1 => 'प्रश्न कधी वजा केले जातात?';

  @override
  String get qaPacksFaqA1 =>
      'तुम्ही प्रश्न सबमिट करता तेव्हा प्रत्येक वेळी एक प्रश्न वजा केला जातो. मासिक सदस्यत्वाचे प्रश्न प्रथम वापरले जातात, नंतर पॅकचे प्रश्न.';

  @override
  String get qaPacksFaqQ2 => 'पॅकची कालमर्यादा असते का?';

  @override
  String get qaPacksFaqA2 =>
      'होय, पॅक खरेदीपासून ९० दिवसांसाठी वैध असतात. कालबाह्य झाल्यानंतर न वापरलेले प्रश्न नष्ट होतात.';

  @override
  String get qaPacksFaqQ3 => 'माझ्याकडे अनेक पॅक असू शकतात का?';

  @override
  String get qaPacksFaqA3 =>
      'होय! अनेक पॅक स्टॅक होऊ शकतात. सर्वात लवकर कालबाह्य होणाऱ्या पॅकमधून प्रथम प्रश्न वापरले जातात (FIFO).';

  @override
  String get qaPacksFaqQ4 => 'जर मी सदस्यत्वात सुधारणा केली तर काय होते?';

  @override
  String get qaPacksFaqA4 =>
      'तुमचे पॅक प्रश्न सक्रिय राहतात आणि तुमचा मासिक सदस्यत्व कोटा संपल्यानंतर वापरले जातात.';

  @override
  String qaPacksQuestionsAvailable(Object count) {
    return '$count प्रश्न उपलब्ध';
  }

  @override
  String qaPacksFromMonthlyPlan(Object count) {
    return 'मासिक योजनेतून $count';
  }

  @override
  String qaPacksFromPacks(Object count) {
    return 'पॅकमधून $count';
  }

  @override
  String qaPacksFromMonthlyAndPacks(Object monthly, Object packs) {
    return 'मासिक योजनेतून $monthly · पॅकमधून $packs';
  }

  @override
  String qaPacksQuestionsInPacks(Object count) {
    return 'पॅकमधून $count प्रश्न';
  }

  @override
  String get qaPacksBestValue => 'अधिक मासिक प्रश्न';

  @override
  String qaPacksQuestionsEach(Object count, Object price) {
    return '$count प्रश्न · प्रति $price';
  }

  @override
  String qaPacksPackPurchased(Object name) {
    return 'खरेदी प्राप्त झाली. तुमचे $name प्रश्न सर्व्हर पुष्टीकरणानंतर दिसतील.';
  }

  @override
  String get qaPacksPurchaseCancelled => 'खरेदी रद्द करण्यात आली.';

  @override
  String get qaPacksPurchaseNotCompleted =>
      'खरेदी पूर्ण झाली नाही. कोणतेही प्रश्न जोडले गेले नाहीत.';

  @override
  String qaPacksPackRemaining(Object type) {
    return '$type पॅक';
  }

  @override
  String qaPacksRemaining(Object remaining, Object total) {
    return '$remaining/$total शिल्लक';
  }

  @override
  String get familyTitle => 'कुटुंब';

  @override
  String get familyNoMembersYet => 'अद्याप कुटुंब सदस्य नाहीत';

  @override
  String get familyNoMembersFound => 'कोणतेही कुटुंब सदस्य आढळले नाहीत';

  @override
  String get familyEmptySubtitle =>
      'कुटुंब सदस्य आपोआप शोधण्यासाठी विमा दस्तऐवज अपलोड करा, किंवा स्वतः एक जोडा.';

  @override
  String get familyAddMember => 'कुटुंब सदस्य जोडा';

  @override
  String get familyLibraryError => 'तुमची पॉलिसी लायब्ररी लोड करता आली नाही.';

  @override
  String get familyMembersReadError =>
      'तुमच्या पॉलिसीमधून कव्हर केलेले कुटुंब सदस्य वाचता आले नाहीत.';

  @override
  String get familyPeopleCovered => 'कव्हर केलेले लोक';

  @override
  String get familyPeopleSubtitle =>
      'तुमच्या पॉलिसीमध्ये आढळलेल्या लोकांचे स्पष्ट दृश्य, तसेच तुम्ही स्वतः जोडलेले कोणीही.';

  @override
  String get familySectionLabel => 'कुटुंब आणि विमाकृत सदस्य';

  @override
  String get familyRemoveTitle => 'कुटुंब सदस्य काढायचा?';

  @override
  String familyRemoveContent(Object name) {
    return 'तुमच्या कुटुंब यादीतून $name काढायचा? याचा तुमच्या पॉलिसी दस्तऐवजांवर परिणाम होणार नाही.';
  }

  @override
  String get familyAddButton => 'कुटुंब सदस्य जोडा';

  @override
  String get familyManualBadge => 'स्वतः जोडले';

  @override
  String get familyFromDocumentBadge => 'दस्तऐवजातून';

  @override
  String familyRemoveTooltip(Object name) {
    return '$name काढा';
  }

  @override
  String familyDateOfBirth(Object date) {
    return 'जन्मतारीख: $date';
  }

  @override
  String get familyDetailEditTooltip => 'सदस्य संपादित करा';

  @override
  String get familyDetailHintName => 'पूर्ण नाव';

  @override
  String get familyDetailMemberUpdated => 'सदस्य अद्यतनित केला';

  @override
  String familyDetailUpdateError(Object error) {
    return 'सदस्य अद्यतनित करू शकलो नाही: $error';
  }

  @override
  String get familyDetailDobLabel => 'जन्मतारीख';

  @override
  String get familyDetailSourceLabel => 'स्रोत';

  @override
  String get familyDetailCoveringPolicies => 'कव्हर करणाऱ्या पॉलिसी';

  @override
  String get familyDetailManualSource => 'स्वतः जोडले';

  @override
  String get familyDetailAutoSource => 'पॉलिसीवरून शोधले';

  @override
  String familyDetailNoPolicies(Object name) {
    return '$name चा उल्लेख करणारी कोणतीही पॉलिसी आढळली नाही. त्यांचा समावेश असलेली पॉलिसी अपलोड करा किंवा स्वतः जोडा.';
  }

  @override
  String get relationshipDependent => 'आश्रित';

  @override
  String get relationshipSpouse => 'जोडीदार';

  @override
  String get relationshipChild => 'मूल';

  @override
  String get relationshipParent => 'पालक';

  @override
  String get relationshipSibling => 'भावंड';

  @override
  String get relationshipPrimaryInsured => 'प्राथमिक विमाकृत';

  @override
  String get relationshipOther => 'इतर';

  @override
  String get insuranceCardsTitle => 'विमा कार्ड्स';

  @override
  String get insuranceCardsEmptyTitle => 'अद्याप विमा कार्ड्स नाहीत';

  @override
  String get insuranceCardsEmptySubtitle =>
      'तुमच्या फोनवर महत्त्वाचे तपशील ठेवण्यासाठी पॉलिसी फाइल निवडा.';

  @override
  String get insuranceCardsChooseFile => 'पॉलिसी फाइल निवडा';

  @override
  String get insuranceCardsHeaderTitle => 'तुमचे पॉलिसी तपशील, नेण्यासाठी तयार';

  @override
  String get insuranceCardsHeaderSubtitle =>
      'पॉलिसी आणि विमा कंपनीच्या तपशीलांसाठी द्रुत संदर्भ. तुमच्या विमा कंपनीकडून पुराव्याच्या आवश्यकता तपासा.';

  @override
  String get insuranceCardsPolicyNumber => 'पॉलिसी क्रमांक';

  @override
  String get insuranceCardsCoverage => 'कव्हरेज';

  @override
  String get insuranceCardsPremium => 'प्रीमियम';

  @override
  String get insuranceCardsValidFrom => 'यापासून वैध';

  @override
  String get insuranceCardsValidUntil => 'यापर्यंत वैध';

  @override
  String get insuranceCardsCallInsurer => 'विमा कंपनीला कॉल करा';

  @override
  String get insuranceCardsShareCard => 'कार्ड शेअर करा';

  @override
  String get insuranceCardsExpired => 'कालबाह्य';

  @override
  String get insuranceCardsShareTitle => 'कवरवाईज पॉलिसी संदर्भ';

  @override
  String get insuranceCardsInsurerPrefix => 'विमा कंपनी: ';

  @override
  String get insuranceCardsPolicyNumberPrefix => 'पॉलिसी क्रमांक: ';

  @override
  String get insuranceCardsCoveragePrefix => 'कव्हरेज: ';

  @override
  String get insuranceCardsValidUntilPrefix => 'यापर्यंत वैध: ';

  @override
  String get insuranceCardsHelplinePrefix => 'विमा कंपनी हेल्पलाइन: ';

  @override
  String get insuranceCardsShareFooter =>
      'विमा कंपनी आणि स्रोत पॉलिसी दस्तऐवजासह वर्तमान तपशील तपासा.';

  @override
  String get insuranceCardsPhoneError => 'फोन अॅप उघडू शकलो नाही';

  @override
  String get insuranceCardsShareError => 'शेअरिंग पर्याय उघडू शकलो नाही';

  @override
  String get renewalTitle => 'नूतनीकरण कॅलेंडर';

  @override
  String get renewalEmptyTitle => 'कोणतीही पॉलिसी ट्रॅक केलेली नाही';

  @override
  String get renewalEmptySubtitle =>
      'नूतनीकरण तारखा ट्रॅक करण्यासाठी पॉलिसी फाइल निवडा.';

  @override
  String get renewalHeaderTitle => 'नूतनीकरणे नजरेआड होऊ देऊ नका';

  @override
  String get renewalHeaderSubtitle =>
      'प्रथम कशाकडे लक्ष देणे आवश्यक आहे ते पहा आणि विमा कंपनीचे संपर्क तपशील जवळ ठेवा.';

  @override
  String get renewalReminderText =>
      'पॉलिसी कालबाह्य होण्याच्या ३०, १५, ७ आणि १ दिवस आधी स्मरणपत्रे सेट करा.';

  @override
  String get renewalRemindersOn => 'नूतनीकरण स्मरणपत्रे चालू आहेत.';

  @override
  String get renewalNotificationsOff =>
      'सूचना बंद आहेत. तुम्ही सेटिंग्जमध्ये त्या सुरू करू शकता.';

  @override
  String get renewalSectionExpired => 'कालबाह्य';

  @override
  String get renewalSectionExpiringSoon => 'लवकरच कालबाह्य होत आहे';

  @override
  String get renewalSectionActive => 'सक्रिय';

  @override
  String get renewalSectionNoDate => 'कालबाह्य तारीख आढळली नाही';

  @override
  String get renewalNoDateInfo =>
      'तुमच्या पॉलिसीमध्ये कालबाह्य तारीख आढळली नाही — तुमचे पॉलिसी दस्तऐवज तपासा';

  @override
  String get renewalInsurerNotFound => 'विमा कंपनी आढळली नाही';

  @override
  String renewalExpires(Object date) {
    return '$date रोजी कालबाह्य होते';
  }

  @override
  String get renewalContactToRenew => 'नूतनीकरणासाठी विमा कंपनीशी संपर्क साधा';

  @override
  String get renewalStartRenewal => 'नूतनीकरण सुरू करा';

  @override
  String renewalRenewTitle(Object type) {
    return '$type नूतनीकरण';
  }

  @override
  String renewalContactInsurer(Object insurer) {
    return 'नूतनीकरण प्रक्रिया सुरू करण्यासाठी $insurer शी संपर्क साधा.';
  }

  @override
  String get renewalCallHelpline => 'हेल्पलाइनवर कॉल करा';

  @override
  String get renewalSendEmail => 'ईमेल पाठवा';

  @override
  String renewalContactInfoNotFound(Object insurer) {
    return '$insurer साठी संपर्क माहिती आढळली नाही. तुमचे पॉलिसी दस्तऐवज तपासा किंवा थेट विमा कंपनीशी संपर्क साधा.';
  }

  @override
  String get renewalPhoneDialerError => 'फोन डायलर उघडू शकलो नाही';

  @override
  String get renewalEmailClientError => 'ईमेल क्लायंट उघडू शकलो नाही';

  @override
  String renewalExpiringPolicies(Object date) {
    return '$date रोजी कालबाह्य होणाऱ्या पॉलिसी';
  }

  @override
  String renewalExpiringCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'या तारखेला $count पॉलिसी कालबाह्य',
      one: 'या तारखेला 1 पॉलिसी कालबाह्य',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'सेटिंग्ज';

  @override
  String get settingsHeaderTitle => 'तुमचे अॅप, तुमची प्राधान्ये';

  @override
  String get settingsHeaderSubtitle =>
      'प्रवेश, स्मरणपत्रे आणि या डिव्हाइसवर काय ठेवायचे ते व्यवस्थापित करा.';

  @override
  String get settingsSectionPlan => 'योजना';

  @override
  String get settingsSectionAccount => 'खाते';

  @override
  String get settingsSectionExperience => 'अनुभव';

  @override
  String get settingsSectionAppDetails => 'अॅप तपशील';

  @override
  String get settingsSectionPrivacy => 'गोपनीयता आणि संमती';

  @override
  String get settingsSectionDeviceData => 'डिव्हाइस डेटा';

  @override
  String settingsCurrentPlan(Object plan) {
    return 'सध्याची योजना: $plan';
  }

  @override
  String get settingsQaPacks => 'प्रश्न-उत्तर पॅक';

  @override
  String settingsQuestionsInPacks(Object count) {
    return 'पॅकमध्ये $count प्रश्न';
  }

  @override
  String get settingsBuyQuestions => 'सदस्यत्वाशिवाय प्रश्न खरेदी करा';

  @override
  String get settingsRenews => 'नूतनीकरण होते';

  @override
  String get settingsSignedIn => 'साइन इन केले';

  @override
  String get settingsSupabaseAccount => 'सुपाबेस खाते';

  @override
  String get settingsAccountLinked => 'खाते लिंक केले';

  @override
  String get settingsLinkYourPhone => 'तुमचा फोन लिंक करा';

  @override
  String settingsConnectedAs(Object phone) {
    return '$phone म्हणून कनेक्ट केले';
  }

  @override
  String get settingsBackupSubtitle =>
      'पॉलिसी बॅकअप करा आणि दुसऱ्या डिव्हाइसवर वापरा';

  @override
  String get settingsAppearance => 'स्वरूप';

  @override
  String settingsThemeMode(Object mode) {
    return '$mode';
  }

  @override
  String get settingsNotifications => 'सूचना';

  @override
  String get settingsNotificationsSubtitle =>
      'नूतनीकरण स्मरणपत्रे आणि शांत तास';

  @override
  String get settingsSmartSuggestions => 'कव्हरेज अंतर्दृष्टी';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'लवकरच: तुमच्या पॉलिसी तपशीलांवर आधारित कव्हरेज मार्गदर्शन';

  @override
  String get settingsServiceEndpoint => 'सेवा एंडपॉइंट';

  @override
  String get settingsClearDataTitle => 'सर्व स्थानिक डेटा साफ करायचा?';

  @override
  String get settingsClearDataAction => 'स्थानिक डेटा साफ करा';

  @override
  String get settingsClearDataContent =>
      'यामुळे या डिव्हाइसवरील सर्व स्थानिक कागदपत्रे, पॉलिसी सारांश, प्रश्न-उत्तर इतिहास, कुटुंब सदस्य आणि सत्र डेटा काढून टाकला जाईल. सर्व्हरवरील अपलोड केलेल्या कागदपत्रांवर परिणाम होणार नाही. ही क्रिया या डिव्हाइसवरून पूर्ववत करता येणार नाही.';

  @override
  String get settingsClearDataSuccess =>
      'या डिव्हाइसवरून सर्व स्थानिक डेटा साफ केला.';

  @override
  String get settingsClearDataSubtitle =>
      'कागदपत्रे, सारांश, इतिहास आणि कुटुंब सदस्य काढा';

  @override
  String get settingsNoConsentRecords => 'कोणतेही संमती रेकॉर्ड नाहीत';

  @override
  String get settingsConsentRecorded =>
      'तुम्ही तुमची पहिली पॉलिसी अपलोड करता तेव्हा संमती रेकॉर्ड केली जाते';

  @override
  String get settingsConsentPolicyProcessing => 'पॉलिसी प्रक्रिया';

  @override
  String get settingsConsentAnalytics => 'वापर विश्लेषण';

  @override
  String get settingsConsentLeadCapture => 'संपर्क कॅप्चर';

  @override
  String get settingsConsentTermsAccepted => 'अटी स्वीकारल्या';

  @override
  String settingsConsentGranted(Object date, Object version) {
    return '$date रोजी मंजूर • v$version';
  }

  @override
  String settingsConsentRevoked(Object date) {
    return '$date रोजी रद्द';
  }

  @override
  String get settingsConsentActive => 'सक्रिय';

  @override
  String get settingsConsentRevokedLabel => 'रद्द केले';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsLanguageSubtitle => 'तुमची प्राधान्यकृत अॅप भाषा निवडा';

  @override
  String get profileTitle => 'प्रोफाइल';

  @override
  String get profileDefaultHeader => 'तुमचे कवरवाईज प्रोफाइल';

  @override
  String get profileLinkedHeader =>
      'लिंक केले आणि तुमच्या सर्व डिव्हाइसवर तयार.';

  @override
  String get profileUnlinkedHeader =>
      'तुमचे पॉलिसी वर्कस्पेस सध्या या डिव्हाइसवरच राहते.';

  @override
  String get profileCreateAccount => 'सुरक्षित खाते तयार करा';

  @override
  String get profileRestoreWorkspace =>
      'हे पॉलिसी वर्कस्पेस डिव्हाइसवर पुनर्संचयित करा';

  @override
  String get profileSignedInAccount => 'साइन इन केलेले खाते';

  @override
  String get profileWorkspaceLinked =>
      'वर्कस्पेस तुमच्या खात्याशी लिंक केले आहे';

  @override
  String get profilePhoneNumber => 'फोन नंबर';

  @override
  String get profileNotLinked => 'लिंक केले नाही';

  @override
  String get profileSecureSession => 'सुरक्षित सत्र';

  @override
  String get profileAccountSessionActive =>
      'या डिव्हाइसवर खाते सत्र सक्रिय आहे';

  @override
  String get profileAnonymousSessionActive =>
      'या डिव्हाइसवर अनामिक सत्र सक्रिय आहे';

  @override
  String get profileAppSection => 'अॅप';

  @override
  String get profileFamilySection => 'कुटुंब';

  @override
  String get profilePrivacySection => 'गोपनीयता';

  @override
  String get profileDeviceFirstStorage => 'डिव्हाइस-प्रथम स्टोरेज';

  @override
  String get profileDeviceFirstSubtitle =>
      'हे डिव्हाइस संरक्षित स्थानिक कॅशे ठेवते; सिंकसाठी खाते डेटा सुरक्षितपणे संग्रहित केला जाऊ शकतो.';

  @override
  String get profileDeleteAccount => 'खाते हटवा';

  @override
  String get profileDeleteAccountSubtitle =>
      'खाते आणि सर्व सर्व्हर डेटा कायमचे काढा';

  @override
  String get profileCreateAccountFirst => 'ते हटवण्यासाठी प्रथम खाते तयार करा';

  @override
  String get profileFooter =>
      'कवरवाईज तुम्हाला तुमच्या पॉलिसी समजण्यास मदत करते. ते विमा विकत नाही.';

  @override
  String get profileDeleteConfirmTitle => 'खाते कायमचे हटवायचे?';

  @override
  String get profileDeleteConfirmHeader => 'हे कायमचे हटवले जाईल:';

  @override
  String get profileDeleteItemAccount => '• तुमचे कवरवाईज खाते';

  @override
  String get profileDeleteItemDocs =>
      '• आमच्या सर्व्हरवरील सर्व अपलोड केलेली पॉलिसी कागदपत्रे';

  @override
  String get profileDeleteItemSummaries =>
      '• सर्व पॉलिसी सारांश आणि एम्बेडिंग्ज';

  @override
  String get profileDeleteItemHistory =>
      '• सर्व्हरवरील तुमचा प्रश्न-उत्तर इतिहास';

  @override
  String get profileDeleteWarning =>
      'ही क्रिया या डिव्हाइसवरून पूर्ववत करता येणार नाही. या डिव्हाइसवरील स्थानिक डेटा सेटिंग्ज → स्थानिक डेटा साफ करा याद्वारे स्वतंत्रपणे साफ केला जाईल.';

  @override
  String get profileDeleteEverything => 'सर्वकाही हटवा';

  @override
  String get profileDeleteTypeTitle => 'पुष्टी करण्यासाठी DELETE टाइप करा';

  @override
  String get profileDeleteTypeWarning =>
      'ही तुमची शेवटची संधी आहे. सर्व डेटा कायमचा हटविला जाईल.';

  @override
  String get profileDeleteTypeHint => 'DELETE टाइप करा';

  @override
  String get profileDeletePermanently => 'कायमचे हटवा';

  @override
  String get profileDeletingAccount => 'खाते हटवत आहे...';

  @override
  String profileDeleteComplete(Object docs, Object files) {
    return 'खाते हटवले. $docs दस्तऐवज आणि $files स्टोरेज फाइल काढल्या.';
  }

  @override
  String profileDeletePartial(Object failed) {
    return 'खाते हटवणे अंशतः पूर्ण झाले. अयशस्वी टप्पे: $failed. सर्व्हर हटवणे पूर्ण झाले आहे असे समजू नका.';
  }

  @override
  String profileDeleteRequested(Object status) {
    return 'खाते हटवण्याची विनंती केली. स्थिती: $status.';
  }

  @override
  String get profileDeletionStatusTitle => 'खाते हटवण्याची स्थिती';

  @override
  String get profileDeletionStatusPending =>
      'हटवणे रांगेत आहे. सर्व्हर मिटवण्याची पडताळणी होईपर्यंत तुमचे खाते सक्रिय राहील.';

  @override
  String get profileDeletionStatusRunning =>
      'हटवण्याची प्रक्रिया सुरू आहे. मिटवणे सुरू असताना नवीन खाते लेखन थांबवले आहे.';

  @override
  String get profileDeletionStatusFailed =>
      'शेवटच्या हटवण्याच्या प्रयत्नाकडे लक्ष देणे आवश्यक आहे.';

  @override
  String get profileDeletionStatusRefresh => 'स्थिती रीफ्रेश करा';

  @override
  String get profileDeletionStatusUnavailable =>
      'हटवण्याची स्थिती तात्पुरती अनुपलब्ध आहे.';

  @override
  String profileInFlightWarning(Object count) {
    return '$count दस्तऐवज प्रक्रिया करत आहेत. खाते हटवण्यापूर्वी प्रक्रिया पूर्ण होण्याची प्रतीक्षा करा.';
  }

  @override
  String get upgradeTitle => 'तुमची योजना निवडा';

  @override
  String get upgradeBillingUnavailable =>
      'बिलिंग अद्याप उपलब्ध नाही. कृपया नंतर पुन्हा प्रयत्न करा.';

  @override
  String get upgradeCouldNotOpenSettings => 'सदस्यत्व सेटिंग्ज उघडू शकलो नाही';

  @override
  String upgradeSuccess(Object plan) {
    return '$plan मध्ये सुधारणा केली! तुमच्या नवीन वैशिष्ट्यांचा आनंद घ्या.';
  }

  @override
  String get upgradePurchaseCancelled => 'खरेदी रद्द करण्यात आली.';

  @override
  String get upgradeMonthly => 'मासिक';

  @override
  String get upgradeAnnual => 'वार्षिक';

  @override
  String get upgradeSaveUpTo => '४४% पर्यंत बचत करा';

  @override
  String get upgradeCurrentPlan => 'सध्याची योजना';

  @override
  String get upgradeFreeForever => 'नेहमी विनामूल्य';

  @override
  String upgradeTo(Object plan) {
    return '$plan मध्ये सुधारणा करा';
  }

  @override
  String get upgradeComparePlans => 'योजनांची तुलना करा';

  @override
  String get upgradeQuestions => 'प्रश्न';

  @override
  String get upgradeFaqSwitch => 'मी योजना बदलू शकतो का?';

  @override
  String get upgradeFaqSwitchAnswer =>
      'तुम्ही तुमच्या अॅप स्टोअर किंवा प्ले स्टोअर सदस्यत्व सेटिंग्जद्वारे योजना बदल व्यवस्थापित करू शकता.';

  @override
  String get upgradeFaqPacks => 'माझ्या प्रश्न-उत्तर पॅकचे काय?';

  @override
  String get upgradeFaqPacksAnswer =>
      'पॅक प्रश्न सक्रिय राहतात आणि तुमचा मासिक सदस्यत्व कोटा संपल्यानंतर वापरले जातात.';

  @override
  String get upgradeFaqCancel => 'मी कसे रद्द करू?';

  @override
  String get upgradeFaqCancelAnswer =>
      'तुमच्या अॅप स्टोअर किंवा प्ले स्टोअर सदस्यत्व सेटिंग्जमधून कधीही रद्द करा.';

  @override
  String get upgradeAccessUntil => 'यापर्यंत प्रवेश';

  @override
  String get upgradePolicies => 'पॉलिसी';

  @override
  String get upgradeQaPerMonth => 'दरमहा प्रश्न-उत्तर';

  @override
  String get upgradeComparePolicies => 'पॉलिसींची तुलना करा';

  @override
  String get upgradeFamilyView => 'कुटुंब दृश्य';

  @override
  String get upgradeCloudSync => 'क्लाउड सिंक';

  @override
  String get upgradeEmergency => 'आणीबाणी';

  @override
  String get upgradeAnnualReview => 'वार्षिक पुनरावलोकन';

  @override
  String get upgradeAdvancedSearch => 'प्रगत शोध';

  @override
  String accountTitle(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'खाते तयार करा',
        'other': 'साइन इन करा',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountHeaderTitle => 'तुमचे पॉलिसी वर्कस्पेस संरक्षित करा';

  @override
  String get accountHeaderSubtitle =>
      'खाते तुम्हाला दुसऱ्या डिव्हाइसवर तुमचे कवरवाईज वर्कस्पेस पुनर्संचयित करू देते.';

  @override
  String get accountNameLabel => 'नाव (पर्यायी)';

  @override
  String get accountEmailLabel => 'ईमेल';

  @override
  String get accountPasswordLabel => 'पासवर्ड';

  @override
  String get accountResendBanner =>
      'तुमचा ईमेल अद्याप पुष्टी केलेला नाही. तुमचा इनबॉक्स तपासा किंवा पुन्हा पाठवा.';

  @override
  String get accountResend => 'पुन्हा पाठवा';

  @override
  String get accountForgotPassword => 'पासवर्ड विसरलात?';

  @override
  String get accountResendVerification => 'पुष्टीकरण ईमेल पुन्हा पाठवा';

  @override
  String accountSwitchToSignIn(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'आधीपासून खाते आहे? साइन इन करा',
        'other': 'कवरवाईजवर नवीन आहात? खाते तयार करा',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountGoogleSignIn => 'गूगलसह सुरू ठेवा';

  @override
  String get accountAuthNotConfigured =>
      'या बिल्डसाठी खाते प्रमाणीकरण कॉन्फिगर केलेले नाही.';

  @override
  String get accountEnterEmail => 'कृपया तुमचा ईमेल पत्ता प्रविष्ट करा.';

  @override
  String get accountPasswordTooShort => 'पासवर्ड किमान ८ वर्णांचा असावा.';

  @override
  String get accountInvalidEmail => 'कृपया वैध ईमेल पत्ता प्रविष्ट करा.';

  @override
  String get accountCheckEmail =>
      'खात्याची पुष्टी करण्यासाठी तुमचा ईमेल तपासा, नंतर साइन इन करा.';

  @override
  String get accountIncorrectCredentials =>
      'चुकीचा ईमेल किंवा पासवर्ड. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get accountAlreadyRegistered =>
      'या ईमेलसह खाते आधीपासून अस्तित्वात आहे. साइन इन करून पहा.';

  @override
  String get accountPasswordRequirements =>
      'पासवर्ड आवश्यकता पूर्ण करत नाही. किमान ८ वर्ण वापरा.';

  @override
  String accountCouldNotAction(String action) {
    String _temp0 = intl.Intl.selectLogic(
      action,
      {
        'true': 'खाते तयार',
        'other': 'खात्यात साइन इन',
      },
    );
    return '$_temp0 करू शकलो नाही.';
  }

  @override
  String get accountEnterEmailFirst =>
      'प्रथम वर तुमचा ईमेम प्रविष्ट करा, नंतर पासवर्ड विसरलात वर टॅप करा.';

  @override
  String get accountResetEmailSent =>
      'पासवर्ड रीसेट ईमेल पाठवला. तुमचा इनबॉक्स तपासा.';

  @override
  String get accountCouldNotReset =>
      'रीसेट ईमेल पाठवू शकलो नाही. तुमचा ईमेल तपासा आणि पुन्हा प्रयत्न करा.';

  @override
  String get accountEnterEmailResend =>
      'प्रथम वर तुमचा ईमेल प्रविष्ट करा, नंतर पुष्टीकरण पुन्हा पाठवा वर टॅप करा.';

  @override
  String get accountVerificationSent =>
      'पुष्टीकरण ईमेल पाठवला. तुमचा इनबॉक्स तपासा.';

  @override
  String get accountCouldNotVerify =>
      'पुष्टीकरण ईमेल पाठवू शकलो नाही. नंतर पुन्हा प्रयत्न करा.';

  @override
  String get accountCouldNotGoogle =>
      'गूगलसह साइन इन करू शकलो नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get notifTitle => 'नूतनीकरण स्मरणपत्रे';

  @override
  String get notifHeaderTitle => 'नूतनीकरणाच्या आधीच सजग रहा';

  @override
  String get notifHeaderSubtitle =>
      'हे डिव्हाइस तुम्हाला केव्हा आठवण करून द्यावे ते निवडा. सूचना या स्मरणपत्रे आहेत, विमा कंपनीच्या नूतनीकरण सूचना नव्हेत.';

  @override
  String get notifMasterToggle => 'नूतनीकरण स्मरणपत्रे';

  @override
  String get notifEnabledSubtitle => 'या डिव्हाइसवर सुरू';

  @override
  String get notifDisabledSubtitle => 'बंद';

  @override
  String get notifSectionRemindMe => 'कालबाह्य होण्यापूर्वी मला आठवण करून द्या';

  @override
  String get notifSectionRemindMeDescription =>
      'तुमची पॉलिसी कालबाह्य होण्यापूर्वी किती दिवस आधी स्मरणपत्र प्राप्त करायचे ते निवडा.';

  @override
  String get notifNoReminderTimes => 'कोणतीही स्मरणपत्र वेळ निवडलेली नाही.';

  @override
  String get notifSectionQuietHours => 'शांत तास';

  @override
  String get notifSectionQuietHoursDescription =>
      'या तासांदरम्यान सूचना नाहीत.';

  @override
  String get notifStartTime => 'सुरू वेळ';

  @override
  String get notifEndTime => 'समाप्त वेळ';

  @override
  String get notifSectionPerPolicy => 'प्रति-पॉलिसी स्मरणपत्रे';

  @override
  String get notifSectionPerPolicyDescription =>
      'वैयक्तिक पॉलिसीसाठी स्मरणपत्रे चालू/बंद करा.';

  @override
  String get notifPreferencesSaved => 'प्राधान्ये जतन केली';

  @override
  String get docsTitle => 'कागदपत्रे';

  @override
  String docsSlotsUsed(Object count) {
    return '$count पैकी 5 विनामूल्य पॉलिसी स्लॉट वापरले';
  }

  @override
  String get docsTypeChanged => 'प्रकार बदलला';

  @override
  String get docsRemovedLocal =>
      'या डिव्हाइसवरून काढले. सर्व्हर कॉपीवर परिणाम झाला नाही.';

  @override
  String get docsReplaceSuccess => 'दस्तऐवज यशस्वीरित्या बदलला';

  @override
  String get docsPreview => 'पूर्वावलोकन';

  @override
  String get docsDownloadSource => 'स्रोत डाउनलोड करा';

  @override
  String get docsChangeType => 'प्रकार बदला';

  @override
  String get docsAskQuestions => 'प्रश्न विचारा';

  @override
  String get docsReadingPolicy => 'पॉलिसी वाचत आहे';

  @override
  String get docsUploadRequired => 'सर्व्हरवर अपलोड आवश्यक';

  @override
  String get docsRetryUpload => 'अपलोड पुन्हा करा';

  @override
  String get docsNeedsAttention => 'लक्ष आवश्यक';

  @override
  String get docsReadyForQuestions => 'प्रश्नांसाठी तयार';

  @override
  String get docsSaved => 'जतन केले';

  @override
  String get docsRefreshingTypes => 'दस्तऐवज प्रकार रीफ्रेश करत आहे...';

  @override
  String get docsTypesRefreshed => 'दस्तऐवज प्रकार यशस्वीरित्या रीफ्रेश केले!';

  @override
  String get docsReplace => 'बदला';

  @override
  String get docsRemoveFromDevice => 'या डिव्हाइसवरून काढा';

  @override
  String get docsRemoveFromDeviceTitle => 'या डिव्हाइसवरून काढायचे?';

  @override
  String get docsDeletePolicy => 'पॉलिसी हटवा';

  @override
  String get docsDeletePolicyTitle => 'पॉलिसी हटवायची?';

  @override
  String docsDeletePolicyContent(Object filename) {
    return 'यामुळे \"$filename\" कवरवाईज आणि या डिव्हाइसवरून कायमचे हटवले जाईल.';
  }

  @override
  String get docsDeleted => 'पॉलिसी हटवली';

  @override
  String get docsReplaceDocumentTitle => 'दस्तऐवज बदलायचा?';

  @override
  String get docsReplaceDocument => 'दस्तऐवज बदला';

  @override
  String get docsCurrentDocument => 'सध्याचा दस्तऐवज';

  @override
  String get docsSelectReplacement => 'बदली फाइल निवडा';

  @override
  String docsReplaceWillDelete(Object filename) {
    return 'यामुळे \"$filename\" हटवले जाईल आणि नवीन फाइलसह बदलले जाईल.';
  }

  @override
  String get docsReplaceAnalysisLost =>
      'जुन्या दस्तऐवजाचे विश्लेषण नष्ट होईल. नवीन दस्तऐवज ताज्या पद्धतीने प्रक्रिया केली जाईल.';

  @override
  String docsUploadedDate(Object date) {
    return 'अपलोड केले: $date';
  }

  @override
  String get docsClearReplacement => 'बदली फाइल साफ करा';

  @override
  String get docsArchive => 'संग्रहित करा';

  @override
  String get docsArchived => 'संग्रहित';

  @override
  String get docsRestore => 'पुनर्संचयित करा';

  @override
  String get docsRestored => 'पॉलिसी पुनर्संचयित केली';

  @override
  String get docsArchivedSuccess => 'पॉलिसी संग्रहित केली';

  @override
  String get docsShowArchived => 'संग्रहित दाखवा';

  @override
  String get docsHideArchived => 'संग्रहित लपवा';

  @override
  String get docsArchiveConfirmTitle => 'पॉलिसी संग्रहित करायची?';

  @override
  String docsArchiveConfirmContent(Object filename) {
    return '\"$filename\" तुमच्या सक्रिय पॉलिसी यादीतून लपवले जाईल. तुम्ही संग्रहातून कधीही पुनर्संचयित करू शकता.';
  }

  @override
  String get docsDeletePermanentWarning =>
      'यामुळे पॉलिसी कवरवाईज आणि या डिव्हाइसवरून कायमची हटवली जाईल. त्याऐवजी संग्रहित करण्याचा विचार करा.';

  @override
  String get docsLimitWarning =>
      'तुम्ही तुमच्या विनामूल्य स्टोरेज मर्यादेजवळ आहात. जागा मोकळी करण्यासाठी जुन्या पॉलिसी संग्रहित करा.';

  @override
  String docsLimitCountdown(Object limit, Object remaining, Object used) {
    return '$limit पैकी $used स्लॉट वापरले — $remaining शिल्लक';
  }

  @override
  String docsLimitRemaining(Object remaining) {
    return '$remaining विनामूल्य स्लॉट शिल्लक';
  }

  @override
  String get docsSortLabel => 'क्रमवारी लावा';

  @override
  String get docsFilterLabel => 'फिल्टर';

  @override
  String get docsSortDateNewest => 'नवीन प्रथम';

  @override
  String get docsSortDateOldest => 'जुने प्रथम';

  @override
  String get docsSortNameAZ => 'नाव अ–आ';

  @override
  String get docsSortNameZA => 'नाव आ–अ';

  @override
  String get docsSortType => 'प्रकारानुसार';

  @override
  String get docsFilterAll => 'सर्व प्रकार';

  @override
  String docsFilterResultCount(Object count, Object total) {
    return '$total पैकी $count पॉलिसी';
  }

  @override
  String get docsRenameTitle => 'पॉलिसीचे नाव बदला';

  @override
  String get docsRenameHint => 'नवीन नाव प्रविष्ट करा';

  @override
  String get docsRenameSave => 'जतन करा';

  @override
  String get docsRenameSuccess => 'पॉलिसीचे नाव बदलले';

  @override
  String get docsRenameEmpty => 'नाव रिकामे असू शकत नाही';

  @override
  String get tosTitle => 'सेवेच्या अटी';

  @override
  String get tosCopySuccess => 'सेवेच्या अटी क्लिपबोर्डवर कॉपी केल्या';

  @override
  String get tosLoadError => 'सेवेच्या अटी लोड करता आल्या नाहीत.';

  @override
  String get privacyTitle => 'गोपनीयता धोरण';

  @override
  String get privacyCopySuccess => 'गोपनीयता धोरण क्लिपबोर्डवर कॉपी केले';

  @override
  String get privacyLoadError => 'गोपनीयता धोरण लोड करता आले नाही.';

  @override
  String get processingReceived => 'प्राप्त झाले';

  @override
  String get processingProcessing => 'प्रक्रिया करत आहे';

  @override
  String get processingCategorising => 'वर्गीकरण करत आहे';

  @override
  String get processingFinishingUp => 'अंतिम टप्पा';

  @override
  String get processingReceivedDesc => 'तुमची पॉलिसी प्राप्त झाली आहे';

  @override
  String get processingProcessingDesc => 'मजकूर वाचत आणि काढत आहे';

  @override
  String get processingCategorisingDesc =>
      'पॉलिसी प्रकार आणि विमा कंपनी ठरवत आहे';

  @override
  String get processingFinishingUpDesc => 'तुमची पॉलिसी शोधण्यायोग्य करत आहे';

  @override
  String get onboardSubtitle =>
      'तुमच्या वास्तविक पॉलिसीवर आधारित स्पष्ट उत्तरे मिळवा — इंटरनेटवरून सामान्य सल्ला नव्हे.';

  @override
  String get onboardNoDataStored =>
      'तुमच्या संमतीशिवाय कोणताही पॉलिसी डेटा संग्रहित किंवा शेअर केला जाणार नाही.';

  @override
  String get onboardTermsAcceptance =>
      'मी गोपनीयता धोरण आणि सेवेच्या अटी वाचल्या आहेत आणि स्वीकारतो/ते.';

  @override
  String get emergencyTitle => 'आणीबाणी';

  @override
  String get emergencyHelpAtGlance => 'एक दृष्टीक्षेपात मदत';

  @override
  String get dashboardQuickActions => 'द्रुत क्रिया';

  @override
  String get dashboardEmergency => 'आणीबाणी';

  @override
  String get dashboardAddPolicy => 'पॉलिसी फाइल जोडा';

  @override
  String get searchTitle => 'शोध';

  @override
  String get searchHint => 'सर्व पॉलिसीमध्ये शोधा...';

  @override
  String get searchNoResults => 'कोणतेही निकाल सापडले नाहीत';

  @override
  String get coverageGapTitle => 'कव्हरेज पुनरावलोकन';

  @override
  String get coverageGapEmpty =>
      'उपलब्ध पॉलिसी मजकुरातून अद्याप कोणतेही संभाव्य कव्हरेज प्रश्न चिन्हांकित केले गेले नाहीत';

  @override
  String get literacyTitle => 'विमा शब्दकोश';

  @override
  String get literacySearchHint => 'अटी शोधा...';

  @override
  String get docTypePickerTitle => 'दस्तऐवज प्रकार निवडा';

  @override
  String get fileTypeSupported => 'समर्थित फाइल प्रकार';

  @override
  String get fileTypePdf => 'PDF दस्तऐवज';

  @override
  String get fileTypeImage => 'प्रतिमा (JPEG, PNG)';

  @override
  String get fileTypeMaxSize => 'कमाल फाइल आकार: २० MB';

  @override
  String get fileTypeUnsupported =>
      'हा फाइल प्रकार समर्थित नाही. कृपया PDF किंवा प्रतिमा निवडा.';

  @override
  String get whatIfTitle => 'काय-जर कॅल्क्युलेटर';

  @override
  String get whatIfDescription =>
      'विविध कव्हरेज पर्याय तुमच्या अंदाजित खर्चावर कसा परिणाम करतात ते एक्सप्लोर करा.';

  @override
  String get batchPickMultiple => 'एकाधिक फाइल्स निवडा';

  @override
  String batchUploadingPendingCount(Object count) {
    return '$count फाइल अपलोड करत आहे…';
  }

  @override
  String batchUploadingProgress(Object done, Object total) {
    return '$total पैकी $done अपलोड केले';
  }

  @override
  String get batchCompleted => 'सर्व फाइल्स अपलोड झाल्या';

  @override
  String batchCompletedCount(Object count) {
    return '$count फाइल्स यशस्वीरित्या अपलोड झाल्या';
  }

  @override
  String get batchSomeFailed => 'काही अपलोड अयशस्वी झाले';

  @override
  String batchFailedCount(Object failed, Object total) {
    return '$total पैकी $failed फाइल्स अयशस्वी';
  }

  @override
  String batchFileTooLargeMB(Object maxMB) {
    return 'ही फाइल $maxMB MB मर्यादा ओलांडते आणि वगळली जाईल';
  }

  @override
  String get batchFileUnsupported => 'असमर्थित फाइल प्रकार — वगळले';

  @override
  String get batchDuplicateSkipped => 'डुप्लिकेट — वगळले';

  @override
  String get batchRetryFailed => 'अयशस्वी अपलोड पुन्हा करा';

  @override
  String get batchDone => 'झाले';

  @override
  String get batchAddMore => 'अधिक फाइल्स जोडा';

  @override
  String get batchSelectAll => 'सर्व निवडा';

  @override
  String get familyVisTitle => 'कव्हरेज नकाशा';

  @override
  String get familyVisHeader => 'पॉलिसी-सूचीबद्ध कुटुंब सदस्य';

  @override
  String get familyVisSubtitle =>
      'प्रत्येक पॉलिसीत सूचीबद्ध कुटुंब सदस्यांची तुलना करा; तुमच्या विमा कंपनीकडून कव्हरेज तपासा.';

  @override
  String get familyVisMembers => 'कुटुंब सदस्य';

  @override
  String get familyVisPolicies => 'पॉलिसी';

  @override
  String get familyVisEmptyTitle => 'अद्याप कव्हरेज डेटा नाही';

  @override
  String get familyVisEmptySubtitle =>
      'तुमच्या पॉलिसी दस्तऐवजात सूचीबद्ध नावांची तुलना करण्यासाठी पॉलिसी अपलोड करा आणि कुटुंब सदस्य जोडा.';

  @override
  String familyVisNoPolicies(Object name) {
    return 'अद्याप $name ची सूची करणारी कोणतीही पॉलिसी नाही.';
  }

  @override
  String get familyVisSeeMap => 'पॉलिसी सदस्य नकाशा पहा';

  @override
  String get coverageShareSummary => 'Share summary';

  @override
  String get coverageShareSubject => 'CoverWise policy coverage summary';

  @override
  String get coverageShareError => 'Could not open sharing options';
}
