# Legal-risk remediation record - 2026-07-25

## Scope and evidence boundary

This record documents the second remediation pass after the copy audit in `docs/legal_risk_copy_audit_2026-07-24.md` and the priority list in `docs/legal_risk_remediation_priority_2026-07-25.md`.

Evidence level for this pass: Tier 1, static inspection and copy review. These edits are for the solo product owner and AI-agent workflow; they are not an external legal opinion, insurer approval, production security attestation, store review, or runtime deletion proof.

The edits reduce wording risk. They do not establish that the product is legally compliant, that a claim is covered, that a deletion request is complete, or that a security control works in production.

## Changes made

### 1. Insurance card and proof-of-cover boundary

- `mobile/lib/screens/insurance_card_screen.dart`
  - Changed the class description from a digital proof-of-insurance card to a policy quick-reference card.
  - Documented that the shareable output is not insurer-issued proof of cover.
- `mobile/lib/screens/more_screen.dart`
  - Changed "Keep digital proof of cover close" to "Keep policy details close for reference".
- `mobile/lib/l10n/app_en.arb`
  - Changed the header to "Your policy details, ready to carry".
  - Changed the share title to "CoverWise policy reference".
- `mobile/lib/l10n/app_hi.arb`
  - Applied the equivalent Hindi wording.
- `mobile/lib/l10n/app_localizations_gen_en.dart`
- `mobile/lib/l10n/app_localizations_gen_hi.dart`
- `mobile/lib/localization/app_localizations.dart`
  - Kept generated and legacy localization values aligned with the source wording.

Reason: an app-generated summary can be mistaken for an insurer-issued certificate or proof of entitlement. The new wording describes the actual product role and keeps verification with the insurer and source policy document.

### 2. Renewal and availability claims

- `site/index.html`
  - Changed "No more reading 40-page policy documents alone" to a time-saving description without an absolute promise.
  - Changed "Never miss a renewal" to "Keep renewals in view".
  - Changed the offline statement from all information being available offline to selected information being available when saved locally.
- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_hi.arb`
- `mobile/lib/l10n/app_localizations_gen_en.dart`
- `mobile/lib/l10n/app_localizations_gen_hi.dart`
- `mobile/lib/localization/app_localizations.dart`
  - Changed the renewal heading from an outcome guarantee to a monitoring description.
  - Changed "Get reminders" to "Set reminders" so the copy does not promise successful delivery.

Reason: notification delivery, permission state, device settings, expiry extraction, offline state, and platform scheduling can prevent an outcome even when the feature is enabled.

### 3. Privacy and security wording

- `mobile/lib/widgets/lead_capture_dialog.dart`
  - Removed the unqualified "securely store" wording from the processing-consent explanation.
  - Replaced the device-only contact promise with a Privacy Policy reference.
  - Changed "I agree to secure policy processing" to "I agree to policy processing".
- `mobile/lib/widgets/shared/newsletter_signup_sheet.dart`
  - Removed the absolute "stays on this device and is never shared" promise.
  - Referred to newsletter use and the Privacy Policy instead.
- `mobile/lib/widgets/shared/agent_request_sheet.dart`
  - Removed the absolute policy-data "never shared" promise.
  - Kept the explicit name/phone sharing disclosure and referred users to the Privacy Policy for policy-data processing.
- `mobile/lib/widgets/dashboard/first_upload_cta.dart`
  - Removed "always available" and unqualified "securely" promises.
  - Described workspace availability and server processing more narrowly.
- `mobile/lib/screens/processing_status_screen.dart`
  - Changed "Document saved securely" to "Document received".
- `mobile/lib/services/document_service.dart`
  - Removed "securely" from save-failure messages so an error message does not make a security guarantee.
- `src/frontend/templates/index.html`
  - Changed "it always defers" to the bounded statement that the app defers to the policy document and insurer.
  - Changed "Offline-ready details" to "Saved details when offline".
- `src/frontend/templates/landing.html`
  - Changed the metadata description from "preliminary claims guidance" to finding claim-process details in policy documents.

Reason: privacy, confidentiality, security, offline availability, and retention claims must match the actual data flow and the applicable Privacy Policy. Absolute wording is not appropriate where the behavior depends on consent, sync, providers, permissions, or runtime state.

### 4. Commercial wording

- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_hi.arb`
- `mobile/lib/l10n/app_localizations_gen_en.dart`
- `mobile/lib/l10n/app_localizations_gen_hi.dart`
- `mobile/lib/localization/app_localizations.dart`
  - Changed the pack label "Best value" to a factual quantity-oriented label: "More monthly questions" and its Hindi equivalent.

Reason: comparative value claims require substantiation and can be misleading when plan prices, limits, taxes, regional availability, or purchase terms differ.

