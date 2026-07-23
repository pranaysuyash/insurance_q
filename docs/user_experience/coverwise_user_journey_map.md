# CoverWise User Journey Map

**Status:** Living product artifact; append dated updates rather than rewriting history.
**Version:** 1.0 baseline, 2026-07-21
**Owner / next reviewer:** Pranay
**Evidence boundary:** This document separates static code evidence, targeted-test evidence, runtime/manual evidence, product decisions, and future exploration. A journey marked “current” means the path exists in the present codebase; it does not mean the whole journey has passed real-device end-to-end validation.

## 0. Why this document exists

This is the canonical journey map for CoverWise. It answers:

1. What a person is trying to accomplish.
2. What the ideal experience should do from trigger to outcome.
3. What the current code and observed runtime actually do.
4. What future journeys are worth building, and which are deliberately rejected.
5. What happens on happy, failure, optional, alternate, retry, offline, privacy, and operator paths.

The strategic exploration map remains the place for product-boundary and opportunity exploration: [`docs/review/exploration_map.md`](../review/exploration_map.md). The canonical system map remains [`docs/architecture/coverwise_canonical_architecture.md`](../architecture/coverwise_canonical_architecture.md). This file is the single journey-shaped source of truth; older journey documents are historical inputs and should not be treated as current implementation contracts.

## 1. Product boundary that governs every journey

CoverWise is a solo, non-regulated personal-information product. It helps a person understand and organize policies they already own.

The durable core is:

```text
user-owned policy
  → securely import
  → process and normalize
  → show evidence and uncertainty
  → explain in plain language
  → organize household knowledge
  → remind and help the person prepare
```

The product does not sell, solicit, procure, rank, recommend, quote, renew, represent claims, sell leads, or act as insurer/broker infrastructure. It must not diagnose, predict disease, prescribe treatment, or turn health records into an insurer/employer/advertiser signal.

That boundary changes how journeys are named:

| User language | CoverWise interpretation | Allowed outcome |
|---|---|---|
| “Am I covered?” | Find what the uploaded policy says and what it does not make verifiable | Cited facts, uncertainty, and a prompt to check the insurer/contract |
| “Which policy is better?” | Compare owned policies dimension by dimension | Cited differences and missing-data warnings; no overall recommendation |
| “How do I claim?” | Explain the policy’s stated process and preparation checklist | Neutral guidance and insurer contact; no representation or claim filing |
| “Should I renew?” | Make dates and contact details easy to find | Reminder and neutral contact action; no renewal transaction or recommendation |
| “Do I need more cover?” | Show missing or unverified information without declaring under-insurance | Factual “not found in uploaded documents” state; no premium advice |

## 2. Journey inventory: ideal, current, and future

Legend:

- **Ideal** = the long-term first-principles experience inside the product boundary.
- **Current** = present code path, with evidence level stated.
- **Future** = an approved or exploratory direction, not a current promise.
- **Rejected / parked** = deliberately outside the product boundary.

