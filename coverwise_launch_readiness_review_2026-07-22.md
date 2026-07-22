# CoverWise launch-readiness review

**Review date:** 22 July 2026  
**Repository:** `pranaysuyash/insurance_q`  
**Branch reviewed:** `main`  
**Head reviewed:** `3de87938b3cedf110729fdc69640e7e939372fc8`  
**Review basis:** current code, migrations, tests, launch evidence and official store requirements. Older audit findings were retained only where they still reproduce in current `main`.

---

## 1. Executive decision

### Public launch verdict: NO-GO

CoverWise is no longer an unstable prototype. The core architecture has materially improved:

- principal-scoped encrypted Hive workspaces
- owner-scoped backend reads and deletes
- durable outbox contracts
- server-authoritative policy and Q&A limits
- RevenueCat webhook authority
- source-document download contracts
- guest-to-account server claim machinery
- a broad automated test base
- release configuration that fails closed

That is real progress.

The remaining problems are concentrated, but several are launch-blocking because they create one of four failures:

1. **The user can be misled:** “All Documents” Q&A silently queries one document; phone capture is presented as account backup; generic heuristics are called an Insurance Health Score and coverage-gap analysis.
2. **User data can be lost or orphaned:** Google OAuth does not run the guest-workspace migration used by email authentication.
3. **A visible feature does not do what it says:** renewal “scheduling” displays notifications immediately and is not initialized as a complete native notification lifecycle.
4. **Production is not proven:** the current evidence record still has invalid embedding credentials, a missing remote table, no deployed durable worker, no real RevenueCat sandbox lifecycle, no production-signed store build and no hosted CI evidence for the latest head.

### Internal decision

- **Internal engineering build:** viable after fixing the auth migration and Q&A scope bugs.
- **Closed beta:** viable after the production environment, worker, schema, billing and store-build gates pass.
- **Public store release:** viable only after the misleading trust surfaces and legal/product claims are removed or corrected.

### Strong recommendation

Do not try to finish every feature already visible in the app. That is the slowest and riskiest path.

Launch a narrower product:

> Upload a policy, extract a grounded summary, inspect the source, ask questions against one or all policies, and retain the workspace safely.

Everything else must either be demonstrably correct or be hidden from the first public release.

---

## 2. Current launch scorecard

| Domain | Score | Decision |
|---|---:|---|
| Core upload → process → summary → Q&A loop | 3.5/5 | Keep, after two P0 functional fixes |
| Backend authority and tenant isolation | 4/5 | Strong code contract; production proof incomplete |
| Authentication and identity lifecycle | 2/5 | Google migration path is unsafe |
| Local storage and encryption | 3/5 | Metadata encrypted; source files need a defined protection contract |
| Cross-device restore and sync | 2.5/5 | Documents reconcile; “full workspace restore” is overclaimed |
| Offline and retry behavior | 3.5/5 | Good pending-upload foundation; edge cases remain |
| Billing and usage enforcement | 3.5/5 | Server-side design is good; real provider lifecycle unproven |
| UX and product flow | 2.5/5 | Too broad; several labels do not match behavior |
| UI system and accessibility | 3.5/5 | Coherent components and tests; density and trust hierarchy need work |
| Insurance trust and evidence | 2/5 | Q&A direction is good; health/gap advice is not grounded enough |
| Privacy and account deletion | 3/5 | In-app deletion exists; external deletion and policy truth need closure |
| Store and native readiness | 2.5/5 | Android target is current; signed distribution and iOS archive proof missing |
| CI, observability and operations | 2.5/5 | Test breadth is strong; production and hosted evidence are incomplete |

---

## 3. What is genuinely strong now

Several findings from older reviews are no longer accurate and should not keep consuming attention.

### 3.1 Backend commercial authority

Current code now reserves policy slots on the server under an owner lock, counts pending reservations, finalizes only after persistence, and releases on failure. Q&A uses an idempotent request ID with reserve/finalize/release semantics. Billing treats client sync as telemetry while verified RevenueCat webhook state remains authoritative.

**Keep this architecture.** Do not move commercial authority back into Flutter.

Evidence:

- `src/services/policy_slot_reservation_service.py`
- `supabase/migrations/20260721170000_policy_slot_reservations.sql`
- `supabase/migrations/20260721220000_fix_policy_slot_pending_race.sql`
- `src/services/qa_usage_service.py`
- `supabase/migrations/20260721180000_qa_usage_ledger.sql`
- `supabase/migrations/20260721190000_qa_usage_reservation_lifecycle.sql`
- `src/api/subscription.py`
- `src/services/billing_ledger_service.py`

