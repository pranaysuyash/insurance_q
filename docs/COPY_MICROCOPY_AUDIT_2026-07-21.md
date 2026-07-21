# CoverWise Copy & Microcopy Audit

**Date:** 2026-07-21
**Scope:** All user-facing screens, widgets, empty states, error messages, snackbar text, button labels, tooltips, and accessibility labels.
**Method:** Screen-by-screen read-through with ratings per section.

---

## Overall Assessment

| Dimension | Rating | Notes |
|-----------|--------|-------|
| **Tone consistency** | 8/10 | Warm, plain-language, non-jargony. Strong across onboarding and policy detail. |
| **Clarity** | 7/10 | Most text is clear. A few places use internal jargon ("extraction", "substrate", "evidence"). |
| **Empathy** | 8/10 | Error states are gentle. Processing status explains *why* something matters. |
| **Actionability** | 7/10 | CTAs are mostly clear. Some empty states could be more specific about what to do next. |
| **Brevity** | 6/10 | Some screens have verbose subtitles that could be tightened. Long descriptions in onboarding. |
| **Accessibility labels** | 7/10 | Semantics present on most interactive elements. A few spots missing `semanticsLabel`. |
| **Indian English adaptation** | 9/10 | Currency (₹), insurer names, date formats all Indian-context aware. Excellent. |
| **Dark mode copy** | 9/10 | All text uses theme-derived colors. No hardcoded colors breaking in dark mode. |

**Overall: 7.6/10** — Strong foundation with room for refinement in brevity and jargon reduction.

---

## Screen-by-Screen Audit

### 1. Onboarding Screen (`onboarding_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| Page 1 eyebrow | `UNDERSTAND` | ✅ 9/10 | Clear, action-oriented |
| Page 1 title | `Turn policy pages into plain answers.` | ✅ 9/10 | Excellent value prop |
| Page 1 description | `Add a policy once. We process it securely on our servers to surface the cover, exclusions and benefits that matter.` | ⚠️ 7/10 | "Process it securely on our servers" — users may worry about data. Could say "We read your policy so you don't have to." |
| Page 2 eyebrow | `ASK` | ✅ 9/10 | |
| Page 2 title | `Ask your policy, not the internet.` | ✅ 10/10 | Perfect. Memorable. |
| Page 2 description | `Get document-grounded answers in everyday language, with the policy always within reach.` | ⚠️ 7/10 | "Document-grounded" is internal jargon. Users don't think in terms of "grounding". Suggest: "Get clear answers based on your actual policy, not generic advice." |
| Page 3 eyebrow | `STAY READY` | ✅ 8/10 | |
| Page 3 title | `Know what needs attention next.` | ✅ 9/10 | |
| Page 3 description | `Keep policy details, renewals and preparation notes together—without selling you another policy.` | ✅ 9/10 | The "without selling you" line is a strong trust signal. |
| CTA (last page) | `Add my first policy` | ✅ 10/10 | Personal, action-oriented |
| Skip button | `Skip intro` | ✅ 9/10 | Clear |
| Analytics toggle | `Anonymous usage stats` / `Only anonymous usage events are sent; policy content is not included.` | ✅ 9/10 | Transparent and honest |
| Terms checkbox | `I have read and agree to the Privacy Policy and Terms of Service` | ✅ 9/10 | Standard, compliant |

**Summary:** Strong onboarding. Two description refinements suggested.

---

### 2. Dashboard Screen (`dashboard_screen.dart` + widgets)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Home` | ✅ 9/10 | Simple, expected |
| Page header | `Your cover, at a glance` / `See what is protected, what needs attention, and what to do next.` | ✅ 9/10 | Clear, reassuring |
| Refresh tooltip | `Refresh policy overview` | ✅ 8/10 | |
| Error state | `We could not load your policy overview.` | ✅ 9/10 | Uses "we" — empathetic |
| Quick Actions — Ask | `Ask CoverWise` | ✅ 9/10 | Brand + action |
| Quick Actions — Emergency | `Emergency` | ⚠️ 7/10 | Could be `Emergency contacts` or `Get help now` for more clarity |
| Quick Actions — Compare | `Compare` | ✅ 8/10 | |
| Quick Actions — What-If | `What-if` | ⚠️ 6/10 | Not self-explanatory. Suggest: `What-if calculator` or `Explore changes` |
| AI Health Check badge | `Soon` | ✅ 8/10 | Clear coming-soon indicator |
| Welcome card | Dynamic policy counts | ✅ 8/10 | |
| Preventive tips | Dynamic tips from summaries | ✅ 8/10 | |
| First Upload CTA title | `Turn your first policy into clear answers` | ✅ 9/10 | |
| First Upload CTA subtitle | `Choose a PDF or policy image. CoverWise organizes the file and shows the cover, exclusions and dates for you to review.` | ✅ 8/10 | |
| First Upload CTA trust line | `Your original policy is always available. We process it securely to generate summaries.` | ✅ 9/10 | Trust-building |
| First Upload CTA button | `Choose policy file` | ✅ 9/10 | |

