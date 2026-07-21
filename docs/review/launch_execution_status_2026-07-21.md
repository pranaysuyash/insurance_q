# Launch execution status — 2026-07-21

This is an execution record. Launch claims below are based on commands, current code, and local runtime behavior, not on planning documents.

## Current decision

CoverWise is not launch-ready yet. The local API path is runnable and the launch-critical mobile surface has substantial passing coverage, but production configuration, real external credentials, a production-like Supabase verification, and a verified release artifact are still missing.

## Code changes made in this pass

- Hardened nullable legal-document copy actions.
- Isolated Flutter Hive test directories to prevent cross-test locking.
- Corrected consent ledger revoke timestamps and latest-record selection.
- Corrected analytics consent cache evaluation after revoke/regrant.
- Made OCR optional at API import time when native OCR dependencies are unavailable.
- Verified the local OCR stack against the project venv and Homebrew runtime libraries; installed the missing `pdf2image==1.17.0` dependency and recorded it in `requirements-local.txt`.
- Fixed app startup ordering so analytics opens only after encrypted Hive boxes exist, and made `PrincipalKeyService` shared across callers.
- Added OpenAI SDK compatibility fallback for `max_completion_tokens`.
- Made production-config validation runnable from the repository root.
- Made the populated dashboard’s finite content eagerly testable and isolated its family extraction provider in dashboard tests.
- Updated dashboard test expectations to match the strings rendered by the current widgets.
- Isolated legal asset-bundle caches and made the upgrade purchase test use a genuinely pending billing future.

## Evidence captured from code/runtime

| Check | Result | Evidence tier |
|---|---|---|
| `flutter analyze` | No issues found | Tier 1 |
| Analytics consent gate tests | 5 passed | Tier 2 |
| Dashboard tests | 16 passed | Tier 2 |
| Complete Flutter test suite | 554 passed | Tier 2 |
| Launch-critical mobile bundle | 132 passed | Tier 2 |
| Backend targeted tests | 33 passed | Tier 2 |
| Local backend `/healthz`, `/readyz`, `/health` | All 200 while server was running | Tier 4 |
| Local deployed-launch verification | Liveness, readiness, anonymous identities, profile isolation, and owner-scoped lists passed | Tier 3 |
| LLM token compatibility probe | Passed | Tier 2 |
| OCR imports with project venv + Homebrew dylib path | `PDFProcessor`, `ImageProcessor`, and `OCRPipeline` imported successfully | Tier 2 |
| Live iOS simulator + serve-sim | App running on iPhone 17 Pro; serve-sim HTTP 200 | Tier 4 |
| Production config validator against current `.env` | Failed safely with required production variables/backends missing | Tier 1 |
| Android release build | Not verified; Flutter const-finder snapshot/Gradle toolchain failure | Tier 1 failure |

## Remaining blockers and closure paths

1. Production environment is incomplete. Supply real Supabase URL, service-role key, anonymous-auth signing key, public site URL, allowed origins, and Supabase-backed repository/object/vector backend settings; rerun `tools/validate_production_config.py`.
2. The local OpenAI key currently receives 401 invalid-key responses. Replace it with a valid production credential or explicitly configure the intended production fallback, then rerun real extraction and question-answer flows.
3. Supabase production schema/RLS cannot be verified from this checkout because there is no linked project configuration or reachable local Postgres. Link the intended project or provide the approved database target, run schema lint/migrations, and execute authenticated cross-owner isolation checks.
4. The Android release artifact is not verified. Repair or replace the Flutter SDK cache containing the missing `const_finder.dart.snapshot`, then complete a clean Gradle build with real release defines. Do not ship the staging compile attempt.
5. External distribution/deployment was not performed. No deployment destination or production credentials were available, and no commit or push was authorized.

## Artifact and workspace state

All work remains uncommitted. Existing parallel changes were preserved. `insurance_app.db` changed during local backend startup and remains for review; it was not reverted or deleted.

## Anything else?

No additional launch blocker was inferred from documents alone. The blockers above are the ones reproduced from current code, commands, runtime output, or missing executable deployment prerequisites.