### 3.2 Durable work contracts

The production upload path persists the source, records metadata, reserves entitlement capacity, creates an encrypted processing-input envelope and enqueues durable work. It rolls back rather than returning a false `202` if no durable work record exists.

The worker now registers document-processing, substrate-extraction, billing reconciliation, subscription writeback and account-deletion handlers.

Evidence:

- `src/api/document.py`
- `src/workers/outbox_worker.py`
- `src/services/job_outbox_service.py`
- `tools/deploy_outbox_worker.sh`

The design is acceptable. The open issue is deployment proof, not another queue redesign.

### 3.3 Principal-scoped metadata encryption

The local metadata boxes use a random 256-bit principal DEK kept in platform secure storage. The key no longer derives from rotating JWT text. Hive handles are closed and reopened across principal transitions.

Evidence:

- `mobile/lib/services/principal_key_service.dart`
- `mobile/lib/services/hive_workspace_service.dart`
- `mobile/lib/main.dart`

This is the right direction. The remaining risks are transition atomicity, key-corruption handling and plaintext source files.

### 3.4 Owner scoping and deletion ordering

Document list, detail, status, source URL, queries and deletion derive the owner from the authenticated principal. Deletion fences processing, removes derived data, deletes source objects and registered artifacts before removing metadata.

Evidence:

- `src/api/document.py`
- `src/app/main.py`
- `src/services/account_lifecycle_service.py`
- `src/services/artifact_registry.py`

### 3.5 Automated test breadth

The current launch execution record reports:

- 378 backend tests passing, one deliberately gated integration skip
- 636 Flutter tests passing serially
- clean Flutter analysis
- targeted remote Supabase billing and outbox validation

This is a useful base. It is not equivalent to production proof, but it means the remaining launch work can be surgical.

Evidence:

- `docs/review/launch_execution_status_2026-07-21.md`
- `.github/workflows/ci.yml`

---

# 4. P0 launch blockers

## P0-1. Google OAuth does not migrate the guest workspace

### Current behavior

The email flow runs:

1. `prepareAnonymousWorkspaceClaim()`
2. sign in or sign up
3. `claimAnonymousData()`

The Google flow runs only `signInWithGoogle()` and immediately returns from the account screen. When the auth-state listener sees the account principal, it consumes a one-shot “preserve workspace” marker. Google never sets that marker. The principal transition can therefore delete the local guest workspace. It also never calls the server guest-to-account claim.

Evidence:

- `mobile/lib/screens/account_screen.dart`
- `mobile/lib/main.dart`
- `mobile/lib/services/auth_service.dart`
- `mobile/lib/services/hive_workspace_service.dart`

### Failure modes

- guest uploads one or more policies
- user chooses Google sign-in
- account session becomes active
- local principal changes without preserving guest boxes
- guest server records remain under the anonymous owner
- app appears signed in but the prior workspace is missing

The email path has a second problem: if account sign-in succeeds but `claimAnonymousData()` fails, the generic catch path can report that sign-in failed although the session is already active.

### Required fix

Create one orchestration used by every auth method:

`linkGuestWorkspaceToAccount(authAction)`

State machine:

1. capture guest principal and API owner
2. persist a transition journal outside the principal-encrypted workspace
3. preserve a local workspace snapshot
4. establish account session
5. claim guest server data idempotently
6. reopen/re-encrypt the workspace for the account principal
7. reconcile server documents and summaries
8. verify expected counts/identities
9. clear the transition journal
10. surface one of:
   - linked
   - signed in, migration pending
   - migration failed, retry available

Do not collapse account authentication and workspace migration into one generic exception.

### Acceptance evidence

- guest upload → email sign-up → exact document remains
- guest upload → Google OAuth → exact document remains
- process killed after OAuth callback → next launch resumes transition
- server claim retry is idempotent
- account A cannot claim account B or a previously claimed guest
- failed claim does not tell the user they are signed out
- sign-out and sign-in to another account do not leak local state

---

## P0-2. “All Documents” Q&A silently queries the first policy

### Current behavior

The UI sets `selectedDocumentProvider` to `null` for “All Documents.” The request helper interprets `null` as “use the first document.”

Evidence:

- `mobile/lib/screens/qa_screen.dart`

This is not a minor filter bug. It makes the answer scope false while the UI explicitly tells the user it is searching across all policies.

### Required fix

Replace nullable scope with an explicit model:

```text
QueryScope.allDocuments
QueryScope.singleDocument(documentId)
```

Request contract:

- all documents: omit `document_id` and send explicit scope metadata if useful
- single document: resolve the backend document ID and send exactly one filter

Render the active scope in the answer card and history record.

### Acceptance evidence

- network contract test proves all-doc request contains no document filter
- answer result contains citations from two documents in a seeded multi-policy case
- single-document request cannot return a citation from another document
- history preserves the scope used at answer time

---

## P0-3. Renewal reminders are not scheduled reminders

### Current behavior

`NotificationService.scheduleRenewalReminders()` computes future dates but calls `show()`, which displays a notification immediately. Quiet hours are evaluated against the current hour, not the intended delivery time. The app auto-invokes this method once summaries load. Permission handling is Android-specific and no current startup call initializes the notification plugin.

Evidence:

- `mobile/lib/services/notification_service.dart`
- `mobile/lib/screens/renewal_calendar_screen.dart`
- `mobile/lib/main.dart`

### Fastest launch decision

**Hide the reminder CTA and notification-preferences surface for the first release.**

A correct implementation requires:

- plugin initialization at startup
- iOS and Android permission handling
- timezone initialization
- zoned scheduling, not `show()`
- stable notification IDs
- update/cancel/reschedule when a policy changes
- quiet-hours delivery semantics
- reboot/timezone change behavior
- tests on real Android and iOS devices

A half-fixed reminder system is worse than no reminders because renewal timing is a consequential promise.

### Acceptance evidence if retained

- future trigger appears only at the intended time
- four configured dates create four scheduled requests, not immediate notifications
- disabled policy cancels its requests
- date edit replaces old requests
- quiet-hour trigger moves to the next allowed time
- app restart does not duplicate requests
- iOS permission denial and Android permission denial are handled honestly

---

## P0-4. Insurance Health Score and Coverage Gaps overstate what the system knows

### Insurance Health Score problems

The score:

- awards full gap points when zero gaps exist, which conflates “no analysis” with “no risk”
- compares exact strings such as `health`, `motor`, `life` against document labels such as `Health Insurance`
- can award full active-policy points from a single policy
- labels users “Excellent,” “Good” or “At Risk”
- says coverage is “strong across the board”

Evidence:

- `mobile/lib/providers/health_score_provider.dart`
- `mobile/lib/widgets/health_score_card.dart`

This is an invented metric without calibration, regulatory basis, sufficient household context or evidence coverage.

### Coverage Gaps problems

The gap engine produces generic recommendations to buy health, life, auto, critical-illness or maternity cover based on document-type presence and keyword absence. Keyword absence is not evidence that coverage is absent. It may mean extraction failed, the clause was expressed differently, or the uploaded corpus is incomplete.

Evidence:

- `mobile/lib/services/policy_extraction_service.dart`
- `mobile/lib/screens/coverage_gap_screen.dart`

### Required launch decision

Remove both surfaces from the first public build.

Replace them with a grounded **Policy Readiness** checklist:

- policy type identified
- insurer identified
- policy number identified
- start and expiry dates identified
- source pages available
- extraction requires review
- policy expired or expiring, based on an extracted date with citation

Never use “coverage health,” “gap,” “at risk,” or purchase recommendations without a more rigorous evidence and compliance model.

---

## P0-5. Phone capture is presented as account linking and backup

### Current behavior

Settings and Profile infer “linked” state from a phone number saved in Hive. The UI says:

- Account linked
- Connected as …
- Back up policies and use them on another device
- Linked and ready across your devices

The phone action only writes or deletes a local value. It is not authentication, account recovery or cloud backup.

Evidence:

- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/screens/profile_screen.dart`
- `mobile/lib/localization/app_localizations.dart`
- `mobile/lib/widgets/phone_capture_sheet.dart`

### Required fix

Remove phone capture from account and backup surfaces.

Possible later uses:

- optional contact preference
- support callback number
- insurer communication helper

Those require purpose-specific consent and must not change account state.

Account-linked UI must depend only on a verified account session and successful workspace reconciliation.

---

## P0-6. Production dependencies and deployment are still open

The repository’s current execution record explicitly says the app is not launch-ready. Open items include:

- invalid current OpenAI embedding credential
- remote `model_run_results` table missing
- production auth/configuration incomplete
- real signed Android bundle not regenerated with production values
- no iOS distribution archive proof
- no external deployment completed
- no real RevenueCat sandbox delivery lifecycle
- outbox worker not deployed externally
- hosted CI not verified for the latest state

Evidence:

- `docs/review/launch_execution_status_2026-07-21.md`

### Required closure order

1. apply and verify the complete remote schema
2. replace credentials and make `/health` pass
3. deploy API
4. deploy worker with minimum one instance or another guaranteed poller
5. perform a real queued document round trip
6. perform real RevenueCat purchase, restore, renewal/cancellation/refund/expiry events
7. generate production-signed Android App Bundle
8. generate iOS archive and export
9. run store binaries against the actual production environment
10. capture immutable evidence for the exact submitted commit

No launch claim should rely on localhost, placeholder build defines or synthetic-only provider events.

---

## P0-7. External account-deletion path is missing

The app has an in-app account-deletion flow. Google Play also requires a functional external web resource for requesting deletion when an app supports account creation.

Repository search shows planning and legal references but no implemented external deletion resource.

### Required fix

Publish a stable HTTPS page under the same developer/app identity. It must:

- name CoverWise and the developer
- let the user initiate deletion without reinstalling the app
- identify the account safely
- explain deletion scope and retained data
- explain subscription cancellation separately
- issue a trackable request/reference
- not require a phone call

Wire the URL into Play Console’s Data safety/account deletion field and the privacy policy.

For Apple, keep the in-app deletion path easy to find and verify that delayed deletion status is explained clearly.

---

## P0-8. Privacy and product copy do not fully match behavior

Current policy and UI claims include:

- “information broker”
- users can export policy summaries and Q&A history
- full workspace restore across devices
- phone-linked backup
- device-protected local cache
- policy documents stored until account deletion
- analytics and retention descriptions that may not match the canonical deployed system

Evidence:

- `mobile/assets/legal/privacy_policy.md`
- `docs/legal/privacy_policy.md`
- `mobile/lib/localization/app_localizations.dart`
- `mobile/lib/screens/profile_screen.dart`
- `mobile/lib/screens/settings_screen.dart`

### Required fix

Perform a product-truth pass before a legal-style pass.

Use “policy information assistant,” not “information broker.”

Describe exact scopes:

- source files stored locally and/or server-side
- which local files are encrypted
- what account restore restores
- what remains device-only
- which processors receive document text
- how long each artifact is retained
- how per-document deletion differs from account deletion
- what portability/export is actually available

Either implement export or remove the right-to-export product claim until it exists.

---

# 5. Storage, encryption and data lifecycle review

## 5.1 What is encrypted

Hive metadata boxes use a principal-scoped AES key stored in platform secure storage.

This covers:

- document metadata
- app state
- resolved-gap state
- analytics buffer
- consent ledger
- Q&A history
- field overrides
- entitlements

Evidence:

- `mobile/lib/services/hive_workspace_service.dart`
- `mobile/lib/services/principal_key_service.dart`

## 5.2 What is not encrypted by the app

Uploaded policy source files are copied into the application Documents directory as plaintext. Downloaded server sources are also written there as plaintext.

Evidence:

- `mobile/lib/services/local_storage_service.dart`

Android backup is disabled, which reduces one path. iOS currently has no visible code contract for excluding cached policy files from backup or applying explicit file-protection classes.

### Recommended launch contract

- Store temporary downloaded sources under the cache directory, not Documents.
- Exclude cached files from backups.
- Delete cache on sign-out/principal transition.
- Encrypt any user-retained offline source with a file-specific key wrapped by the principal DEK.
- Record file hash, size, origin and cache state.
- Verify the hash after download, not only byte count.
- Make offline retention explicit to the user.

## 5.3 Key corruption handling

If a stored DEK is malformed, current code generates a new one. Existing encrypted boxes then become unreadable. A comment says “the migration path will handle the data loss,” but no safe data-recovery path can decrypt data after key replacement.

Evidence:

- `mobile/lib/services/principal_key_service.dart`

Required behavior:

- fail closed with a recoverable “local secure storage unavailable/corrupt” state
- do not overwrite the key automatically
- offer server restore when the account owns remote documents
- offer explicit local reset only after explanation

## 5.4 Legacy box migration atomicity

Migration reads entries, deletes the old box, creates the new encrypted box and rewrites entries. A crash after deletion but before complete rewrite can lose local state.

Evidence:

- `mobile/lib/services/principal_key_service.dart`
- `mobile/lib/main.dart`

Before public update distribution:

- test upgrade from every previously distributed build
- migrate to a temporary box/file
- verify count and checksum
- atomically swap
- preserve old data until verification succeeds

If no public users exist, consider removing legacy migration debt from the public first release and handling only known beta builds separately.

## 5.5 Clear-local-data behavior

Settings clears two open boxes, clears SharedPreferences, recursively deletes the application Documents directory, invalidates providers, cancels notifications, clears consent and clears the custom API token. Other principal boxes are not centrally closed before recursive deletion. The Supabase account session remains active.

Evidence:

- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/services/hive_workspace_service.dart`

