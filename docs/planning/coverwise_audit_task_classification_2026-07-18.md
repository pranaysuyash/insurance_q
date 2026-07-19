# Audit Task Classification — 2026-07-18 (REVISION 2)

**Updated:** 2026-07-18 (4th audit found; full re-classification)

**Source audits (all from 2026-07-18, total 4):**
1. `docs/audits/policy_detail_screen_audit.md` — **17 tasks** (2 P0 + 6 P1 + 6 P2 + 3 P3)
2. `coverwise_architecture_audit_2026-07-18.docx` — **~70 tasks** (14 P0 + 18 P1 + 30 phased + 22 verification + 10 ADRs)
3. `coverwise_document_intelligence_trust_audit_2026-07-18.md` — **15 P0 + 23 P1 + 7 phases + 6 decisions + 5 evaluation tiers**
4. `coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` — **18 P0 + 38 P1 + 6 phases + 38 tests + 8 release gates**

**Total: ~140+ explicit/implicit tasks across 4 audits.**

**All 4 audits return NO-GO.** They are interlocking: trust's NO-GO depends on evidence not being preserved; security's NO-GO depends on identity/lifecycle not being connected; architecture's NO-GO depends on production paths being durable; the MD audit's NO-GO depends on the screen claiming data the system can't prove.

This is NOT all of them, and the right move is NOT to start working them top-to-bottom. Both **trust Phase 0** and **security Phase 0** are "stop false claims before adding capability" — and the security audit is the bigger Phase 0 (9 items vs 6 in trust).

---

## Bucket 1: Already done (by RevOps R1 or earlier work)

| Task | Source audit(s) | Status |
|---|---|---|
| R1.6: `app_session_started` emission | RevOps R1 | ✅ done today |
| R1.7: `identity_created` + `account_created` | RevOps R1 | ✅ done today |
| R1.8: INSTALL_REFERRER receiver | RevOps R1 | ✅ done today |
| 16 new events in `analytics_schema.dart` | RevOps R1.5 | ✅ done today |
| Analytics dual-write to Supabase | RevOps R1.4 | ✅ done today |
| 9 RevOps tables + `profiles.role` | RevOps R1.1 | ✅ done today |
| 3 dashboard views (DAU, conversion, cohort) | RevOps R1.2 | ✅ done today |
| SQLite → Supabase migration script | RevOps R1.3 | ✅ done today |

**8 of ~140 tasks done.**

---

## Bucket 2: Phase 0 tasks I implemented today (state)

> The trust audit's Phase 0 (6 items) and the security audit's Phase 0 (9 items) overlap and contradict in important ways. **I implemented the trust audit's Phase 0, which is necessary but NOT sufficient.** I missed the security audit's Phase 0 entirely.

| # | Task | Source | Status | Conflicts with security audit? |
|---|---|---|---|---|
| 1 | P0-0.5 Encrypted PDF: implemented unlock (audit said pick one) | Trust P0-0.5 | ✅ done, 3 new tests | No — the security audit does not flag encrypted PDF |
| 2 | P0-0.3 Confidence badge: shows "uncalibrated" when flag off | Trust P0-0.3 | ✅ done | No |
| 3 | P0-0.6 Contextual retrieval: disabled by default | Trust P0-0.6 | ✅ done | No |
| 4 | P0-0.1 + P0-0.2 Document state derivation | Trust P0-0.1 + P0-0.2 | ✅ done, 11 unit tests | **Partial conflict**: security P0-04 says "account deletion reports success" — my fix doesn't address that. But state derivation does help future deletion code be truthful. |
| 5 | P0-0.4 Evidence guard on `PolicySummary` | Trust P0-0.4 | ✅ done, `dart analyze` clean | No — but the security audit's P0-18 says privacy copy also needs to be fixed; this is the same family of "stop lying" work |
| 6 | P0-2.6 Remove unused `context` param from `_QuickActions` | Policy detail | ❌ not done | No |
| 7 | P0-2.7 Migrate 18 hardcoded colors to theme | Policy detail | ❌ not done | No |
| 8 | P0-2.8 Pass 3 review + final report | (motto v3 §0.4.2) | ❌ not done | No |

**4.5 of 8 trust-Phase-0 tasks done; 1 broken-then-fixed; 3 not done.**

**Critical gap: ZERO of the security audit's Phase 0 items is done.** The security audit's Phase 0 has 9 items, all of them customer-facing-false-claim removals:

| # | Security P0 | Severity | One-liner |
|---|---|---|---|
| 1 | P0-07 | Critical | Remove "Copy session token" UI |
| 2 | P0-13 | Critical | Remove/relabel phone backup and account claims |
| 3 | P0-02 / P0-03 | Critical | Rename policy delete to "Remove from this device"; disable Replace |
| 4 | P0-04 | Critical | Return 202 (not 200) on account deletion; never false complete |
| 5 | P0-08 + P0-10 | Critical | Restrict analytics reads to operators; disable optional analytics by default |
| 6 | P0-12 | Critical | Stop raw exception telemetry |
| 7 | P0-18 | Critical | Correct device-first / no-sharing / deletion privacy copy |
| 8 | P0-14 (partial) | Medium | Add Android backup/data-extraction rules |
| 9 | P0-01 (partial) | Medium | Sign-out must switch/lock the local workspace |

The security audit's Phase 0 is **the most consequential Phase 0** because it directly contradicts customer-visible claims that users can be harmed by (the audit explicitly says "the right long-term solution is not to add more disclaimers — it is to establish one canonical principal model, account-scoped local storage, server-side consent, complete data inventory, durable deletion, operator auth, enforced telemetry schemas, etc.").

**My trust-Phase-0 work is necessary but not sufficient.** The operator (Pranay) needs to know this.

---

## Bucket 3: Actionable now (security Phase 0, 9 items)

These are the security audit's Phase 0. They are concrete, well-scoped, and **higher leverage than finishing my trust-Phase-0 work** because they directly affect customer-facing claims and data lifecycle.

| # | Task | Source | Effort | Files |
|---|---|---|---|---|
| 9 | P0-07: Remove "Copy session token" UI action in profile | Security P0-07 | Tiny | `mobile/lib/screens/profile_screen.dart` |
| 10 | P0-13: Remove/relabel phone backup/account claims in `PhoneCaptureSheet` | Security P0-13 | Small | `mobile/lib/widgets/phone_capture_sheet.dart` |
| 11 | P0-02: Rename mobile "Delete policy" copy to "Remove from this device" | Security P0-02 | Small | `mobile/lib/screens/documents_list.dart` and related |
| 12 | P0-03: Disable Replace button until old remote data is handled | Security P0-03 | Small | `mobile/lib/services/document_service.dart` |
| 13 | P0-04: Return `202 deletion_requested` from `DELETE /user/account`; never 200 on partial | Security P0-04 + Arch P0-07 | Small | `src/api/user.py` (already touched) |
| 14 | P0-08: Restrict analytics read endpoints to operator role | Security P0-08 | Small | `src/api/analytics.py` (already touched) — add `require_operator` |
| 15 | P0-10: Disable optional analytics by default; require explicit grant | Security P0-10 | Small | `mobile/lib/services/analytics_service.dart` |
| 16 | P0-12: Stop raw exception telemetry; emit allowlisted error codes only | Security P0-12 | Small | `mobile/lib/widgets/shared/global_error_boundary.dart` |
| 17 | P0-18: Correct device-first, no-sharing, deletion copy on privacy screen | Security P0-18 | Small | `mobile/lib/screens/privacy_security_screen.dart` |

**Subtotal: 9 tasks, ~1 day. All small. The trust audit's P0-0.5 contradiction (encrypted PDF) is the only place where my previous work and this Phase 0 conflict, and the conflict resolves in favor of the security audit (encrypt-PDF is fine; the lying copy is what's wrong).**

### Why this slice first

Per the security audit's own Phase 0 rationale: *"the right long-term solution is not to add more disclaimers."* Removing the lying copy and the token-copy button is **higher leverage** than any further extraction accuracy work, because:

1. The user is currently being told things that are operationally false
2. The token-copy button is the highest-blast-radius issue (a 30-day bearer token in the clipboard)
3. The phone backup claim is a regulatory exposure (false claim about data backup)
4. The "Document deleted successfully" toast is the most common user-facing contradiction

Per **motto v3 §0 (build the best, not the safest small change)**, this is the right move because it's the audit's explicit Phase 0.

---

## Bucket 4: Continue trust-Phase-0 (3 remaining items)

| # | Task | Effort |
|---|---|---|
| 6 | P0-2.6: Remove unused `context` param from `_QuickActions` | Tiny |
| 7 | P0-2.7: Migrate 18 hardcoded colors to theme | Small |
| 8 | P0-2.8: Pass 3 review + final acceptance report per motto v3 §0.4.2 | Tiny |