| ID | Journey | Ideal outcome | Current reality | Future direction / decision |
|---|---|---|---|---|
| J01 | Discover and decide to try | Person understands the neutral value proposition and starts without being misled about advice, selling, or claims | App has CoverWise onboarding copy and a first-policy CTA; external acquisition and message consistency need review | Evidence-backed public education and an example-driven entry path; no lead capture from sensitive content |
| J02 | Cold launch and onboarding | Splash → three concise value moments → clear scope/privacy notice → explicit consent → usable home | `SplashScreen`, `OnboardingScreen`, SharedPreferences completion flag, terms/consent and analytics consent paths exist. Real-device audit found intermittent lower-screen interaction and relaunch/onboarding persistence failures; treat Tier 4 proof as incomplete | Durable onboarding state, resumable consent, accessible hit targets, and an optional read-only sample policy |
| J03 | Anonymous start, account creation, sign-in, sign-out | Person gets value quickly, then can claim the workspace without losing documents; identity changes are explicit | Anonymous token, auth provider, email/password, Google OAuth, reset-password and account screens exist; owner-claim and backend refresh routes exist | Make principal ownership and local encrypted-data migration observable; verify every identity transition end to end |
| J04 | First document import | Person selects a PDF/image, understands what is uploaded and why, consents once for processing, and sees immediate durable progress | `DocumentsScreen` supports file selection, web/file variants, processing consent, limit checks, local pending state, and `POST /documents/upload` | Multi-file queue, camera capture, resumable upload, clear local/server state machine, and consent withdrawal semantics |
| J05 | Document processing and extraction | Processing is asynchronous, retryable, explainable, and ends in a cited, reviewable policy record | Backend accepts upload, persists document state, runs processing/evidence paths, and exposes status/summary/page routes. Architecture says outbox is the long-term primitive, but migration is incomplete | Finish one durable outbox path, expose real stages, retry safely, quarantine partial results, and show operator health |
| J06 | Review extracted policy | Person can distinguish source-backed facts, missing fields, uncertain extraction, and original pages | `PolicyDetailScreen`, evidence route, citation cards, document preview, and page routes exist; substrate architecture defines source spans and field evidence | Source-page highlighting, field correction with provenance, reprocessing, and “not verified” states for every claim-shaped field |
| J07 | Ask a policy question | Person asks in natural language, gets a concise answer, sees source citations/confidence, and can recover when evidence is weak | `QaScreen`, `/query`, `/documents/query`, RAG pipeline, history, follow-ups, feedback, and usage/entitlement surfaces exist. Cross-document scope and fresh-runtime RAG health remain verification gaps | One canonical owner-scoped Q&A route, streaming or staged progress, citation verification, answer history export/deletion, and safe fallback templates |
| J08 | Search and navigate knowledge | Person finds a policy, field, clause, or prior answer without remembering where it lives | `SearchScreen` and `/search` navigation surface exist in the mobile app; backend-wide search contract needs inventory/verification | Unified search over policy metadata, source text, citations, and saved answers with explicit ranking and no unsupported semantic claims |
| J09 | Manage document lifecycle | Person views, previews, replaces, reprocesses, archives, deletes, and understands consequences | List, preview, replacement, delete, status, local encrypted storage, storage contract, and account deletion paths exist; full deletion propagation is still a high-risk closure item | Durable lifecycle state machine, undo window where safe, deletion receipt, and source/object/vector/cache/analytics cleanup evidence |
| J10 | Understand coverage facts and gaps | Person sees what is explicitly present, absent, or unknown in owned policies | `CoverageGapScreen` and tracking exist, but exploration-map boundary says recommendation-like wording must be neutralized | “Coverage understanding” substrate view: cited facts, missing fields, questions to ask insurer; never “you are under-insured” or product recommendations |
| J11 | Compare owned policies | Person compares two or more owned policies on normalized, cited dimensions | `PolicyComparisonScreen` exists; normalization, source citation, missing-field behavior, and recommendation copy require continued alignment | Dimension-specific comparison with denominator/tax/rider rules, evidence links, and export; no best-policy verdict |
| J12 | Family / household organization | Person sees who is named across owned policies, corrects household records, and understands visibility | `FamilyScreen`, detail screen, manual members, auto-detected members, and family routes exist; privacy/deletion expansion is documented in ADRs | Per-member coverage map, explicit source/manual badges, scoped sharing, and deletion propagation |
| J13 | Renewal awareness | Person sees expiry dates, receives controlled reminders, and can contact the named insurer | `RenewalCalendarScreen`, notification preferences, local scheduling, and neutral contact actions exist; “start renewal” language needs review | Renewal diff against a newly uploaded document; reminders remain informational, never a sales funnel |
| J14 | Emergency access | Person reaches policy number, insurer, coverage, expiry, and helpline quickly—even with poor connectivity | `EmergencyScreen` and insurance-card surface exist; offline completeness is not yet proven | Signed/encrypted offline emergency card, explicit stale timestamp, controlled sharing, and revocation behavior |
| J15 | Claims preparation | Person understands policy-stated steps and gathers documents without believing CoverWise represents them | Claims assistant and claim tracking screens exist; current path is guidance/local tracking, not insurer integration | Evidence-backed claim-preparation packet and optional document vault, subject to separate medical-data/privacy decisions; no filing or representation by default |
| J16 | Insurance literacy | Person learns terminology while viewing their own policy | `InsuranceLiteracyScreen` and quiz exist | Contextual definitions tied to cited policy clauses, with accessibility and localization research |
| J17 | Plan limits, paywall, and subscription | Person sees limits before being blocked, understands price/entitlement, and can restore or cancel safely | RevenueCat initialization, entitlement providers, paywall/upgrade screens, and subscription routes exist; full billing E2E/idempotency proof remains required | Provider-neutral entitlement ledger, webhook reconciliation, restore/refund recovery, and transparent cost/value messaging |
| J18 | Help, feedback, and trust | Person can report a problem, understand uncertainty, and reach support without exposing excess data | Help/support, feedback, analytics, legal screens, and consent ledger paths exist; analytics safety and operator access still need hardening | Redacted diagnostics, explainable processing receipt, purpose-scoped support access, and auditable operator workflow |
| J19 | Privacy, consent, export, and deletion | Person can see purposes, withdraw optional consent, export own data, and request complete deletion | Privacy/terms/profile/deletion UI and server-side consent primitives exist; deletion is high-risk and not fully Tier 3+ closed | Purpose-specific ledger enforcement, deletion outbox, propagation receipt, export format, retention register, and privacy release gates |
| J20 | Return visit / lifecycle loop | Person returns when a policy changes, a reminder fires, a question arises, or a household record needs updating | Dashboard, local persistence, reminders, history, and notifications exist; cold relaunch stability and freshness need runtime proof | A trustworthy “what changed / what needs attention / what is stale” home, with no manufactured engagement |

## 3. Canonical end-to-end happy path

This is the primary product journey: a person has a policy, wants to understand it, and receives a cited result.

```mermaid
flowchart TD
    A[Person discovers CoverWise] --> B[Cold launch]
    B --> C{Onboarding already complete?}
    C -- No --> D[Scope, privacy, terms, consent]
    D --> E{Consent accepted?}
    E -- No --> D2[Explain choice and remain usable where possible]
    D2 --> E
    E -- Yes --> F[Empty dashboard]
    C -- Yes --> F2[Dashboard with local workspace]
    F --> G[Choose policy file]
    F2 --> H{Existing documents?}
    H -- No --> G
    H -- Yes --> I[Open policy, search, ask, compare, family, or reminder]
    G --> J[Select PDF/image]
    J --> K{Valid and within entitlement?}
    K -- No --> K1[Explain validation or plan limit]
    K1 --> J
    K -- Yes --> L{First processing consent?}
    L -- Yes --> M[Purpose-specific processing consent]
    L -- No --> N[Use existing consent record]
    M --> N
    N --> O[Upload and persist document ownership]
    O --> P[Processing status]
    P --> Q{Processing completed with usable evidence?}
    Q -- No --> R[Explain failed/partial state, retry or replace]
    R --> P
    Q -- Yes --> S[Policy detail with evidence and uncertainty]
    S --> T{Person's next need}
    T -- Understand field --> U[Open citation/source page]
    T -- Ask question --> V[Owner-scoped Q&A]
    T -- Organize --> W[Family, compare, reminders, search]
    T -- Prepare --> X[Neutral claim/emergency contact guidance]
    U --> S
    V --> Y{Evidence sufficient?}
    Y -- Yes --> Z[Answer + citation + confidence]
    Y -- No --> Z1[Not found/uncertain + next safe action]
    Z --> V2[Follow-up, feedback, save, share/export where allowed]
    Z1 --> V2
    W --> S
    X --> S
    V2 --> AA[Durable workspace and auditable lifecycle]
```

## 3.1 J02–J07 journey-state inventory (ideal/current/future)

| Journey | Ideal | Current | Future |
|---|---|---|---|
| J02 onboarding | Fast, explicit, server-auditable consent and purpose versioning with durable completion state | Local onboarding marker and consent handling exist; server-auditable outcomes are not fully closed for all branches | Single canonical server-first consent ledger with explicit decline/retry/offline states |
| J03 identity | Canonical principal lifecycle with migration receipts and two-user isolation | Dual local/server principal model with partial migration evidence | Canonical principal migration with encrypted local key transfer proof + explicit deletion job receipts |
| J04 upload | One production enqueue path through durable queue and deterministic job receipt | Durable outbox path is reachable, but non-canonical enqueue and in-process behaviors still need explicit disallow proof | Remove non-canonical upload paths; prove only outbox-based terminal outcomes |
| J05 processing | Single lease-aware processor with bounded retries and explicit terminal recovery states | Mixed processing behavior with unverified duplicate/recovery boundaries | Bounded lease contention recovery and dead-letter closure as production-default behavior |
| J06 evidence | Always provenance-typed evidence and owner-scoped source navigation | Structured evidence is present; provenance typing and cross-owner runtime proofs are incomplete | Full typed evidence schema + stale/invalid provenance state, two-owner replay proof |
| J07 Q&A | One owner-scoped query route with citationed answer + explicit uncertainty fallback | Two query routes and unclosed multi-owner runtime fallback | Canonical owner-scoped route with explicit safe-unknown and cost-sensitive escalation policy |

