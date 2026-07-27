// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Gujarati (`gu`).
class AppLocalizationsGenGu extends AppLocalizationsGen {
  AppLocalizationsGenGu([String locale = 'gu']) : super(locale);

  @override
  String get appName => 'CoverWise';

  @override
  String get commonShowLess => 'ઓછું બતાવો';

  @override
  String get commonShowMore => 'વધુ બતાવો';

  @override
  String get cancel => 'રદ કરો';

  @override
  String get save => 'સાચવો';

  @override
  String get remove => 'દૂર કરો';

  @override
  String get add => 'ઉમેરો';

  @override
  String get clear => 'સાફ કરો';

  @override
  String get enable => 'સક્રિય કરો';

  @override
  String get disable => 'નિષ્ક્રિય કરો';

  @override
  String get version => 'આવૃત્તિ';

  @override
  String get upgrade => 'અપગ્રેડ કરો';

  @override
  String get manage => 'વ્યવસ્થાપિત કરો';

  @override
  String get signOut => 'સાઇન આઉટ';

  @override
  String get signIn => 'સાઇન ઇન';

  @override
  String get createAccount => 'ખાતું બનાવો';

  @override
  String get buy => 'ખરીદો';

  @override
  String get startAsking => 'પૂછવાનું શરૂ કરો';

  @override
  String get getMore => 'વધુ મેળવો';

  @override
  String get getPacks => 'પૅક મેળવો';

  @override
  String get viewPolicy => 'પોલિસી જુઓ';

