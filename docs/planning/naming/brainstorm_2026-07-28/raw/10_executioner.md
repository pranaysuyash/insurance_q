# EXECUTIONER — raw output

**Agent:** subagent (general-purpose)
**Role:** Executioner (kill test)
**Tone:** argues for abandonment; only concedes if it survives
**Status:** complete
**Captured:** 2026-07-28

---

# KILL TEST: The CoverWise Naming Exercise

## The case under test
Not the app. The naming *process*: 16-name slate, 24-entry do-not-repitch ledger, 8-dimension scoring rubric, counsel-clearance gate, a 53KB clearance report, a 63KB voting pack, a 31KB rename strategy doc, a 59KB doctrine doc — all produced in the last 3 days on a product that has never had a paying customer.

---

## KILL ARGUMENT 1 (steelman): Wrong sequencing — the name is downstream of the product, but naming has been installed as the launch gate that blocks shipping

The rename strategy doc (`docs/planning/naming/rename_strategy_and_inventory_2026-07-28.md`, line 358–359) does something load-bearing and almost invisible: it promotes the clearance report's six-point release gate to **"the canonical launch gate for any public release,"** explicitly stating it "supersedes any earlier 'ship under CoverWise' assumption."

This is a priority inversion. The engineering launch-readiness review (`coverwise_launch_readiness_review_2026-07-22.md`) lists eight P0 blockers that have nothing to do with the name: P0-1 Google OAuth silently drops the guest workspace on sign-in (data loss), P0-3 renewal reminders call `show()` not `schedule()` (the feature does not work), P0-6 has no signed Android bundle and no iOS archive, and the backend runs a 13-month-old stale image with no real RevenueCat sandbox ever exercised. Those are the actual launch gate. By decree, the *name* is now the gate, and the bugs are not.

A brand with no product behind it is unvalidatable. You cannot know whether "North & Kin" is memorable until someone tries to remember it while their parent is in the hospital — which requires the Q&A to actually search all documents (it currently queries only the first one, P0-2). Naming a product whose core trust flow is broken is optimizing the variable that does not exist yet at the expense of the variable that does.

**Evidence that would make me concede:** the rename is genuinely cheap and fast, runs in parallel with P0 work, and does *not* block the backend deploy or the signed build. Then sequencing is not the issue — it is just parallelism. (The doc claims the rename is "mechanical" and "low cost now." If that were true, it would not also be the canonical launch gate. It is one or the other.)

## KILL ARGUMENT 2 (steelman): This is avoidance wearing the costume of strategy

The effort signal is lopsided and damning. In the last three days (2026-07-25 to 07-28) the working tree gained four substantial naming/brand artifacts: the 53KB clearance report, the 63KB voting pack, the 31KB rename strategy doc, and a revised 59KB `motto_v4.md`. In the same window, exactly **one** P0-relevant source file was touched (`mobile/lib/screens/qa_screen.dart`). The git log since the readiness review contains two commits that even mention a P0 area (`e55b34e` PolicyExtractionService dio fix, `12738c0` authenticatedDioProvider refactor) — both DI plumbing, neither closing P0-1, P0-3, P0-6, or P0-7.

The shape of the process is the tell. A 16-name slate with a do-not-repitch ledger and an 8-dimension rubric is a high-effort, high-completion-satisfaction, low-exposure activity. It feels like strategy. It produces documents. It has gates and tiers and verdicts (RED/90+). It is, behaviorally, the exact profile of productive procrastination: elaborate enough to feel like real work, detached enough from the scary unglamorous task (rebuilding the signed bundle, fixing the OAuth state machine, replacing the stale image) to never trigger the discomfort that real work triggers.

The founder "explicitly invoked this and wants it thorough." That is not counter-evidence. It is the mechanism. Avoidance is never chosen reluctantly.

**Evidence that would make me concede:** commits closing P0-1 (the OAuth migration state machine), P0-6 (a real signed Android App Bundle + iOS archive against production env), and replacement of the stale backend image, landing in the same week as the naming docs, at equal or greater commit volume. If the naming is happening *alongside* the bugs rather than *instead of* them, the avoidance thesis collapses. Right now it does not collapse.

## KILL ARGUMENT 3 (steelman): Premature optimization for a portfolio that does not exist

The entire doctrine is built on a vision stated once by the founder: *"CoverWise is a set of different products, same and different markets, same industry."* From that single sentence, the naming constraints cascade: the name must (a) be coined/arbitrary for trademark leverage, (b) survive expansion into "warranties, benefits, household risk, B2B distribution," (c) be ownable across Classes 9/36/42 and multiple jurisdictions, (d) avoid the entire "Cover-*" family, (e) pass spoken-referral tests in four Indian languages.