## 3.2 J02–J07 deep path with failures, alternates, and optional routes

```mermaid
flowchart TD
    A[Cold launch]
    A --> B{Onboarding complete?}
    B -- No --> C[Onboarding flow]
    C --> C1[Read scope and privacy]
    C1 --> C2{User action on onboarding terms}
    C2 -- Accept --> C3[Record acceptance version]
    C2 -- Decline required terms --> C4[Surface limited usage and safe alternative]
    C2 -- Skip/close --> C5[Enter limited mode with explicit warning]
    C4 --> C3
    C5 --> C3
    C3 --> D[Local state marker set]
    B -- Yes --> D

    D --> E[Dashboard + workspace hydration]
    E --> F{Create identity transition now?}
    F -- Stay anonymous --> G[Anonymous principal with local workspace]
    F -- Sign in / sign up --> H[Auth provider + callbacks]
    G --> I[Document entry point]
    H --> H1{Auth success?}
    H1 -- No --> H2[Retry auth / reset password / support]
    H1 -- Yes --> I
    H2 --> I

    I --> J{Upload source}
    J -- File picker --> K[PDF / image selected]
    J -- Camera capture (future) --> K
    J -- Sample policy --> K2[Demo workspace]
    K --> L{Validation and consent}
    K2 --> L
    L -- Invalid format --> L1[Validation message + retry]
    L -- Consent needed --> L2[Processing consent decision]
    L -- Valid and consented --> M[Start processing path]
    L2 -- Decline --> C4
    L1 --> J

    M --> N{Upload path}
    N --> N1[Local pending artifact]
    N1 --> N2{Backend connectivity}
    N2 -- Offline --> N3[Keep local pending; retry queue]
    N2 -- Online --> O[Create durable outbox envelope]
    N3 --> N4{User-triggered retry}
    N4 -- Retry now --> O
    N4 -- Later --> N3

    O --> P{Processing worker lease}
    P -- Conflict/retry window --> P1[Backoff and lease recovery]
    P1 --> P
    P -- Accepted --> Q[OCR/extraction + policy parser]
    Q --> Q1{Extraction outcome}
    Q1 -- Partial --> Q2[Store partial evidence + open for repair]
    Q1 -- Failed --> Q3[Failure classification + user-facing reason]
    Q1 -- Success --> R[Verified evidence + source spans + page artifacts]
    Q2 --> R
    Q3 --> R

    R --> S[Document detail / policy fields]
    S --> T{User next move}
    T -- Browse fields --> U[Open source-backed field + page]
    T -- Ask question --> V[Q&A path]
    T -- Family/reminders/help --> W[Optional non-core products]
    T -- Contact insurer/export/share --> X[Safe action utilities]

    U --> S
    V --> V1{Answer pipeline}
    V1 -- evidence enough --> V2[Answer + citation + confidence + links]
    V1 -- missing or weak --> V3[Not found / uncertain + narrowing suggestion]
    V1 -- model fail/timeout --> V4[Retry, fallback policy, or safe unavailable]
    V3 --> Y[Follow up question / open source page]
    V4 --> Y
    V2 --> Y

    Y --> Z[Question history, feedback, usage counters]

    W --> S
    X --> S
    Z --> AA[Workspace updated]
    AA --> AB[Return loops: reminders, updates, stale checks]
    AB --> E

    N3 --> AC[Delete request or sign out]
    O --> AC
    AC --> AD[Deletion queue + audit receipt + propagation checks]
    AD --> E

    N3 --> AE{Plan limit / entitlement}
    AE -- Available --> O
    AE -- Exhausted --> AF[Show limit, plan options, and hard stop paths]
    AF --> AG{User choice}
    AG -- Cancel --> E
    AG -- Delete upload backlog --> AD
    AG -- Upgrade/recover --> AH[Billing/restore flow + entitlement sync]
    AH --> I
```

### J02–J07 end-to-end trace graph (happy, non-happy, optional, alternate)

