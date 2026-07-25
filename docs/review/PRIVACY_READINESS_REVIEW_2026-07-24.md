# Privacy readiness review — 2026-07-24

**Scope:** buyer-facing review of consent, retention, legal-document delivery,
data-subject controls, and their operational evidence. This is an engineering
readiness record, not legal advice, a legal opinion, or a compliance
certification.

## Current boundary

CoverWise is a policy-information assistant. It processes policy documents,
derived summaries/search data, user questions, account identifiers, consent
events, and opt-in analytics. It must not be represented as a legally approved
privacy programme or as having completed a data-protection impact assessment
until the external gates below have evidence from the accountable owners.

## Implemented controls and evidence

| Control | Canonical path | Current evidence | Limit |
|---|---|---|---|
| Versioned in-app privacy policy and terms | `mobile/assets/legal/` via `LegalContentLoader` | Tier 2: legal screen tests pass | A packaged document is not proof of hosted release content or founder-approved wording. |
| App/publishable-document parity | `mobile/assets/legal/` and `docs/legal/` | Tier 2: `tests/test_legal_document_contract.py` | Does not fetch or verify a hosted page. |
| Consent recording and revocation history | `src/api/consent.py`, `src/services/consent_ledger_service.py`, `supabase/migrations/20260719000000_consent_ledger.sql` | Tier 2: service/schema tests pass | Remote migration, authenticated client sync, and access-control proof remain unexecuted. |
| Consent-purpose separation | `supabase/migrations/20260721260000_dataset_consent_purposes.sql` | Tier 2: schema contract tests pass | Release must apply all migrations in order and prove their status remotely. |
| Analytics retention primitive | `tools/run_data_retention.py`, `src/services/analytics_retention_service.py` | Tier 2: retention tests pass | The command is not scheduled by application startup; no production execution report exists. |
| Published analytics retention default | Privacy policy says 30 days; `DEFAULT_ANALYTICS_RETENTION_DAYS = 30` | Tier 2: regression test passes | An environment override changes the public commitment and needs a founder decision. |
| Access/export and deletion request paths | `src/api/user.py`, `mobile/lib/services/auth_service.dart`, Profile privacy section, account-lifecycle service and durable outbox | Tier 2: lifecycle/deletion/export contract tests pass | A real authenticated export and end-to-end deletion job have not been observed. |

## Material external release gates

1. **Founder decision on entity details:** the Terms still contain the
   unresolved `[Jurisdiction]` placeholder. The founder must select the
   governing law, controller/entity identity, applicable jurisdictional
   disclosures, children threshold, liability wording, and sub-processor
   statements. Do not replace this with an engineering guess.
2. **Hosted legal pages:** provide immutable HTTPS privacy and terms URLs,
   build the release with `PRIVACY_POLICY_URL`, `TERMS_OF_SERVICE_URL`, and a
   non-development `PRIVACY_POLICY_VERSION`. The build gate now invokes
   `tools/verify_hosted_legal_documents.py` against those URLs to check HTTPS,
   no-store policy, source hash/metadata, and exact rendered-source parity.
   Retain that successful output and manually review the rendered documents;
   the local contract does not prove a hosted page exists.
3. **Support and rights operations:** confirm the configured support mailbox
   is monitored; name the responder and service-level process for access,
   correction, export, deletion, and privacy inquiries. Test one request in a
   non-production account without exposing real customer data.
   Use the non-secret
   `SUPPORT_AND_DATA_RIGHTS_OPERATIONS_ATTESTATION_TEMPLATE.md` to retain the
   ownership, rehearsal, escalation, and exception record; it is not itself
   proof that the mailbox is monitored.
4. **Consent and retention production proof:** apply the migrations to the
   intended environment; record grant and withdrawal as an authenticated user;
   verify current/history views are principal-scoped; run the retention command
   on a synthetic stale analytics event; retain the operator report and audit
   the retained/legal-hold behavior.
5. **Processor and transfer diligence:** obtain current contractual/security
   terms for Supabase and OpenAI, identify data-region/transfer decisions, and
   record the approved sub-processor list and review cadence.
