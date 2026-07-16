# CoverWise account authentication architecture

**Date:** 2026-07-16  
**Status:** implemented locally; production enablement remains configuration-gated  
**Decision owner:** Pranay

## Finding

CoverWise did have an authentication mechanism, but it was device-scoped
anonymous identity rather than user account authentication:

- `POST /user/anonymous` issues a server-signed 30-day bearer token.
- Flutter stores that token in `flutter_secure_storage`.
- Policy documents and processing requests are owner-scoped to the anonymous
  subject, with repository-level isolation tests.
- There was no account sign-up, sign-in, email confirmation, password reset,
  refresh-session UI, cross-device identity, or anonymous-to-account migration.

That distinction matters because a policy document is sensitive customer data.
The current anonymous flow is useful for a low-friction first session, but it is
not sufficient as the durable ownership boundary for a launch product.

## Decision

Use **Supabase Auth** for account identity and session lifecycle, on the same
Supabase project already chosen for production Postgres/pgvector and private
document storage.

The layers are intentionally separated:

1. **Supabase Auth** owns email/password credentials, email confirmation,
   access/refresh tokens, session revocation, and account UUIDs.
2. **Flutter** uses `supabase_flutter` to persist and refresh the user session
   in platform-managed app storage. The publishable/anonymous key is build-time
   public configuration; the service-role key never ships to a client.
3. **FastAPI** accepts the Supabase access token on policy-bearing routes and
   validates it through Supabase Auth. It maps the verified subject to the
   existing `User` model with `identity_type=account`.
4. **DocumentRepository** remains the only metadata ownership boundary.
   `/user/claim-anonymous` atomically transfers documents from the verified
   anonymous subject to the verified account subject.

No second password database, custom refresh-token table, Firebase dependency,
or duplicate document route is introduced.

## Why this package and database

`supabase_flutter` is the official Flutter integration and supports the
existing Dart/Flutter app platforms. This repository currently uses Dart 3.8,
so the dependency is pinned to the compatible `2.15.x` line rather than the
newer release that requires Dart 3.9.

Supabase is preferred over adding Firebase Auth because the current canonical
production data direction already uses Supabase Postgres/pgvector and Storage.
Adding Firebase would create a second identity/vendor boundary and require
mapping Firebase UIDs into Supabase-owned data. Supabase Auth also avoids
implementing password hashing, refresh rotation, email confirmation, and
recovery flows in this repository.

## Request and state flow

```text
First launch
  -> anonymous token (existing low-friction mode)
  -> upload/query owned by anon:<subject>

Account creation/sign-in
  -> Supabase Auth session
  -> API validates Supabase access token
  -> /user/claim-anonymous verifies the old anonymous token
  -> documents.owner_id and serialized payload.user_uid are transferred
  -> subsequent API calls use account UUID
```

The transfer is explicit and auditable. It is not inferred from an email,
client-supplied UID, or a local session ID. If the transfer fails, the old
anonymous token remains available and the account session is not silently
claimed.

## Files changed

- `src/utils/supabase_auth.py`: server-side Supabase Auth verification.
- `src/api/user.py`: accepts account or anonymous principals and adds the
  authenticated owner-transfer endpoint.
- `src/services/document_repository.py`: canonical transfer operation for
  SQLite, Supabase, and an explicit unsupported response for the historical
  DynamoDB adapter.
- `infra/supabase/001_coverwise_schema.sql`: service-role-only transfer RPC.
- `mobile/pubspec.yaml`: `supabase_flutter` dependency.
- `mobile/lib/services/auth_service.dart`: account session access, sign-in,
  sign-up, sign-out, and anonymous-data claim.
- `mobile/lib/screens/account_screen.dart`: email/password account UI.
- `mobile/lib/screens/profile_screen.dart`: account entry and signed-in state.
- `mobile/lib/main.dart`, `mobile/lib/config/app_config.dart`: Supabase
  initialization and build configuration.

## Configuration contract

### API / Cloud Run

Already-required production values remain required:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (server only)
- `ANONYMOUS_AUTH_SIGNING_KEY` (anonymous compatibility path)

Supabase Auth email confirmation and password recovery URLs must be configured
in the Supabase dashboard before inviting real users. The current implementation
does not claim that email delivery is configured merely because the code exists.

### Flutter release

Pass these with `--dart-define`:

```text
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<publishable-or-anon-key>
```

Never pass `SUPABASE_SERVICE_ROLE_KEY` to Flutter.

## Security and operational requirements

- Account access tokens are never logged or copied into analytics.
- Anonymous and account ownership are verified from bearer credentials, never
  from request fields such as `user_id` or `session_id`.
- The transfer RPC is executable only by `service_role`.
- Duplicate upload behavior remains owner-scoped and idempotent.
- Sign-out revokes the Supabase client session; local anonymous data is not
  silently deleted.
- Account deletion, data export, password-reset UI, MFA, and support-assisted
  recovery are follow-up features requiring explicit product/legal decisions.

## Verification status

Static implementation evidence is present in the files above. Targeted Python
tests cover anonymous behavior, account-principal mapping, and local repository
ownership transfer. Flutter analysis and the existing full Flutter test suite
also pass. Flutter analysis/build with the actual project Supabase
configuration is still required; a local build without those values proves
only the compatibility fallback path.

Evidence tier at document update: **Tier 2 (targeted tests passed)**. The
acceptance gate is Tier 3+ for the account flow: create/confirm account, sign
in, claim a real anonymous document, sign out, sign back in, and verify the
document remains visible only to that account.

## Revisit triggers

Revisit this choice if account requirements expand to enterprise SSO, regulated
regional identity hosting, native passkeys as the primary method, or a
non-Supabase production data plane. Until then, adding Firebase or a custom
password service would increase operational and migration risk without user
value.