```mermaid
flowchart TD
    %% Entry and onboarding
    subgraph S1["J02 Cold launch + onboarding"]
      A1["Person opens app"]
      A2{"Onboarding complete?"}
      A1 --> A2
      A2 -->|No| A3["Show onboarding + privacy/scope"]
      A2 -->|Yes| A8["Go to home/workspace"]
      A3 --> A4{"Required terms accepted?"}
      A4 -->|No| A5["Limited mode + explicit warning"]
      A4 -->|Skip| A5
      A4 -->|Yes| A6["Persist completion + purpose state"]
      A5 --> A6
      A6 --> A8
    end

    %% Identity
    subgraph S2["J03 Identity and ownership"]
      B1["Continue as anonymous"]
      B2{"Sign in / sign up now?"}
      A8 --> B1
      B1 --> B2
      B2 -->|No| B3["Anonymous workspace"]
      B2 -->|Yes| B4["Auth callback + token refresh"]
      B4 --> B5{"Auth success?"}
      B4 -->|Failure| B6["Retry / reset / support"]
      B5 -->|Failure| B6
      B5 -->|Success| B7["Claim local + remote ownership"]
      B6 -->|Retry| B4
      B7 --> B3
    end

    %% Upload
    subgraph S3["J04 Upload"]
      C1["Open document source"]
      B3 --> C1
      C1 --> C2{"Selection type"}
      C2 -->|Existing file| C3["PDF/image selected"]
      C2 -->|Sample policy| C8["Demo workspace flow"]
      C2 -->|Camera capture| C4["Capture path (future)"]
      C4 --> C3
      C3 --> C5{"Validation + consent"}
      C8 --> C5
      C5 -->|Invalid| C6["Validation error + action"]
      C5 -->|Consent declined| C7["Sync-limited path"]
      C5 -->|Pass + consent| C9["Create upload intent"]
      C6 --> C1
      C7 --> C9
      C9 --> C10{"Connectivity"}
      C10 -->|Offline| C11["Persist pending upload"]
      C10 -->|Online| C12["Create durable outbox envelope"]
      C11 --> C13{"Retry policy"}
      C13 -->|Later| C11
      C13 -->|Now| C12
    end

    %% Processing
    subgraph S4["J05 Processing"]
      D1["Worker lease claim"]
      C12 --> D1
      C11 --> D1
      D1 --> D2{"Lease acquired?"}
      D2 -->|No| D10["Bounded retry"]
      D2 -->|Yes| D3["OCR/extraction"]
      D3 --> D4{"Outcome"}
      D4 -->|Success| D7["Verified evidence produced"]
      D4 -->|Partial| D5["Partial / text required"]
      D4 -->|OCR required| D6["OCR required retry/fallback"]
      D4 -->|Failed| D8["Failure class"]
      D4 -->|Deleted| D9["Skip with deletion fence"]
      D5 --> D10
      D6 --> D10
      D8 --> D10
      D10 -->|Retry cap hit| D11["Dead-letter + operator action"]
      D7 --> E1["Policy detail"]
      D5 --> E2["Policy detail (partial)"]
      D6 --> E2
      D8 --> E2
      D9 --> E3["Policy unavailable / locked"]
      E2 --> F1["Ask question"]
      E3 --> F1
      D10 --> C10
    end

    %% Evidence
    subgraph S5["J06 Evidence"]
      E1 --> E4{"Evidence state"}
      E4 -->|Verified| E5["Cited field + source + confidence"]
      E4 -->|Not found| E6["Unknown / stale marker"]
      E4 -->|Cross-owner| E7["Owner-denied + no leak"]
      E6 --> E8["Reprocess / keep partial"]
      E7 --> E8
      E8 --> F1
    end

    %% Q&A
    subgraph S6["J07 Q&A"]
      F1 --> F2{"Corpus + retrieval quality"}
      F2 -->|Good| F3["Cited answer + confidence"]
      F2 -->|Weak| F4["Not found / safe fallback"]
      F2 -->|Timeout| F5["Retry + retry reason"]
      F2 -->|Wrong scope| F6["Owner-scoped failure"]
      F3 --> F7["Source navigation + history"]
      F4 --> F7
      F5 --> F7
      F6 --> F7
      F7 --> F8["Usage counters + audit receipts"]
      F8 --> F9["Workspace loop"]
    end

    %% Optional and alternate loops
    F9 --> A1
    F9 --> G1["Billing / family / reminders / help (optional journeys)"]
    G1 --> A1
```

### J02–J07 per-journey end-to-end diagrams (happy, non-happy, optional)

```mermaid
flowchart LR
    %% J02
    subgraph J02["J02 Cold start + onboarding"]
      J02_A["Open app"] --> J02_B{"Onboarding complete?"}
      J02_B -- No --> J02_C["Show privacy/scope/terms"]
      J02_B -- Yes --> J02_E["Workspace-ready home"]
      J02_C --> J02_D{"Required terms?"}
      J02_D -- Accept --> J02_F["Persist completion + purpose record"]
      J02_D -- Decline --> J02_G["Limited mode with explicit warning"]
      J02_D -- Skip --> J02_G
      J02_G --> J02_E
      J02_F --> J02_E
    end

    %% J03
    subgraph J03["J03 Identity and ownership"]
      J03_A["Use home workspace"] --> J03_B{"Stay anonymous or claim now?"}
      J03_B -- Anonymous --> J03_C["Continue with anonymous principal"]
      J03_B -- Sign-in --> J03_D["Auth callback"]
      J03_D --> J03_E{"Auth success?"}
      J03_E -- No --> J03_F["Retry / reset / support"]
      J03_E -- Yes --> J03_G["Claim anonymous workspace"]
      J03_F --> J03_D
      J03_G --> J03_H["Principal namespace migration"]
      J03_C --> J03_I["Owner-scoped operations"]
      J03_H --> J03_I
    end

    %% J04
    subgraph J04["J04 Upload"]
      J04_A["Select source"] --> J04_B{"Selection mode"}
      J04_B -- File --> J04_C["Validate format/size"]
      J04_B -- Sample (opt) --> J04_C
      J04_B -- Camera (future) --> J04_C
      J04_C --> J04_D{"Validation + consent"}
      J04_D -- Fail --> J04_E["Return actionable error"]
      J04_D -- Consent missing --> J04_F["No upload + limited path"]
      J04_D -- Pass --> J04_G["Create outbox envelope"]
      J04_E --> J04_C
      J04_F --> J04_G
      J04_G --> J04_H{"Online?"}
      J04_H -- Offline --> J04_I["Persist local pending"]
      J04_H -- Online --> J04_J["Mark received/processing"]
      J04_I --> J04_H
    end

    %% J05
    subgraph J05["J05 Processing"]
      J05_A["Worker lease attempt"] --> J05_B{"Lease acquired?"}
      J05_B -- No --> J05_C["Backoff + bounded retry"]
      J05_B -- Yes --> J05_D["OCR/extraction/parser"]
      J05_C --> J05_B
      J05_D --> J05_E{"Terminal class"}
      J05_E -- Partial --> J05_F["Partial result + repair hint"]
      J05_E -- OCR required --> J05_G["OCR path + retry"]
      J05_E -- Failed --> J05_H["Failure state + operator-visible reason"]
      J05_E -- Completed --> J05_I["Evidence ready / summary state"]
      J05_E --> J05_H
      J05_G --> J05_D
      J05_F --> J05_I
      J05_I --> J05_J["Store classification + provenance"]
    end

    %% J06
    subgraph J06["J06 Evidence review"]
      J06_A["Open policy detail"] --> J06_B{"Owner check"}
      J06_B -- No --> J06_X["Owner denied"]
      J06_B -- Yes --> J06_C["Load summary + citations + pages"]
      J06_C --> J06_D{"Evidence state"}
      J06_D -- Verified --> J06_E["Show value + source/page"]
      J06_D -- Unknown / stale --> J06_F["Show not verified + action"]
      J06_D -- Empty --> J06_G["Prompt reprocess / replace"]
      J06_E --> J06_H["Capture user action"]
      J06_F --> J06_H
      J06_G --> J06_H
      J06_H --> J06_I["Audit state + history"]
    end

    %% J07
    subgraph J07["J07 Q&A"]
      J07_A["Ask natural-language question"] --> J07_B{"Owner scoped context"}
      J07_B -- No owner scope --> J07_C["400/403-style scope block"]
      J07_B -- Owner yes --> J07_D{"Retrieval confidence"}
      J07_D -- Strong --> J07_E["Cited answer + confidence"]
      J07_D -- Weak --> J07_F["Safe not-found + follow-up"]
      J07_D -- Timeout --> J07_G["Retry + fallback template"]
      J07_F --> J07_H["History + usage counters"]
      J07_G --> J07_H
      J07_E --> J07_H
      J07_C --> J07_H
    end

    J03_I --> J04_A
    J04_J --> J05_A
    J05_J --> J06_A
    J06_H --> J07_A
```

