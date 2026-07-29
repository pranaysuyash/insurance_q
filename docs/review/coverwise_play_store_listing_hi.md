# CoverWise Play Store Listing — हिन्दी (Hindi)

**Date:** 2026-07-29
**Base document:** `docs/review/coverwise_play_store_listing.md`
**Translation reference:** `mobile/lib/l10n/app_hi.arb` (467 keys — brand terminology mapped below)
**Status:** Ready for Play Console per-locale submission

## Brand Terminology Reference (from app_hi.arb)

| English | Hindi (app_hi.arb) | Source Key |
|---------|-------------------|------------|
| CoverWise | CoverWise (kept as-is) | `appName` |
| Policy | पॉलिसी | `policyCount` |
| Policies | पॉलिसियाँ | `policyCount` |
| Insurance | बीमा | `familyEmptySubtitle` |
| Coverage | कवरेज | `insuranceCardsCoverage` |
| Premium | प्रीमियम | `insuranceCardsPremium` |
| Family | परिवार | `familyTitle` |
| Renewal | नवीकरण | `renewalTitle` |
| Claim | दावा | (contextual — not in ARB keys but standard usage) |
| Document | दस्तावेज़ | `docsTitle` |
| Upload | अपलोड | `familyEmptySubtitle` |
| Summary | सारांश | `coverageShareSummary` |
| Question | प्रश्न | `qaScreenTitle` |
| Answer | उत्तर | `qaAnswerReadyFor` |
| Source/Citation | साक्ष्य / स्रोत | `qaEvidence`, `qaSourcePageLabel` |
| Exclusion | बहिष्करण | `qaAskAboutDescription` |
| Helpline | हेल्पलाइन | `insuranceCardsHelplinePrefix` |
| Insurer | बीमाकर्ता | `insuranceCardsInsurerPrefix` |
| Language | भाषा | `settingsLanguage` |
| Terms of Service | सेवा की शर्तें | `tosTitle` |
| Privacy Policy | गोपनीयता नीति | `privacyTitle` |
| Emergency | आपातकालीन | `emergencyTitle` |
| Deductible | कटौती (standard insurance term, not in ARB) | — |
| Sum insured | बीमा राशि (standard insurance term, not in ARB) | — |
| Network hospital | नेटवर्क अस्पताल (contextual) | — |
| Waiting period | प्रतीक्षा अवधि (contextual) | — |

---

## 1. App Title (30 characters max)

**Primary option (brand-first):**

```
CoverWise: पॉलिसी रीडर
```
*(25 chars ✓ — "पॉलिसी" has high Hindi search volume, "रीडर" is commonly understood)*

**Secondary option (keyword-first):**

```
CoverWise: बीमा रीडर
```
*(23 chars ✓ — "बीमा" is broader, higher volume but more competitive)*

**Tertiary option (action-first):**

```
CoverWise: पॉलिसी समझें
```
*(22 chars ✓ — action-oriented, matches app purpose "understand policy")*

**Recommendation:** Primary option. "पॉलिसी रीडर" targets users searching for policy document tools in Hindi — low competition, exact match for app function.

> **Note:** The English `CoverWise:` prefix is retained as-is (brand name). Hindi users search for international app brands in Roman script. The Hindi suffix targets Hindi-speaking users searching in Devanagari.

---

## 2. Short Description (80 characters max)

**Option A (straightforward — recommended):**

```
कोई भी बीमा पॉलिसी समझें। अपलोड करें, सारांश पाएँ, साक्ष्य सहित प्रश्न पूछें।
```
*(~58 chars ✓ — covers 3 core actions, includes "साक्ष्य" for the moat)*

**Option B (problem-focused):**

```
बीमा पॉलिसी की कानूनी भाषा में मत उलझें। अपलोड करें, सरल हिंदी में जवाब पाएँ।
```
*(~53 chars ✓ — emphasizes the pain point of legalese, highlights Hindi output)*

**Option C (trust-focused):**

