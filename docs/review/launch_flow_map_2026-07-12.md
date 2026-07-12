# CoverWise — Complete Product Flow Map

**Date:** 2026-07-12
**Purpose:** Launch-readiness audit. Every screen, every flow, what exists,
what should exist, and gaps — from a solo-founder personal-brand launch
perspective.

---

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│                    CoverWise App                      │
│                   (Flutter, 5 tabs)                   │
│                                                       │
│  ┌─────────┐ ┌──────────┐ ┌────┐ ┌───────┐ ┌──────┐│
│  │ Home    │ │Documents │ │ QA │ │Family │ │ More ││
│  │(Dash)   │ │          │ │    │ │       │ │      ││
│  └────┬────┘ └────┬─────┘ └─┬──┘ └───┬───┘ └──┬───┘│
│       │           │         │        │         │     │
│       ▼           ▼         ▼        ▼         ▼     │
│  ┌─────────────────────────────────────────────────┐│
│  │            Riverpod Providers                   ││
│  │  documents │ summaries │ family │ qa │ questions││
│  └────────────────────┬────────────────────────────┘│
│                       │                              │
│  ┌────────────────────▼────────────────────────────┐│
│  │         Services Layer (Dio HTTP)                ││
│  │  DocumentService │ QueryService │ PolicyExtract ││
│  └────────────────────┬────────────────────────────┘│
│                       │                              │
│  ┌────────────────────▼────────────────────────────┐│
│  │       Hive (local persistence, offline-first)   ││
│  │  documents │ app_state │ qa_history │ summaries ││
│  └─────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────┘
                        │ HTTPS
                        ▼
