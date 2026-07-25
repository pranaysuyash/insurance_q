---
name: legal-risk-remediation
version: "2026-07-25"
author: prawn
description: "Use to remediate high-risk legal/financial wording in product surfaces after a legal-risk audit."
---

# legal-risk-remediation

## Core principle
Translate legal-risk audit findings into safe, reviewable copy changes with explicit fallback language, bounded claims, and source-of-truth references.

## When to use
- legal-risk audit found high-severity phrasing in marketing or onboarding
- before shipping claims-related copy that could be interpreted as guarantees
- when policy/billing/deletion language changes in docs, app, and web surfaces

## Required inputs
- audit document path from `docs/legal_risk_*_YYYY-MM-DD.md`
- scope map of impacted surfaces (docs, mobile, web, ARB, screens)

## Process
1. Create a `Remediation Worklist` section in the audit doc (or new doc if needed).
2. Classify each finding by surface:
   - legal boundary / policy support
   - reliability / availability
   - deletion, retention, recovery
   - claims, refunds, eligibility, billing
3. For each high-risk phrase, replace with bounded language:
   - remove absolute promises (`guarantee`, `instant`, `always`, `cannot fail`)
   - remove implied entitlement (`decides`, `approves`, `ensures`, `as-is proof`)
   - require explicit verification wording (`verify with insurer`, `review source document`, `subject to policy text`)
4. Push identical legal meaning to all duplicate legal sources (`docs/legal` and `mobile/assets/legal`) in the same edit pass.
5. Update localized strings for all user-facing legal-bounded labels.
6. Re-run the audit tool once edits are done and capture final risk deltas.

## Output
- `docs/legal_risk_remediation_<date>.md` with:
  - changed path list
  - old/new wording snippets (path:line)
  - residual high-risk findings
  - solo-owner review owner and review date

## Success criteria
- No remaining high-severity claims of guaranteed outcomes or binding authority.
- Legal source-of-trust language matches across docs + assets.
- Deletion/retrieval/claim-related wording explicitly states limits and verification steps.
- Localization paths updated where user-visible legal wording changed.
- No external counsel, ISO program, or enterprise compliance process is required by this skill. Escalate externally only if the solo owner later chooses that path or a distribution partner explicitly requires it.