### Diagram legend

- **Solid flow**: happy-chain progression.
- **Node/edge labels**: non-happy recovery and boundary-deny branches are labeled inline.
- **Optional nodes**: sample policy, camera capture, and optional future journeys are exploratory and must remain explicitly separated from promises.

### Happy-path acceptance contract

The journey is not successful merely because a file reached an API. A successful outcome requires:

| Layer | Required result |
|---|---|
| Person | Understands at least one policy fact and where it came from |
| Product | Shows a useful, plain-language result without overstating certainty |
| Evidence | Claim-shaped fields have source/page/span provenance or are shown as not verified |
| Pipeline | Upload, processing, extraction, and query have owner scope, retry/failure states, and no silent fallback |
| Storage | Original file, metadata, derived fields, vectors, cache, and local copies have explicit lifecycle ownership |
| Operator | Failure, retry, cost, latency, model/provider, and deletion state are inspectable |

## 4. Non-happy paths, alternates, and optional branches

```mermaid
flowchart LR
    A[User action] --> B{Can the app proceed?}
    B -- Offline --> C[Local pending state]
    C --> D{Retry policy}
    D -- Retry --> E[Idempotent upload/sync]
    D -- Cancel --> F[Keep local draft with clear status]
    B -- Invalid file --> G[Actionable validation error]
    G --> A
    B -- Consent declined --> H[Explain consequence; do not process]
    B -- Entitlement exhausted --> I[Show limit, existing data, upgrade or delete]
    I --> J{User choice}
    J -- Upgrade --> K[Billing flow with restore/failure recovery]
    J -- Delete --> L[Explicit deletion confirmation]
    J -- Cancel --> M[Return to workspace]
    B -- Auth expired --> N[Re-auth / claim anonymous workspace]
    N --> O{Identity transition succeeds?}
    O -- No --> P[Keep data scoped and explain next step]
    O -- Yes --> Q[Migrate principal-scoped local state]
    B -- Processing failure --> R[Show stage, reason class, retry/replace]
    R --> D
    B -- Weak evidence --> S[Show unknown/not verified]
    S --> T[Open source, ask narrower question, or contact insurer]
    B -- Backend unavailable --> U[Do not fabricate result]
    U --> V[Show cached/stale data with timestamp or safe unavailable state]
    B -- Delete request --> W[Queue durable deletion]
    W --> X[Receipt, audit, propagation status]
```

### Alternate and optional branches that must remain explicit

| Branch | User choice | Product rule |
|---|---|---|
| Anonymous vs account | Start now or sign in first | Anonymous value is allowed, but ownership transfer must be explicit and lossless |
| File vs camera | Import existing PDF/image or capture pages | Original capture remains source; image quality and page order are visible |
| Local OCR vs server processing | Use device-assisted extraction where offered | Label local OCR as a sidecar; original file remains source of truth |
| Sample policy vs real policy | Explore a bundled/read-only example or upload personal data | Sample must never mix with the user’s owned workspace or analytics identity |
| One policy vs household | Understand one policy or organize multiple policies | Every result shows document and owner scope |
| Question vs browse | Ask in natural language or inspect source | Browse/source verification is always available when a claim is shown |
| Compare vs recommend | Compare dimensions or ask “what should I buy?” | Comparison is allowed; purchase/recommendation is rejected or reframed |
| Claim guidance vs claim filing | Read preparation steps or submit to insurer | CoverWise can guide and organize; it does not represent or file by default |
| Renewal reminder vs renewal transaction | Receive reminder or contact insurer | Reminders and contact are allowed; renewal transaction is out of scope |
| Share/export | Share a bounded card/report or keep private | Show exact fields, destination, timestamp, and revoke/delete implications |
| Optional health records | Keep local records/reminders or do not use | Local-first, neutral, optional, and separate from policy intelligence until separately approved |

## 5. Journey detail cards

Each card uses the same contract: trigger → input → system work → state → user output → operator visibility → failure/retry → stored data.

### J02 — Cold launch and onboarding

**Ideal:** Open app → splash → understand / ask / stay-ready value → read scope and privacy → choose optional analytics consent separately → accept required terms → land on an empty but actionable dashboard. On repeat launch, skip onboarding and restore the correct principal-scoped workspace.

**Current evidence:** `mobile/lib/main.dart` checks `SharedPreferences` for `onboarding_complete`; `mobile/lib/screens/onboarding_screen.dart` writes completion and records consent. The 2026-07-20 runtime audit observed clean cold-launch visuals but also intermittent lower-screen taps, black-screen relaunch behavior, and onboarding appearing again after relaunch. The visual path is Tier 4; the complete reliable path is not closed.

**Non-happy paths:** consent declined; app killed during completion; backend unavailable; terms version changes; partial analytics consent; accessibility text scaling; deep link before onboarding; repeated tap on CTA.

**Required future state:** onboarding completion, consent version, and workspace readiness must be separate state transitions with an observable receipt. No silent “best effort” path may make the user believe a server-side consent event succeeded when it did not.

### J03 — Identity and ownership

**Ideal:** Anonymous user can upload and inspect a policy. Sign-up/sign-in claims that exact workspace. Sign-out makes ownership and local-data behavior explicit. Password reset and OAuth return through validated deep links. Account deletion revokes access and starts durable deletion.

**Current evidence:** `AuthService`, `auth_provider.dart`, `account_screen.dart`, `reset_password_screen.dart`, `src/api/user.py`, and principal-scoped local storage implement substantial pieces. Full device + backend ownership transition is not established at Tier 3+ in this baseline.