**Summary:** Dashboard is well-structured. "What-if" label needs clarification. Emergency button could be more action-oriented.

---

### 3. Documents Screen (`documents_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| Upload CTA (no docs) | `Add your first policy file` | ✅ 9/10 | |
| Upload CTA (has docs) | `Add new policy` | ✅ 9/10 | Compact, contextual |
| Expanded upload title | `Add a policy file` | ✅ 8/10 | |
| Close button tooltip | `Close upload section` | ✅ 8/10 | |
| Select button | `Select Document` | ⚠️ 7/10 | Could be `Choose file` for simpler language |
| OCR toggle | `On-device OCR (experimental)` | ✅ 8/10 | Honest about experimental status |
| Upload button | `Upload & process` | ✅ 9/10 | Clear action |
| Duplicate dialog title | `This policy is already saved` | ✅ 9/10 | |
| Duplicate dialog body | `An identical or matching policy is already on this device:` | ✅ 8/10 | |
| Duplicate dialog explanation | `CoverWise avoids creating duplicate policy records. You can use the saved policy or replace it after deleting the old copy.` | ✅ 8/10 | |
| Duplicate dialog CTA | `Use Saved Policy` | ✅ 8/10 | |
| Error: password required | `This PDF could not be opened.` | ⚠️ 6/10 | Doesn't mention password. Suggest: `This PDF is password-protected. Please unlock it and try again.` |
| Error: storage limit | (via PaywallScreen) | ✅ 8/10 | |
| Offline message | `$selectedName saved locally (offline mode)` | ✅ 8/10 | Honest about offline state |
| Queued message | `$selectedName saved locally; server upload still required` | ⚠️ 7/10 | "server upload still required" sounds like an error. Suggest: `Saved locally. It will be processed when you're back online.` |
| Rate limit message | (via RateLimitDialog) | ✅ 8/10 | |

**Summary:** Good overall. Password error and queued upload messages need refinement.

---

### 4. Q&A Screen (`qa_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Ask CoverWise` | ✅ 9/10 | |
| Tab: Suggested | `Suggested` | ✅ 9/10 | |
| Tab: Your question | `Your question` | ✅ 9/10 | |
| Tab: History | `History` | ✅ 9/10 | |
| Budget banner: zero | `No questions remaining` | ✅ 9/10 | |
| Budget banner: low | `$remaining questions left` | ✅ 8/10 | |
| Budget CTA | `Get more` | ✅ 8/10 | |
| Entitlement block snackbar | `No questions remaining. Buy a Q&A pack or upgrade your plan.` | ✅ 9/10 | Clear, actionable |
| Document selector label | `ASK ABOUT` | ✅ 8/10 | |
| All documents chip | `All Documents ($count)` | ✅ 9/10 | |
| Single document chip | `Single Document` | ✅ 8/10 | |
| Cross-doc hint | `Search across all your uploaded policies` | ✅ 9/10 | |
| Custom question hint | `e.g., What is the effective date?` | ✅ 9/10 | Good example |
| Custom question description | `Ask about cover, exclusions, dates or wording in your policy.` | ✅ 9/10 | |
| Submit button | `Ask CoverWise` | ✅ 9/10 | |
| Error fallback | `Sorry, that didn't work. Please try again.` | ✅ 9/10 | Gentle, non-alarming |
| Error snackbar | `Could not get an answer. ${error}` | ✅ 8/10 | |
| Answer card — Q prefix | `Q: ${question}` | ✅ 8/10 | |
| Answer card — A prefix | `A: ${text}` | ✅ 8/10 | |
| Sources label | `Sources ($count):` | ✅ 8/10 | |
| Follow-up label | `You might also ask:` | ✅ 9/10 | Natural, helpful |
| Feedback tooltips | `Helpful answer` / `Unhelpful answer` | ✅ 9/10 | |
| Copy tooltip | `Copy answer` | ✅ 9/10 | |
| Copy confirmation | `Answer copied to clipboard` | ✅ 9/10 | |
| Share tooltip | `Share answer` | ✅ 8/10 | |
| History empty state | `No question history yet` | ✅ 9/10 | |
| History search hint | `Search history...` | ✅ 9/10 | |
| History no results | `No matches for "$query"` | ✅ 9/10 | |
| History "Show more" | `Show more` / `Show less` | ✅ 9/10 | Standard pattern |
| Confidence badge | `uncalibrated` (when not calibrated) | ⚠️ 6/10 | Internal term. Users won't understand. Suggest: hide entirely or show `Based on available data` |

