# Legal Risk Remediation Priority Pack

Date: 2026-07-25

Status: Documentation-only follow-up (no product changes applied yet).

Goal: convert the audit inventory into a prioritized sequence of fixes, while preserving reviewability and limiting downstream legal risk.

## Priority 1 — Legal/insurer-role and advice-boundary risk (fix first)
These statements are highest risk because they define the legal position of the product.

1. Align all role/positioning copy across legal + app + web:
   - Non-insurer / non-adviser / non-broker disclaimers
   - Explicit statement that insurer/policy is source of truth for binding decisions
   - AI answer limitation language
   - Claims/coverage determination boundaries

Key files to verify line-level consistency:
- `docs/legal/terms_of_service.md`
- `docs/legal/privacy_policy.md`
- `mobile/assets/legal/terms_of_service.md`
- `mobile/assets/legal/privacy_policy.md`
- `src/frontend/templates/index.html`
- `src/frontend/templates/landing.html`
- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_hi.arb`
- `mobile/lib/screens/privacy_policy_screen.dart`
- `mobile/lib/screens/terms_of_service_screen.dart`
- `mobile/lib/screens/about_screen.dart`

2. Ensure claims language does not imply legal determination/guarantees:
   - Claims assistant/tracking screens should frame support guidance as informational only
   - Avoid phrasing that can be interpreted as an official claim filing/completion outcome

Key files to verify:
- `mobile/lib/screens/claim_assistance_screen.dart`
- `mobile/lib/screens/claim_tracking_screen.dart`
- `mobile/lib/screens/claims_assistant_screen.dart`
- `mobile/lib/widgets/claims_workflow_sheet.dart`
- `mobile/lib/widgets/claims/claim_status_timeline.dart`
- `mobile/lib/widgets/policy_comparison_sheet.dart`

## Priority 2 — Billing, questions entitlement, and purchase/pack expectations
Any mismatch here can create regulator/customer complaints around unfair trade practices and deceptive UX.

1. Verify all paid-usage communication is consistent:
   - “No subscription / subscription needed” style claims
   - Pack rollover/fallback behavior
   - Restoration / cancellation expectations
   - Availability of features with unpaid state

Key files:
- `mobile/lib/screens/upgrade_screen.dart`
- `mobile/lib/screens/qa_packs_screen.dart`
- `mobile/lib/screens/paywall_screen.dart`
- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/screens/profile_screen.dart`
- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_hi.arb`
- `mobile/lib/screens/qa_screen.dart`

2. Check marketing copy that implies entitlement state without clear conditions:
- `src/frontend/templates/index.html`
- `src/frontend/templates/landing.html`
- `site/index.html`
- `site/terms.html`

## Priority 3 — Privacy, deletion, and retention precision
Critical for data-rights, auditability, and trust.

1. Account/data deletion messaging should match actual system behavior:
   - Distinguish local vs server deletion clearly
   - Clarify irreversible or staged statuses precisely
   - Avoid mixing “removed”, “queued”, and “complete” without explicit state semantics

Key files:
- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_hi.arb`
- `mobile/lib/screens/profile_screen.dart`
- `mobile/lib/screens/account_screen.dart`
- `docs/legal/privacy_policy.md`
- `docs/legal/terms_of_service.md`
- `mobile/assets/legal/privacy_policy.md`
- `mobile/assets/legal/terms_of_service.md`

2. Verify consent and data handling statements in all user touchpoints:
- `mobile/lib/screens/processing_status_screen.dart`
- `mobile/lib/screens/notification_preferences_screen.dart`
- `mobile/lib/screens/settings_screen.dart`
- `site/privacy.html`

## Priority 4 — AI accuracy / reliability / source verification
These are medium-high legal-product risk if wording suggests certainty.

1. Keep all AI outputs consistently labeled as assistance only.
2. Keep every important claim tied to source doc verification where possible.
3. Ensure errors and fallback behavior messaging is not minimized.

Key files:
- `mobile/lib/screens/qa_screen.dart`
- `mobile/lib/widgets/field_citations_card.dart`
- `mobile/lib/widgets/answer_verification_badge.dart`
- `mobile/lib/widgets/shared/global_error_boundary.dart`
- `mobile/lib/widgets/shared/screen_error_boundary.dart`
- `mobile/lib/screens/insights_screen.dart`
- `site/privacy.html`

## Priority 5 — Emergency/urgency claims and operational readiness statements
Any “always available / at the exact moment” phrasing should be bounded by app behavior.

Key files:
- `mobile/lib/screens/emergency_screen.dart`
- `mobile/lib/screens/renewal_calendar_screen.dart`
- `mobile/lib/screens/insurance_card_screen.dart`
- `mobile/lib/screens/coverage_gap_screen.dart`
- `mobile/lib/screens/what_if_calculator_screen.dart`

## Remediation workflow (safe, non-code first)
1. Freeze canonical legal copy set
- Decide whether `docs/legal/*` is canonical, and keep `mobile/assets/legal/*` as generated mirror only.
- If divergence is intentional, document reasoned precedence in `docs/`.

2. Create phrase-level change log
- Track each changed sentence with old/new copy and rationale.
- Include legal/comms owner approval in the change note.

3. Enforce copy guardrails
- Add a lightweight regex/lint check during review (manual is fine initially) for high-risk phrases:
  - `guarantee`, `always correct`, `official`, `we will`, `claims are covered`, `we determine`
  - `no risk` / `always accepted` / `never` + legal verbs
- Validate all entitlement terms across UI, ARB, and legal docs.

4. Re-run this legal-risk-audit skill after edits
- Reconcile with pre-existing scan list in `docs/legal_risk_copy_audit_2026-07-24.md`.

## Suggested sequencing
- Week 1: Fix Priority 1 and legal/source consistency.
- Week 2: Fix Priority 2 wording alignment + billing state clarifications.
- Week 3: Update delete/privacy strings and state transitions.
- Week 4: Reduce reliability overclaims, add QA proof check.

## Open questions to resolve before copy edits
- Is `docs/legal/*` the immutable source for legal terms, or should `mobile/assets/legal/*` remain separately versioned?
- Are current backend guarantees aligned with any onboarding or template claims around immediacy/coverage readiness?
- Who should sign off each category before release: owner is primary, with optional legal counsel engagement if you choose it for extra assurance.