**High-risk checks:** token expiry, refresh failure, two users on one device, app reinstall, auth callback tampering, anonymous claim replay, local Hive lock, deletion during processing, and no cross-owner document access.

### J04/J05 — Import, processing, extraction

**Ideal:** Select → validate → consent → upload → durable accepted state → progress by real stage → retryable processing → evidence-backed result. Every retry is idempotent; a failed attempt never silently replaces a prior good result.

**Current evidence:** `POST /documents/upload`, document repository/object storage, `DocumentProcessingService`, status and summary routes, evidence pipeline, local pending upload state, and `ProcessingStatusScreen` exist. The architecture identifies the outbox as the long-term async primitive but records that current migration is incomplete. This is a high-risk path; static presence is not E2E proof.

**Failure classes:** invalid/encrypted/oversized file; unsupported image; network timeout; duplicate upload; lease contention; OCR failure; extraction hallucination; missing citation; vector-store failure; outbox dead letter; entitlement race; user deletes during processing.

**Operator requirement:** a support/operator view must show document id, owner scope, stage, attempts, lease, last error class, model/provider, cost, and safe retry action without exposing raw content unnecessarily.

### J06/J07 — Evidence review and Q&A

**Ideal:** Policy detail is the trust center. A field is either cited to source text/page/span, explicitly marked uncertain/not found, or not rendered as a fact. Q&A uses the same owner scope and evidence contract, cites source text, and declines safely when retrieval or verification fails.

**Current evidence:** `docs/architecture/coverwise_canonical_architecture.md` defines the substrate and source/retrieval-text split. `src/api/evidence.py`, `evidence_pipeline.py`, `citation_verifier.py`, `PolicyDetailScreen`, and `QaScreen` implement pieces. Current docs also note cross-document Q&A and fresh-runtime RAG health as gaps.

**Failure classes:** no documents; question outside corpus; ambiguous policy scope; stale index; low retrieval confidence; LLM timeout; malformed structured answer; citation not substring of source; provider fallback; user asks for advice or diagnosis.

**Safe response:** say what the document supports, what it does not show, why confidence is limited, and the next safe action. Never fill missing insurance facts from general model knowledge.

### J09/J19/J20 — Lifecycle, privacy, and return visits

**Ideal:** The person can see every stored representation of a document, update or delete it, inspect consent purposes, export bounded data, and return later to a clearly timestamped workspace. Deletion is a durable workflow with a receipt, not a best-effort HTTP response.

**Current evidence:** local encrypted Hive work, Supabase storage/data contracts, consent ledger, account deletion endpoint, profile UI, and notification scheduling exist. The repo’s audits and ADRs explicitly treat deletion propagation, consent enforcement, operator trust, and durable work as incomplete/high-risk areas.

**Required future state:** object → metadata → chunks/vector → cache → analytics → derived evidence → local copy → backups/retention must have a documented lifecycle, owner, and proof of completion or exception.

## 6. Operator and system journey behind the user journey

The product journey is only complete when the system can explain itself after the person leaves the screen.

```mermaid
sequenceDiagram
    participant U as Person
    participant M as Mobile app
    participant A as FastAPI API
    participant P as Processing/evidence pipeline
    participant S as Supabase/storage/vector data
    participant O as Operator/support

    U->>M: Selects policy / asks question
    M->>A: Owner-scoped request + consent/version
    A->>S: Persist intent and source metadata
    A->>P: Process or generate answer
    P->>S: Write status, evidence, citations, cost, audit metadata
    P-->>A: Success / partial / failure
    A-->>M: User-safe state and next action
    M-->>U: Cited result, unknown state, or recovery action
    O->>S: Inspect scoped health, retries, failures, deletion, cost
    O->>A: Perform reason-required recovery action
    A->>S: Append audit event and state transition
```

Operator questions that every meaningful journey must answer:

- What happened?
- When did it happen?
- Which owner, document, and request were involved?
- Which external service/model/provider was used?
- Was there a retry, fallback, duplicate, timeout, or partial result?
- What did the person see?
- What can the operator safely do next?
- What data was stored, for what purpose, and how is deletion proven?

## 7. Future journey portfolio

### Approved long-term directions

1. **Evidence-backed policy intelligence:** every claim-shaped output has a source, page, span, confidence, and “not verified” alternative.
2. **Household policy organization:** family members, ownership, source/manual corrections, scoped sharing, and deletion.
3. **Coverage understanding:** factual missing-field and clause comparison, not under-insurance advice.
4. **Renewal diff:** compare old and newly uploaded policy documents to reveal changed dates, limits, exclusions, and missing fields.
5. **Claim preparation:** neutral checklist and document organization, with separate privacy rules for sensitive records.
6. **Durable privacy lifecycle:** consent purpose, export, deletion propagation, retention, and auditable operator access.
7. **Trustworthy return loop:** stale-state and change detection that earns a return visit without engagement manipulation.

### Exploratory directions requiring a separate decision

- optional local-first health records, reminders, and export;
- controlled value-add partnerships with explicit disclosure and consent;
- paid review services only if the entity, role, contracts, and regulatory posture are separately decided;
- multilingual documents and localized explanation;
- camera capture and page-quality correction;
- cross-document Q&A with explicit scope selection.

### Rejected or parked journeys

- buy or renew insurance inside CoverWise;
- product recommendations, ranking, “best plan,” or personalized premium advice;
- insurer/employer/advertiser targeting based on uploaded content or health;
- clinical diagnosis, prediction, prescription, or treatment planning;
- customer claim representation or false certainty that a claim will succeed;
- behavioral advertising in the authenticated policy viewer;
- training on raw customer documents by default.

## 8. Evidence and verification register