**Summary:** Q&A screen is one of the best-copied screens. Only the confidence badge label needs work.

---

### 5. Policy Detail Screen (`policy_detail_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Policy details` | ✅ 9/10 | |
| View source tooltip | `View source document` | ✅ 9/10 | |
| Ask question tooltip | `Ask a Question` | ✅ 9/10 | |
| Share tooltip | `Share Policy Summary` | ✅ 9/10 | |
| Page header subtitle (no insurer) | `Your policy, translated into the details that matter.` | ✅ 9/10 | |
| Page header subtitle (with insurer) | `$insurer • Your policy at a glance` | ✅ 9/10 | |
| Corrections badge | `1 field corrected` / `$n fields corrected` | ✅ 9/10 | Clear feedback |
| Status: ACTIVE | `ACTIVE` | ✅ 9/10 | |
| Status: EXPIRED | `EXPIRED` | ✅ 9/10 | |
| Status: EXPIRING | `$n LEFT` | ✅ 9/10 | Urgency without alarm |
| Coverage gaps button | `What your policy covers` | ✅ 9/10 | Plain language |
| Claim assistance button | `How to file a claim` | ✅ 9/10 | Action-oriented |
| Benefits section | `What this policy covers` | ✅ 9/10 | |
| Exclusions section | `Important exclusions` | ✅ 8/10 | Could be `What's NOT covered` for more directness |
| Waiting periods | `Timing conditions` | ⚠️ 6/10 | "Timing conditions" is bureaucratic. Suggest: `Waiting periods` or `When coverage starts` |
| Coverage items header | `Coverage details` / `Item-by-item view` | ⚠️ 7/10 | "Item-by-item view" is jargon. Suggest: `Detailed breakdown` |
| Money labels | `Sum Insured` / `Premium` / `Deductible` | ⚠️ 7/10 | "Sum Insured" is insurance jargon. Suggest: `Coverage amount` or keep but add tooltip |
| Quick action: Ask | `Ask about this policy` | ✅ 9/10 | |
| Quick action: Share | `Share policy summary` | ✅ 9/10 | |
| Quick action: Call | `Call insurer` | ✅ 9/10 | |
| Quick action: Email | `Email insurer` | ✅ 9/10 | |
| Extraction disclaimer | `Extracted on $date from your uploaded policy document. Always verify important details against the source document and your insurer.` | ✅ 9/10 | Honest, builds trust |
| Unverified title | `Not yet verified` | ✅ 9/10 | |
| Unverified explanation | (long paragraph about missing fields) | ⚠️ 7/10 | Too long. Could be 2 sentences. |
| Unverified CTA | `View source document` / `Ask about this policy` | ✅ 9/10 | |
| Snackbar: opening page | `Opening page $n from the source document…` | ✅ 8/10 | |
| Empty: no documents | `No documents available.` | ⚠️ 6/10 | Could be more helpful: `No policies on this device. Upload one to get started.` |
| Empty: doc not found | `Document not found on this device.` | ⚠️ 6/10 | Could suggest: `Try refreshing, or upload the document again.` |
| Empty: no local file | `Source document is only available on the device where it was uploaded.` | ✅ 8/10 | Honest about limitation |

