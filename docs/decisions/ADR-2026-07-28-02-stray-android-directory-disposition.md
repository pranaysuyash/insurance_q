# ADR-2026-07-28-02: Delete the stray top-level `android/` directory; the canonical Android project is `mobile/android/`

**Format:** Per `motto_v4.md` §0.12 (Decision Record Requirement) and §0.12.1 (Update Log rule). Decisions-first per §0.12.2 — ADR lands before execution. Supersession/canonical-path authority per §7. Single-source-of-truth per §13 / §11.

- **Decision:** The top-level `android/` directory is **deleted entirely** (both the historically-tracked `android/key.properties` and the `android/key.properties.example` I added to it on 2026-07-28). The canonical Android project is `mobile/android/`, which is already correctly configured. No replacement is created because none is needed — the real project was already clean before this session.
- **Date:** 2026-07-28
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Proposed → operator-approved inline** ("so do all now, same rules apply"). Operator instructed execution under the same doctrine (long-term, first-principles, motto_v4, documented). Recorded as Accepted per §0.12.1; the operator's instruction is quoted in the Update log.
- **Related artifacts:** `docs/audits/coverwise_overlooked_risks_round2_2026-07-28.md` (G-1 retraction to be corrected against this ADR), `mobile/android/app/build.gradle.kts:14` (the canonical-path evidence), `mobile/android/.gitignore:12` (the correct ignore rule), `mobile/android/key.properties.example` (the correct, pre-existing example).

---

## Update log

- **2026-07-28 (original):** Initial proposal. During the G-1 retraction work it emerged that the `key.properties` I had untracked lived in a stray top-level `android/` directory that is not the canonical Android project, and that the real project at `mobile/android/` was already correctly configured (key.properties ignored, .example present). The honest disposition is: delete the stray directory entirely, restore nothing, because the canonical path already has the right shape. Status: Proposed.
- **2026-07-28 (operator instruction, Accepted):** Operator said "so do all now, same rules apply - long term 1st principle, motto_v4, documented." This is sign-off to execute the deletion under doctrine, not a minimal-patch instruction. Status: **Accepted.** Execution proceeds in dependency order: revert my staged change → delete stray dir → correct the G-1 audit retraction → acceptance report.

---

## Context

### How the stray directory arose

The repository contains two `android/`-named paths:

1. **`mobile/android/`** — the real Flutter Android project. Full scaffold: `app/`, `gradle/`, `build.gradle.kts`, `settings.gradle.kts`, `gradlew`, `AndroidManifest.xml` under `app/src/main/`. This is what `flutter build apk` reads.
2. **`android/`** (top-level, repo root) — contains exactly two files: `key.properties` (committed by accident in `b736fca` / `d050f28`, the "APK distribution" commits) and `key.properties.example` (added by me on 2026-07-28 in error). **No build files, no manifest, no `app/`, no `gradle/`. It is not an Android project.** It is a husk created when a Gradle/Flutter command was run from the repo root and a file landed in the wrong place.

### Evidence the top-level `android/` is non-canonical and unread

- `mobile/android/app/build.gradle.kts:14`: `val keystorePropertiesFile = rootProject.file("key.properties")`. `rootProject` from `app/build.gradle.kts` resolves to `mobile/android/`, **not** the repo root. The build never reads `android/key.properties`.
- `grep` across `*.sh`, `*.yml`, `.github/workflows/`, `tools/`, and the Gradle files for any reference to the top-level `android/` path: **zero references.** Nothing points at it.
- The stray `key.properties` content is `storePassword=android / keyPassword=android / keyAlias=upload` — the documented Flutter debug-keystore defaults. It carries no real credential.
- The canonical `mobile/android/key.properties` is correctly ignored by `mobile/android/.gitignore:12` (`key.properties`) and is not tracked. The canonical `mobile/android/key.properties.example` already exists (pre-this-session) and is the example developers actually need.

### What I did wrong on 2026-07-28

1. I untracked `android/key.properties` (`git rm --cached`) and treated this as a "hygiene fix."
2. I created `android/key.properties.example` next to it.
3. I recorded both as a completed fix in the round-2 audit's G-1 retraction.

All three were aimed at the **wrong directory**. The canonical project was already correctly configured and I did not verify the canonical path before acting. The "fix" was inert: it touched a husk nothing reads, and the real project was already clean.

### Why this is a doctrine decision, not just file cleanup

This is not "delete a junk file." Two motto_v4 clauses make the disposition a recorded decision:

- **§7 (Supersession / Canonical Replacement):** "do not keep two editable sources of truth." The top-level `android/` is a parallel, non-canonical truth-source for "where the Android signing config lives." Even though nothing reads it, its presence in the tree is a trap for the next agent or contributor (including, demonstrably, me this session) who assumes `android/` at the repo root is the Android project.
- **§13 / §11 (no duplicate or parallel implementations):** one canonical Android project. The stray directory is a duplicate-path smell that has already caused one real misdiagnosis (G-1).