| Area | Evidence in this baseline | Tier | Closure needed |
|---|---|---:|---|
| Cold launch visuals | `docs/review/coverwise_launch_audit_2026-07-20.md` screenshots and observations | 4 | Repeat on current build after navigation fixes |
| Mobile navigation | Static route/navigation inspection plus audit failures | 1 + 4 | Reliable real-device navigation through all five tabs |
| Upload contract | Flutter service and FastAPI route inspection | 1 | Real document upload through storage and processing |
| Evidence substrate | Architecture, routes, services, migrations, tests | 1–2 | Real policy with page/source citation verification |
| Q&A | Screens, routes, RAG code, targeted tests; runtime health has known gaps | 1–2 | Fresh backend, owner-scoped question, citation and fallback proof |
| Auth/ownership | Auth providers, user routes, principal storage code and tests | 1–2 | Anonymous → account claim, expiry, two-user isolation, deletion |
| Billing | RevenueCat and subscription code | 1–2 | Sandbox purchase/restore/webhook/idempotency proof |
| Deletion/privacy | UI, consent ledger, deletion endpoint, ADRs/audits | 1–2 | Durable deletion receipt across every representation |
| J02–J07 live runtime probe (2026-07-22) | Upload consent/auth gates, idempotent replay, owner-scoped evidence access, and `/query`/`/documents/query` fallback behavior observed on `:8010` | 2–4 | Same-session processing-to-summary/evidence completion and two-principal replay under restart remain open |

## 9. Open exploration questions

These are deliberately left open for continued discussion:

1. Is the first-run value proposition “understand one policy” strong enough without a bundled sample policy, or does a sample create trust/data-separation risk worth the complexity?
2. What is the smallest evidence-backed output that makes a person trust the app after upload: policy identity, dates, premium, insurer contact, or a cited answer?
3. Should Q&A be document-scoped by default, with an explicit household scope switch, or should the policy detail screen own all questions?
4. What does “share” mean in the product: emergency card, cited answer, full policy, or an export bundle—and which fields are never shareable by default?
5. Is coverage-gap language worth keeping if it cannot recommend action, or should it become a narrower “missing or unverified policy fields” surface?
6. What operator role is needed at launch: a single support/security operator with reason-required audit, or a staged role model already reflected in the ADRs?
7. What is the minimum real-document benchmark and citation acceptance threshold before evidence-backed claims can appear in marketing?
8. Which future features create the highest durable value without creating a second business model: household organization, renewal diff, claim preparation, or evidence-backed annual review?

## 9.1 J02–J07 continuation flow for decision gates (2026-07-22)

```mermaid
flowchart TD
    A[J02: launch] --> B{Onboarding complete?}
    B -->|No| C[J02: onboarding + purpose/privacy]
    B -->|Yes| D[J03: workspace-ready home]
    C --> E{Required terms accepted?}
    E -->|Decline| F[J02: limited mode + explicit warning]
    E -->|Accept| D
    F --> D

    D --> G{Identity transition now?}
    G -->|Anonymous| H[J03: anonymous workspace]
    G -->|Sign in/sign up| I[J03: provider callback]
    I --> J{Auth success?}
    J -->|No| K[J03: retry/reset/password path]
    K --> I
    J -->|Yes| L[J03: claim ownership]

    H --> M[J04: open source]
    L --> M
    M --> N{Source + consent}
    N -->|Missing consent| O[J04: consent required rejection 422]
    N -->|Bad token| P[J04: auth rejected 401]
    N -->|Valid| Q[J04: upload received]
    N -->|Duplicate hash| R[J04: idempotent replay + same doc id]

    Q --> S[J05: poll status]
    R --> S
    S --> T{processing state}
    T -->|processing| U[J05: staged progress]
    T -->|partial / text_required / ocr_required| V[J05: recovery path + keep partial]
    T -->|failed| W[J05: explicit failed + retry/replace]
    T -->|completed| X[J06: evidence visible]

    U --> T
    V --> Y[J06: partial / unknown / not-ready]
    W --> Y
    X --> Y2[J06: field + source + span review]
    Y --> Y2

    Y2 --> Z[J07: ask question]
    Z --> AA{answer quality}
    AA -->|good| AB[J07: cited answer + confidence]
    AA -->|weak/no context| AC[J07: fallback + missing info]
    AA -->|timeout| AD[J07: explicit timeout + retry]
    AA -->|cross-owner| AE[J07: owner scoped no bleed]

    AB --> AF[J07: source navigation + feedback + usage]
    AC --> AF
    AD --> AF
    AE --> AF

    AF --> AG[J01+ return flow: family/help/billings/compare/reminders]
    AG --> D

    %% optional + compatibility branch
    N -->|Future: sample policy| AH[J04 alt: demo policy]
    AH --> N
    Z -->|Compat path for external callers| AI["/documents/query compatibility"]
    AI --> AF
```

### Branch ledger update for this continuation

| Journey | Verified in this continuation | Outstanding Tier 3+ gap |
|---|---|---|
| J02 | Onboarding path and consent gates remain behaviorally distinct | whether onboarding/consent is a hard server-enforced launch contract |
| J03 | Anonymous upload + claim path observed; local migration hardening continues through tests | two-principal authenticated replay/restart across local + backend not yet closed |
| J04 | Upload consent/auth/replay contract branches observed | proof that durable outbox branch is used for every production upload path |
| J05 | failure and partial branches produce non-claiming terminal states (`completed_summary_partial`, `failed`) and explicit owner-scoped missing-doc responses | recovery under restart + crash + duplicate lease with same processing document |
| J06 | cross-owner cannot read foreign evidence routes; same-owner partial documents return `404` for `/summary` and `/evidence/field-citations` until full policy extraction completes | evidence-page navigation and positive-field provenance for successful summaries remain open |
| J07 | `/query` route returns no-context-safe fallbacks for weak/cross-owner context; legacy `/documents/query` compatibility route functions with form list semantics | canonical-route migration completion and cross-owner same-session replay still open |

## 9.2 J02–J07 continuation execution checkpoint (2026-07-22, same-session 8010 replay)

- **Live stack**: `http://127.0.0.1:8010`
- **Probe tokenization**: one anonymous token per actor, one document used for per-lane evidence.

Observed outcomes:

1. `POST /documents/upload` without consent:
   - `422` with `processing_consent_required`.
2. `POST /documents/upload` with same anonymous owner and same bytes:
   - idempotent contract held; response includes `documents[0].idempotent_replay=true` and same `document.id`.
3. Processing:
   - status path reaches `processing` then `completed_summary_partial` in short interval.
   - `/documents/{id}/summary` remains `404 No policy summary found...` for this synthetic lane.
4. Evidence and isolation:
   - Owner A can read status; owner B receives 404 on `/documents/{id}`, `/documents/{id}/status`, and `/evidence/{id}/field-citations`.
5. Q&A:
   - `/query` with in-scope doc returns answer + source metadata with explicit confidence.
   - owner mismatch `/query` returns safe no-context fallback (`confidence: 0.0`).
   - `/documents/query` compatibility route is active and requires form list semantics (`document_ids=[]` expected).