  @override
  String policyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count પોલિસીઓ',
      one: '1 પોલિસી',
    );
    return '$_temp0';
  }

  @override
  String resultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count પરિણામો',
      one: '1 પરિણામ',
    );
    return '$_temp0';
  }

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count દિવસો',
      one: '1 દિવસ',
    );
    return '$_temp0';
  }

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'દિવસોમાં',
      one: 'દિવસમાં',
    );
    return '$count $_temp0 સમાપ્ત થાય છે';
  }

  @override
  String daysLeft(Object days) {
    return '$days દિવસ બાકી';
  }

  @override
  String daysBefore(Object days) {
    return '$days દિવસ પહેલાં';
  }

  @override
  String get qaScreenTitle => 'CoverWise ને પૂછો';

  @override
  String get qaTabSuggested => 'સૂચવેલ';

  @override
  String get qaTabYourQuestion => 'તમારો પ્રશ્ન';

  @override
  String get qaTabHistory => 'ઇતિહાસ';

  @override
  String get qaNoQuestionsRemaining => 'કોઈ પ્રશ્ન બાકી નથી';

  @override
  String qaQuestionsLeft(Object remaining) {
    return '$remaining પ્રશ્નો બાકી';
  }

  @override
  String qaMonthlyPlusPack(Object monthly, Object pack, Object packs) {
    return '$monthly માસિક + $pack પૅક';
  }

  @override
  String qaPackQuestions(Object count, Object packs) {
    return '$packs પૅકમાં $count પ્રશ્નો';
  }

  @override
  String qaMonthlyPlan(Object remaining) {
    return 'આ મહિને $remaining પ્રશ્નો બાકી';
  }

  @override
  String get qaAskAbout => 'વિશે પૂછો';

  @override
  String get qaQuestionSource => 'પ્રશ્ન સ્રોત';

  @override
  String qaAllDocuments(Object count) {
    return 'બધા દસ્તાવેજો ($count)';
  }

  @override
  String get qaSingleDocument => 'એક દસ્તાવેજ';

  @override
  String get qaNoDocumentSelected => 'કોઈ દસ્તાવેજ પસંદ થયો નથી';

  @override
  String get qaSearchAllPolicies => 'તમારી બધી અપલોડ કરેલી પોલિસીઓમાં શોધો';

  @override
  String get qaAskAboutDescription =>
      'તમારી પોલિસીમાં કવરેજ, બાકાત, તારીખો અથવા શબ્દરચના વિશે પૂછો.';

  @override
  String get qaHintText => 'દા.ત., અસરકારક તારીખ શું છે?';

  @override
  String get qaClearQuestion => 'પ્રશ્ન સાફ કરો';

  @override
  String get qaNoHistoryYet => 'હજી સુધી કોઈ પ્રશ્ન ઇતિહાસ નથી';

  @override
  String get qaSearchHistory => 'ઇતિહાસમાં શોધો...';

  @override
  String qaNoMatchesFor(Object query) {
    return '\"$query\" માટે કોઈ મેળ નથી';
  }

  @override
  String get qaToday => 'આજે';

  @override
  String get qaYesterday => 'ગઈકાલે';

  @override
  String get qaThisWeek => 'આ અઠવાડિયે';

  @override
  String get qaEarlier => 'અગાઉ';

  @override
  String get qaSourcesLabel => 'સ્રોત';

  @override
  String get qaFollowUpLabel => 'તમે આ પણ પૂછી શકો છો:';

  @override
  String get qaHelpfulAnswer => 'મદદરૂપ જવાબ';

  @override
  String get qaUnhelpfulAnswer => 'બિનમદદરૂપ જવાબ';

  @override
  String get qaCopyAnswer => 'જવાબ કૉપિ કરો';

  @override
  String get qaAnswerCopied => 'જવાબ કૉપિ થયો';

  @override
  String get qaShareAnswer => 'જવાબ શેર કરો';

  @override
  String get qaAnswerCopiedToClipboard => 'જવાબ ક્લિપબોર્ડ પર કૉપિ થયો';

  @override
  String get qaEvidence => 'પુરાવા';

  @override
  String get qaCitationUnknown => 'અજ્ઞાત';

  @override
  String qaCitationSource(Object index) {
    return 'સ્રોત $index';
  }

  @override
  String qaCitationSourcePage(Object index, Object page) {
    return 'સ્રોત $index • પાનું $page';
  }

  @override
  String get qaPolicyDoesNotEstablish => 'પોલિસી શું સ્થાપિત કરતી નથી';

  @override
  String qaAnswerReadyFor(Object question) {
    return '$question માટે જવાબ તૈયાર';
  }

  @override
  String qaCouldNotGetAnswer(Object error) {
    return 'જવાબ મેળવી શક્યા નહીં. $error';
  }

  @override
  String get qaFallbackAnswer =>
      'માફ કરશો, તે કામ કર્યું નહીં. કૃપા કરીને ફરી પ્રયાસ કરો.';

  @override
  String get qaPolicySource => 'પોલિસી સ્રોત';

  @override
  String get qaViewSource => 'સ્રોત જુઓ';

  @override
  String get qaViewSourcePage => 'પાના પર જુઓ';

  @override
  String get qaNoSourceDocument => 'સ્રોત દસ્તાવેજ ઉપલબ્ધ નથી';

  @override
  String qaSourcePageLabel(Object page) {
    return 'પાનું $page';
  }

  @override
  String get qaRelevanceTooltip =>
      'આ સ્રોત તમારા પ્રશ્ન સાથે કેટલો નજીકથી મેળ ખાય છે';

  @override
  String get qaOfflineMessage =>
      'You are offline. Please check your connection and try again.';

  @override
  String get confidenceHigh => 'ઉચ્ચ';

  @override
  String get confidenceMedium => 'મધ્યમ';

  @override
  String get confidenceLow => 'નીચું';

  @override
  String confidenceLabel(Object level) {
    return '$level વિશ્વાસ';
  }

  @override
  String get qaPacksTitle => 'Q&A પૅક્સ';

  @override
  String get qaPacksBuyHeading => 'પૅક ખરીદો';

  @override
  String get qaPacksSubtitle =>
      'કોઈ સબ્સ્ક્રિપ્શનની જરૂર નથી. એક વાર ચૂકવો, પ્રશ્નો પૂછો.';

  @override
  String get qaPacksYourPacks => 'તમારા પૅક્સ';

  @override
  String get qaPacksPurchasedSuccess =>
      'ખરીદી પ્રાપ્ત થઈ. સર્વર પુષ્ટિ પછી પ્રશ્નો દેખાશે.';

  @override
  String get qaPacksHowTheyWork => 'પૅક્સ કેવી રીતે કામ કરે છે';

  @override
  String get qaPacksFaqQ1 => 'પ્રશ્નો ક્યારે કાપવામાં આવે છે?';

  @override
  String get qaPacksFaqA1 =>
      'દર વખતે જ્યારે તમે સબમિટ કરો ત્યારે એક પ્રશ્ન કપાય છે. માસિક સબ્સ્ક્રિપ્શન પ્રશ્નો પહેલા ઉપયોગ થાય છે, પછી પૅક પ્રશ્નો.';

  @override
  String get qaPacksFaqQ2 => 'શું પૅક્સ સમાપ્ત થાય છે?';

  @override
  String get qaPacksFaqA2 =>
      'હા, પૅક્સ ખરીદીથી ૯૦ દિવસ માટે માન્ય છે. વણઉપયોગી પ્રશ્નો સમાપ્તિ પછી ખોવાઈ જાય છે.';

  @override
  String get qaPacksFaqQ3 => 'શું મારી પાસે બહુવિધ પૅક્સ હોઈ શકે છે?';

  @override
  String get qaPacksFaqA3 =>
      'હા! બહુવિધ પૅક્સ સ્ટેક થાય છે. પ્રશ્નો પહેલા સમાપ્ત થતા પૅકમાંથી ઉપયોગ થાય છે (FIFO).';

  @override
  String get qaPacksFaqQ4 => 'જો હું સબ્સ્ક્રિપ્શનમાં અપગ્રેડ કરું તો શું થાય?';

  @override
  String get qaPacksFaqA4 =>
      'તમારા પૅક પ્રશ્નો સક્રિય રહે છે અને તમારા માસિક ક્વોટા ખતમ થયા પછી ઉપયોગ થાય છે.';

  @override
  String qaPacksQuestionsAvailable(Object count) {
    return '$count પ્રશ્નો ઉપલબ્ધ';
  }

  @override
  String qaPacksFromMonthlyPlan(Object count) {
    return '$count માસિક યોજનામાંથી';
  }

  @override
  String qaPacksFromPacks(Object count) {
    return '$count પૅકમાંથી';
  }

  @override
  String qaPacksFromMonthlyAndPacks(Object monthly, Object packs) {
    return '$monthly માસિક યોજનામાંથી · $packs પૅકમાંથી';
  }

  @override
  String qaPacksQuestionsInPacks(Object count) {
    return '$count પૅકમાંથી';
  }

  @override
  String get qaPacksBestValue => 'વધુ માસિક પ્રશ્નો';

  @override
  String qaPacksQuestionsEach(Object count, Object price) {
    return '$count પ્રશ્નો · $price દરેક';
  }

  @override
  String qaPacksPackPurchased(Object name) {
    return 'ખરીદી પ્રાપ્ત થઈ. તમારા $name પ્રશ્નો સર્વર પુષ્ટિ પછી દેખાશે.';
  }

  @override
  String get qaPacksPurchaseCancelled => 'ખરીદી રદ કરવામાં આવી.';

  @override
  String get qaPacksPurchaseNotCompleted =>
      'ખરીદી પૂર્ણ થઈ નથી. કોઈ પ્રશ્નો ઉમેરાયા નથી.';

  @override
  String qaPacksPackRemaining(Object type) {
    return '$type પૅક';
  }

  @override
  String qaPacksRemaining(Object remaining, Object total) {
    return '$remaining/$total બાકી';
  }

  @override
  String get familyTitle => 'કુટુંબ';

  @override
  String get familyNoMembersYet => 'હજી સુધી કોઈ કુટુંબ સભ્યો નથી';

  @override
  String get familyNoMembersFound => 'કોઈ કુટુંબ સભ્યો મળ્યા નથી';

  @override
  String get familyEmptySubtitle =>
      'કુટુંબ સભ્યોને આપમેળે શોધવા માટે વીમા દસ્તાવેજો અપલોડ કરો, અથવા મેન્યુઅલી ઉમેરો.';

  @override
  String get familyAddMember => 'કુટુંબ સભ્ય ઉમેરો';

  @override
  String get familyLibraryError => 'તમારી પોલિસી લાઇબ્રેરી લોડ થઈ શકી નહીં.';

  @override
  String get familyMembersReadError =>
      'તમારી પોલિસીઓમાંથી આવરી લેવાયેલા કુટુંબ સભ્યો વાંચી શકાયા નહીં.';

  @override
  String get familyPeopleCovered => 'આવરી લેવાયેલા લોકો';

  @override
  String get familyPeopleSubtitle =>
      'તમારી પોલિસીઓમાં મળેલા લોકોનો સ્પષ્ટ દૃશ્ય, ઉપરાંત તમે જાતે ઉમેરો છો તે.';

  @override
  String get familySectionLabel => 'કુટુંબ અને વીમાધારક સભ્યો';

  @override
  String get familyRemoveTitle => 'કુટુંબ સભ્ય દૂર કરો?';

  @override
  String familyRemoveContent(Object name) {
    return '$name ને તમારી કુટુંબ યાદીમાંથી દૂર કરો? આ તમારા પોલિસી દસ્તાવેજોને અસર કરતું નથી.';
  }

  @override
  String get familyAddButton => 'કુટુંબ સભ્ય ઉમેરો';

  @override
  String get familyManualBadge => 'મેન્યુઅલ';

  @override
  String get familyFromDocumentBadge => 'દસ્તાવેજમાંથી';

  @override
  String familyRemoveTooltip(Object name) {
    return '$name ને દૂર કરો';
  }

  @override
  String familyDateOfBirth(Object date) {
    return 'જન્મ તારીખ: $date';
  }

  @override
  String get familyDetailEditTooltip => 'સભ્ય સંપાદિત કરો';

  @override
  String get familyDetailHintName => 'પૂરું નામ';

  @override
  String get familyDetailMemberUpdated => 'સભ્ય અપડેટ થયો';

  @override
  String familyDetailUpdateError(Object error) {
    return 'સભ્ય અપડેટ કરી શકાયો નહીં: $error';
  }

  @override
  String get familyDetailDobLabel => 'જન્મ તારીખ';

  @override
  String get familyDetailSourceLabel => 'સ્રોત';

  @override
  String get familyDetailCoveringPolicies => 'આવરી લેતી પોલિસીઓ';

  @override
  String get familyDetailManualSource => 'મેન્યુઅલી ઉમેરાયેલ';

  @override
  String get familyDetailAutoSource => 'પોલિસીમાંથી શોધાયેલ';

  @override
  String familyDetailNoPolicies(Object name) {
    return '$name ને યાદી કરતી કોઈ પોલિસી મળી નથી.';
  }

  @override
  String get relationshipDependent => 'આશ્રિત';

  @override
  String get relationshipSpouse => 'જીવનસાથી';

  @override
  String get relationshipChild => 'બાળક';

  @override
  String get relationshipParent => 'માતા-પિતા';

  @override
  String get relationshipSibling => 'ભાઈ-બહેન';

  @override
  String get relationshipPrimaryInsured => 'મુખ્ય વીમાધારક';

  @override
  String get relationshipOther => 'અન્ય';

  @override
  String get insuranceCardsTitle => 'વીમા કાર્ડ્સ';

  @override
  String get insuranceCardsEmptyTitle => 'હજી સુધી કોઈ વીમા કાર્ડ નથી';

  @override
  String get insuranceCardsEmptySubtitle =>
      'તમારા ફોન પર મુખ્ય વિગતો તૈયાર રાખવા માટે પોલિસી ફાઇલ પસંદ કરો.';

  @override
  String get insuranceCardsChooseFile => 'પોલિસી ફાઇલ પસંદ કરો';

  @override
  String get insuranceCardsHeaderTitle =>
      'તમારી પોલિસી વિગતો, લઈ જવા માટે તૈયાર';

  @override
  String get insuranceCardsHeaderSubtitle =>
      'પોલિસી અને વીમા કંપનીની વિગતો માટે ઝડપી સંદર્ભ. તમારા વીમા કંપની સાથે પુરાવા જરૂરિયાતો ચકાસો.';

  @override
  String get insuranceCardsPolicyNumber => 'પોલિસી નંબર';

  @override
  String get insuranceCardsCoverage => 'કવરેજ';

  @override
  String get insuranceCardsPremium => 'પ્રીમિયમ';

  @override
  String get insuranceCardsValidFrom => 'થી માન્ય';

  @override
  String get insuranceCardsValidUntil => 'સુધી માન્ય';

  @override
  String get insuranceCardsCallInsurer => 'વીમા કંપનીને કૉલ કરો';

  @override
  String get insuranceCardsShareCard => 'કાર્ડ શેર કરો';

  @override
  String get insuranceCardsExpired => 'સમાપ્ત';

  @override
  String get insuranceCardsShareTitle => 'CoverWise પોલિસી સંદર્ભ';

  @override
  String get insuranceCardsInsurerPrefix => 'વીમા કંપની: ';

  @override
  String get insuranceCardsPolicyNumberPrefix => 'પોલિસી નંબર: ';

  @override
  String get insuranceCardsCoveragePrefix => 'કવરેજ: ';

  @override
  String get insuranceCardsValidUntilPrefix => 'સુધી માન્ય: ';

  @override
  String get insuranceCardsHelplinePrefix => 'વીમા કંપની હેલ્પલાઇન: ';

  @override
  String get insuranceCardsShareFooter =>
      'વીમા કંપની અને સ્રોત પોલિસી દસ્તાવેજ સાથે વર્તમાન વિગતો ચકાસો.';

  @override
  String get insuranceCardsPhoneError => 'ફોન એપ્લિકેશન ખોલી શકાઈ નહીં';

  @override
  String get insuranceCardsShareError => 'શેરિંગ વિકલ્પો ખોલી શકાયા નહીં';

  @override
  String get renewalTitle => 'નવીકરણ કેલેન્ડર';

  @override
  String get renewalEmptyTitle => 'કોઈ પોલિસી ટ્રેક થઈ નથી';

  @override
  String get renewalEmptySubtitle =>
      'નવીકરણ તારીખો ટ્રેક કરવા માટે પોલિસી ફાઇલ પસંદ કરો.';

  @override
  String get renewalHeaderTitle => 'નવીકરણોને દૃશ્યમાં રાખો';

  @override
  String get renewalHeaderSubtitle =>
      'જુઓ કોના પર પહેલા ધ્યાન આપવાની જરૂર છે અને વીમા કંપની સંપર્ક વિગતો નજીક રાખો.';

  @override
  String get renewalReminderText =>
      'પોલિસી સમાપ્ત થાય તેના ૩૦, ૧૫, ૭ અને ૧ દિવસ પહેલાં રિમાઇન્ડર સેટ કરો.';

  @override
  String get renewalRemindersOn => 'નવીકરણ રિમાઇન્ડર્સ ચાલુ છે.';

  @override
  String get renewalNotificationsOff =>
      'સૂચનાઓ બંધ છે. તમે સેટિંગ્સમાં તેને સક્રિય કરી શકો છો.';

  @override
  String get renewalSectionExpired => 'સમાપ્ત';

  @override
  String get renewalSectionExpiringSoon => 'ટૂંક સમયમાં સમાપ્ત થશે';

  @override
  String get renewalSectionActive => 'સક્રિય';

  @override
  String get renewalSectionNoDate => 'સમાપ્તિ તારીખ મળી નથી';

  @override
  String get renewalNoDateInfo =>
      'તમારી પોલિસીમાં સમાપ્તિ તારીખ મળી નથી — તમારો પોલિસી દસ્તાવેજ તપાસો';

  @override
  String get renewalInsurerNotFound => 'વીમા કંપની મળી નથી';

  @override
  String renewalExpires(Object date) {
    return '$date ના રોજ સમાપ્ત થાય છે';
  }

  @override
  String get renewalContactToRenew => 'નવીકરણ માટે વીમા કંપનીનો સંપર્ક કરો';

  @override
  String get renewalStartRenewal => 'નવીકરણ શરૂ કરો';

  @override
  String renewalRenewTitle(Object type) {
    return '$type નવું કરો';
  }

  @override
  String renewalContactInsurer(Object insurer) {
    return 'નવીકરણ પ્રક્રિયા શરૂ કરવા $insurer નો સંપર્ક કરો.';
  }

  @override
  String get renewalCallHelpline => 'હેલ્પલાઇન પર કૉલ કરો';

  @override
  String get renewalSendEmail => 'ઇમેઇલ મોકલો';

  @override
  String renewalContactInfoNotFound(Object insurer) {
    return '$insurer માટે સંપર્ક માહિતી મળી નથી. તમારો પોલિસી દસ્તાવેજ તપાસો અથવા સીધા વીમા કંપનીને કૉલ કરો.';
  }

  @override
  String get renewalPhoneDialerError => 'ફોન ડાયલર ખોલી શકાયું નહીં';

  @override
  String get renewalEmailClientError => 'ઇમેઇલ ક્લાયંટ ખોલી શકાયું નહીં';

  @override
  String renewalExpiringPolicies(Object date) {
    return '$date ના રોજ સમાપ્ત થતી પોલિસીઓ';
  }

  @override
  String renewalExpiringCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count પોલિસીઓ',
      one: '1 પોલિસી',
    );
    return '$_temp0 આ તારીખે સમાપ્ત થઈ રહી છે';
  }

  @override
  String get settingsTitle => 'સેટિંગ્સ';

  @override
  String get settingsHeaderTitle => 'તમારી એપ્લિકેશન, તમારી પસંદગીઓ';

  @override
  String get settingsHeaderSubtitle =>
      'ઍક્સેસ, રિમાઇન્ડર્સ અને આ ઉપકરણ પર શું રહે છે તે મેનેજ કરો.';

  @override
  String get settingsSectionPlan => 'યોજના';

  @override
  String get settingsSectionAccount => 'ખાતું';

  @override
  String get settingsSectionExperience => 'અનુભવ';

  @override
  String get settingsSectionAppDetails => 'એપ્લિકેશન વિગતો';

  @override
  String get settingsSectionPrivacy => 'ગોપનીયતા અને સંમતિ';

  @override
  String get settingsSectionDeviceData => 'ઉપકરણ ડેટા';

  @override
  String settingsCurrentPlan(Object plan) {
    return 'વર્તમાન યોજના: $plan';
  }

  @override
  String get settingsQaPacks => 'Q&A પૅક્સ';

  @override
  String settingsQuestionsInPacks(Object count) {
    return '$count પ્રશ્નો પૅક્સમાં';
  }

  @override
  String get settingsBuyQuestions => 'સબ્સ્ક્રિપ્શન વિના પ્રશ્નો ખરીદો';

  @override
  String get settingsRenews => 'નવું થાય છે';

  @override
  String get settingsSignedIn => 'સાઇન ઇન થયેલ';

  @override
  String get settingsSupabaseAccount => 'Supabase ખાતું';

  @override
  String get settingsAccountLinked => 'ખાતું લિંક થયેલ';

  @override
  String get settingsLinkYourPhone => 'તમારો ફોન લિંક કરો';

  @override
  String settingsConnectedAs(Object phone) {
    return '$phone તરીકે કનેક્ટ થયેલ';
  }

  @override
  String get settingsBackupSubtitle =>
      'પોલિસીઓનો બેકઅપ લો અને બીજા ઉપકરણ પર ઉપયોગ કરો';

  @override
  String get settingsAppearance => 'દેખાવ';

  @override
  String settingsThemeMode(Object mode) {
    return '$mode';
  }

  @override
  String get settingsNotifications => 'સૂચનાઓ';

  @override
  String get settingsNotificationsSubtitle => 'નવીકરણ રિમાઇન્ડર્સ અને શાંત સમય';

  @override
  String get settingsSmartSuggestions => 'કવરેજ આંતરદૃષ્ટિ';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'ટૂંક સમયમાં: તમારી પોલિસી વિગતો પર આધારિત કવરેજ માર્ગદર્શન';

  @override
  String get settingsServiceEndpoint => 'સેવા એન્ડપોઇન્ટ';

  @override
  String get settingsClearDataTitle => 'બધો સ્થાનિક ડેટા સાફ કરો?';

  @override
  String get settingsClearDataAction => 'સ્થાનિક ડેટા સાફ કરો';

  @override
  String get settingsClearDataContent =>
      'આ આ ઉપકરણમાંથી બધા સ્થાનિક રીતે સંગ્રહિત દસ્તાવેજો, પોલિસી સારાંશ, Q&A ઇતિહાસ, કુટુંબ સભ્યો અને સત્ર ડેટા દૂર કરે છે. સર્વર પર અપલોડ કરેલા દસ્તાવેજો અસરગ્રસ્ત થતા નથી. આ ક્રિયા આ ઉપકરણથી પાછી લઈ શકાતી નથી.';

  @override
  String get settingsClearDataSuccess =>
      'આ ઉપકરણમાંથી બધો સ્થાનિક ડેટા સાફ થયો.';

  @override
  String get settingsClearDataSubtitle =>
      'દસ્તાવેજો, સારાંશ, ઇતિહાસ અને કુટુંબ સભ્યો દૂર કરો';

  @override
  String get settingsNoConsentRecords => 'કોઈ સંમતિ રેકોર્ડ નથી';

  @override
  String get settingsConsentRecorded =>
      'જ્યારે તમે તમારી પ્રથમ પોલિસી અપલોડ કરો ત્યારે સંમતિ રેકોર્ડ થાય છે';

  @override
  String get settingsConsentPolicyProcessing => 'પોલિસી પ્રોસેસિંગ';

  @override
  String get settingsConsentAnalytics => 'ઉપયોગ આંકડા';

  @override
  String get settingsConsentLeadCapture => 'સંપર્ક કેપ્ચર';

  @override
  String get settingsConsentTermsAccepted => 'શરતો સ્વીકારેલ';

  @override
  String settingsConsentGranted(Object date, Object version) {
    return '$date ના રોજ મંજૂર • v$version';
  }

  @override
  String settingsConsentRevoked(Object date) {
    return '$date ના રોજ રદ કરેલ';
  }

  @override
  String get settingsConsentActive => 'સક્રિય';

  @override
  String get settingsConsentRevokedLabel => 'રદ કરેલ';

  @override
  String get settingsLanguage => 'ભાષા';

  @override
  String get settingsLanguageSubtitle =>
      'તમારી પસંદગીની એપ્લિકેશન ભાષા પસંદ કરો';

  @override
  String get profileTitle => 'પ્રોફાઇલ';

  @override
  String get profileDefaultHeader => 'તમારી CoverWise પ્રોફાઇલ';

  @override
  String get profileLinkedHeader => 'તમારા ઉપકરણો પર લિંક અને તૈયાર.';

  @override
  String get profileUnlinkedHeader =>
      'તમારી પોલિસી વર્કસ્પેસ હાલમાં આ ઉપકરણ પર રહે છે.';

  @override
  String get profileCreateAccount => 'સુરક્ષિત ખાતું બનાવો';

  @override
  String get profileRestoreWorkspace =>
      'આ પોલિસી વર્કસ્પેસને ઉપકરણો વચ્ચે પુનઃસ્થાપિત કરો';

  @override
  String get profileSignedInAccount => 'સાઇન ઇન થયેલ ખાતું';

  @override
  String get profileWorkspaceLinked => 'વર્કસ્પેસ તમારા ખાતા સાથે લિંક થયેલ છે';

  @override
  String get profilePhoneNumber => 'ફોન નંબર';

  @override
  String get profileNotLinked => 'લિંક થયેલ નથી';

  @override
  String get profileSecureSession => 'સુરક્ષિત સત્ર';

  @override
  String get profileAccountSessionActive => 'આ ઉપકરણ પર ખાતું સત્ર સક્રિય';

  @override
  String get profileAnonymousSessionActive => 'આ ઉપકરણ પર અજ્ઞાત સત્ર સક્રિય';

  @override
  String get profileAppSection => 'એપ્લિકેશન';

  @override
  String get profileFamilySection => 'કુટુંબ';

  @override
  String get profilePrivacySection => 'ગોપનીયતા';

  @override
  String get profileDeviceFirstStorage => 'ઉપકરણ-પ્રથમ સંગ્રહ';

  @override
  String get profileDeviceFirstSubtitle =>
      'આ ઉપકરણ સંરક્ષિત સ્થાનિક કેશ રાખે છે; સમન્વય માટે ખાતા ડેટા પણ સુરક્ષિત રીતે સંગ્રહિત થઈ શકે છે.';

  @override
  String get profileDeleteAccount => 'ખાતું કાઢી નાખો';

  @override
  String get profileDeleteAccountSubtitle =>
      'ખાતું અને બધો સર્વર ડેટા કાયમ માટે દૂર કરો';

  @override
  String get profileCreateAccountFirst =>
      'તેને કાઢી નાખવા માટે પહેલા ખાતું બનાવો';

  @override
  String get profileFooter =>
      'CoverWise તમને તમારી પોલિસીઓ સમજવામાં મદદ કરે છે. તે વીમો વેચતું નથી.';

  @override
  String get profileDeleteConfirmTitle => 'ખાતું કાયમ માટે કાઢી નાખો?';

  @override
  String get profileDeleteConfirmHeader => 'આ કાયમ માટે કાઢી નાખશે:';

  @override
  String get profileDeleteItemAccount => '• તમારું CoverWise ખાતું';

  @override
  String get profileDeleteItemDocs =>
      '• અમારા સર્વર્સ પરના બધા અપલોડ કરેલા પોલિસી દસ્તાવેજો';

  @override
  String get profileDeleteItemSummaries =>
      '• બધા પોલિસી સારાંશ અને એમ્બેડિંગ્સ';

  @override
  String get profileDeleteItemHistory => '• સર્વર પર તમારો Q&A ઇતિહાસ';

  @override
  String get profileDeleteWarning =>
      'આ ક્રિયા આ ઉપકરણથી પાછી લઈ શકાતી નથી. આ ઉપકરણ પરનો સ્થાનિક ડેટા સેટિંગ્સ → સ્થાનિક ડેટા સાફ કરો દ્વારા અલગથી સાફ થશે.';

  @override
  String get profileDeleteEverything => 'બધું કાઢી નાખો';

  @override
  String get profileDeleteTypeTitle => 'પુષ્ટિ કરવા DELETE લખો';

  @override
  String get profileDeleteTypeWarning =>
      'આ તમારી છેલ્લી તક છે. બધો ડેટા કાયમ માટે ભૂંસી નાખવામાં આવશે.';

  @override
  String get profileDeleteTypeHint => 'DELETE લખો';

  @override
  String get profileDeletePermanently => 'કાયમ માટે કાઢી નાખો';

  @override
  String get profileDeletingAccount => 'ખાતું કાઢી રહ્યા છે...';

  @override
  String profileDeleteComplete(Object docs, Object files) {
    return 'ખાતું કાઢી નાખ્યું. $docs દસ્તાવેજ(ઓ) અને $files સંગ્રહ ફાઇલ(ઓ) દૂર કરી.';
  }

  @override
  String profileDeletePartial(Object failed) {
    return 'ખાતું કાઢી નાખવાનું આંશિક રીતે પૂર્ણ થયું. નિષ્ફળ તબક્કા: $failed. સર્વર કાઢી નાખવાનું પૂર્ણ થયું છે તેમ ન માનો.';
  }

  @override
  String profileDeleteRequested(Object status) {
    return 'ખાતું કાઢી નાખવાની વિનંતી કરી. સ્થિતિ: $status.';
  }

  @override
  String get profileDeletionStatusTitle => 'ખાતું કાઢી નાખવાની સ્થિતિ';

  @override
  String get profileDeletionStatusPending =>
      'કાઢી નાખવાની કતારબદ્ધ છે. સર્વર ભૂંસી નાખવાની પુષ્ટિ થાય ત્યાં સુધી તમારું ખાતું સક્રિય રહે છે.';

  @override
  String get profileDeletionStatusRunning =>
      'કાઢી નાખવાની પ્રક્રિયા ચાલી રહી છે. ભૂંસી નાખવાની પ્રક્રિયા ચાલે ત્યારે નવા ખાતા લેખનો થોભાવવામાં આવ્યા છે.';

  @override
  String get profileDeletionStatusFailed =>
      'છેલ્લા કાઢી નાખવાના પ્રયાસને ધ્યાનની જરૂર છે.';

  @override
  String get profileDeletionStatusRefresh => 'સ્થિતિ તાજી કરો';

  @override
  String get profileDeletionStatusUnavailable =>
      'કાઢી નાખવાની સ્થિતિ હાલમાં ઉપલબ્ધ નથી.';

  @override
  String profileInFlightWarning(Object count) {
    return '$count દસ્તાવેજ(ઓ) હજી પ્રોસેસ થઈ રહ્યા છે. તમારું ખાતું કાઢી નાખતા પહેલા પ્રોસેસિંગ પૂર્ણ થવાની રાહ જુઓ.';
  }

  @override
  String get upgradeTitle => 'તમારી યોજના પસંદ કરો';

  @override
  String get upgradeBillingUnavailable =>
      'બિલિંગ હજી ઉપલબ્ધ નથી. કૃપા કરીને પછીથી ફરી પ્રયાસ કરો.';

  @override
  String get upgradeCouldNotOpenSettings =>
      'સબ્સ્ક્રિપ્શન સેટિંગ્સ ખોલી શકાયા નહીં';

  @override
  String upgradeSuccess(Object plan) {
    return '$plan માં અપગ્રેડ થયા! તમારી નવી સુવિધાઓનો આનંદ લો.';
  }

  @override
  String get upgradePurchaseCancelled => 'ખરીદી રદ કરવામાં આવી.';

  @override
  String get upgradeMonthly => 'માસિક';

  @override
  String get upgradeAnnual => 'વાર્ષિક';

  @override
  String get upgradeSaveUpTo => '44% સુધી બચાવો';

  @override
  String get upgradeCurrentPlan => 'વર્તમાન યોજના';

  @override
  String get upgradeFreeForever => 'હંમેશા મફત';

  @override
  String upgradeTo(Object plan) {
    return '$plan માં અપગ્રેડ કરો';
  }

  @override
  String get upgradeComparePlans => 'યોજનાઓની તુલના કરો';

  @override
  String get upgradeQuestions => 'પ્રશ્નો';

  @override
  String get upgradeFaqSwitch => 'શું હું યોજનાઓ બદલી શકું?';

  @override
  String get upgradeFaqSwitchAnswer =>
      'તમે એપ સ્ટોર અથવા પ્લે સ્ટોર સબ્સ્ક્રિપ્શન સેટિંગ્સ દ્વારા યોજના ફેરફારો મેનેજ કરી શકો છો.';

  @override
  String get upgradeFaqPacks => 'મારા Q&A પૅક્સ વિશે શું?';

  @override
  String get upgradeFaqPacksAnswer =>
      'પૅક પ્રશ્નો સક્રિય રહે છે અને તમારા માસિક ક્વોટા ખતમ થયા પછી ઉપયોગ થાય છે.';

  @override
  String get upgradeFaqCancel => 'હું કેવી રીતે રદ કરું?';

  @override
  String get upgradeFaqCancelAnswer =>
      'તમારા એપ સ્ટોર અથવા પ્લે સ્ટોર સબ્સ્ક્રિપ્શન સેટિંગ્સમાંથી ગમે ત્યારે રદ કરો.';

  @override
  String get upgradeAccessUntil => 'સુધી ઍક્સેસ';

  @override
  String get upgradePolicies => 'પોલિસીઓ';

  @override
  String get upgradeQaPerMonth => 'દર મહિને Q&A';

  @override
  String get upgradeComparePolicies => 'પોલિસીઓની તુલના કરો';

  @override
  String get upgradeFamilyView => 'કુટુંબ દૃશ્ય';

  @override
  String get upgradeCloudSync => 'ક્લાઉડ સમન્વય';

  @override
  String get upgradeEmergency => 'કટોકટી';

  @override
  String get upgradeAnnualReview => 'વાર્ષિક સમીક્ષા';

  @override
  String get upgradeAdvancedSearch => 'અદ્યતન શોધ';

  @override
  String accountTitle(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'ખાતું બનાવો',
        'other': 'સાઇન ઇન કરો',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountHeaderTitle => 'તમારી પોલિસી વર્કસ્પેસને સુરક્ષિત કરો';

  @override
  String get accountHeaderSubtitle =>
      'ખાતું તમને બીજા ઉપકરણ પર તમારી CoverWise વર્કસ્પેસ પુનઃસ્થાપિત કરવા દે છે.';

  @override
  String get accountNameLabel => 'નામ (વૈકલ્પિક)';

  @override
  String get accountEmailLabel => 'ઇમેઇલ';

  @override
  String get accountPasswordLabel => 'પાસવર્ડ';

  @override
  String get accountResendBanner =>
      'તમારો ઇમેઇલ હજી પુષ્ટિ થયો નથી. તમારો ઇનબોક્સ તપાસો અથવા ફરીથી મોકલો.';

  @override
  String get accountResend => 'ફરીથી મોકલો';

  @override
  String get accountForgotPassword => 'પાસવર્ડ ભૂલી ગયા?';

  @override
  String get accountResendVerification => 'ચકાસણી ઇમેઇલ ફરીથી મોકલો';

  @override
  String accountSwitchToSignIn(String isSignUp) {
    String _temp0 = intl.Intl.selectLogic(
      isSignUp,
      {
        'true': 'પહેલેથી ખાતું છે? સાઇન ઇન કરો',
        'other': 'નવા CoverWise માં? ખાતું બનાવો',
      },
    );
    return '$_temp0';
  }

  @override
  String get accountGoogleSignIn => 'Google સાથે ચાલુ રાખો';

  @override
  String get accountAuthNotConfigured =>
      'આ બિલ્ડ માટે ખાતા પ્રમાણીકરણ ગોઠવેલ નથી.';

  @override
  String get accountEnterEmail => 'કૃપા કરીને તમારો ઇમેઇલ સરનામું દાખલ કરો.';

  @override
  String get accountPasswordTooShort =>
      'પાસવર્ડ ઓછામાં ઓછા ૮ અક્ષરોનો હોવો જોઈએ.';

  @override
  String get accountInvalidEmail => 'કૃપા કરીને માન્ય ઇમેઇલ સરનામું દાખલ કરો.';

  @override
  String get accountCheckEmail =>
      'ખાતાની પુષ્ટિ કરવા તમારો ઇમેઇલ તપાસો, પછી સાઇન ઇન કરો.';

  @override
  String get accountIncorrectCredentials =>
      'ખોટો ઇમેઇલ અથવા પાસવર્ડ. કૃપા કરીને ફરી પ્રયાસ કરો.';

  @override
  String get accountAlreadyRegistered =>
      'આ ઇમેઇલ સાથેનું ખાતું પહેલેથી અસ્તિત્વમાં છે. સાઇન ઇન કરવાનો પ્રયાસ કરો.';

  @override
  String get accountPasswordRequirements =>
      'પાસવર્ડ જરૂરિયાતો પૂરી કરતો નથી. ઓછામાં ઓછા ૮ અક્ષરોનો ઉપયોગ કરો.';

  @override
  String accountCouldNotAction(String action) {
    String _temp0 = intl.Intl.selectLogic(
      action,
      {
        'true': 'ખાતું બનાવી',
        'other': 'ખાતામાં સાઇન ઇન કરી',
      },
    );
    return '$_temp0 શકાયું નહીં.';
  }

  @override
  String get accountEnterEmailFirst =>
      'પહેલા ઉપર તમારો ઇમેઇલ દાખલ કરો, પછી પાસવર્ડ ભૂલી ગયા પર ટેપ કરો.';

  @override
  String get accountResetEmailSent =>
      'પાસવર્ડ રીસેટ ઇમેઇલ મોકલ્યો. તમારો ઇનબોક્સ તપાસો.';

  @override
  String get accountCouldNotReset =>
      'રીસેટ ઇમેઇલ મોકલી શકાયો નહીં. તમારો ઇમેઇલ તપાસો અને ફરી પ્રયાસ કરો.';

  @override
  String get accountEnterEmailResend =>
      'પહેલા ઉપર તમારો ઇમેઇલ દાખલ કરો, પછી ચકાસણી ફરીથી મોકલો પર ટેપ કરો.';

  @override
  String get accountVerificationSent =>
      'ચકાસણી ઇમેઇલ મોકલ્યો. તમારો ઇનબોક્સ તપાસો.';

  @override
  String get accountCouldNotVerify =>
      'ચકાસણી ઇમેઇલ મોકલી શકાયો નહીં. પછીથી ફરી પ્રયાસ કરો.';

  @override
  String get accountCouldNotGoogle =>
      'Google સાથે સાઇન ઇન કરી શકાયું નહીં. કૃપા કરીને ફરી પ્રયાસ કરો.';

  @override
  String get notifTitle => 'નવીકરણ રિમાઇન્ડર્સ';

  @override
  String get notifHeaderTitle => 'નવીકરણોથી આગળ રહો';

  @override
  String get notifHeaderSubtitle =>
      'આ ઉપકરણે તમને ક્યારે યાદ કરાવવું તે પસંદ કરો.';

  @override
  String get notifMasterToggle => 'નવીકરણ રિમાઇન્ડર્સ';

  @override
  String get notifEnabledSubtitle => 'આ ઉપકરણ પર સક્રિય';

  @override
  String get notifDisabledSubtitle => 'નિષ્ક્રિય';

  @override
  String get notifSectionRemindMe => 'સમાપ્તિ પહેલાં મને યાદ કરાવો';

  @override
  String get notifSectionRemindMeDescription =>
      'તમારી પોલિસી સમાપ્ત થાય તેના કેટલા દિવસ પહેલાં રિમાઇન્ડર મેળવવા માંગો છો તે પસંદ કરો.';

  @override
  String get notifNoReminderTimes => 'કોઈ રિમાઇન્ડર સમય પસંદ થયા નથી.';

  @override
  String get notifSectionQuietHours => 'શાંત સમય';

  @override
  String get notifSectionQuietHoursDescription =>
      'આ સમય દરમિયાન કોઈ સૂચનાઓ નહીં.';

  @override
  String get notifStartTime => 'શરૂઆતનો સમય';

  @override
  String get notifEndTime => 'સમાપ્તિ સમય';

  @override
  String get notifSectionPerPolicy => 'પ્રતિ-પોલિસી રિમાઇન્ડર્સ';

  @override
  String get notifSectionPerPolicyDescription =>
      'વ્યક્તિગત પોલિસીઓ માટે રિમાઇન્ડર્સ ચાલુ/બંધ કરો.';

  @override
  String get notifPreferencesSaved => 'પસંદગીઓ સાચવી';

  @override
  String get docsTitle => 'દસ્તાવેજો';

  @override
  String docsSlotsUsed(Object count) {
    return '$count મફત પોલિસી સ્લોટમાંથી વપરાયેલ';
  }

  @override
  String get docsTypeChanged => 'પ્રકાર બદલાયો';

  @override
  String get docsRemovedLocal =>
      'આ ઉપકરણમાંથી દૂર કરેલ. સર્વર નકલ અસરગ્રસ્ત થઈ નથી.';

  @override
  String get docsReplaceSuccess => 'દસ્તાવેજ સફળતાપૂર્વક બદલાયો';

  @override
  String get docsPreview => 'પૂર્વદર્શન';

  @override
  String get docsDownloadSource => 'સ્રોત ડાઉનલોડ કરો';

  @override
  String get docsChangeType => 'પ્રકાર બદલો';

  @override
  String get docsAskQuestions => 'પ્રશ્નો પૂછો';

  @override
  String get docsReadingPolicy => 'પોલિસી વાંચી રહ્યા છે';

  @override
  String get docsUploadRequired => 'સર્વર અપલોડ જરૂરી';

  @override
  String get docsRetryUpload => 'અપલોડ ફરી પ્રયાસ કરો';

  @override
  String get docsNeedsAttention => 'ધ્યાનની જરૂર છે';

  @override
  String get docsReadyForQuestions => 'પ્રશ્નો માટે તૈયાર';

  @override
  String get docsSaved => 'સાચવેલ';

  @override
  String get docsRefreshingTypes => 'દસ્તાવેજ પ્રકારો તાજા થઈ રહ્યા છે...';

  @override
  String get docsTypesRefreshed => 'દસ્તાવેજ પ્રકારો સફળતાપૂર્વક તાજા થયા!';

  @override
  String get docsReplace => 'બદલો';

  @override
  String get docsRemoveFromDevice => 'આ ઉપકરણમાંથી દૂર કરો';

  @override
  String get docsRemoveFromDeviceTitle => 'આ ઉપકરણમાંથી દૂર કરો?';

  @override
  String get docsDeletePolicy => 'પોલિસી કાઢી નાખો';

  @override
  String get docsDeletePolicyTitle => 'પોલિસી કાઢી નાખો?';

  @override
  String docsDeletePolicyContent(Object filename) {
    return 'આ \"$filename\" ને CoverWise અને આ ઉપકરણમાંથી કાયમ માટે કાઢી નાખે છે.';
  }

  @override
  String get docsDeleted => 'પોલિસી કાઢી નાખી';

  @override
  String get docsReplaceDocumentTitle => 'દસ્તાવેજ બદલો?';

  @override
  String get docsReplaceDocument => 'દસ્તાવેજ બદલો';

  @override
  String get docsCurrentDocument => 'વર્તમાન દસ્તાવેજ';

  @override
  String get docsSelectReplacement => 'બદલી ફાઇલ પસંદ કરો';

  @override
  String docsReplaceWillDelete(Object filename) {
    return 'આ \"$filename\" ને કાઢી નાખશે અને તેને નવી ફાઇલથી બદલશે.';
  }

  @override
  String get docsReplaceAnalysisLost =>
      'જૂના દસ્તાવેજનું વિશ્લેષણ ખોવાઈ જશે. નવા દસ્તાવેજની ફરીથી પ્રક્રિયા થશે.';

  @override
  String docsUploadedDate(Object date) {
    return 'અપલોડ: $date';
  }

  @override
  String get docsClearReplacement => 'બદલી ફાઇલ સાફ કરો';

  @override
  String get docsArchive => 'આર્કાઇવ';

  @override
  String get docsArchived => 'આર્કાઇવ થયેલ';

  @override
  String get docsRestore => 'પુનઃસ્થાપિત કરો';

  @override
  String get docsRestored => 'પોલિસી પુનઃસ્થાપિત થઈ';

  @override
  String get docsArchivedSuccess => 'પોલિસી આર્કાઇવ થઈ';

  @override
  String get docsShowArchived => 'આર્કાઇવ બતાવો';

  @override
  String get docsHideArchived => 'આર્કાઇવ છુપાવો';

  @override
  String get docsArchiveConfirmTitle => 'પોલિસી આર્કાઇવ કરો?';

  @override
  String docsArchiveConfirmContent(Object filename) {
    return '\"$filename\" તમારી સક્રિય પોલિસી યાદીથી છુપાઈ જશે. તમે કોઈપણ સમયે આર્કાઇવમાંથી પુનઃસ્થાપિત કરી શકો છો.';
  }

  @override
  String get docsDeletePermanentWarning =>
      'આ પોલિસીને CoverWise અને આ ઉપકરણ બંનેમાંથી કાયમ માટે કાઢી નાખે છે. તેના બદલે આર્કાઇવ કરવાનું વિચારો.';

  @override
  String get docsLimitWarning =>
      'તમે તમારી મફત સંગ્રહ મર્યાદાની નજીક છો. જગ્યા ખાલી કરવા જૂની પોલિસીઓ આર્કાઇવ કરો.';

  @override
  String docsLimitCountdown(Object limit, Object remaining, Object used) {
    return '$limit માંથી $used સ્લોટ વપરાયેલ — $remaining બાકી';
  }

  @override
  String docsLimitRemaining(Object remaining) {
    return '$remaining મફત સ્લોટ બાકી';
  }

  @override
  String get docsSortLabel => 'સૉર્ટ કરો';

  @override
  String get docsFilterLabel => 'ફિલ્ટર કરો';

  @override
  String get docsSortDateNewest => 'નવામાં નવું';

  @override
  String get docsSortDateOldest => 'જૂનામાં જૂનું';

  @override
  String get docsSortNameAZ => 'નામ A–Z';

  @override
  String get docsSortNameZA => 'નામ Z–A';

  @override
  String get docsSortType => 'પ્રકાર દ્વારા';

  @override
  String get docsFilterAll => 'બધા પ્રકારો';

  @override
  String docsFilterResultCount(Object count, Object total) {
    return '$total માંથી $count પોલિસીઓ';
  }

  @override
  String get docsRenameTitle => 'પોલિસીનું નામ બદલો';

  @override
  String get docsRenameHint => 'નવું નામ દાખલ કરો';

  @override
  String get docsRenameSave => 'સાચવો';

  @override
  String get docsRenameSuccess => 'પોલિસીનું નામ બદલાયું';

  @override
  String get docsRenameEmpty => 'નામ ખાલી હોઈ શકતું નથી';

  @override
  String get tosTitle => 'સેવાની શરતો';

  @override
  String get tosCopySuccess => 'સેવાની શરતો ક્લિપબોર્ડ પર કૉપિ થઈ';

  @override
  String get tosLoadError => 'સેવાની શરતો લોડ કરી શકાઈ નહીં.';

  @override
  String get privacyTitle => 'ગોપનીયતા નીતિ';

  @override
  String get privacyCopySuccess => 'ગોપનીયતા નીતિ ક્લિપબોર્ડ પર કૉપિ થઈ';

  @override
  String get privacyLoadError => 'ગોપનીયતા નીતિ લોડ કરી શકાઈ નહીં.';

  @override
  String get processingReceived => 'પ્રાપ્ત થયેલ';

  @override
  String get processingProcessing => 'પ્રક્રિયા ચાલુ છે';

  @override
  String get processingCategorising => 'શ્રેણીબદ્ધ કરી રહ્યા છે';

  @override
  String get processingFinishingUp => 'પૂરું કરી રહ્યા છે';

  @override
  String get processingReceivedDesc => 'તમારી પોલિસી પ્રાપ્ત થઈ ગઈ છે';

  @override
  String get processingProcessingDesc => 'લખાણ વાંચી અને કાઢી રહ્યા છે';

  @override
  String get processingCategorisingDesc =>
      'પોલિસી પ્રકાર અને વીમા કંપની નક્કી કરી રહ્યા છે';

  @override
  String get processingFinishingUpDesc =>
      'તમારી પોલિસી શોધી શકાય તેવી બનાવી રહ્યા છે';

  @override
  String get onboardSubtitle =>
      'ઇન્ટરનેટથી સામાન્ય સલાહ નહીં — તમારી વાસ્તવિક પોલિસી પર આધારિત સ્પષ્ટ જવાબો મેળવો.';

  @override
  String get onboardNoDataStored =>
      'તમારી સંમતિ વિના કોઈ પોલિસી ડેટા સંગ્રહિત અથવા શેર કરવામાં આવશે નહીં.';

  @override
  String get onboardTermsAcceptance =>
      'મેં ગોપનીયતા નીતિ અને સેવાની શરતો વાંચી અને સ્વીકારી છે.';

  @override
  String get emergencyTitle => 'કટોકટી';

  @override
  String get emergencyHelpAtGlance => 'એક નજરમાં મદદ';

  @override
  String get dashboardQuickActions => 'ઝડપી ક્રિયાઓ';

  @override
  String get dashboardEmergency => 'કટોકટી';

  @override
  String get dashboardAddPolicy => 'પોલિસી ફાઇલ ઉમેરો';

  @override
  String get searchTitle => 'શોધો';

  @override
  String get searchHint => 'બધી પોલિસીઓમાં શોધો...';

  @override
  String get searchNoResults => 'કોઈ પરિણામ મળ્યું નથી';

  @override
  String get coverageGapTitle => 'કવરેજ સમીક્ષા';

  @override
  String get coverageGapEmpty =>
      'ઉપલબ્ધ પોલિસી લખાણમાંથી હજી સુધી કોઈ સંભવિત કવરેજ પ્રશ્નો ચિહ્નિત થયા નથી';

  @override
  String get literacyTitle => 'વીમા શબ્દકોશ';

  @override
  String get literacySearchHint => 'શબ્દો શોધો...';

  @override
  String get docTypePickerTitle => 'દસ્તાવેજ પ્રકાર પસંદ કરો';

  @override
  String get fileTypeSupported => 'આધારભૂત ફાઇલ પ્રકારો';

  @override
  String get fileTypePdf => 'PDF દસ્તાવેજો';

  @override
  String get fileTypeImage => 'છબીઓ (JPEG, PNG)';

  @override
  String get fileTypeMaxSize => 'મહત્તમ ફાઇલ કદ: 20 MB';

  @override
  String get fileTypeUnsupported =>
      'આ ફાઇલ પ્રકાર આધારભૂત નથી. કૃપા કરીને PDF અથવા છબી પસંદ કરો.';

  @override
  String get whatIfTitle => 'What-If કેલ્ક્યુલેટર';

  @override
  String get whatIfDescription =>
      'વિવિધ કવરેજ વિકલ્પો તમારા અંદાજિત ખર્ચને કેવી અસર કરે છે તે અન્વેષણ કરો.';

  @override
  String get batchPickMultiple => 'બહુવિધ ફાઇલો પસંદ કરો';

  @override
  String batchUploadingPendingCount(Object count) {
    return '$count ફાઇલો અપલોડ થઈ રહી છે...';
  }

  @override
  String batchUploadingProgress(Object done, Object total) {
    return '$total માંથી $done અપલોડ થયેલ';
  }

  @override
  String get batchCompleted => 'બધી ફાઇલો અપલોડ થઈ';

  @override
  String batchCompletedCount(Object count) {
    return '$count ફાઇલો સફળતાપૂર્વક અપલોડ થઈ';
  }

  @override
  String get batchSomeFailed => 'કેટલાક અપલોડ નિષ્ફળ થયા';

  @override
  String batchFailedCount(Object failed, Object total) {
    return '$total માંથી $failed ફાઇલો નિષ્ફળ';
  }

  @override
  String batchFileTooLargeMB(Object maxMB) {
    return 'આ ફાઇલ $maxMB MB મર્યાદા કરતાં મોટી છે અને છોડી દેવામાં આવશે';
  }

  @override
  String get batchFileUnsupported =>
      'બિનઆધારભૂત ફાઇલ પ્રકાર — છોડી દેવામાં આવ્યું';

  @override
  String get batchDuplicateSkipped => 'ડુપ્લિકેટ — છોડી દેવામાં આવ્યું';

  @override
  String get batchRetryFailed => 'નિષ્ફળ અપલોડ ફરી પ્રયાસ કરો';

  @override
  String get batchDone => 'થઈ ગયું';

  @override
  String get batchAddMore => 'વધુ ફાઇલો ઉમેરો';

  @override
  String get batchSelectAll => 'બધા પસંદ કરો';

  @override
  String get familyVisTitle => 'કવરેજ નકશો';

  @override
  String get familyVisHeader => 'પોલિસી-યાદી કુટુંબ સભ્યો';

  @override
  String get familyVisSubtitle =>
      'દરેક પોલિસીમાં યાદી થયેલા કુટુંબ સભ્યોની તુલના કરો; તમારા વીમા કંપની સાથે કવરેજ ચકાસો.';

  @override
  String get familyVisMembers => 'કુટુંબ સભ્યો';

  @override
  String get familyVisPolicies => 'પોલિસીઓ';

  @override
  String get familyVisEmptyTitle => 'હજી સુધી કોઈ કવરેજ ડેટા નથી';

  @override
  String get familyVisEmptySubtitle =>
      'તમારા પોલિસી દસ્તાવેજોમાં યાદી થયેલા નામોની તુલના કરવા પોલિસીઓ અપલોડ કરો અને કુટુંબ સભ્યો ઉમેરો.';

  @override
  String familyVisNoPolicies(Object name) {
    return '$name ને યાદી કરતી હજી સુધી કોઈ પોલિસી નથી.';
  }

  @override
  String get familyVisSeeMap => 'પોલિસી સભ્ય નકશો જુઓ';

  @override
  String get coverageShareSummary => 'Share summary';

  @override
  String get coverageShareSubject => 'CoverWise policy coverage summary';

  @override
  String get coverageShareError => 'Could not open sharing options';
}