**Summary:** Strong overall. "Timing conditions", "Sum Insured", and "Item-by-item view" need plain-language alternatives.

---

### 6. Emergency Screen (`emergency_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Emergency Card` / `Emergency details` | ✅ 9/10 | |
| Page header | `Help at a glance` / `Keep policy numbers and insurer contact details ready when time matters.` | ✅ 10/10 | Excellent. Urgency without panic. |
| Empty state | `No policies loaded` / `Choose a policy file to keep emergency information ready.` | ✅ 9/10 | |
| Empty CTA | `Choose policy file` | ✅ 8/10 | |
| Status badges | `ACTIVE` / `EXPIRED` / `EXPIRING` | ✅ 9/10 | |
| Info rows | `Policy number` / `Coverage` / `Expires` | ✅ 9/10 | Plain language |
| Call button | `Call insurer • $number` | ✅ 10/10 | Shows number inline — excellent for emergencies |
| Email button | `Email • $email` | ✅ 9/10 | |

**Summary:** Emergency screen has excellent copy. The "Help at a glance" header and inline phone number are standout UX decisions.

---

### 7. Processing Status Screen (`processing_status_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Preparing your policy` | ✅ 9/10 | Reassuring |
| Page header | `Turning pages into answers` | ✅ 10/10 | Beautiful metaphor |
| Stage: Received | `Received` / `Document saved securely` | ✅ 9/10 | |
| Stage: Processing | `Reading text` / `Extracting text from your document` | ✅ 9/10 | Plain language for OCR |
| Stage: Extraction | `Extracting details` / `Identifying coverage, premiums, and dates` | ✅ 9/10 | |
| Stage: Classification | `Classifying` / `Determining policy type and insurer` | ⚠️ 7/10 | "Classifying" is technical. Suggest: `Categorising` or `Identifying policy type` |
| Stage: Indexing | `Indexing` / `Making your policy searchable` | ⚠️ 7/10 | "Indexing" is technical. Suggest: `Finishing up` or `Preparing for search` |
| Stage: Complete | `Complete` / `Your policy is ready` | ✅ 10/10 | |
| Stage: Failed | `Failed` / `Something went wrong` | ✅ 8/10 | Gentle error |
| Dismiss warning | `Still processing?` / `Your document is still being processed. You can close this screen — processing continues in the background.` | ✅ 9/10 | Honest, reassuring |
| Timeout message | `Processing is taking longer than expected. You can close this screen and check back later.` | ✅ 9/10 | |
| Error retry CTA | `Back to documents` | ✅ 8/10 | |

**Summary:** Excellent processing copy. "Classifying" and "Indexing" stages use internal jargon — should be plain language.

---

### 8. Settings Screen (`settings_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Settings` | ✅ 9/10 | |
| Page header | `Your app, your preferences` / `Manage access, reminders and what stays on this device.` | ✅ 9/10 | |
| Plan label | `Current plan: $tier` | ✅ 9/10 | |
| Plan tagline | (dynamic per tier) | ✅ 8/10 | |
| Upgrade CTA | `Upgrade` / `Manage` | ✅ 9/10 | Context-aware |
| Q&A Packs subtitle | `Buy questions without a subscription` | ✅ 9/10 | Clear value prop |
| Renewal date | `Renews` / `$date` | ✅ 8/10 | |
| Account email | (shows email) | ✅ 9/10 | |
| Phone linked | `Account linked` / `Connected as $phone` | ✅ 9/10 | |
| Phone unlinked | `Link your phone` / `Back up policies and use them on another device` | ✅ 9/10 | Clear benefit |
| Appearance | `Appearance` / `$mode` | ✅ 9/10 | |
| Notifications | `Notifications` / `Renewal reminders and quiet hours` | ✅ 9/10 | |
| Smart Suggestions | `Smart Suggestions` / `AI-powered coverage recommendations` | ✅ 8/10 | |
| Clear data dialog | `Clear all local data?` / (detailed warning) | ✅ 9/10 | Thorough, honest |
| Clear data CTA | `Clear` | ✅ 8/10 | |
| Clear confirmation | `All local data cleared.` | ✅ 9/10 | |

**Summary:** Settings screen copy is clean and well-structured.

---