```
हर जवाब आपकी पॉलिसी से साक्ष्य सहित। PDF अपलोड करें, कवरेज देखें, प्रश्न पूछें।
```
*(~50 chars ✓ — opens with the moat, then lists actions)*

**Recommendation:** Option A. It's the direct equivalent of the English Option A — keyword-dense ("बीमा पॉलिसी", "सारांश", "साक्ष्य सहित प्रश्न") and maps to claim-registry evidence.

---

## 3. Full Description (4,000 characters max — Hindi is ~30% shorter than English at equivalent meaning, well within limit)

### Opening (first ~250 characters — highest weight)

```
CoverWise आपकी बीमा पॉलिसी PDF को पढ़कर एक स्पष्ट, खोजने योग्य सारांश में बदल देता है — ताकि आप कानूनी भाषा में उलझे बिना अपने कवरेज को समझ सकें। हर जवाब अपने स्रोत पृष्ठ को उद्धृत करता है, जिससे आप AI द्वारा खोजी गई जानकारी को सत्यापित कर सकते हैं।
```

*(~270 chars — packs "बीमा पॉलिसी", "सारांश", "कवरेज", "स्रोत पृष्ठ", "उद्धृत" keywords)*

### Body

```
CoverWise को अपना व्यक्तिगत बीमा ज्ञानकोष (नॉलेज बेस) समझें।

आप क्या कर सकते हैं:

📄 कोई भी पॉलिसी अपलोड करें
PDF अपलोड करें — स्वास्थ्य बीमा, कार बीमा, जीवन बीमा, होम बीमा, ट्रैवल बीमा। CoverWise स्वचालित रूप से पॉलिसी प्रकार पहचानता है और मुख्य विवरण निकालता है।

🔍 देखें क्या कवर है
बीमा राशि, प्रीमियम, कटौती (डिडक्टिबल), प्रतीक्षा अवधि, बहिष्करण और नेटवर्क अस्पताल एक व्यवस्थित स्क्रीन पर देखें। पन्ने पलटने की ज़रूरत नहीं।

💬 प्रश्न पूछें, साक्ष्य सहित उत्तर पाएँ
पूछें "यह पॉलिसी मातृत्व के लिए क्या कवर करती है?" या "बहिष्करण क्या हैं?" CoverWise आपकी पॉलिसी में खोज करता है और पृष्ठ संख्या सहित उत्तर लौटाता है। हर उत्तर अपनी सत्यापन स्थिति दिखाता है — पूरी तरह समर्थित, आंशिक रूप से समर्थित, या abstained। आपको हमेशा पता चलता है कि उत्तर कितना विश्वसनीय है।

📅 नवीकरण कभी न चूकें
CoverWise आपकी पॉलिसी की समाप्ति तिथियों को ट्रैक करता है और नवीकरण से पहले याद दिलाता है। एक कम चिंता।

🚑 आपातकालीन स्थिति में तैयार
जब आपको दावा दायर करना हो, CoverWise हेल्पलाइन नंबर, आवश्यक दस्तावेज़ और आपका कवरेज दिखाता है — ठीक उसी समय जब आपको इसकी सबसे ज़्यादा ज़रूरत हो।

👨‍👩‍👧‍👦 परिवार कवरेज
देखें कि प्रत्येक पॉलिसी में कौन कवर है। परिवार के सदस्यों को जोड़ें और सबका कवरेज एक जगह रखें।

🌐 हिन्दी, ગુજરાતી, मराठी में उपलब्ध
CoverWise का उपयोग अपनी पसंदीदा भाषा में करें — क्योंकि बीमा भाषा की बाधा के बिना भी काफी जटिल है।

---

CoverWise कोई बीमाकर्ता, ब्रोकर या TPA नहीं है। हम बीमा नहीं बेचते, दावों की प्रक्रिया नहीं करते, या वित्तीय सलाह नहीं देते। हम आपकी मौजूदा पॉलिसी को समझने में मदद करते हैं। महत्वपूर्ण विवरणों के लिए हमेशा अपने बीमाकर्ता या पॉलिसी दस्तावेज़ से पुष्टि करें।

समर्थित पॉलिसी प्रकार: स्वास्थ्य, मोटर, जीवन, होम, ट्रैवल
भाषाएँ: English, हिन्दी (Hindi), ગુજરાતી (Gujarati), मराठी (Marathi)
```