Create one lifecycle operation:

`clearLocalWorkspace({keepAccountSession: true})`

It must close every box, delete source/cache files, clear local secure tokens that belong to the anonymous API workspace, reopen a clean principal workspace and verify emptiness.

Do not let a screen own filesystem and encryption lifecycle logic.

---

# 6. Authentication and identity review

CoverWise currently coordinates three identities:

1. local encryption principal
2. Supabase authentication principal
3. custom API bearer owner for guest mode

This can work, but it needs an explicit identity state machine.

## Required canonical states

- local-only guest
- server guest
- account authenticated, guest claim pending
- account authenticated, workspace linked
- account authenticated, migration failed
- deletion pending
- deletion running
- deletion failed
- signed out/local-only

Each state should define:

- which bearer token is used
- which DEK is active
- which server owner is authoritative
- whether upload/query/delete are allowed
- whether reconciliation is allowed
- what the user sees

## Auth UX improvements

- Add password visibility toggle and autofill hints.
- Use localized strings already defined instead of duplicated literals.
- Do not pop the Google account screen before migration status is known.
- Distinguish “email confirmed but workspace not linked” from authentication failure.
- Explain whether sign-out removes local copies.
- On deletion, explain store subscriptions are managed separately.
- Reauthenticate before destructive account deletion where provider policy requires it.

---

# 7. Sync and offline review

## 7.1 What works

- locally saved pending uploads
- retry on app startup
- retry on connectivity restoration
- remote metadata reconciliation
- on-demand signed source download
- local records preserve pending uploads while server documents reconcile
- server IDs are retained separately from local IDs

Evidence:

- `mobile/lib/services/document_service.dart`
- `mobile/lib/services/local_storage_service.dart`
- `mobile/lib/main.dart`

## 7.2 Remaining edge cases

### Password-protected PDFs

The password is intentionally not retained, so automatic retry cannot succeed after restart. Do not leave these in a generic retry loop.

Required state: `needs_password`.

### Complete-list assumption

Local reconciliation may remove server-linked records that are absent from the fetched server list. This is safe only after a complete, successfully paginated read.

Required:

- reconcile against an explicit complete snapshot
- do not delete on partial page, timeout or malformed response
- use server revision/cursor if available

### Source integrity

Downloaded files are checked for emptiness and length, not a cryptographic digest.

Required:

- server returns immutable source hash
- client verifies SHA-256 before marking cache valid

### Conflicts and manual state

Manual family members, Q&A history, resolved flags, notification preferences and field overrides are predominantly device state. The app should not claim full workspace restore until those have a deliberate sync/export contract.

### Sign-out

Ordinary sign-out deletes the local account workspace and opens a local-only workspace. That can be acceptable, but the app must explain the consequence before sign-out and only after server reconciliation is known healthy.

---

# 8. Feature-by-feature launch decision

## Keep in first public release

### Onboarding

Keep after legal links, consent version and copy are production-verified.

Primary outcome should be one action: **Add my first policy**.

### Documents

Keep. This is the product backbone.

Required states:

- local only
- upload pending
- needs password
- received
- processing
- ready
- failed, retryable
- failed, unsupported
- deleting
- remote only
- cached offline

### Processing status

Keep, but map UI to server states rather than a timer. The user should be able to leave and return.

### Policy details and source preview

Keep. Every consequential extracted field should have a visible source path or “not verified” state.

### Ask CoverWise

Keep after fixing all-documents scope and completing real production RAG verification.

### Search

Keep as a secondary capability. Clarify whether search is local extracted-summary search or server full-policy search.

### Profile, Settings, Privacy, Help and About

Keep after account/phone/storage copy is corrected.

### Emergency quick reference

Keep only as “quick reference,” not proof of insurance and not emergency advice. Show source and last-updated state.

## Keep but demote

### Family

Remove it from primary bottom navigation for the first release. Keep a read-only derived view under More only if every member can be traced to a policy source. Manual members must be labeled device-only unless synced.

### Insurance cards

Keep only if renamed and framed as a policy quick-reference card. Avoid “digital proof of cover” unless insurers accept the representation.

### Insurance literacy

Safe to retain under More. It should not compete with the main task.

### Renewal calendar

Keep the sorted expiry-date view. Hide reminders until scheduling is real.

## Hide from first public release

