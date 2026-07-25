---
name: legal-risk-audit
description: "Use when reviewing app/product copy for legal exposure (insurance, legal/financial claims, AI guidance disclaimers, billing terms, privacy/deletion wording, and claims-related statements)."
metadata:
  author: prawn
  version: "2026-07-24"
---

# legal-risk-audit

## Core principle
Find and document all user-visible legal-risk wording before editing any product copy. Never assume legal safety from a few screens; audit the full copy surface and any duplicated legal sources.

## When to use
Use this skill for:
- legal/compliance review requests of app copy
- insurance/claims wording audits
- launch readiness checks involving terms, privacy, claims, or billing text
- before adding/modifying any marketing, onboarding, or policy-related microcopy

## Scope to inspect
- `docs/legal/*.md`
- `mobile/assets/legal/*.md`
- `site/**/*.html`
- `src/frontend/templates/**/*.html`
- `mobile/lib/l10n/*.arb`
- `mobile/lib/screens/**/*.dart`
- `mobile/lib/widgets/**/*.dart`

## Search checklist
Run these checks exactly in this order:

1. **Pattern scan (static)**
   - `not an insurer|not a broker|not legal advice|not financial advice|liable|liability|not liable|indemn|refund|cancel|subscription|plan|billing|delete account|delete.*data|delete.*policy|policy document|coverage|claim|claims|AI[- ]generated|may contain errors|verify with insurer|source of truth|as is|no warranty|as-is|unverified|cannot|denied|termination|suspend|restore`
2. **Duplicate authority sources check**
   - Verify whether legal docs exist in both `docs/legal` and `mobile/assets/legal` and whether they differ.
3. **Claim-support wording check**
   - Any phrase implying official coverage, claim entitlement, guaranteed outcome, or legal authority must be tracked.
4. **Billing & entitlement cross-surface check**
   - Confirm every paid/plan/pack entitlement phrase is aligned across ARB, plan screens, and marketing copy.
5. **Deletion & recovery consistency check**
   - Track all “permanent”, “irreversible”, queue/status, and staged-deletion wording.
6. **Operational reliability check**
   - Flag statements implying guaranteed uptime, immediate response, guaranteed parsing/extraction, or certain AI behavior.

## Output format (required)
Produce a markdown artifact with:
- Scope and timestamp
- Full scanned file list
- Heatmap: files by highest-risk count
- Detailed evidence by file with `path:line` snippets
- Category buckets (legal disclaimer / claims guidance / billing / privacy deletion / reliability / AI accuracy)
- Open questions + contradictions (if any)
- Suggested remediation buckets (editorial, legal review, product behavior, localization updates)

## Acceptance before handing off
- No code changes.
- Evidence list must include line references.
- Include all scanned directories even if findings are low density.
- Call out duplicate legal-source drift explicitly.

## Storage convention
Save artifacts under `docs/` with date suffix, e.g.:
- `docs/legal_risk_copy_audit_YYYY-MM-DD.md`