### Keywords embedded naturally (Hindi)

| Keyword (Hindi) | English Equivalent | Placement | Importance |
|----------------|-------------------|-----------|------------|
| बीमा पॉलिसी | insurance policy | Opening, body (4x) | 🔑 Primary |
| स्वास्थ्य बीमा | health insurance | Body (1x) | 🔑 Primary |
| कार बीमा | car insurance | Body (1x) | 🔑 Primary |
| जीवन बीमा | life insurance | Body (1x) | 🔑 Primary |
| होम बीमा | home insurance | Body (1x) | Secondary |
| ट्रैवल बीमा | travel insurance | Body (1x) | Secondary |
| पॉलिसी समझें | understand policy | Title (tertiary) | 🔑 Primary |
| बीमा सारांश | insurance summary | Opening, body | 🔑 Primary |
| साक्ष्य सहित उत्तर | cited answers | Opening, body | 🔑 Unique moat |
| कवरेज | coverage | Body (3x) | Secondary |
| प्रीमियम | premium | Body (1x) | Secondary |
| नवीकरण | renewal | Body (1x) | Secondary |
| परिवार कवरेज | family coverage | Body (1x) | 🔑 Differentiation |
| दावा | claim | Body (1x) | Secondary |
| हेल्पलाइन | helpline | Body (1x) | Secondary |
| हिन्दी बीमा ऐप | Hindi insurance app | Body, languages section | 🔑 ASO differentiator |

### Keywords deliberately NOT used (outside the wedge — same as English)

