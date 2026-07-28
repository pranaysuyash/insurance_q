# Launch External-Alignment Doc — Domain, Legal Hosting, Billing, Marketing Claims

**Date:** 2026-07-28
**Status:** Living alignment doc. Blocks on the rename decision (§1) and domain registration (§2).
**Decision owner:** Pranay
**Doctrine:** `motto_v4.md` — §0.1.1 (anything else?), pattern families (privacy-policy-per-surface, launch-claim registry), §0.5 (evidence tiers)
**Related:** `rename_strategy_and_inventory_2026-07-28.md`, `revenuecat_webhook_handler_spec_2026-07-28.md`, `platform_decision_reassessment_2026-07-28.md`

---

## Why this exists

Several launch requirements are interdependent and scattered: the domain, hosted legal docs, support email, billing webhook URL, store data-safety declarations, and marketing-claim honesty. They all depend on the domain existing, and the domain depends on the name being final. This doc ties them into one dependency chain so nothing is missed.

The mobile app already enforces this via fail-closed release validation (`app_config.dart:validateReleaseConfiguration`): a production build **refuses to compile** unless `PRIVACY_POLICY_URL`, `TERMS_OF_SERVICE_URL`, `SUPPORT_EMAIL`, and `PRIVACY_POLICY_VERSION` are all valid HTTPS/email values. So these aren't optional — the app won't ship without them.

---

## 1. Dependency on the rename

Every external surface below carries the brand name. **Nothing in §2–§6 should be executed until the rename decision (§1 of `rename_strategy_and_inventory_2026-07-28.md`) is settled.** Registering `coverwise.app` resources now, then renaming, means double work and abandoned URLs.

**Exception:** the backend deployment (Render) and Supabase are name-agnostic infrastructure — those can proceed regardless of brand.

---

## 2. Domain (the root unblocker)

| Item | Status | Owner |
|---|---|---|
| Domain chosen | ⬜ pending rename | Founder |
| Domain registered | ⬜ | Founder |
| DNS A/CNAME records | ⬜ after deploy | Founder + agent |
| SSL/TLS | ⬜ (free via Let's Encrypt on Render, or Render's managed cert) | Agent |

**Current state:** `coverwise.app` does not resolve (confirmed 07-25: `Could not resolve host`). The legal-hosting and webhook-URL work all block here.

**Subdomains to plan (whatever the domain):**
- `app.<domain>` or apex `<domain>` — backend API (Render URL behind a custom domain)
- `www.<domain>` / apex — marketing site + hosted privacy/terms
- (optional) `status.<domain>` — status page (defer)

---

## 3. Hosted legal documents (store requirement, blocks release build)

The app validates that these resolve over HTTPS at build time:

