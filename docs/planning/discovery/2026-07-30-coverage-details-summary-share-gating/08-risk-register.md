# 08 — Risk Register

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc H (Part 0)** — risks identified during Part 0
**Author:** session-init agent
**Date:** 2026-07-30

---

## Reading guide

For each risk:

- **Type** — product / user / architecture / data / security / privacy / reliability / performance / accessibility / operational / dependency / migration / regression / scope / delivery
- **Cause** — root pattern
- **Likelihood** — Low / Medium / High (with magnitude qualifier if useful)
- **Impact** — what breaks
- **Severity** — Blocker / Critical / High / Medium / Low / Informational
- **Detection** — how we would notice
- **Mitigation** — what reduces the chance or impact
- **Contingency** — what to do if it materialises
- **Owner** — who tracks it
- **Status** — Active / Mitigated / Accepted / Deferred / Closed

---

## R-1 — Auth_service.dart compile block persists, share-gate verification remains uncompletable

- **Type:** Delivery + Dependency
- **Cause:** Parallel-agent refactor on `mobile/lib/services/auth_service.dart` introduces a `createdAt` type mismatch (lines 302→303, comment shifted between runs). Visible diff shows the fix (defensive parse) is in their working set but not landed at the cited line.
- **Likelihood:** High (evidence: line-movement confirms active editing; no landing observed during this session's poll cycles).
- **Impact:** Cannot complete WS-1 of the approved execution brief. The 6 share-gate test cases stay unverified.
- **Severity:** **Blocker** for evidence tier (cannot reach Tier 2).
- **Detection:** `flutter test ...` compile error present; no movement over multiple poll cycles.
- **Mitigation:** Pause per §23 hold; do not patch contested file; allow parallel-agent's diff to land.
- **Contingency:** If refactor stalls >24 hours, ask operator to either (a) escalate ownership of the contested files for this session, or (b) accept the workstream as "verified by static inspection, Tier 1 only" and document the gap.
- **Owner:** Operator (decides escalation); parallel-agent session (lands the fix).
- **Status:** **Active, paused.**

## R-2 — Substring test contract silently drifts

- **Type:** Regression (testing brittleness)
- **Cause:** Test 1 uses `find.textContaining('Export is available on Plus')`; if the canonical gate-reason copy drifts in a way that still contains the substring, the test passes while user-visible messaging changed.
- **Likelihood:** Low (the canonical copy lives in one place; drift is rare).
- **Impact:** Future copy edits could ship without test signal.
- **Severity:** Low.
- **Detection:** Manual review during voice/copy iterations, or a launch-claim registry audit.
- **Mitigation:** If drift becomes a real risk, tighten to exact match or add a `Key` on the snackbar message widget.
- **Contingency:** Tighten the assertion if/when a real-world drift happens.
- **Owner:** Future copy-quality session.
- **Status:** **Accepted** — current contract is by design.

## R-3 — Out-of-scope file accidentally edited

- **Type:** Regression / Local-work preservation
- **Cause:** Temptation to fix the auth_service.dart compile block by patching the line; the in-flight refactor and motto §23 forbid it.
- **Likelihood:** Low (the plan and MANIFEST both say "do not touch contested files").
- **Impact:** Could conflict with the parallel agent's work, cause merge conflicts, or violate §23.
- **Severity:** Medium (would require reverting edits and apologies).
- **Detection:** `git status -s` and `git diff --stat` after every tool call.
- **Mitigation:** Hard edit boundary per plan §8.22 ("Safeguards"). Per-edit pre/post `git status -s` check.
- **Contingency:** If accidentally modified, revert immediately via `git checkout -- <file>` (with operator approval per motto §3).
- **Owner:** session-init agent (continuous vigilance).
- **Status:** **Mitigated by discipline.**

## R-4 — Scope expansion into screen refactor

- **Type:** Scope
- **Cause:** `CoverageDetailsSummaryScreen` is a god-object (935 lines). Tempting to refactor while already working with it.
- **Likelihood:** Low (the plan §8.13 explicitly forbids; plan §8.18 self-critic covers it).
- **Impact:** Would balloon scope, conflict with parallel refactor if the parallel agent also touches the screen, and bloat the diff.
- **Severity:** Medium.
- **Detection:** New file changes outside the WS-1/WS-2 trio.
- **Mitigation:** plan §8.5 explicit exclusions. Self-critic on every workstream.
- **Contingency:** Revert and reaffirm scope.
- **Owner:** session-init agent.
- **Status:** **Mitigated by plan.**

## R-5 — Constitution sign-off drift during execution

- **Type:** Doctrine / authority
- **Cause:** Operator signs off ADR-2026-07-29-02 during this session (low-probability) or after (medium-probability). Constitution's binding status changes.
- **Likelihood:** Low during a single session (docs don't update mid-flight).
- **Impact:** If status flips, workstream's gate classifications could be tightened; not a defect.
- **Severity:** Low.
- **Detection:** Future re-read of the ADR's Update Log.
- **Mitigation:** Treat as *Proposed* throughout; re-classify in future sessions if sign-off lands.
- **Contingency:** None needed.
- **Owner:** Operator.
- **Status:** **Accepted** (low risk).

## R-6 — Test infrastructure failure (Hive/HiveTestHelper regresses)

- **Type:** Reliability
- **Cause:** The test under examination does not directly invoke `HiveTestHelper` for the share-gate tier assertions, but `setUpAll` does. If Hive init regresses, the test would fail for infrastructure reasons, not behavioral ones.
- **Likelihood:** Low (HiveTestHelper is a stable shared utility).
- **Impact:** Test failure could be misread as product regression.
- **Severity:** Low.
- **Detection:** Error traceback would point at Hive init, not at the share-gate trio.
- **Mitigation:** Run `mobile/test/entitlement_test.dart` and `mobile/test/coverwise_snackbar_test.dart` together for infrastructure baseline once compile clears.
- **Contingency:** If infrastructure regresses, treat as a separate pre-existing issue per motto §6 (fix in same pass).
- **Owner:** session-init agent + future test infra owner.
- **Status:** **Accepted** (low risk; gated on R-1 clearing).

## R-7 — `find.text('Upgrade')` finds or fails to find the snackbar action label

- **Type:** Testing brittleness (UI)
- **Cause:** The snackbar widget tree may render the action label inside a `TextButton` whose internal semantics label might or might not surface to `find.text`. Or the snackbar builder may render the label inside a structure that does not yield a plain `Text` widget at the top of the tree.
- **Likelihood:** Medium-low (depends on CoverWiseSnackBar implementation). I have not yet verified the exact snackbar widget tree.
- **Impact:** Test 1 could pass on positive assertions but fail on `expect(find.text('Upgrade'), findsOneWidget)`.
- **Severity:** Would-be blocker if it materialises, but currently unobserved (we can't run the test).
- **Detection:** Test 1's exact-match assertion on `'Upgrade'`.
- **Mitigation:** If it fails, *inspect* `CoverWiseSnackBar.warning` rendering. If the action label is rendered inside a non-Text wrapper, wrap the action label with a `Key('upgrade-action-label')` and update the test to use `find.byKey(Key('upgrade-action-label'))`.
- **Contingency:** Document the diagnosis and apply the smallest fix in WS-2.
- **Owner:** session-init agent (in WS-2 if R-1 clears and R-7 materialises).
- **Status:** **Latent** (depends on R-1 clearing).

## R-8 — Voice/copy consistency during copy edits

- **Type:** Product
- **Cause:** Any edit to gate-reason copy must align with `DESIGN.md` voice: "Direct, honest, technical but accessible, conservative."
- **Likelihood:** Out-of-scope — no copy edits in this workstream.
- **Severity:** Not applicable.
- **Status:** **Accepted** (no edits planned).

## R-9 — Dependency churn (`pubspec.yaml` / `pubspec.lock` mid-edit)

- **Type:** Dependency
- **Cause:** Parallel-agent work includes 4 line insertions to `pubspec.yaml` and 6 changes to `pubspec.lock`. We do not need to depend on those changes.
- **Likelihood:** Low (we don't add deps in this workstream).
- **Severity:** Informational.
- **Mitigation:** Lockfile updates don't affect test execution for the share-gate trio.
- **Status:** **Accepted.**

## R-10 — Commit timing: no commit required by the plan, but operator may follow up

- **Type:** Delivery
- **Cause:** Plan §8 explicitly says no commit. If operator later asks for a commit, it should be reviewed per the plan's no-co-author-trailer rule (motto §20).
- **Likelihood:** High that operator will eventually ask for commit on the bundle/docs findings.
- **Severity:** Informational.
- **Mitigation:** When asked, prepare commit message without AI co-author trailer, group files by concern per motto §8.
- **Status:** **Accepted.**

---

## Risk summary

| Risk | Severity | Status |
|---|---|---|
| R-1 Compile block | Blocker | Active, paused per §23 |
| R-2 Substring drift | Low | Accepted (by design) |
| R-3 Out-of-scope edit | Medium | Mitigated by discipline |
| R-4 Scope expansion | Medium | Mitigated by plan |
| R-5 Constitution drift | Low | Accepted |
| R-6 Test infra failure | Low | Accepted (gated) |
| R-7 Snackbar action find | Latent | Pending observation |
| R-8 Voice/copy | n/a | Accepted (no edits) |
| R-9 Dep churn | Informational | Accepted |
| R-10 Commit timing | Informational | Accepted |

## Anything else? (motto §0.1.1)

R-1 is the dominant risk and the only one that prevents completion. R-7 is a latent companion risk that may surface the moment R-1 clears. Together they form the workstream's actionable risk surface. The remaining eight risks are housekeeping and discipline — present for completeness, not for action in this session.