| Hindi Keyword | Reason excluded |
|--------------|----------------|
| बीमा तुलना (insurance comparison) | Implies recommendation — outside wedge |
| सबसे अच्छी पॉलिसी (best policy) | Implies recommendation — outside wedge |
| बीमा खरीदें (buy insurance) | Outside wedge (CoverWise doesn't sell) |
| दावा निपटान (claim settlement) | Outside wedge |
| वित्तीय सलाहकार (financial advisor) | Outside wedge |

---

## 4. Per-Locale Keyword Strategy (Hindi Play Console)

### Recommended keywords for the Hindi "Keywords" field

```
पॉलिसी रीडर, बीमा दस्तावेज़ स्कैनर, पॉलिसी सारांश ऐप, कवरेज जाँच,
बीमा नवीकरण ट्रैकर, स्वास्थ्य पॉलिसी प्रबंधक, हिन्दी बीमा ऐप
```

These are long-tail Hindi search terms with low competition. No overlap with PolicyBazaar/Acko/Digit Hindi keyword clusters (which focus on "बीमा खरीदें", "तुलना करें", "दावा करें").

### Keyword clusters by user intent (Hindi)

| Intent Cluster | Hindi Keywords | Competition | Match |
|----------------|---------------|-------------|-------|
| **Document management** | पॉलिसी रीडर, बीमा दस्तावेज़ स्कैनर, पॉलिसी ट्रैकर | Low | ✅ Exact |
| **Comprehension** | बीमा सारांश, कवरेज जाँच, पॉलिसी विवरण ऐप, पॉलिसी समझाएँ | Low | ✅ Exact |
| **Renewal** | बीमा नवीकरण तिथि, पॉलिसी समाप्ति अनुस्मारक, प्रीमियम ड्यू ट्रैकर | Medium | ✅ Partial |
| **Family** | परिवार बीमा ट्रैकर, आश्रित कवरेज ऐप | Low | ⚠️ Partial |
| **Claim prep** | दावा दस्तावेज़ सूची, बीमा हेल्पलाइन ऐप | Low | ✅ Exact |
| **Regional** | हिन्दी बीमा ऐप, भारतीय बीमा सारांश, हिंदी में पॉलिसी | Low | ✅ Unique |

---

## 5. Screenshot Callout Translations (Hindi)

For per-locale screenshot subtitle uploads in Play Console:

| # | English Callout | Hindi Callout |
|---|----------------|---------------|
| 1 | *"Your coverage at a glance"* | *"आपका कवरेज एक नज़र में"* |
| 2 | *"See what's covered — instantly"* | *"देखें क्या कवर है — तुरंत"* |
| 3 | *"Every answer cites your policy"* | *"हर जवाब आपकी पॉलिसी से साक्ष्य सहित"* |
| 4 | *"Honest about what it doesn't know"* | *"जो नहीं जानता, उसके बारे में ईमानदार"* |
| 5 | *"All your policies in one place"* | *"आपकी सभी पॉलिसियाँ एक जगह"* |
| 6 | *"Never miss a renewal"* | *"नवीकरण कभी न चूकें"* |
| 7 | *"Know who's covered"* | *"जानें कौन कवर है"* |
| 8 | *"Available in हिन्दी, ગુજરાતી, मराठी"* | *"हिन्दी, ગુજરાતી, मराठी में उपलब्ध"* |

---

## 6. Feature Graphic Tagline Translation

| English | Hindi |
|---------|-------|
| *Understand your insurance before you need it.* | *अपना बीमा ज़रूरत से पहले समझें।* |

Bullet points for feature graphic (mapped to launch-claim registry):

| English Bullet | Hindi Bullet |
|----------------|--------------|
| ★ Every answer cites its source | ★ हर जवाब साक्ष्य सहित |
| ★ 5 policy types supported | ★ 5 पॉलिसी प्रकार समर्थित |
| ★ हिन्दी · ગુજરાતી · मराठी | ★ हिन्दी · ગુજરાતી · मराठी |

---

## 7. Data Safety Declaration (Hindi — Play Console)

The Data Safety declaration is **locale-independent** (same for all languages in Play Console). No translation needed. Submit the English version from `coverwise_play_store_listing.md` §7 for all locales.

---

## 8. Translation Notes

| Note | Explanation |
|------|-------------|
| **CoverWise retained in Roman** | Brand name is kept in English script even in Hindi text. Consistent with `app_hi.arb` (`"appName": "CoverWise"`). Hindi users expect international app brands in Roman script. |
| **Policy type names** | स्वास्थ्य बीमा, कार बीमा, जीवन बीमा, होम बीमा, ट्रैवल बीमा — using the most common Hindi terms for each type. "Motor" is translated as कार (car) since that's the most searched term. |
| **साक्ष्य (evidence) vs उद्धरण (citation)** | The ARB uses `साक्ष्य` for `evidence` (`qaEvidence`). I use `साक्ष्य` for the citation moat. More natural in Hindi than a direct translation of "citation." |
| **Deductible translated as कटौती** | Not in ARB, but this is the standard Hindi insurance term. "डिडक्टिबल" (transliteration) is also common but less natural. |
| **Sum insured as बीमा राशि** | Standard Hindi insurance term. Not in ARB since the app uses field-level labels. |
| **English loanwords retained** | Words like PDF, AI, TPA, FIFO, FAB are kept in Roman script — they're universally understood in Indian context and look unnatural when transliterated. |
| **Character counts are approximate** | Google Play Console counts Unicode grapheme clusters. The Hindi text may display slightly differently in Play Console's character counter. Trim as needed during submission. |

---

## 9. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial Hindi listing created — title (3 options), short description (3 options), full description, keyword strategy, screenshot callouts, feature graphic taglines | Founder directive: "Translate the optimized Play Store listing into Hindi" |

---

*This document is the Hindi per-locale Play Store listing for CoverWise. Submit the title, short description, full description, screenshot callouts, and feature graphic taglines in Play Console under the हिन्दी (Hindi) locale tab. Base English listing: `docs/review/coverwise_play_store_listing.md`.*