Per §6 ("pre-existing" is not an excuse) and §21 (Code Is Evidence — when a decision changes, the refactor is in scope), the existence of the stray dir predating me does not authorize leaving it. But per §4 (Local Work Preservation) and §6.1, deleting something I did not create requires the disposition to be a recorded, operator-approved decision. This ADR is that record.

---

## Options considered

### Option A: Delete the stray `android/` entirely. CHOSEN.

- **How:** revert my staged `git rm --cached android/key.properties` (so the index is clean), then delete the top-level `android/` directory and its two files. No replacement. The canonical `mobile/android/` is untouched.
- **Why chosen:** the canonical project is already correct; the stray directory is a non-canonical duplicate path that has already caused one misdiagnosis; deleting it is the §7/§13 disposition. Restoring the stray file to tracking (Option B) would preserve a known trap for no benefit.
- **Cost:** none beyond the deletion. No build, no migration, no test impact (nothing reads the path).

### Option B: Restore the stray `key.properties` to tracking; delete only my `.example`. (Full revert to pre-session state.)

- **How:** `git restore --staged android/key.properties` and `rm android/key.properties.example`. Leave the stray dir exactly as I found it.
- **Why rejected:** leaves a known non-canonical duplicate path in the tree. Contradicts §7 (do not keep two truth sources) and §6 ("pre-existing" is not an excuse to leave a problem). The operator's instruction ("long term 1st principle, motto_v4") explicitly asks for the doctrine-aligned outcome, not the minimal-restore outcome.

### Option C: Keep the stray dir; add a README explaining it is unused.

- **Why rejected:** documentation of a known-wrong path is worse than removing it. Adds a third artifact to maintain and still leaves the trap. §11 ("prefer simplification, consolidation, and canonical ownership over adding more layers").

---

## The contract

1. **Revert my staged change.** `git restore --staged android/key.properties` so the index no longer holds the staged deletion. (The file returns to tracked state, as it was before this session.)
2. **Delete the top-level `android/` directory.** `rm -rf android/`. This removes both the historically-tracked `android/key.properties` and my erroneous `android/key.properties.example`.
3. **Stage the deletion of `android/key.properties`** as part of this decision (it is now a tracked-file deletion, intentional and ADR-backed, distinct from my earlier mistaken untrack).
4. **Do not touch `mobile/android/` at all.** It is the canonical project and was already correct.
5. **Correct the round-2 audit G-1 retraction** so the audit record matches reality: G-1 retracted (no real secret), AND no fix was needed or correctly applied by me (the real project was already clean), AND the stray dir is deleted per this ADR.
6. **No commit without operator approval** (motto_v4 §3, §17). Execution here means: stage the changes in the working tree, produce the acceptance report, and hand off for the operator's commit decision.

---

## Why this path

### Canonical-path argument (§7, §13)

There is exactly one Android project: `mobile/android/`. The build resolves `key.properties` there (`build.gradle.kts:14`). Maintaining a second `android/` at the repo root is a parallel truth-source for signing-config location. §7 is explicit: do not keep two editable sources of truth; migrate to the canonical path. Here the "migration" is recognition that the canonical path already has everything and the duplicate is empty.

### Anti-trap argument (§6, §21)

The stray directory already caused a real failure this session: I assumed `android/key.properties` was the signing config the build uses and wrote a finding + a "fix" against it. A future agent or contributor will hit the same assumption. Leaving the trap in place because "it's pre-existing" is exactly what §6 forbids. Deleting it removes the failure mode at its root.

### First-principles argument

The signing-config file belongs next to the build that reads it. The build is in `mobile/android/`. Therefore the file belongs in `mobile/android/`. A copy at the repo root has no first-principles justification — it exists only because a command was once run from the wrong directory. First-principles cleanup removes artifacts that have no reason to exist.

### Whole-answer argument (§0.0.1)

The whole answer is not "untrack the file" (my earlier wrong action) and not "restore the file" (Option B, which preserves the trap). The whole answer is "remove the duplicate path so the canonical path is unambiguous." That is what this ADR does.

---

## Tradeoffs

- **A historically-tracked file is deleted.** `android/key.properties` has been in the tree since `b736fca`. Deleting it is a tracked-file deletion, recorded in history. Mitigation: the file is junk (debug defaults, unread by the build); git history preserves it forever; this ADR records why it was removed.
- **If some out-of-tree tooling ever expected `android/key.properties` at the repo root, it breaks.** Mitigation: grep found zero references to the top-level `android/` path in any script, workflow, or build file. The risk is theoretical, not demonstrated.
- **The deletion mixes "my mistake" with "pre-existing junk" in one commit.** Mitigation: this ADR separates them in the record. The commit message (when the operator authorizes it) should reference this ADR.