| Required env | Must point to | Source file in repo |
|---|---|---|
| `PRIVACY_POLICY_URL` | hosted privacy policy | `docs/legal/privacy_policy.md` + `mobile/assets/legal/privacy_policy.md` |
| `TERMS_OF_SERVICE_URL` | hosted terms | `docs/legal/terms_of_service.md` + `mobile/assets/legal/terms_of_service.md` |
| `PRIVACY_POLICY_VERSION` | dated version string | (set as `--dart-define`) |
| `SUPPORT_EMAIL` | real, non-disposable inbox | (founder's email) |

**Hosting options (pick one):**
1. **Render static site** (recommended) — deploy the `site/` directory as a free Render static site at `www.<domain>`. Privacy at `/privacy`, terms at `/terms`. Same host as backend → one platform.
2. **GitHub Pages** — free, but adds a second platform to operate.
3. **Cloudflare Pages** — free, fast, but a third account.

**Recommendation:** Render static site — keeps everything on one platform (motto §12: reduce operator cognitive load).

**Existing verifier:** `tools/verify_hosted_legal_documents.py` already checks the URLs are reachable and match the repo source. Reuse it as the gate.

---

## 4. Support email

| Item | Status |
|---|---|
| `SUPPORT_EMAIL` value | ⬜ founder decides (likely `support@<domain>`) |
| Inbox actually receives mail | ⬜ (set up routing: e.g. ImprovMX free forwarding → founder's Gmail, or Google Workspace) |

**Free path:** ImprovMX or Cloudflare Email Routing forwards `support@<domain>` → founder's existing Gmail. No mailbox cost. Google Workspace ($6/user/mo) only if a separate inbox is wanted.

**Store impact:** Both Play and App Store require a support contact. The app already validates `SUPPORT_EMAIL` is a non-disposable email at build time (`app_config.dart:172`).

---

## 5. Billing webhook URL (blocks paid features, not free launch)

Once the backend is on Render with a custom domain, the RC webhook endpoint becomes:

```
https://app.<domain>/subscription/webhook
```

**What the founder must do in RC:**
1. RC dashboard → Project → Webhooks → Add endpoint → paste the URL above.
2. RC generates an Authorization header secret.
3. That secret must match `REVENUECAT_WEBHOOK_AUTHORIZATION` in the backend `.env`.

**Current state:** `REVENUECAT_WEBHOOK_AUTHORIZATION` exists in `.env` (value present). When RC is configured, align the two. Until then, paid features don't work — but a free-tier launch is unaffected.

---

## 6. Store data-safety / privacy declarations (Play Console)

Google Play requires a Data Safety declaration describing what data the app collects and how. This must match the actual SDK/integration set. **Current integrations and their data:**

| Integration | Data collected | Declared purpose |
|---|---|---|
| Supabase (auth + storage) | User ID, email, uploaded documents | App functionality (account, file storage) |
| OpenAI | Document text (sent for analysis) | App functionality (processing) — disclosed as third-party transfer |
| RevenueCat | Purchase history, app user ID | Purchases (financial info) |
| Hive (local) | Encrypted metadata on device | App functionality (local storage) — not transmitted |
| Google ML Kit OCR | On-device text recognition | App functionality — on-device, not transmitted |
| (future) AdMob | Advertising ID, usage | Advertising — only if/when rewarded ads ship |

**Critical honesty rule (motto §0.2, §0.5):** the declaration must match reality. Adding AdMob later requires updating the declaration. The launch declaration should reflect what ships at launch — no more, no less.

**Sub-processor disclosure in privacy policy:** the policy already lists Supabase and OpenAI. When AdMob ships, add Google Ads. The privacy-policy-per-surface pattern (motto pattern family) applies: each data-handling surface has its own disclosure.

---

## 7. Launch-claim registry (motto §0 pattern family)

Every public marketing claim must map to: claim text → implementation path → tests that gate it → evidence tier → release state. The 07-18 product-strategy audit found several overclaims. The registry is the corrective mechanism.

**Claims to audit before any marketing copy ships:**

| Claim | Current truth | Required to make it true |
|---|---|---|
| "Evidence-backed answers" | Partial — citation trust audit found contamination | Citation verifier + disable contextual retrieval until fixed |
| "Private by design" | Partial — plaintext source files, local-only principal ID regenerates | Define source-file protection; fix principal ID stability |
| "Works offline" | Partial — emergency card cached; Q&A needs backend | Qualify: "emergency card works offline" |
| "Bank-grade encryption" | ❌ Overclaim — AES-256 only on metadata DEK, not source files | Remove claim OR extend encryption to source files |
| "Understand any policy" | Partial — tested on limited doc types | Qualify scope until broader doc-type coverage proven |

**Rule:** a claim cannot ship until its registry entry shows Tier 3+ evidence. This is the gate that prevents the marketing overclaims the audits flagged.

---

## 8. Anything else? (motto §0.1.1)

**Yes:**

1. **App store screenshots + listing copy.** These carry the brand name and claims. They block on: rename (for the name), domain (for support URL), and claim registry (for honest copy). Start drafting copy now against the agreed MVP surface (upload → summary → source → Q&A); finalize after name + domain.

2. **DPIA / data-processing needs (India DPDP Act).** The Digital Personal Data Protection Act 2023 applies. A full DPIA may be needed for an app processing insurance documents (sensitive financial data). **Founder must get local legal counsel** — this is outside what an agent can assess and outside the "no regulatory stuff" scope the founder set. Flagging only; not actioning.

3. **Backup MX / email deliverability.** If support email forwards to Gmail, ensure SPF/DKIM/DMARC are set so user emails don't land in spam. Minor but affects "support responsiveness" perception.

4. **The `site/` directory.** There's already a marketing site (`site/index.html`, `site/privacy.html`, `site/terms.html`) with ~20 brand references. It deploys as part of the legal-hosting step. It needs the same rename pass + claim-registry audit as the app.

---

## 9. Critical path summary

```
Rename decision (§1)
    │
    ├──► Domain register (§2)
    │       │
    │       ├──► Host legal docs (§3) ──► unblocks release build
    │       ├──► Support email (§4)   ──► unblocks release build
    │       ├──► Webhook URL (§5)     ──► unblocks paid features
    │       └──► Store data-safety (§6)
    │
    ├──► Claim registry (§7)          ──► unblocks marketing copy
    │
    └──► Listing assets (§8.1)

Backend→Render (independent of rename) can proceed in parallel.
```

**The single biggest unblocker is the name decision.** Everything external chains from it.

---

## Update log

- 2026-07-28: created. Tied domain, legal hosting, support email, billing webhook, data-safety, and claim registry into one dependency chain. Anchored to rename decision and fail-closed release validation.
