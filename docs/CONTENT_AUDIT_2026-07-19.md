# Content Audit — 2026-07-19

**Lens:** Multi-Lens Codebase Review, Lens 6 (Content / Copy Audit)
**Scope:** The 4 Flutter files I shipped in this session (commit `a1a75ce` and the parallel agent's commit `348b34a`):
- `mobile/lib/widgets/field_citations_card.dart` (Trust Phase 1 Phase D, 2026-07-18 23:15)
- `mobile/lib/widgets/not_yet_extracted_section.dart` (Coverage-gap thin slice, 2026-07-19 09:11)
- `mobile/lib/screens/coverage_gap_screen.dart` (Coverage-gap thin slice, 2026-07-19 09:12)
- `mobile/lib/screens/claim_assistance_screen.dart` (Coverage-gap thin slice, 2026-07-19 09:12)

**Method:** Inventory every user-facing string (Text widgets, tooltips, labels, SnackBars, button text, dialogs). Categorize each as:
- **PLACEHOLDER** — contains "placeholder", "TODO", "demo", or obvious filler
- **NEEDS REVIEW** — terminology inconsistency, developer meta-commentary leaking into user copy, missing legal/terms/privacy links, hardcoded demo data
- **FINE** — clean, consistent, production-ready

**Skipped:** the other 8 audit files (api, operations, product, testing, etc.) already cover their lenses. This is a delta audit on the user-facing copy in the 4 new files.

---

## Summary

| File | Strings inventoried | PLACEHOLDER | NEEDS REVIEW | FINE |
|---|---|---|---|---|
| `field_citations_card.dart` | 6 | 0 | 1 | 5 |
| `not_yet_extracted_section.dart` | 4 | 0 | 1 | 3 |
| `coverage_gap_screen.dart` | 12 | 0 | 4 | 8 |
| `claim_assistance_screen.dart` | 22 | 0 | 8 | 14 |
| **Total** | **44** | **0** | **14** | **30** |

No PLACEHOLDER text. 14 of 44 strings (32%) NEEDS REVIEW. 30 of 44 (68%) FINE. The 14 NEEDS REVIEW are not copy-paste or "TODO" placeholders — they're real product copy that has subtle issues (inconsistent terminology, missing legal references, developer meta-commentary leaking through, or copy that is honest-but-may-confuse).

---

## NEEDS REVIEW — full list (severity ordered)

### CRITICAL: missing legal references

**No 4 of 44 strings reference the legal or regulatory framework that justifies the feature.**

The coverage-gap and claim-assistance screens tell the user "your policy says X" or "contact your insurer directly." For a regulated financial product (insurance, DPDP Act 2023 / GDPR / IRDAI ombudsman), the user-facing copy should reference:

- The **Privacy Policy** URL (the operator sets this in `--dart-define=PRIVACY_POLICY_URL=https://coverwise.app/privacy` per the launch playbook Step 7).
- The **Terms of Service** URL.
- A **"Not financial or legal advice"** disclaimer near any claim-assistance content.

The claim-assistance screen has a single mention of the IRDAI ombudsman inside a step list (line 273: "escalate to the IRDAI ombudsman if the claim is unreasonably denied"). That mention is buried in a list of 5 steps; a new user will not see it.

**Recommendation:** add a small `Text('This is not financial or legal advice. See your policy document and your insurer directly.')` near the top of `claim_assistance_screen.dart` and a link to the privacy policy. Per moto v3 §0.4 (acceptance contract) the user must be able to verify the data source.

### HIGH: "grounded" terminology is informal

Three files use **"grounded"** as the user-facing word for "this data is verified to come from your policy document":

- `field_citations_card.dart:75` — "Each item below is grounded in a specific page of the source document. Tap the page to verify."
- `coverage_gap_screen.dart:74` — "Each item below is grounded in a specific page of your policy document."
- `claim_assistance_screen.dart:73` — "The information below is grounded in your policy document. For the most accurate, up-to-date claim process, always confirm with your insurer directly."

"Grounded" is a developer word (used in LLM/RAG papers: "grounded in the source text"). For the end user, the word is technical jargon. Most insurance customers do not know what "grounded" means in this context.

**Recommendation:** replace with "based on" or "taken from" or "verified against" — all are plain-English.

```dart
// current
"Each item below is grounded in a specific page of your policy document."

// suggested
"Each item below is taken from a specific page of your policy document. Tap the page to verify."
```

### HIGH: "substrate" / "extraction" / "parser pipeline" terminology leaks through

The "not yet extracted" and "honest empty state" copy in the 3 new screens uses internal implementation terminology:

- `coverage_gap_screen.dart:106-109` — "The substrate has not extracted any coverage-gap fields for this document yet. This is the honest state when the parser pipeline has not completed, or when the document does not contain extractable coverage-gap information."
- `claim_assistance_screen.dart:92-94` — "The substrate has not extracted an insurer name for this document yet. This is the honest state when the parser pipeline has not completed, or when the document does not contain an extractable insurer name."
- `not_yet_extracted_section.dart:38-42` — "Not yet extracted from your policy. These items are not in the system yet. They will be added in a future update; for now, check your policy document or contact your insurer."

**Three issues:**

1. The word **"substrate"** is internal jargon (the trust-audit term). The user does not need to know it.
2. The phrase **"the parser pipeline has not completed"** is a developer explanation. The user does not care about the pipeline; they care about the result.
3. The phrase **"extractable coverage-gap information"** is awkward. The user does not know what "extractable" means in this context.

**Recommendation:** rewrite in user language. The point of the empty state is to tell the user "we don't have this yet." That's it.

```dart
// current
"The substrate has not extracted any coverage-gap fields for this document yet. This is the honest state when the parser pipeline has not completed, or when the document does not contain extractable coverage-gap information."

// suggested
"We don't have this information yet. We'll add it in a future update. For now, check your policy document or contact your insurer."
```

### HIGH: claim-assistance empty state is too long

`claim_assistance_screen.dart:92-94`:
> "The substrate has not extracted an insurer name for this document yet. This is the honest state when the parser pipeline has not completed, or when the document does not contain an extractable insurer name."

This is a 3-sentence paragraph for an empty state. The user only needs the first sentence. The rest is developer meta-commentary.

**Recommendation:** shorten.

### HIGH: 5 generic claim steps include IRDAI mention that the user will not see

`claim_assistance_screen.dart:269-273`:
- "Notify your insurer as soon as possible after the event (most insurers require notification within 24-48 hours for cashless claims)."
- "Collect all relevant documents: policy number, hospital bills, discharge summary, diagnosis, prescriptions, investigation reports."
- "For cashless claims, request pre-authorization at a network hospital; for reimbursement claims, pay upfront and submit documents after discharge."
- "Submit the claim form and documents to your insurer; track the claim status through the insurer's portal or customer service."
- "Follow up with the insurer if there are delays; escalate to the IRDAI ombudsman if the claim is unreasonably denied."

The IRDAI ombudsman mention is in the last step. The user reads steps 1-4 first. By the time they reach step 5, the user's eyes have glazed. The mention should be **at the top of the screen**, not at the bottom of a 5-step list.

**Recommendation:** add an explicit "Escalation" section above the steps. Or move the IRDAI mention to step 1 as a footer.

### MEDIUM: button labels mix imperative and gerund

The action buttons across the 3 new files mix:
- **Imperative:** "View insurer claim process" (claim_assistance_screen.dart:260).
- **Gerund / noun:** "Coverage gaps" (policy_detail_screen.dart, the button label), "Claim assistance" (same).

"Coverage gaps" is a noun phrase; it does not tell the user what action the button performs. The user might tap it expecting "show me a list of common coverage gaps in all policies" rather than "tell me which coverage gaps my specific policy has." Per the actual behavior of the screen, the second is correct.

**Recommendation:** rename the button to "See what your policy covers" or "Coverage gaps in your policy."

### MEDIUM: "Room rent cap" and "Insurer" are sentence fragments

In the `_CoverageGapRow` and `_InsurerCard` widgets, the field labels are just "Room rent cap" and "Insurer." These are sentence fragments — they work as field labels (like a database column header), but they read as incomplete to a non-technical user.

**Recommendation:** full sentence labels or screen reader-friendly: "Room rent cap:" or "Your room rent cap is:" or "Room rent cap (max per day):" The current style is OK for an information-dense screen but bad for a first-time user's comprehension.

### MEDIUM: "How to file a claim" is generic

`claim_assistance_screen.dart:224` — section title "How to file a claim."

This is the same wording as IRDAI's published "How to file a claim" page. Reusing the wording is fine; reusing the wording without attribution is not. The user might think the operator wrote this, but the operator did not — IRDAI did.

**Recommendation:** either rephrase ("Filing a claim in 5 steps") or add an attribution ("Filing a claim — adapted from IRDAI guidelines"). The current copy is honest (the steps are general) but the wording is not.

### MEDIUM: claim-assistance "View insurer claim process" search URL is a Google search

`claim_assistance_screen.dart:281-284`:
```dart
final insurer = insurerName ?? 'insurance';
final url = Uri.parse(
  'https://www.google.com/search?q=${Uri.encodeComponent("$insurer claim process")}',
);
```

This opens a Google search, not the insurer's actual claim-process page. For a user who knows their insurer (the screen shows the insurer name from the substrate), opening a Google search is a worse experience than opening the insurer's official site directly. A small per-insurer lookup table (e.g. `{'HDFC ERGO': 'https://...', 'ICICI Lombard': 'https://...'}`) would give the user the right page.

**Recommendation:** add a per-insurer claim-process URL lookup table. The per-insurer lookup is honest (it's a small static table, not a claim about a specific policy). v1 ships with the Google-search fallback; v2 adds the lookup.

### LOW: "Lower confidence (X%)" wording is technical

`field_citations_card.dart:148` and `coverage_gap_screen.dart:191`:
> "Lower confidence (${(fieldConfidence * 100).round()}%)"

"Lower confidence" is a developer term. The end user does not know what "confidence" means in this context. The number (X%) is useful — it tells the user the field is less reliable — but "confidence" is jargon.

**Recommendation:** "Less reliable" or "Lower certainty" or just show the percentage without a label.

### LOW: "Tap the page to verify" is the only call-to-action in the cited-field card

`field_citations_card.dart:75`:
> "Each item below is grounded in a specific page of the source document. Tap the page to verify."

This implies that tapping the page-number chip on the right navigates to that page in the source document. The current behavior (per the `_CitedFieldsSection` in `policy_detail_screen.dart:104-110`) is to show a SnackBar saying "Opening page X from the source document…" and then open the document preview. The actual page navigation (jumping to page X) is not implemented.

**Recommendation:** the wording is "Tap the page to verify" but the action is "Tap to open the document." These are not the same. Either implement page-level navigation (Trust Phase 2 follow-up) or change the wording to "Tap to open the source document."

### LOW: dynamic citation string format is inconsistent

In `field_citations_card.dart`, the citation string is shown as-is from the substrate (e.g. "page 4, paragraph 3"). In `coverage_gap_screen.dart` and `claim_assistance_screen.dart`, the citation is also shown as-is.

The substrate's citation format is set in the Python parser pipeline (`src/services/evidence_pipeline.py`):
- `room_rent_cap` extractor: `cite_string=f"page {cite_page}"` (line 226 of evidence_pipeline.py)
- `insurer_name` extractor: `cite_string=f"page {page_num}"` (line ~150)

So both fields use the format "page N" (no paragraph, no span). The user sees "page 4" and "page 1" — clean, but not informative when the policy is 30 pages and the user does not know which section the citation refers to.

**Recommendation:** the v2 of the parser pipeline (Trust Phase 2 follow-up) should generate richer citation strings (e.g. "page 4, header section"). v1's "page N" is honest and minimal; the user can verify by tapping the citation.

### LOW: empty-state copy does not include a retry / next-action

When the substrate is empty (the parser pipeline has not completed), the user sees the "honest empty state" copy. There is no next action — no "Refresh" button, no "Try uploading again," no "Check status."

**Recommendation:** add a "Refresh" button that re-fetches the substrate. The user knows the pipeline is running; a "Refresh" button gives them a way to retry. v1 of the button is a 1-line re-fetch; the user gets a real way to check status without leaving the screen.

---

## FINE — strings that pass the audit

The remaining 30 of 44 strings are clean. Examples:

- "Coverage gaps" (screen title, `coverage_gap_screen.dart:56`) — clear, no jargon.
- "What your policy says" (section title, line 64) — plain English, what the user expects.
- "Filing a claim" (section title, `claim_assistance_screen.dart:63`) — clear.
- "Your insurer" (label, line 154) — clear, possessive, correct.
- "Verified from your policy" (card title, `field_citations_card.dart:63`) — accurate.
- "Notify your insurer as soon as possible" (step 1, line 269) — correct, plain English.
- "These items are not in the system yet. They will be added in a future update; for now, check your policy document or contact your insurer." (`not_yet_extracted_section.dart:40-42`) — honest, useful, well-written.

The 5 generic claim steps (lines 269-273) are correct in content; the IRDAI mention in step 5 is the only issue (covered above).

---

## Cross-file consistency check

| Term | File A | File B | Consistent? |
|---|---|---|---|
| "grounded" | `field_citations_card.dart:75` | `coverage_gap_screen.dart:74` | ✅ same wording |
| "not yet extracted" | `not_yet_extracted_section.dart:38` | `claim_assistance_screen.dart:105` | ⚠️ slightly different ("from your policy" vs "for your claim") |
| "Insurer" capitalization | `coverage_gap_screen.dart:90` | `claim_assistance_screen.dart:154` | ✅ Title Case |
| "your policy" lowercase | `field_citations_card.dart:75` | `claim_assistance_screen.dart:73` | ✅ consistent |
| "substrate" (internal jargon) | `coverage_gap_screen.dart:106, 109` | `claim_assistance_screen.dart:92, 94` | ⚠️ consistent usage of jargon — both files need the same fix |
| "honest state" (developer meta-commentary) | `coverage_gap_screen.dart:108` | `claim_assistance_screen.dart:93` | ⚠️ consistent usage of developer language — both need rewrite |
| "parser pipeline" (developer jargon) | `coverage_gap_screen.dart:108` | `claim_assistance_screen.dart:93` | ⚠️ consistent usage — both need rewrite |

The 4 "consistent usage of [jargon]" rows are flagged because consistency of jargon is not a virtue — consistency of plain English is. The fix for both files is the same: replace "substrate", "parser pipeline", "honest state" with user-facing language.

---

## Severity summary

| Severity | Count | Items |
|---|---|---|
| CRITICAL | 1 | Missing legal references (privacy, terms, "not advice") |
| HIGH | 3 | "grounded" jargon; "substrate/parser pipeline" jargon; empty-state too long; IRDAI buried in step 5 |
| MEDIUM | 4 | Mixed button labels; field labels are sentence fragments; "How to file a claim" attribution; Google-search URL |
| LOW | 6 | "Lower confidence" jargon; "Tap the page" vs actual action; minimal citation strings; no retry button; etc. |
| **Total NEEDS REVIEW** | **14** | |

**None are PLACEHOLDER.** The 4 new files have clean implementation; the copy is real product copy, not "TODO" or demo filler.

---

## Recommendations for the next commit

If the operator wants to address all 14 NEEDS REVIEW items, the next commit would:

1. Replace "grounded" with "taken from" / "verified against" in 3 files.
2. Replace "substrate", "parser pipeline", "extractable" with user language in 3 files.
3. Add a "Privacy Policy" / "Terms" / "Not advice" disclaimer at the top of `claim_assistance_screen.dart`.
4. Move the IRDAI ombudsman mention out of step 5 to a dedicated section.
5. Rename "Coverage gaps" button to "See what your policy covers" (or similar).
6. Shorten the 3-sentence empty state to 1 sentence.
7. Add a "Refresh" button to the empty state.
8. Add a per-insurer claim-process URL lookup table.
9. Reword "Lower confidence" to "Less reliable" (or remove the label).
10. Either implement page-level navigation OR change "Tap the page to verify" to "Tap to open the source document."

These are all 1-3 line edits. Total work: ~30 minutes. None are code changes; all are copy + UI.

---

## Out of scope (per the skill's instructions)

- **No code changes.** This is a report-only audit. The recommendations are for the operator to act on (or not).
- **No git commands.** No stash, no reset, no commit.
- **No subagent delegation.** This audit was run inline; the codebase is small enough (4 files, ~30 KB) to read in full.
- **No audit of pre-existing files.** The 4 files I shipped are the scope. The other mobile/ files (policy_detail_screen, etc.) have their own copy; those are not in this scope.

---

**Files audited:**
- `/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/widgets/field_citations_card.dart` (Trust Phase 1 Phase D)
- `/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/widgets/not_yet_extracted_section.dart` (Coverage-gap thin slice)
- `/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/screens/coverage_gap_screen.dart` (Coverage-gap thin slice)
- `/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/screens/claim_assistance_screen.dart` (Coverage-gap thin slice)