6. **Data inventory and retention schedule:** the founder must approve retention periods for
   source documents, derived text/embeddings, questions, consent/audit logs,
   backups, deletion-job logs, and account records. The code currently has a
   tested analytics default only; it does not establish a complete legal
   retention schedule.

## Addendum — release guard for incomplete legal terms (2026-07-24)

`tools/validate_legal_release_assets.py` now checks the publishable and
Flutter-packaged legal files for byte parity and known unresolved legal
placeholders. `tools/build_mobile_release.sh` invokes it before analysis,
tests, signing, or artifact creation. The current preflight intentionally
fails on `[Jurisdiction]` in the Terms; this prevents a public build from
silently carrying the known incomplete term. Focused legal parity/preflight
tests report **3 passed** (Tier 2). This is a deployment safeguard only: the
founder must choose and approve the jurisdiction,
entity/controller details, and the remaining legal decisions above.

The preflight also now rejects the phrase `information broker` in the Terms.
The document otherwise says CoverWise is not a broker, so publishing both
statements would create a material product-role contradiction. This is a guard,
not a rewrite: the founder must select and approve the
replacement wording.

The public FastAPI frontend now calls that same preflight before production
startup. A web deployment cannot bypass the mobile release gate and expose the
marketing surface while the canonical Terms are incomplete or the packaged
assets drift. The frontend records only an error count, then refuses startup.
This is still a local Tier 2 control—not proof that a production deployment,
immutable HTTPS pages, or founder approval of the wording exists.

The frontend now also provides `/privacy` and `/terms` from the exact
`docs/legal/` sources. Each response is `no-store` and includes the source
SHA-256 in both a response header and page metadata; the production image
copies that canonical directory rather than a second legal-content copy. This
makes a future approved deployment mechanically able to use the configured
public URLs and makes hosted-versus-source comparison auditable. The endpoints
do not make the URLs immutable, establish DNS/TLS hosting, or satisfy legal
approval; those remain release-owner decisions.

The active public footer links to both routes, so the pages are discoverable as
well as present in the sitemap. The integrated frontend/legal/container suite
reports **19 passed** (Tier 2). This is not browser/device observation or a
deployed HTTPS verification.

The legal-page renderer escapes document markup and emits a restrictive
content-security policy, `no-referrer`, and `nosniff` headers. A regression
test substitutes hostile source markup and confirms it is displayed as text.
This protects the document-delivery surface; it does not approve the legal
content or prove a deployed browser policy.

## Release decision

**Status: not sale- or public-launch-ready on privacy/legal evidence.** The
code provides useful local controls, but the unresolved legal placeholder and
the lack of production proof mean this work is Tier 2, not Tier 3+.

## Addendum — account export reachability (2026-07-24)

The owner-scoped `GET /user/account/export` endpoint is now reachable through
the Profile privacy section for signed-in accounts. Before sharing the export,
the app explicitly warns that it can include short-lived private-source links.
The focused mobile UI/contract checks and backend deletion/export checks pass.
This makes the access/portability control usable in the product; it does not
prove the authenticated endpoint against a deployed environment or validate
the export contents against real customer data.

## Three-pass review

### Pass 1 — immediate correctness

Checked consent, retention, legal assets, export, and deletion paths. Corrected
the 365-day fallback so it matches the published 30-day analytics period, and
made the bundled policy reachable when a development/review build has no hosted
policy URL.

### Pass 2 — architecture and long-term viability

Kept the existing canonical consent ledger, retention command, durable deletion
path, and legal-document loader. Added only a parity contract; no second
consent, retention, or legal-content authority was introduced.

### Pass 3 — supervision readiness

Separated local test proof from legal, deployment, support, and processor
evidence. Each remaining gate has a concrete owner class and executable proof.

## Anything else?

Yes. Legal wording, data-region choices, and retention periods are product and
operational decisions, not values an agent should infer. A buyer should treat
them as explicit closing conditions and price the asset accordingly until they
are resolved.
