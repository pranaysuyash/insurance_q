# ADR-2026-07-21-03: Value-first guest access with an account conversion boundary

Status: Proposed product default; account-first versus guest-first remains an experiment decision.

Date: 2026-07-21

## Decision

Keep the first value moment available to a guest, then ask for an account when
the user needs durable recovery, cross-device access, family sharing, or a
paid entitlement that must survive identity changes. Do not enable a second
anonymous identity provider while the existing custom guest bearer identity
remains canonical.

This is a product and measurement default, not a final account-first decision.
The onboarding policy must remain experimentable until real activation,
paywall, purchase, retention, recovery, and support data selects a winner.

## Code evidence

- `POST /user/anonymous` creates the current guest owner and preserves it across
  requests.
- `POST /user/claim-anonymous` transfers guest document ownership to the
  authenticated account with an idempotent `identity_aliases` record.
- `mobile/lib/services/auth_service.dart` emits claim lifecycle events and only
  clears the guest token after a successful claim.
- `mobile/lib/services/billing_adapter.dart` associates RevenueCat with the
  account UID and reconciles subscription state through the API.
- `mobile/lib/services/analytics_schema.dart` registers identity, paywall,
  purchase, and claim lifecycle events without putting raw identity IDs in
  event properties.
- The remote project currently has Supabase anonymous sign-ins disabled, and
  the mobile path falls back to a device-local principal for encryption.

## Why this path

Guest access reduces friction before the user has seen policy value. A durable
claim boundary preserves the ability to recover work, attribute the funnel,
restore purchases, and operate support workflows after conversion. Mandatory
account creation may improve retention and lifecycle reach, but can reduce the
number of users who reach activation and the paywall.

The revenue question is therefore not “which identity collects more data?” It
is whether improved activation and paywall reach outweigh account-first gains
in recovery, cross-device continuation, lifecycle messaging, subscription
ownership, and renewal attribution.

## Required experiment

Assign a stable onboarding variant before account creation and compare:

- activation: upload started, extraction completed, first useful answer;
- monetization: paywall reach, trial start, purchase, renewal, refund;
- durability: account conversion, guest claim success, restore success;
- retention: day-7 and day-30 return;
- quality and operations: orphaned guests, deletion completion, support contacts;
- attribution integrity: one journey across guest, account, and RevenueCat IDs.

Do not declare a winner from client-only purchase reports. RevenueCat webhook
delivery must be configured, and the server billing ledger must be durable and
remote before revenue conclusions are trusted.

## Revisit trigger

Revisit this decision after a staging end-to-end run and a pre-registered
experiment cohort has enough observations to compare the metrics above. Also
revisit immediately if the product chooses Supabase Auth anonymous sessions as
the canonical owner; that choice requires retiring or migrating the custom
guest bearer owner rather than maintaining two owner systems.

## Known risks and closure path

- The production RevenueCat entitlement/webhook path now has a canonical
  Supabase ledger/RPC; SQLite remains a development compatibility adapter.
  Execute and concurrency-test the remote migration before production billing
  scale-up.
- A real guest-to-account purchase/restore flow has not been exercised against
  a staging account pair. Run the sandbox flow and verify claim, restore,
  expiration, sign-out, and deletion behavior.
- Production OpenAI and deployment values remain credential-dependent. Keep
  those checks explicit in the launch report.