- Insurance Health Score
- Coverage Gaps
- What-if calculator
- generic preventive tips that imply advice
- claims guide and claims tracker unless completed
- Smart Suggestions
- plan-gated features whose gates are not enforced
- phone “linking”
- notification preferences until scheduling is complete

Do not delete the code immediately. Remove routes and visible entry points behind one release-scope flag so the first public build is truthful.

---

# 9. UX and navigation review

## Current problem

The populated Home screen includes:

- quick actions
- search
- health score
- summary cards
- welcome/statistics card
- recent activity
- family
- document summary
- preventive tips
- terminology

The More screen exposes a large set of planning, claims, comparison, calculator, account and learning tools.

This makes the app look feature-rich but weakens the primary mental model.

## Recommended first-release navigation

### Bottom navigation

1. Home
2. Policies
3. Ask
4. More

Remove Family as a primary tab until it is a proven retention driver and the entitlement contract is settled.

### Home

1. primary action: Add policy or Ask about existing policy
2. processing/attention queue
3. policy list or next-expiry cards
4. most recent verified answer

Nothing else above the fold.

### Policies

- filter by state and type
- clear sync/processing badges
- source availability
- delete/replace behavior
- no local/server ambiguity

### Ask

- explicit scope
- selected policies visible
- answer confidence hidden until calibrated
- citations before follow-up suggestions
- no answer when evidence is insufficient
- source navigation works offline when cached

### More

- Search
- Renewal dates
- Emergency quick reference
- Family, if retained
- Insurance basics
- Profile
- Settings
- Privacy
- Help
- About

## UX language rules

- “Policy” for the user object, “document” only when discussing the uploaded file.
- “Saved on this device” versus “Backed up to your account.”
- “Source not verified” rather than a neutral missing value.
- “Could not retrieve a verified answer” rather than generic AI failure.
- “Quick reference” rather than proof.
- “Needs review” rather than low confidence if confidence is not calibrated.
- Never expose backend names such as “Supabase account” or the raw service endpoint in normal production settings.

---

# 10. UI and accessibility review

## Strengths

- coherent shared components
- consistent card/action-row language
- dark and light themes
- explicit large-text handling in some complex tiles
- semantic loading labels
- broad widget tests

## Required improvements

### Information hierarchy

Use fewer simultaneous cards and stronger priority order. Consequential source-backed information must visually outrank education and upsell content.

### State colors

Do not rely on color alone. Every status requires text and icon semantics.

### Text scaling

Test 200 percent text scale for:

- policy list rows
- Q&A source cards
- bottom navigation
- comparison
- dialogs
- deletion and billing flows

### Screen reader

Verify:

- citation buttons announce page and policy
- processing steps announce current state, not every rebuild
- destructive actions include scope
- charts/scores removed or have equivalent text
- tab and scope selection announce selected state

### Motion

Respect reduced motion globally. Do not autoplay demo navigation in any production-capable build.

### Native permissions

Remove unused camera and photo-library declarations/dependencies unless a complete scan flow ships. Remove development-only local-network/Bonjour keys from release iOS configuration.

---

# 11. Billing and monetization review

## What is right

- server authority
- webhook idempotency
- stale-event ordering
- verified-state precedence
- pack FIFO/expiry concepts
- Q&A request idempotency
- upload reservation before work

## What is inconsistent

The plan model advertises cloud sync, comparison, family, emergency and advanced search as paid features. Searches show the gate definitions, but the corresponding UI surfaces do not consistently call them. Basic account restore already exists independently of plan.

## Recommended monetization contract

Keep safety and ownership free:

- one policy
- account creation
- restore that policy
- per-document deletion
- source viewing
- limited verified Q&A

Monetize:

- additional policy slots
- higher monthly Q&A
- multi-policy comparison
- household collaboration, not merely a local family list
- structured annual review after it is evidence-grounded
- export/report packages
- longer history and automation after sync is complete

Do not charge for basic recovery of user-owned data. Do not advertise a paid gate that is not enforced server-side.

## Required real-provider tests

- new purchase
- restore
- renewal
- cancellation with access until expiry
- billing issue
- product change
- refund
- refund reversal semantics
- expiration
- duplicate webhook
- stale webhook
- transfer
- consumable pack purchase
- unknown product
- app reinstall
- account switch

The final entitlement shown in Flutter must match the server ledger after every case.

---

# 12. Backend, infrastructure and operations review

## API readiness

`/healthz` is process liveness. `/readyz` currently checks initialized service objects. `/health` probes embedding capability and can be degraded while `/readyz` remains 200.

This separation is reasonable for process orchestration, but it is not sufficient as a launch gate. A release verifier must test the actual product contract:

- create identity
- upload a fixture
- worker claims job
- processing completes
- summary exists
- query returns grounded citation
- source link opens
- deletion removes all artifacts
- cross-owner access is denied

## Worker

The dedicated worker script uses minimum one instance, no CPU throttling and concurrency one. Deploy it and prove queue latency, lease recovery and dead-letter handling.

Operational dashboards must include:

- oldest pending job age
- queue depth by type
- retry count
- dead-letter count
- processing duration p50/p95
- extraction failure class
- Q&A latency and no-evidence rate
- source-download errors
- entitlement ledger errors
- deletion backlog and failures

## Supabase

Before launch:

- link the canonical project
- dry-run migrations
- apply all migrations
- run schema verifier
- test RLS with publishable key
- test owner isolation with two real accounts
- test guest claim
- test service-role-only tables and RPCs
- back up and document recovery

## Secrets

Use separate staging and production:

- OpenAI
- Supabase service role
- processing-payload encryption
- RevenueCat webhook authorization
- Android signing
- Apple signing/distribution
- analytics/monitoring

No local `.env` should be treated as production authority.

---

# 13. Store-readiness review

## Android

Positive:

- target/compile SDK 36
- canonical release script validates HTTPS configuration
- release signing is required by the script
- demo mode is rejected
- placeholders and secret-looking client values are rejected

Open:

- regenerate the AAB with real values
- install from the signed release artifact
- run full auth/upload/query/delete/billing flows
- configure Data safety truthfully
- publish external account-deletion resource
- verify developer identity/contact information
- remove unused permissions and native dependencies
- decide code shrinking and mapping-file retention
- upload to internal testing before closed testing

## iOS

Open:

- production bundle ID and signing
- archive and export
- universal-link/associated-domain decision
- OAuth callback validation
- local file backup/protection
- combined privacy-manifest report
- App Privacy answers
- notification permission and scheduling, if retained
- account deletion
- subscription management copy
- TestFlight build and real-device flow

Apple requires privacy manifests/signatures for listed SDKs such as `connectivity_plus`. The correct proof is the Xcode archive’s combined privacy report, not a source-code assumption.

---

# 14. Testing gaps

The unit and widget suites are broad. The missing tests are mainly contract and lifecycle tests.

## Mandatory end-to-end matrix

### Fresh and returning users

- fresh install
- onboarding complete
- app kill during onboarding
- returning guest
- returning account
- reinstall and restore

### Documents

- PDF
- image
- password-protected PDF
- invalid extension
- valid extension with invalid content
- 20 MB boundary
- duplicate source hash
- concurrent uploads at policy limit
- app killed during upload
- app killed during processing
- worker restart
- delete during processing
- replace document
- remote-only source download
- corrupted download

### Authentication

- guest → email account
- guest → Google account
- account A → sign-out → account B
- OAuth cold start
- password reset cold start
- email unconfirmed
- token expiry during upload/query/delete
- account deletion pending/running/failed
- external deletion request

### Q&A

- single policy
- all policies
- no evidence
- conflicting policy clauses
- unsupported question
- budget exhausted
- usage ledger unavailable
- network timeout after server completion
- request retry with same ID
- citations open correct policy/page
- no cross-owner citation

### Billing

Use the real-provider matrix listed earlier.

### Native/store

- Android production-signed AAB installed from Play internal testing
- iOS TestFlight archive
- offline mode
- background/foreground
- low storage
- permission denial
- 200 percent text
- screen reader
- dark mode
- slow network

---

# 15. CI and release engineering

Current CI is a compile/test baseline, not a release pipeline.

## Add gates

- backend formatting and import hygiene incrementally
- type checking for launch-critical Python modules
- dependency vulnerability scan
- secret scan
- migration lint and disposable Supabase reset
- Flutter dependency audit
- Android App Bundle build, not only APK smoke
- iOS no-sign archive compile on macOS runner
- E2E contract suite against ephemeral or staging services
- release configuration validator
- artifact retention
- immutable action versions or pinned SHAs
- SBOM/provenance where practical

## Release identity

Every evidence bundle should record:

- git commit
- migration version
- API image digest
- worker image digest
- Android version/code and signing fingerprint
- iOS version/build
- environment name
- model and prompt versions
- evidence timestamps

---

# 16. Exact launch scope I would choose

## First public promise

> CoverWise helps you store and understand your insurance policies. Upload a policy, review extracted details, open the source, and ask questions that link back to the document.

## First public surfaces