┌───────────────────────────────────────────────────────┐
│              Backend (FastAPI, AWS App Runner)         │
│                                                       │
│  POST /query    → RAG (OpenAI embed + chat + Qdrant) │
│  POST /documents/upload → OCR → ingest → Qdrant      │
│  GET  /documents/{id}/summary → LLM extraction        │
│  GET  /health    → real embedding probe               │
│  GET  /documents/usage-stats → rate limit status      │
└───────────────────────────────────────────────────────┘
```

---

## Tab 1: Home / Dashboard (`dashboard_screen.dart`)

### What exists
- Welcome card: document count, active/expiring policy count
- Policy summary cards: one per uploaded policy (type icon, insurer, status
  badge ACTIVE/EXPIRED/Nd LEFT, coverage/premium/expires chips, policy number)
- Document type overview: 6 hardcoded type cards (Health/Auto/Home/Life/
  Travel/Other) with counts
- Quick actions: Upload Document, Ask a Question, Compare Policies, Insurance
  Terms
- Family section: merged auto-detected + manual members, with Add button
- Recent activities: recently deleted documents, recent questions
- Insurance terminology: 4 terms with "View All"
- Refresh via pull-to-refresh + AppBar button

## Addendum (2026-07-12) — policy-type visual explorer

The dashboard's former horizontal text-card strip has been replaced by a
responsive, keyboard/screen-reader-labelled icon explorer. Each policy type is
represented by its protected object (heartbeat, car, person, home, plane, or
archive) plus a shield badge, an accurate canonical-policy count, selection
motion, and a short plain-language explanation. Counts now use
`mobile/lib/utils/policy_type.dart` rather than raw document-type string
matching, so policy names such as Mediclaim and Term Plan remain in their
correct visual category.

### iOS build compatibility

The iOS deployment target is now 15.5 across the Podfile, Runner target and
Flutter framework metadata. This matches the minimum required by the installed
`google_mlkit_commons` plugin and removes the prior CocoaPods resolution block
when running the app on the current iOS simulator.

### What should exist
- ✅ Welcome card — good
- ✅ Policy summary cards — good, but should show key benefits/exclusions
  (currently extracted but never displayed)
- ⚠️ Document type cards should use flexible type mapping, not hardcoded
  string matching (Indian policies use "Mediclaim", "Family Floater", etc.)
- ✅ Quick actions — good
- ✅ Family section — good (now supports manual add)
- ⚠️ Recent activities section is thin — should show recent Q&A, not just
  deleted docs
- ✅ Terminology — good touch for the target audience

### Gaps
- **Error state has no retry button** — just `Text('Error: $e')`
- **Family section error masked as empty** — backend failure looks like "no
  data"
- **Type classification is fragile** — string `.contains('health')` won't match
  "Mediclaim" or "Family Floater"

---

## Tab 2: Documents (`documents_screen.dart` + `documents_list.dart`)

### What exists
- Upload card: select file → upload → progress → success/error
- Usage stats widget (rate limit display: X/5 uploads)
- Duplicate detection (checks before upload)
- Rate limit handling (shows dialog when exceeded)
- Offline mode (saves locally with "sync pending")
- Document list: expandable cards with metadata (IDs, type, dates, size)
- Per-document actions: "Ask Questions", "Delete"
- Storage limit: 5 documents (free tier)

### What should exist
- ✅ Upload flow — good
- ✅ Rate limit handling — good
- ✅ Offline mode — good
- ⚠️ Delete should invalidate all dependent providers (dashboard count,
  summaries, family members) — **currently broken**
- ⚠️ Should show processing status (uploading → OCR → ingesting → ready)
  not just "completed/failed"
- ⚠️ Should allow re-upload / re-process a failed document

### Gaps
- **Delete doesn't invalidate `documentsProvider` or `policySummariesProvider`**
  → stale dashboard + orphaned summaries after deletion. **Real bug.**
- **No document re-processing** — if OCR/RAG fails, the doc is stuck in
  "failed" with no retry
- Storage limit (5) is hardcoded in two places

---

## Tab 3: Q&A (`qa_screen.dart`)

### What exists
- 3 tabs: Standard Questions / Custom Question / History
- Document selector (pick which policy to ask about)
- 24 standard questions across 6 categories
- Custom question input
- Answer card: question, answer, sources with page numbers, copy + share
- Q&A history (Hive-persisted, max 50)
- Offline banner when no connectivity
- Demo mode (auto-asks 6 questions — must be OFF at launch)

### What should exist
- ✅ Standard questions — good starting set
- ✅ Custom questions — good
- ✅ History — good
- ✅ Sources display — good
- ⚠️ "All Documents" option in selector is non-functional (backend doesn't
  support cross-document queries) — **should be removed or hidden**
- ⚠️ Should show confidence/retrieval info to the user (currently extracted
  from backend response but not displayed)
- ⚠️ No feedback mechanism (was this answer helpful? 👍/👎)

### Gaps
- **"All Documents" → null documentId → backend returns "unavailable"** —
  dead path that frustrates users
- **Demo scripted sequence** must be confirmed off in release build
- **Question rewriting is inconsistent** — only 3 phrases get rewritten
- **Custom answer disappears if user edits the text field after asking**

---

## Tab 4: Family (`family_screen.dart` + `add_family_member_dialog.dart`)

### What exists
- Family member list with source badges (Manual / From document)
- Auto-detection from uploaded policy documents
- Manual add (name, relationship, DOB)
- Delete manual members (with confirmation)
- Persistence in Hive (survives restarts)

### What should exist
- ✅ Auto-detection — good
- ✅ Manual add — good (the dependent-with-own-policy case)
- ✅ Source badges — good
- ⚠️ Should link each member to the policy they're insured under
- ⚠️ Should show coverage status per family member (are they covered?)

### Gaps
- **Error from provider masked as empty** — backend failure looks like "no
  members found"
- No link between a family member and their source policy

---

## Tab 5: More (`more_screen.dart`)

### What exists
Navigation menu to 9 screens:
1. Emergency Card
2. Claims Assistant
3. Renewal Calendar
4. Coverage Gaps
5. Compare Policies
6. Settings
7. Help & Support
8. Privacy & Security
9. About

### What should exist
- ✅ All 9 destinations are real screens (no more "coming soon")
- ⚠️ "Renewal Calendar" promises "get reminders" — **no reminders exist**

---

## More → Emergency Card (`emergency_screen.dart`)

### What exists
- One card per policy: type, insurer, status, policy number, coverage, expiry
- Call helpline button (`tel:`)
- Email button (`mailto:`)

### What should exist
- ✅ Core concept is right — emergency info at a glance
- ⚠️ Should work offline (data comes from cached summaries — currently does)
- ⚠️ Should show all critical emergency numbers, not just insurer helpline
  (e.g., 112, 108 ambulance if health policy)

### Gaps
- **No "contact not available" message** when helpline/email weren't extracted
- Silent no-op if `canLaunchUrl` fails
- No per-type triage logic (health emergency vs. auto accident)

---

## More → Claims Assistant (`claims_assistant_screen.dart`)

### What exists
- Incident type selector (Hospitalization / Auto Accident / Life Claim / Other)
- Policy selection (auto-select best match)
- Claim guide: step-by-step instructions with document checklist
- Call/email from guide
- Notes box

### What should exist
- ✅ Step-by-step guidance — good concept
- ⚠️ All guidance is **static template text**, not derived from the actual
  policy beyond helpline/email. This is acceptable for launch but must be
  communicated honestly.
- ⚠️ Dead-end UX: if summaries are empty but documents exist, the incident
  picker shows but the "Get Claim Guide" button never appears

### Gaps
- **Static templates** — not policy-specific (doesn't read actual claim
  process from the policy text)
- **Dead-end when summaries are empty** but documents exist
- No claim tracking (status, filed date, reference number)

---

## More → Renewal Calendar (`renewal_calendar_screen.dart`)

### What exists
- Sorted list grouped by Expired / Expiring Soon / Active
- Per-policy: type, insurer, expiry date, days remaining
- Policy number display

### What should exist
- ⚠️ Should actually be a calendar (or at least add reminders/notifications)
  — the More menu promises "get reminders"
- ⚠️ Should handle policies with no end date (currently silently dropped)
- ⚠️ Should offer "Add to calendar" / "Set reminder" action

### Gaps
- **Not a calendar, no reminders** — name and description are misleading
- **Policies with no parsed end date are invisible** — not in any section
- Pure read-only, no actions

---

## More → Coverage Gaps (`coverage_gap_screen.dart`)

### What exists
- Gap analysis: High/Medium/Low priority
- Per-gap: category, description, recommendation
- Rule-based: checks for missing health/life/auto, missing maternity/critical
  illness in health, expiring policies

### What should exist
- ✅ Concept is strong — proactive coverage analysis is valuable
- ⚠️ Classification is fragile (string matching on document type)
- ⚠️ Should show what coverage the user *does* have alongside what's missing

### Gaps
- **False "no health insurance"** if policy is classified as "Mediclaim"
- "No gaps detected" with zero summaries is misleading

---

## More → Compare Policies (`policy_comparison_screen.dart`)

### What exists
- DataTable comparing first 2 policies
- Rows: Type, Insurer, Policy Number, Coverage, Premium, Deductible, Dates,
  Status, Helpline

### What should exist
- ⚠️ Should let user select which policies to compare (not always first 2)
- ⚠️ Should support 3+ policies
- ⚠️ Should highlight differences (better/worse coverage, cheaper premium)
- ⚠️ May be redundant with the `PolicyComparisonSheet` on the dashboard

### Gaps
- **Only compares first 2, no selection** — weak
- No difference highlighting
- Redundant with dashboard's comparison sheet

---

## More → Settings (`settings_screen.dart`)

### What exists
- Backend endpoint display
- App version
- Clear local data

### What should exist
- ✅ Minimal is fine for launch
- ⚠️ "Clear local data" is **broken** — only clears SharedPreferences, not
  Hive boxes (where documents, history, family, summaries actually live)

### Gaps
- **Clear local data doesn't clear Hive** — functionally broken vs. label
- Sparse but intentionally so

---

## More → Help & Support (`help_support_screen.dart`)

### What exists
- 5 static FAQs
- Contact support (email)
- App version

### What should exist
- ✅ Good for launch
- ⚠️ Verify `support@coverwise.app` is a real monitored mailbox

### Gaps
- `support@coverwise.app` must exist before launch
- Silent failure if no mail client

---

## More → Privacy & Security (`privacy_security_screen.dart`)

### What exists
- Data summary (stored on device / sent to backend / rate limits)
- Delete data reference
- Self-admitted disclaimer: "not a legal document"

### What should exist
- 🔴 **A real privacy policy** — app stores require one. This is a launch
  blocker.
- Should link to a hosted privacy policy URL
- Should cover: data retention, third-party processors (OpenAI, Qdrant),
  jurisdiction, user rights

### Gaps
- **Self-declared as not legal-ready** — blocker for app store submission
- No external URL
- No retention/deletion rights language

---

## More → About (`about_screen.dart`)

### What exists
- Shield icon, app name, version, description, disclaimer

### What should exist
- ✅ Good for launch
- ⚠️ Should link to Terms of Service and Privacy Policy

### Gaps
- No ToS/PP links (stores expect these)

---

## Cross-cutting flows

### Upload → Process → Q&A (core value flow)
```
User picks PDF
  → mobile uploads to POST /documents/upload
  → backend: save → OCR (PyMuPDF direct text) → ingest to Qdrant
  → backend: extract summary via LLM → store
  → mobile: document appears in list
  → user navigates to QA, selects document
  → user asks question
  → POST /query → backend: embed query → Qdrant search → LLM answer
  → mobile: displays answer with sources