### 9. More Screen (`more_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `More` | ✅ 8/10 | |
| Page header | `Everything else, clearly organised.` / `Tools for understanding, planning and carrying your cover.` | ✅ 9/10 | |
| Search policies | `Search policies` / `Find details across every policy` | ✅ 9/10 | |
| Emergency card | `Emergency card` / `Policy numbers and helplines at a glance` | ✅ 9/10 | |
| Insurance cards | `Insurance cards` / `Keep digital proof of cover close` | ✅ 8/10 | |
| Family | `Family` / `People covered across your policies` | ✅ 9/10 | |
| Renewal calendar | `Renewal calendar` / `Track expiry dates and reminders` | ✅ 9/10 | |
| Coverage gaps | `Coverage gaps` / `Review areas that may need attention` | ✅ 9/10 | |
| Compare policies | `Compare policies` / `See policy details side by side` | ✅ 9/10 | |
| What-if calculator | `What-if calculator` / `Explore possible cover changes` | ✅ 8/10 | |
| Claims info guide | `Claims info guide` / `Understand the usual steps after an incident` | ✅ 8/10 | |
| My claims log | `My claims log` / `Keep a personal record of filed claims` | ✅ 8/10 | |
| Insurance basics | `Insurance basics` / `Learn useful terms without the jargon` | ✅ 9/10 | |
| Profile | `Profile` / `Account information and identity` | ✅ 8/10 | |
| Settings | `Settings` / `Appearance, reminders and local data` | ✅ 9/10 | |
| Notifications | `Notifications` / `Renewal reminders and quiet hours` | ✅ 9/10 | |
| Help & support | `Help & support` / `FAQs and ways to get help` | ✅ 9/10 | |
| Privacy & security | `Privacy & security` / `How CoverWise handles your data` | ✅ 9/10 | |
| About | `About` / `Version, product role and legal information` | ✅ 8/10 | |

**Summary:** More screen has excellent subtitle copy. Each item clearly explains what it does.

---

### 10. Q&A Packs Screen (`qa_packs_screen.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| AppBar title | `Q&A Packs` | ✅ 8/10 | |
| Balance card | `$count questions available` | ✅ 9/10 | |
| Buy section title | `Buy a pack` | ✅ 9/10 | |
| Buy section subtitle | `No subscription needed. Pay once, ask questions.` | ✅ 10/10 | Excellent. Reduces commitment anxiety. |
| Pack: Best value badge | `Best value` | ✅ 9/10 | |
| Buy button | `Buy` | ✅ 8/10 | |
| Purchase success | `Pack purchased! You can now ask more questions.` | ✅ 9/10 | |
| Success CTA | `Start asking` | ✅ 9/10 | |
| FAQ: deduction | `When are questions deducted?` / `A question is deducted each time you submit one.` | ✅ 9/10 | |
| FAQ: expiry | `Do packs expire?` / `Yes, packs are valid for 90 days from purchase.` | ✅ 9/10 | |
| FAQ: stacking | `Can I have multiple packs?` / `Yes! Multiple packs stack.` | ✅ 9/10 | |
| FAQ: upgrade | `What happens if I upgrade to a subscription?` | ✅ 9/10 | |
| Expires warning | `Expires in $n days` (orange when ≤7) | ✅ 9/10 | Good urgency signal |

**Summary:** Q&A Packs screen has excellent copy. The "No subscription needed. Pay once, ask questions." line is a standout.

---

### 11. Empty State Widget (`empty_state_widget.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| Generic empty state | (icon + title + subtitle + action) | ✅ 9/10 | Well-structured, reusable |
| Action button | (dynamic per screen) | ✅ 9/10 | |

**Summary:** Empty states are consistently structured across the app. Good.

---

### 12. Welcome Card (`welcome_card.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| Title | `Your policy hub` | ✅ 9/10 | |
| Subtitle | `$docCount document(s) • $activePolicies active policy/policies` | ✅ 8/10 | |
| Expiring warning | `$expiringCount policy(s) expiring soon` | ✅ 9/10 | |
| Empty state CTA | `Add a policy PDF to see coverage, exclusions and renewal dates in one place.` | ✅ 9/10 | Clear value prop |

**Summary:** Welcome card is clean and informative.

---