---

## Assumptions

- **The canonical Android project is `mobile/android/`.** Verified: `build.gradle.kts:14` resolves there; the full Flutter scaffold is present; `flutter build apk` uses it. Evidence tier 1 (static).
- **Nothing reads the top-level `android/`.** Verified: zero grep hits across scripts, workflows, build files. Evidence tier 1. To reach tier 3 (integration) the operator could run a release build before and after the deletion and confirm identical behavior — recommended at commit time.
- **The stray `key.properties` carries no real credential.** Verified: content is the Flutter debug defaults (`android`/`android`). Evidence tier 1.

---

## Risks

- **An out-of-tree process depends on the stray path.** Mitigation: none found in-repo; operator can confirm by running a build after deletion.
- **Operator wanted the file restored rather than deleted.** Mitigation: this ADR makes the choice explicit; the operator's "do all now, same rules apply" is interpreted as doctrine-aligned (delete), but the operator can override by saying "restore instead" before commit.
- **Future confusion about why `android/key.properties` was tracked then removed.** Mitigation: this ADR + a commit message referencing it.

---

## Validation plan

Per §0.6, this is a low-risk change (deletion of an unread file), so the verification bar is proportionate:

- **Tier 1 (static, done):** canonical-path proof (`build.gradle.kts:14`), zero-references grep, file-content inspection. All recorded above.
- **Tier 3 (integration, recommended at commit time):** operator runs `cd mobile && flutter build apk --release` (with `COVERWISE_RELEASE_BUILD` unset, so it falls back to debug signing) before and after the deletion and confirms the build is unaffected. This is the one check that elevates "nothing references it" to "nothing breaks."

---

## Rollback path

Fully reversible: the deleted `android/key.properties` is recoverable from git history (`git show b736fca:android/key.properties`) and the directory can be recreated. No data loss is possible.

---

## What would cause this decision to be revisited

- **A tool or workflow is discovered that reads `android/key.properties` at the repo root.** Then either the tool is fixed to point at `mobile/android/` (canonical), or — only if the tool cannot be changed — the stray path is restored with a documented reason. Either way, the canonical path stays `mobile/android/`.
- **The Flutter project is re-rooted** (e.g. `mobile/` is flattened to the repo root). Then `android/` at the root *becomes* canonical and this ADR is superseded by a re-rooting ADR.

---

## Anything else? (standing review prompt, §0.1.1)

Two cross-cutting notes:

1. **The G-1 retraction in the round-2 audit must be corrected in the same pass as this ADR** (§0.3 documentation continuity; §0.4 acceptance contract). The current retraction text says "hygiene fix applied: untrack key.properties, add key.properties.example." That is wrong — the "fix" targeted the wrong directory and is now being deleted. The retraction must read: G-1 retracted (no real secret); no fix was needed because the canonical project was already clean; my attempted fix was misdirected and is reverted+superseded by this ADR. This is recorded as a todo and executed in the same pass.

2. **The lesson for the audit process, recorded permanently.** The G-1 failure and this ADR share a root cause: **acting on a file path without verifying it is the canonical path the build/runtime reads.** The corrective, added to my standing method for any future security/build claim: before recommending action on a file, prove (with a command) that the relevant build/runtime resolves to that path. This is the §1.1 (Source-of-Truth) and §0.2 (Confidence Honesty) discipline applied to path claims, and it is the specific trust-rebuilding behavior the operator demanded.

---

## Links

- **Affected files:**
  - `android/` (top-level directory) — **deleted** by this ADR
  - `android/key.properties` — historically tracked, deleted
  - `android/key.properties.example` — my erroneous addition, deleted
  - `docs/audits/coverwise_overlooked_risks_round2_2026-07-28.md` — G-1 retraction corrected against this ADR
- **Canonical (untouched):**
  - `mobile/android/` — the real Android project
  - `mobile/android/key.properties` — correctly gitignored, untracked, the file the build reads
  - `mobile/android/key.properties.example` — the correct example, pre-existing
  - `mobile/android/.gitignore:12` — the correct ignore rule
- **Evidence:**
  - `mobile/android/app/build.gradle.kts:14` — canonical-path proof
  - `b736fca`, `d050f28` — commits that accidentally added the stray file
- **Motto v4 alignment:** §0.0.1 (whole-answer mandate), §0.1.1 (anything-else prompt — answered), §0.2/§1.1 (confidence honesty + source-of-truth: verify canonical path before acting), §0.3 (documentation continuity), §0.4 (acceptance contract), §0.12.1 (update-log rule), §0.12.2 (ADR-first), §4 (local-work preservation — operator approval recorded), §6/§6.1 (pre-existing not an excuse; in blast radius), §7 (supersession/canonical), §11/§13 (single source of truth, no parallel paths), §21 (refactor is part of the decision deliverable).