Open from this checkpoint:

- Positive summary/evidence navigation for a completed doc under the same runtime lane is still open.
- authenticated anonymous-to-account replay/restart and account-level migration closure remains open.

This checkpoint keeps the frontier closed at the contract edge and explicit on what is still not closed.

## 10. Pass notes

### Pass 1 — Immediate correctness and completeness

The inventory covers primary navigation, deep-link features, document lifecycle, Q&A, family, reminders, emergency access, claims preparation, billing, identity, privacy, and operator recovery. Each journey has ideal/current/future status and non-happy branches. Current runtime failures are retained rather than normalized away.

### Pass 2 — Architecture and long-term viability

The map routes all journeys through the canonical mobile → FastAPI → storage/evidence/RAG path. It does not introduce a second API, pipeline, consent system, or journey source of truth. Recommendation-like surfaces are explicitly constrained by the permanent product boundary.

### Pass 3 — Rule compliance and supervision readiness

Claims are tiered by evidence. High-risk journeys name their missing Tier 3+ checks. Future work is framed as decisions and durable contracts, not calendar estimates. The map preserves open questions and rejected paths so later exploration cannot silently drift the product boundary.

### Anything else?

Yes: the main hidden risk is not missing screens; it is a mismatch between a polished screen and the lifecycle underneath it. Every later journey discussion must therefore trace input → processing → storage → output → operator visibility, and must update this map when the product boundary, source of truth, or verification status changes.

## 11. Update log

- **2026-07-21:** Created baseline journey inventory from current Flutter screens, route declarations, FastAPI routes, canonical architecture, exploration map, user-flow planning docs, and the 2026-07-20 runtime launch audit. Established ideal/current/future labels, non-happy-path diagrams, evidence tiers, and open questions. No code behavior changed.
- **2026-07-22:** Added explicit J02–J07 end-to-end flow graph covering happy, non-happy, optional, and alternate transitions (onboarding/identity/upload/processing/evidence/Q&A), aligned with the same execution-ledger in `coverwise_j02_j07_deep_dive_2026-07-21.md`. Added diagram legend and clarified that sample/camera/future journeys are exploratory and must remain non-promissory.
- **2026-07-22 (continuation):** Added live API checkpoints for J02–J07: consent-required upload rejection, invalid-token rejection, idempotent replay (`documents[0].idempotent_replay=true`), explicit document-owner isolation (`404` on foreign owner reads), and query fallback behavior (`/query`/`/documents/query`). Canonical/compatibility query split remains open for completion, as do identity replay and restart proof.
- **2026-07-22 (continuation pass):** Cross-owner same-session probe confirms owner A/B cannot access each other’s documents or evidence routes; `/query` with owner A doc scope returns question + verified citations, while B receives a safe no-relevant fallback.
- **2026-07-22 (continuation pass B):** Added same-session same-token replay evidence on `127.0.0.1:8010` for upload idempotency, partial completion (`completed_summary_partial`), summary/evidence 404 behavior, cross-owner status isolation, and compatibility query form-list requirements for `/documents/query`.
- **2026-07-22 (continuation pass C):** Added claim-route guardrail evidence: `/user/claim-anonymous` is 403 when called by anonymous callers, while unauthorized/malformed body paths confirm payload parsing is still account-gated.
- **2026-07-22 (continuation pass D):** Added local claim-route smoke proof:
  - mocked account bearer to account-token claim flow returns `200` and `identity_link_status: completed`;
  - anonymous bearer to claim returns `403 An account is required to claim data`;
  - route smoke + unit suites capture transfer callback wiring (`begin_identity_link`, `complete_identity_link`, `transfer_owner`);
  - `tests/test_identity_link_service.py` and `tests/test_document_owner_isolation.py` are green (`17/17`).

## 12. J02–J07 deep-dive addendum (2026-07-21)

The detailed implementation audit is preserved at
`docs/review/coverwise_j02_j07_deep_dive_2026-07-21.md`. The canonical map’s
status is now more precise:

- **J02/J03:** local onboarding consent and server consent now converge through
  one cache-scoped sync path, but upload still uses local-offline fallback behavior
  until server append succeeds. Anonymous-to-account claim transfers server
  document ownership with improved local encrypted migration guardrails; end-to-end
  local migration still lacks live two-principal restart proof. Account deletion’s
  `202` contract still references a durable job that is being closed operationally.
- **J04/J05:** upload validation, owner-scoped dedupe, storage rollback, and
  capability-aware processing states are real. In production composition, upload now
  maps to durable outbox processing with `BackgroundTasks` retained only as
  documented non-production compatibility, so crash recovery is still open only at
  live queue/restart evidence.
- **J06:** the evidence substrate and owner check are real, and the main RAG
  query path verifies citations against immutable source text. A fresh
  real-document proof and convergence of weaker model-backed extraction paths
  remain open.
- **J07:** owner scope and honest unavailable/not-found fallbacks exist, but
  `/query` is the canonical mobile contract and `/documents/query` remains
  documented compatibility. One canonical route and a documented retirement path
  for the compatibility surface are required.

This addendum does not convert static inspection into end-to-end completion. The
next verification gate is a real-document, two-principal Tier 3 pass covering
claim, restart/replay, processing completion evidence, and cross-surface answer
alignment.

**2026-07-21 deep-dive update:** Added the dated J02–J07 contract audit,
Supabase security references, risk-ranked closure order, and follow-up questions.
No code behavior changed.

**2026-07-21 verification addendum (refined 2026-07-22):** The focused Python checks are
now passing at fixture level: `test_citation_verifier*` and Supabase FTS assertions are
closed in this repo state (`31` and broader combined `84` passing in a clean combined
run, with seven existing HTTPX deprecation warnings). J06/J07 still depends on live two-principal and real-document evidence gates for
cross-stack replay, owner isolation under restart, and live evidence-owner proof.

For execution sequencing, use the
[`J02–J07 evidence-by-branch command matrix`](../review/coverwise_j02_j07_deep_dive_2026-07-21.md#j02j07-evidence-by-branch-command-matrix-2026-07-22)
in the deep-dive artifact.

That matrix now includes an **Observed execution log** section with the backend probe outcomes that have run in this pass, plus an explicit note that mobile probe execution still needs a stable test runtime.