### 13. Preventive Tips (`preventive_tips.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| Section label | `Health Tips` | ✅ 8/10 | |
| Dismiss all button | `Dismiss All` | ✅ 8/10 | |
| Individual dismiss tooltip | `Dismiss ${tip.title}` | ✅ 9/10 | |
| Tip title/body | (dynamic from PreventiveHealthService) | ✅ 8/10 | |

**Summary:** Tips section is well-structured with good dismiss affordances.

---

### 14. Loading Widget (`loading_widget.dart`)

| Element | Current Copy | Rating | Issue |
|---------|-------------|--------|-------|
| Default label | `Loading` | ✅ 8/10 | |
| LoadingCard label | `Loading…` | ✅ 8/10 | |

**Summary:** Simple and functional.

---

## Cross-Cutting Issues

### 1. Internal Jargon That Should Be Plain Language

| Location | Current | Suggested |
|----------|---------|-----------|
| ProcessingStatusScreen | `Classifying` | `Categorising` or `Identifying policy type` |
| ProcessingStatusScreen | `Indexing` | `Finishing up` or `Preparing for search` |
| PolicyDetailScreen | `Timing conditions` | `Waiting periods` or `When coverage starts` |
| PolicyDetailScreen | `Sum Insured` | `Coverage amount` (keep tooltip for insurance-savvy users) |
| PolicyDetailScreen | `Item-by-item view` | `Detailed breakdown` |
| QaScreen | `uncalibrated` (confidence badge) | Hide entirely or show `Based on available data` |
| OnboardingScreen | `document-grounded answers` | `clear answers based on your actual policy` |

### 2. Inconsistent Tone in Error Messages

| Location | Current | Issue |
|----------|---------|-------|
| DocumentsScreen | `No documents available.` | Too terse. Add a CTA. |
| DocumentsScreen | `Document not found on this device.` | No recovery action suggested. |
| DocumentsScreen | `This PDF could not be opened.` | Doesn't mention password. |
| DocumentsScreen | `server upload still required` | Sounds like an error, not a status. |

### 3. Missing Accessibility Labels

| Location | Missing Label |
|----------|---------------|
| QuickActions buttons | Some `_ActionButton` instances lack `Semantics` labels |
| History tab search | Has `hintText` but no `Semantics` label for screen readers |
| Policy detail editable fields | Editable fields should have `Semantics` for edit/revert actions |

### 4. Hardcoded Strings That Should Be Localized

All user-facing strings are currently hardcoded in Dart files. For future i18n support, consider extracting to an `AppLocalizations` class. This is a P2 item — not blocking for launch but important for scale.

---

## Priority Fixes

### P0 — Must Fix Before Launch
1. **`uncalibrated` confidence badge** — Hide when `confidenceCalibrated` is false (already done) but the label "uncalibrated" still shows. Should be hidden entirely or replaced with a neutral indicator.
2. **`Timing conditions`** → `Waiting periods` (more familiar to Indian insurance users)
3. **`Sum Insured`** → Add tooltip or use `Coverage amount`

### P1 — Should Fix Soon
4. **Processing status `Classifying`/`Indexing`** → Plain language alternatives
5. **`document-grounded answers`** → Plain language in onboarding
6. **`Item-by-item view`** → `Detailed breakdown`
7. **Documents error messages** — Add recovery actions and mention passwords
8. **`server upload still required`** → Rewrite as positive status

### P2 — Nice to Have
9. Extract all strings to `AppLocalizations` for i18n
10. Add missing `Semantics` labels for screen readers
11. Add tooltips for insurance jargon terms (Sum Insured, Deductible, Premium)

---

## What's Excellent (Keep As-Is)

1. **"Ask your policy, not the internet."** — Best headline in the app. Memorable, clear value prop.
2. **"Turning pages into answers"** — Beautiful processing status metaphor.
3. **"No subscription needed. Pay once, ask questions."** — Reduces commitment anxiety perfectly.
4. **"Help at a glance"** + inline phone number on emergency screen — Outstanding emergency UX.
5. **"Without selling you another policy"** — Strong trust signal in onboarding.
6. **Consistent use of `CoverWise` as the agent name** — Builds brand identity across CTAs.
7. **All error messages use "we" or gentle language** — No blaming the user.
8. **Dynamic subtitles that adapt to state** (e.g., Settings phone link/unlink) — Context-aware copy.