- onboarding
- home
- policies
- processing
- policy detail
- source preview/download
- Ask CoverWise
- search
- renewal dates without notifications
- emergency quick reference
- profile/account
- settings
- privacy
- help
- about
- subscription/Q&A packs after real billing proof

## Explicitly excluded

- health score
- coverage-gap recommendations
- what-if calculator
- smart suggestions
- generic claims advice
- claims tracker
- renewal notifications
- phone account linking
- ungrounded preventive recommendations
- any feature gate not enforced

This cut makes the product smaller but more credible. Credibility matters more than menu breadth in an insurance-adjacent product.

---

# 17. Execution order

## Gate A: make the product truthful

1. remove Health Score and Coverage Gaps entry points
2. remove phone-linked backup/account claims
3. hide notification/reminder entry points
4. fix All Documents query scope
5. unify email and Google guest migration
6. correct privacy, account and storage copy
7. remove/demote unfinished More-screen features
8. simplify Home

## Gate B: make user data safe

1. define local-source encryption/cache contract
2. harden key corruption handling
3. centralize clear-local-data lifecycle
4. add principal-transition journal
5. verify legacy migration or remove it from the public path
6. prove two-account isolation and restore

## Gate C: make production real

1. complete remote schema
2. replace model credentials
3. deploy API and worker
4. pass full product health verifier
5. complete real RevenueCat lifecycle
6. create external deletion page
7. generate signed Android and iOS builds
8. run release-binary E2E matrix

## Gate D: closed beta

Track:

- first-policy upload completion
- processing success
- time to first useful answer
- citation open rate
- no-evidence rate
- auth-link failure rate
- restore success
- deletion completion
- crash-free sessions
- queue age
- support issues by failure class

Do not use broad engagement metrics to excuse broken trust flows.

## Gate E: public release

Release only when every P0 has binary evidence and the submitted binaries match the reviewed commit and production schema.

---

# 18. Launch acceptance checklist

## Product

- [ ] First-time user reaches policy upload without confusion
- [ ] One complete policy path works in the submitted binary
- [ ] All Documents Q&A is genuinely multi-policy
- [ ] Every answer identifies its scope
- [ ] Consequential fields expose sources or “not verified”
- [ ] No Health Score or generic gap advice in public release
- [ ] No visible dead/coming-soon surface in primary navigation

## Identity

- [ ] Email guest claim passes
- [ ] Google guest claim passes
- [ ] OAuth cold-start migration resumes
- [ ] Account A/B isolation passes
- [ ] Sign-out behavior is explained
- [ ] Account deletion and status pass
- [ ] External deletion resource is live

## Storage and sync

- [ ] Local source-file contract is implemented and documented
- [ ] iOS backup behavior is verified
- [ ] Pending uploads survive restart
- [ ] Password-required state is explicit
- [ ] Remote reconciliation is complete-snapshot safe
- [ ] Download digest is verified
- [ ] Clear local data is centralized and tested
- [ ] Reinstall restore scope matches copy

## Backend

- [ ] Remote migrations complete
- [ ] `/health` passes
- [ ] API deployed
- [ ] worker deployed
- [ ] real document job round trip passes
- [ ] RLS and cross-owner tests pass
- [ ] deletion artifact traversal passes
- [ ] queue and deletion alerts exist

## Billing

- [ ] real sandbox purchase passes
- [ ] restore passes
- [ ] cancellation/expiry passes
- [ ] refund passes
- [ ] duplicate/stale webhook passes
- [ ] consumable pack passes
- [ ] client matches server ledger
- [ ] paid UI gates match server gates

## Stores

- [ ] Android production-signed AAB
- [ ] Play internal testing install verified
- [ ] Data safety completed from actual data flow
- [ ] account-deletion web URL entered
- [ ] iOS archive and TestFlight build
- [ ] privacy-manifest report reviewed
- [ ] App Privacy completed from actual SDK/data flow
- [ ] support, privacy and terms URLs live
- [ ] screenshots show only shipping features

## Evidence

- [ ] exact commit recorded
- [ ] exact schema version recorded
- [ ] exact API/worker image digests recorded
- [ ] exact store build numbers recorded
- [ ] launch verifier output archived
- [ ] rollback procedure tested

---

# 19. Final recommendation

The codebase does not need another broad architecture rewrite.

It needs:

- a narrower product promise
- five surgical code fixes
- removal of misleading insurance intelligence
- a formal identity-migration lifecycle
- a defined local-source protection contract
- production deployment and store-binary evidence

The fastest credible route is not “finish everything.” It is “make one policy-understanding loop impossible to misunderstand, impossible to cross-contaminate and easy to recover.”

That is the launchable product.