## Residual findings requiring review or evidence

## Remediation Worklist

### Claims, eligibility, and coverage support

- Completed in this continuation pass: changed coverage-gap and family-coverage labels to describe policy review, policy-listed names, and potential questions rather than making a coverage determination.
- Completed in this continuation pass: changed claim-log statuses to `Self-recorded:` labels so approved, rejected, and paid values are not presented as insurer-feed decisions.
- Still open: solo-owner review of the coverage-review methodology, evidence tiers, source citations, and insurer-verification prompts.

Continuation-pass paths: `mobile/lib/screens/coverage_gap_screen.dart`, `mobile/lib/models/claim_record.dart`, `src/frontend/templates/landing.html`, `site/index.html`, `mobile/lib/l10n/app_en.arb`, `mobile/lib/l10n/app_hi.arb`, `mobile/lib/l10n/app_localizations_gen.dart`, `mobile/lib/l10n/app_localizations_gen_en.dart`, `mobile/lib/l10n/app_localizations_gen_hi.dart`, and `mobile/lib/localization/app_localizations.dart`.

### P0 - Owner decisions before launch

1. Coverage-gap and family-coverage features still use domain terms such as "coverage gaps", "covered", and "who is covered". The current marketing copy uses more conditional wording, but the feature can still be interpreted as an adequacy, eligibility, or coverage determination. The solo owner should approve the definition, evidence threshold, source citation behavior, exclusions, and insurer-verification prompt before launch.

2. Claims assistance remains a high-risk surface. It contains policy-derived claim-process information and local claim statuses including approved and paid. The screen explains that users update statuses themselves, but the visual labels can still be mistaken for insurer updates. A release gate should require visible self-recorded status context and a clear statement that CoverWise does not submit claims or receive insurer decisions.

3. Security and privacy marketing claims remain in the product: "Private by design", secure-account/session labels, private storage/search-index descriptions, HTTPS/TLS statements, and no-sale/no-rent statements. These require a lightweight owner-maintained security/privacy evidence note, named subprocessors, and documented retention/deletion behavior. Copy edits alone do not substantiate them; no ISO program or enterprise audit is implied.

4. Deletion and retention language is now more bounded, but the app still needs Tier 3 or higher evidence for local deletion, server deletion, partial failure, retry, account deletion, backups, processor retention, and support-request handling. Published promises must not be stronger than the observable terminal state.

### P1 - Owner review before launch

5. Offline capability is described more carefully, but the product still has offline-assist, offline-upload, and local-cache paths. The release claim should specify which information is cached, whether it is stale, which actions require connectivity, and whether offline answers are explicitly unverified.

6. The app and landing pages describe AI-generated answers, policy extraction, summaries, and claim-process guidance. The solo owner should approve an AI disclosure, error/uncertainty treatment, source citation behavior, and a rule preventing the output from being treated as insurance, legal, financial, or medical advice.

7. Consent copy must be reviewed across document processing, analytics, model improvement, marketing email, advisor requests, and optional contact capture. The purpose-specific ledger is helpful, but the final UI and Privacy Policy must make each purpose optional or required consistently and explain processor sharing accurately. This is a solo-owner product decision, not an enterprise consent certification exercise.

8. Family-member and policy data can contain sensitive personal and health information. The solo owner should document age/guardian handling, dependent data, cross-device sync, international processing, subprocessors, data-subject requests, and retention decisions.

9. The Terms now state India governing law, but the legal entity, registered address, support/escalation contact, consumer-rights language, dispute mechanism, limitation-of-liability enforceability, and jurisdictional availability need owner-owned validation against policy evidence, with optional legal-advisory review if you choose it.

10. Subscription, question-pack, refund, restore, cancellation, expiry, and entitlement copy needs an owner check against the relevant store and payment-provider requirements. The wording must match server entitlement authority and real provider lifecycle evidence, including failed, reversed, refunded, and delayed confirmations.

## Owner review model

- Owner: Pranay, as the sole product owner.
- Review support: AI agents may scan, compare, rewrite, and document wording, but the owner makes the final product decision.
- Target review date: before public launch or store submission.
- Required lightweight evidence: current claim registry, copy parity between app/web/legal sources, representative output review, and known limitations for deletion, claims, privacy, AI, and billing.
- Not required: external counsel, ISO certification, enterprise compliance tooling, insurer approval, or a formal legal department.

## Remediation status

The identified copy-level high-risk phrases in this pass have been softened across their known duplicate surfaces. The remaining findings are owner-review and evidence tasks, not external legal or ISO approval gates. The owner should keep claims bounded, avoid implying insurer authority, and record decisions in the claim registry before launch.