These can be done after Bucket 3. The colors are dark-mode readiness; the context param is a lint cleanup; the final report is mandatory before commit.

---

## Bucket 5: Needs your decision (architectural choice required)

These are the audit items where the choice is yours, not a code edit.

| # | Audit task | Decision needed |
|---|---|---|
| 18 | Trust Phase 1: Build evidence substrate (page_artifacts, source_spans, extracted_fields, field_evidence) | ✅ Built (commits ecab0ba, 0704eb5, 7a42df8, 7bff4d5) |
| 19 | Arch ADR-03: Durable work queue | ✅ Decision recorded: Supabase outbox (commit 70da5e3, ADR-2026-07-19-01). Migration of 5 existing async paths deferred per ADR-2026-07-19-02. |
| 20 | Arch ADR-06: Embedding model | ✅ Decision recorded: `text-embedding-3-small` default, 30-day benchmark for `voyage-3` (ADR-2026-07-19-03). Benchmark script: `tools/benchmark_embedding_models.py`. |
| 21 | Arch ADR-09: Coverage-gap + claim-assistance | ✅ Thin slice shipped in commit a7166ff; full features deferred per ADR-2026-07-19-04 |
| 22 | Arch ADR-10: Canonical architecture doc location | `docs/CANONICAL_SYSTEM.md` or `docs/planning/coverwise_canonical_architecture_<date>.md` |
| 23 | Security Phase 1: Principal-scoped encrypted local storage | Build now or defer? Affects every Hive box. |
| 24 | Security Phase 2: Server-side append-only consent ledger | Build now or defer? Required for compliance. |

**7 decisions blocking implementation.**

---

## Bucket 6: Multi-day architecture work (needs dedicated sessions + ADRs)

Trust audit Phase 1-6 + Architecture audit Phase B-E + Security audit Phase 1-5. Estimated 60-100 days total. Not actionable this turn.

---

## Bucket 7: Blocked on infrastructure or upstream work

~30 tasks across the four audits. All blocked on either Supabase provisioning, real device testing, or the decisions in Bucket 5.

---

## Recommended sequence (motto v3 §0)

### Now: Security Phase 0 (Bucket 3, 9 tasks, ~1 day)

**The security audit's Phase 0 is the highest-leverage move available.** It directly removes the most-harmful false claims (token copy, phone backup, account deletion lie) and is 1 day of work. The trust audit's Phase 0 (which I partially completed) is necessary but not sufficient.

### After security Phase 0: Finish trust Phase 0 (Bucket 4, 3 tasks, ~1 hour)

- P0-2.6 unused context param
- P0-2.7 color migration
- P0-2.8 Pass 3 review

### After both: Decisions in Bucket 5

The 7 decisions are required for any Bucket 6 work. The operator (Pranay) must make them before any multi-day refactor.

### What I am NOT recommending this turn

- Multi-day rewrites of Phase 1+ evidence substrate, principal-scoped local storage, etc.
- Polishing the policy detail screen in isolation (the security audit's P0-18 says privacy copy is false, which is upstream of polish)
- Starting Phase 6 evaluation rebuild (it's the most valuable long-term work but LAST phase, not first)

---

## Update from previous version of this doc

- **Revision 1:** Based on 3 audits (missed the security one). Recommended the trust audit's Phase 0.
- **Revision 2 (this version):** Found the 4th audit. The trust Phase 0 is necessary but not sufficient. The security audit's Phase 0 is the higher-leverage move. **My implementation choice in the previous turn was correct given what I knew, but I did not know enough.** I should have asked "are there other audits from today" before committing to a slice.

This is a motto v3 §0.7 (AI output boundary) and §0.4 (acceptance contract) failure on my part: I verified 3 audits and assumed the work was scoped, when the operator's "all of them" was the unverified scope. The recovery is to (a) re-verify the full set, (b) re-rank, (c) execute the new ranking.

---

## What I will do next

Per the operator's "all of them":

1. **Fix the broken `CoverWiseIconBadge` usage in `policy_detail_screen.dart`** — done this turn
2. **Execute the security audit's Phase 0** (9 small tasks, ~1 day) — start with the highest-blast-radius items
3. **Then finish the trust-Phase-0 tail** (3 small tasks, ~1 hour)
4. **Then write the Pass 3 review** (motto v3 §0.4.2) — final acceptance contract

If the operator wants a different order, they can interrupt and say so.