There is currently one product. It has zero users. There is no second product in the repo, no B2B distribution deal in the docs, no investor memo requiring a portfolio entity. The portfolio is a founder aspiration, not a fact. Yet it is being allowed to multiply the difficulty of naming product #1 by roughly an order of magnitude — and, worse, to justify the elaborate multi-round process ("we cannot just pick a name, we must stress-test it across four hypothetical markets").

This is the textbook premature-optimization signature: paying a permanent complexity cost now to preserve flexibility for a future that is not contracted and may never arrive. If product #1 fails to find product-market fit, the entire portfolio-naming exercise was spent naming nothing. If product #1 succeeds, the founder can umbrella it under a portfolio brand at that point — Amazon did not start as a portfolio name, Google did not, Stripe did not. The portfolio layer is cheap to add later; it is expensive to require now, because it makes every candidate fail more gates.

**Evidence that would make me concede:** a concrete, in-flight second product (a repo, a spec, a paying pilot), a signed B2B distribution partner requiring a portfolio structure, or external capital with a term sheet mandating a holding-brand architecture. Absent any of those, the portfolio constraint is optimizing for a fiction.

---

## VERDICT

**THE EXERCISE SURVIVED THE KILL TEST.**

Barely, and for exactly one reason: the CoverSure collision is not a preference, it is a critical near-homophone with a regulated IRDAI competitor in the same country and category, and the cost asymmetry is real and verifiable. RevenueCat product IDs and the application ID cannot be renamed after a first paying customer or published listing; they can be renamed now, mechanically, for free. That single fact — *permanent later, cheap now* — is what keeps the exercise alive. Every other argument points at killing it.

The exercise survives **the rename**. It does not survive **the process**. The 16-name slate, the do-not-repitch ledger, the 8-dimension rubric, the multi-round voting pack, and the promotion of the clearance gate to "canonical launch gate" are the parts that should be killed. They are the avoidance, the premature optimization, and the sequencing inversion wearing the costume of rigor.

---

## CONDITIONS UNDER WHICH IT STAYS ALIVE

1. **Restore the engineering P0 list as the launch gate.** The clearance report's six-point gate is a *release precondition for the name*, not the launch gate for the product. The product launches when P0-1, P0-3, P0-6, P0-7 are closed *and* the name clears. Both must be true; neither subsumes the other.

2. **Time-box the decision to one founder session.** No 16-name slate, no multi-round voting. Pick one name this week — from the existing slate, or coin one. The founder's own #1 ("North & Kin," 88) is already in front of him. Decisiveness is the missing ingredient, not more candidates.

3. **Pair every naming artifact with a P0 fix commit.** Until P0-1 (OAuth migration), P0-6 (signed bundle + iOS archive against prod), and the stale backend image are closed, no new naming doc is produced. If the founder cannot pair them, the naming stops. This is the test that distinguishes parallel work from avoidance.

4. **Drop the portfolio constraint for v1.** Name the app. Decide the portfolio/umbrella brand when product #2 is real. Do not let a hypothetical second product make naming the first one impossible. The rename doc itself (§1) admits the layers were never separated — fix that architectural fact, then the portfolio name is a later one-line decision.

5. **Counsel clearance is the only step worth real calendar time.** Everything else — `sed` across ~100 test imports, asset regen, env var rename, pbxproj edits — is one gated afternoon. The doc says so. Hold the founder to his own claim.

6. **No public release under any name until both gates pass.** Not "rename then ship a broken app." Not "ship under CoverWise then rename." Both the name and the OAuth flow and the signed build must be real before any store submission.

---

## The thing most people miss about this

The rename being "cheap now, permanent later" is true — but the *elaborate process* makes the rename expensive now, which **inverts the economics the whole argument rests on.** A 16-name slate with a scoring rubric and a do-not-repitch ledger and a counsel gate is not a cheap rename; it is a multi-week strategic initiative. The moment the process costs more than the mechanical rename, the "do it now while it's cheap" argument stops supporting the process and only supports the *act*. The cheapness argument is a license to rename quickly; it is being used as a license to deliberate slowly. That is the trap, and the founder is already inside it: the more doctrine, voting packs, and clearance reports accumulate, the more the naming *feels* like the hard important work — when in fact the hard important work is the OAuth state machine and the signed bundle that have not been touched this week. The naming exercise does not need to be abandoned because the name is unimportant; it needs to be abandoned *in its current form* because the form is the procrastination, and the cost-asymmetry argument only rescues the rename if you actually do it cheaply.