```
**Status:** Works for digital PDFs. Broken if OpenAI key is dead (429/401).
Scanned PDFs get a clear message (no OCR in slim prod image).

### Offline flow
```
User opens app with no connectivity
  → documents load from Hive (local) ✅
  → QA shows OfflineBanner ✅
  → uploads saved locally with "sync pending" ✅
  → summary-dependent screens (Emergency, Claims, Renewal, Gaps, Compare)
    show cached data from Hive ✅
  → new Q&A fails gracefully with "unavailable" ✅
```
**Status:** Works. Offline-first is real.

### Demo mode flow
```
bootstrapPolicyDemo=true (compile-time flag)
  → injects fake ICICI Lombard policy into storage
  → auto-opens demo PDF
  → auto-asks 6 scripted questions
  → returns hardcoded mock answers on any backend failure
```
**Status:** Must be OFF at launch. Default is false. Verify build config.

---

## Extracted-but-undisplayed data

The backend extracts rich policy data that the mobile app never shows:

| Field | Extracted? | Displayed? |
|---|---|---|
| policy_number | ✅ | ✅ (dashboard, emergency) |
| insurer | ✅ | ✅ (dashboard, emergency) |
| insurer_helpline | ✅ | ✅ (emergency, claims) |
| insurer_email | ✅ | ✅ (emergency, claims) |
| coverage_amount | ✅ | ✅ (dashboard, compare) |
| deductible | ✅ | ✅ (compare only) |
| premium_amount | ✅ | ✅ (dashboard, compare) |
| effective_date | ✅ | ✅ (compare) |
| expiration_date | ✅ | ✅ (dashboard, renewal, emergency) |
| **key_benefits** | ✅ | ❌ **never shown** |
| **exclusions** | ✅ | ❌ **never shown** |
| **waiting_periods** | ✅ | ❌ **never shown** |
| **coverage_items** | ✅ | ❌ **never shown** |
| **premium_frequency** | ✅ | ❌ **never shown** |

This is a significant product gap — the system extracts the most valuable
information (what's covered, what's excluded, waiting periods) and then hides
it from the user.

---

## Launch priority matrix

| Priority | Item | Effort |
|---|---|---|
| 🔴 P0 | Privacy policy (real, hosted URL) — store blocker | Low (write) |
| 🔴 P0 | Fix "Clear local data" to also clear Hive | Low |
| 🔴 P0 | Fix delete not invalidating dependent providers | Low |
| 🔴 P0 | Remove/hide "All Documents" QA option (dead path) | Low |
| 🔴 P0 | Verify `support@coverwise.app` exists | Low (verify) |
| 🟡 P1 | Display key_benefits/exclusions/waiting_periods | Medium |
| 🟡 P1 | Fix type classification (Mediclaim → Health) | Medium |
| 🟡 P1 | Handle policies with no end date | Low |
| 🟡 P1 | Remove "get reminders" promise or add reminders | Low/Medium |
| 🟡 P1 | Fix claims assistant dead-end (no summaries + docs) | Low |
| 🟡 P2 | Policy comparison: let user select which to compare | Medium |
| 🟡 P2 | Add answer feedback (👍/👎) | Medium |
| 🟢 P3 | Add renewal reminders (local notifications) | Medium |
| 🟢 P3 | Claim tracking (status, filed date) | Medium |
| 🟢 P3 | Show confidence/retrieval info in answers | Low |
