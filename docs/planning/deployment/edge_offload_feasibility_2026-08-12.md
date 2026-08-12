# Edge Offload Feasibility — OCR / Embedding / Local-LLM to Handset & Browser

**Date:** 2026-08-12
**Type:** Exploration ADR (decision-support, not yet a committed architecture change)
**Author:** Engineering (Forge)
**Supersedes / relates to:** `platform_decision_reassessment_2026-07-28.md` (launch = Render); `mobile_on_device_parsing_research_2026-07-25.md`; `rag_mobile_best_practices_audit_2026-08-12.md`
**Evidence basis:** Tier 1 (static inspection of existing docs + code): `mobile_on_device_parsing_research_2026-07-25.md`, `src/services/citation_verifier.py`, `docs/audit/rag_mobile_best_practices_audit_2026-08-12.md`, `docs/planning/deployment/platform_decision_reassessment_2026-07-28.md`. Cloudflare egress/CDN figures: third-party 2026 pricing aggregators (`egresscost.com`, `tech-insider.org`, `costbench.com`, `ecorpit.com`); cross-checked for internal consistency. Tier 2/3 (runtime egress measurement, on-device model benchmark) **not** performed — flagged where it changes confidence.
**User directive this answers:** "do the short exploration but i would still need the full exploration: 2. Offload to the handset/browser — have we explored it? No....so do all" — plus the two corrections: (a) fragmentation is **global, not India-only**; (b) Cloudflare etc may be cheaper/faster egress/CDN than platform-native egress.

---

## 1. Executive Summary

Offloading the heavy pipeline stages (OCR, embedding, local-LLM) to the user's handset or browser is **technically feasible and already partly implemented on the handset**, but it is **not** a free win and it does **not** overturn the existing launch-platform decision (Render). The decision hinges on three things the prior work did **not** resolve:

1. **Trust anchor.** The entire "evidence-backed" guarantee rests on `citation_verifier.py` anchoring citations on immutable `source_text` (ADR-2026-07-19-11 Layer 3). If the device produces the extracted text, the server must still anchor trust on the **raw PDF in Supabase Storage** and re-verify. This pattern is undocumented and is the real architectural blocker — not device capability.
2. **Scope is global, not India-only.** Prior mobile research is India/Devanagari-centric. A global user base means many more scripts (Arabic, Cyrillic, CJK, Thai…), a far wider device-capability spread (low-end Android in emerging markets *worldwide*), and an iOS/Android model-runtime divergence the current Android/Google-centric stack (ML Kit + MediaPipe) under-serves.
3. **Egress is a platform-agnostic lever.** Cloudflare R2 ($0 egress) and Cloudflare CDN (free bandwidth on the free tier) are strictly cheaper than *any* platform-native egress (Render $0.15/GB, Fly $0.02–0.12/GB, AWS ~$0.09/GB, GCP ~$0.12/GB) and faster for a global audience via 300+ edge PoPs. This is a cross-cutting optimization that is valuable **regardless** of the Render-vs-Fly choice.

**Recommendation (preliminary):** Offload is an **optimization to schedule after launch hardening**, not a launch blocker. Proceed with the trust-anchor pattern as a *required* design constraint for any offload; adopt Cloudflare as the egress/CDN layer now (cheap, reversible, platform-independent); and widen the mobile research from India-only to global before committing engineering effort.

---

## 2. What has ALREADY been explored / built (handset side) — NOT greenfield

This corrects the "we have not explored it" assumption. The handset path is the **most** researched offload vector in the repo:

| Capability | Status | Evidence |
|---|---|---|
| On-device OCR (ML Kit) | **Built + shipped** (iOS pod `MLKitTextRecognition`; `ml_ocr_service.dart`) | `mobile/ios/Pods/MLKitTextRecognition`, `docs/technical/rag/exploration/mobile_on_device_parsing_research_2026-07-25.md` §1 |
| On-device LLM Q&A (Gemma via MediaPipe) | **Built, behind flag** (`on_device_inference_service.dart`, `onDeviceInferenceEnabled`) | same doc §1.2; flagged in audit §5.3 (model SHA-256 declared but not verified at download) |
| Mobile VLM parsing research (SmolDocling-256M, OvisOCR2, etc.) | **Researched, not implemented** — SmolDocling-256M identified as the parsing answer | same doc §"Tier 1" + §"key insight" |
| Frameworks surveyed (MediaPipe, TFLite, ONNX Runtime Mobile, llama.cpp, MLC LLM, ExecuTorch, MLX) | Researched | same doc §"Mobile inference frameworks" |
| Mobile OCR sidecar test | **Exists** | `tests/test_mobile_ocr_sidecar.py` |
| Phase 1 / 1.5 / 2 mobile-first architecture | Proposed | same doc §"Recommended mobile-first parsing architecture" |

**What the existing research gets right:** it already establishes that the phone *can* do OCR (free, on-device), that an offline LLM lane already exists, and that a ~130 MB quantized VLM (SmolDocling-256M) can parse tables/reading-order on-device — which would sharply reduce server embedding/chunking load.

**What the existing research does NOT cover (the genuine gaps this ADR fills):**
- The **browser / WASM / WebGPU** offload path (entirely absent from the repo).
- The **server-side trust-anchor re-verification pattern** for device-extracted text (see §5.3).
- **Global** fragmentation analysis — the doc is explicitly "Phase 1 is mobile-only" and centers India/Devanagari (see §5.4).
- **Cloudflare / CDN egress** comparison (see §5.5).
- The **revised platform-cost math** if the backend shrinks to 256 MB (see §5.7).

---

## 3. The requested topics

### 5.1 Handset offload of OCR / embedding / local-LLM

**OCR:** Already offloaded in practice (ML Kit on-device). Server-side OCR (`src/ocr/pipeline.py`, DocTR via HF APIs per prior notes) becomes a fallback for failed/complex pages. Net: OCR is the *easiest* win and is partly done.

**Embedding:** A policy PDF parsed on-device yields clean Markdown → can be embedded on-device (sentence-transformers / ONNX embedding model) and the backend receives embeddings + text. This removes the heaviest server CPU cost. Caveat: embedding-model consistency must be pinned (audit Finding #6: embedding-model drift is already an unresolved defect) — the device and server must use the *same* embedding model + dimension, or the pgvector index silently breaks. This is the same trap as the current Qdrant path, now replicated at the edge.

**Local-LLM:** Gemma-2B on-device already answers questions offline. For a *global* offline lane this is attractive (no server round-trip, no PII transit). But the local-LLM answer cannot carry the server's citation_verifier grounding — so an on-device answer must be explicitly labeled "unverified / offline" (the mobile app already has a 4-state verification badge; audit §5.4 warns a missing `verificationStatus` currently renders *no* badge — must default to `unverified`).

### 5.2 Browser / WASM / WebGPU offload (NEW — not previously explored)

For users on **desktop/web** (and as an iOS-friendly path, since ML Kit/MediaPipe are Google/Android-centric), the browser can run the same models via:
- **WASM** (ONNX Runtime Web, transformers.js) — uniform across OS, but CPU-bound and slow for VLM parsing (tens of seconds/page).
- **WebGPU** (ONNX Runtime Web GPU, WebLLM for LLM) — near-native speed on capable GPUs; supported in Chrome/Edge/Safari16+/Firefox(behind flag) by 2026, but **not** on low-end mobile browsers.
- **Model distribution overhead:** shipping a 130 MB–1.7 GB model to the browser per session is a large first-load cost; needs caching, versioned CDN, and SHA-256 integrity (same supply-chain control the audit demanded for on-device models, §5.3).

**Verdict:** Browser offload is viable for the **web/desktop** surface and as an iOS hedge, but is slower and heavier to bootstrap than native handset ML. It does **not** replace the handset path; it complements it. No code or design doc for this exists yet — greenfield.

### 5.3 Server-side trust-anchor pattern (THE architectural blocker)

The "evidence-backed" claim is enforced by `citation_verifier.verify_citation()`, which (per ADR-2026-07-19-11 Layer 3):
- Accepts a quote **only if** `quote_source == "source_text"` (rejects `retrieval_text` immediately),
- Verifies the quote is substring/whitespace-normalized present in `source_text`,
- Checks document/page bounds.

If the **device** extracts the text, then `source_text` on the server is whatever the device sent — which is *untrusted input*. The grounding guarantee collapses unless the server re-anchors.

**Required pattern (proposed, not yet implemented):**
1. **Raw PDF in Supabase Storage is the single trust root.** Store the uploaded bytes immutably; never trust device-provided text as `source_text`.
2. **Device extraction = non-authoritative cache.** The device may send its OCR/VLM Markdown to *accelerate* ingestion, but the server treats it as a *proposal*.
3. **Server re-verification.** Either (a) the server re-runs extraction from the canonical PDF (server-side OCR/VLM) and diffs against the device proposal (accept if match ≥ threshold), or (b) the server at minimum re-derives `source_text` from the canonical PDF and verifies every returned citation against *that*. Option (b) is cheaper and sufficient for the citation guarantee.
4. **Integrity enforcement.** Device model artifacts (and browser model blobs) must be SHA-256-verified at download — the audit already flags this as unenforced for the on-device Gemma model (§5.3). Offload multiplies this requirement.
5. **Labeling.** Any answer that relied on device-extracted (re-verified) text vs server-extracted text should be retrievable for audit; the verification badge must always render (default `unverified`).

**Consequence:** offload reduces *cost/latency*, not *server storage of the PDF*. The PDF still lives in Supabase Storage. So offload does **not** achieve "zero server PII" — see §5.6.

### 5.4 Global device fragmentation + server fallback (user correction: not India-only)

Prior research frames the market as India + Devanagari. The user is correct: **people globally buy and need to understand their policies.** Implications the current docs miss:

- **Script coverage.** Latin + Devanagari covers India + much of the West, but global policies span Arabic, Cyrillic, CJK (Chinese/Japanese/Korean), Thai, Hebrew, etc. SmolDocling/DocLayNet is largely Latin-centric; multilingual VLM parsing accuracy on non-Latin scripts must be benchmarked *before* claiming offload works globally.
- **Device-capability spread is global, not just Indian.** Low-RAM Android (2–3 GB) is dominant across South Asia, Africa, Latin America, and parts of SE Asia — not only India. The "256 MB model fits" assumption holds for *mid/high* phones; the global long tail needs the **server fallback** to remain first-class, not an afterthought.
- **iOS/Android divergence.** ML Kit + MediaPipe are Google/Android-centric. iOS needs Core ML / MLX / Vision equivalents (the doc lists MLX as "iOS/macOS only" but does not design the iOS parsing lane). A global product must ship a parsing path on *both* runtimes, or accept Android-first.
- **Fallback design.** Per user: "Offload is an optimization, not the only path." The server pipeline (`src/ocr/pipeline.py`, outbox worker) must remain the default; device offload is an *acceleration* that degrades gracefully to server processing when the device is incapable, offline, or produces low-confidence extraction.

### 5.5 Cloudflare etc — cheaper/faster egress & CDN vs platform-native (user-requested)

**Verified 2026 pricing (aggregators, internally consistent):**

| Egress source | Cost per GB out | Notes |
|---|---|---|
| **Cloudflare R2** | **$0** | Zero egress fees; storage ~$0.015–0.02/GB-mo + per-request ops. Headline differentiator. |
| **Cloudflare CDN** | **$0** bandwidth on free tier (unlimited); Pro $20/mo, Business $200/mo | 300+ edge PoPs → faster global delivery. |
| Render (Hobby) | $0.15/GB | 5 GB/mo included. |
| Fly.io | $0.02 (NA/EU) / $0.04 (AP) / $0.12 (India/Africa) | PAYG, per-region. |
| AWS S3 | ~$0.09/GB | Big-three average $0.087–0.12. |
| GCP | ~$0.12/GB | |
| Azure | ~$0.087/GB | |

**Analysis:**
- Cloudflare egress/CDN is **strictly cheaper** than *every* platform-native egress above. For a policy app where users download parsed PDFs, page images, and reports **globally**, egress is a real and recurring cost — Cloudflare eliminates it.
- Cloudflare is a **cross-cutting layer**, not an either/or with Render/Fly. You still run compute on Render (or Fly); you put **Cloudflare in front** (CDN + WAF + cache for static/API responses) and/or move large object storage to **R2**. This is independent of, and complementary to, the launch-platform decision.
- **Faster for global users:** a single-region Render/Fly instance in Mumbai is far from a user in São Paulo or Berlin; Cloudflare's edge cache serves cached responses from nearby PoPs. This directly addresses the "global, not India-only" correction.
- **Caveat / Tier-2 unverified:** Cloudflare can throttle or charge for "abuse"/excessive bandwidth on the free tier; exact enterprise terms and R2 operation costs at scale were not measured here. Supabase Storage (the canonical object store today) already bundles egress in its plans, so the *immediate* egress saving is for traffic that would otherwise hit Render/Fly/S3 egress, not necessarily Supabase. Re-evaluate once real traffic numbers exist.

**Recommendation:** Adopt Cloudflare as the **egress/CDN layer now** — it is cheap, reversible, and platform-independent, and it is the single highest-leverage cost+speed fix for a global audience. This does not conflict with the Render launch decision.

### 5.6 Privacy / DPDP tension

- **Privacy win (partial):** On-device OCR/parsing means the *compute* runs on the user's hardware; the raw PDF need not be processed server-side for the parse stage. This reduces server-side PII/PHI exposure and helps with **DPDP Act 2023 (India)**, **GDPR (EU)**, and other jurisdictions' data-minimization principles.
- **Privacy limit (important):** Because of §5.3, the **raw PDF must still live in Supabase Storage** as the trust root for citation verification. So offload does **not** achieve "server never sees my policy." The PDF is still uploaded and stored. The privacy benefit is *reduced server compute on PII* and *faster, offline Q&A*, not zero server PII.
- **If true zero-server-PII is wanted:** would require trusting device-extracted text as `source_text` — which **breaks the citation_verifier grounding guarantee** (§5.3). This is a direct trade-off: weaker evidence-backed guarantee vs less server PII. Recommendation: keep the PDF server-side as root; the privacy posture is "minimized compute + encrypted-at-rest + consent-gated," matching the audit's documented mobile strengths (AES-256-GCM, fail-closed consent).

### 5.7 Revised platform math (thin backend → Fly 256 MB viable)

If OCR + embedding move to the device, the backend shrinks to: API (RAG query + LLM call via OpenAI) + the always-on outbox worker. The Python stack (FastAPI + deps) can fit **256 MB** instead of 512 MB.

| Scenario | Render (Starter) | Fly.io (256 MB ×2) | Note |
|---|---|---|---|
| Current (server does OCR/embed) | $14/mo (512 MB ×2) | ~$4/mo (256 MB ×2) | Fly floor already ~half |
| After offload (256 MB backend) | **still $14/mo** (Starter min is 512 MB/service) | **~$4/mo** (256 MB ×2) | Offload makes Fly's floor viable |

**Implication:** Offload does **not** change the *launch* decision (Render was chosen for its native Background Worker primitive + flat predictable billing + low solo DX, per `platform_decision_reassessment_2026-07-28.md` — not raw price). But it **strengthens the case for a cheaper scale-out later**: a 256 MB backend makes Fly (or even serverless) attractive once the worker pattern is proven. So offload is a *future-cost* lever, not a launch-cost lever.

### 5.8 The outbox worker stays server-side

The always-on `src/workers/outbox_worker.py` polls `job_outbox` and processes document/RAG/billing/deletion jobs. This is the load-bearing durable-work primitive (ADR-2026-07-19-10). **Offload does not move the worker to the device** — the device is ephemeral, may be offline, and cannot durably process other users' jobs. The worker remains a server-side service on Render (launch) or Fly (later). Offload only reduces *what* the worker processes (less OCR/embedding), not *where* it runs.

---

## 6. Recommendation (preliminary — not yet committed)

1. **Trust-anchor pattern (§5.3) is a hard prerequisite** for any offload. Document it as an ADR + enforce in `citation_verifier` before shipping device extraction. *Blocking.*
2. **Adopt Cloudflare as egress/CDN layer now** (§5.5). Cheap, reversible, platform-independent, biggest global-speed win. *Do soon.*
3. **Widen mobile research from India-only to global** (§5.4): script-coverage benchmark (non-Latin), iOS Core ML/MLX parsing lane, and an explicit server-fallback design. *Before* engineering effort on offload.
4. **Schedule handset offload as a post-launch optimization**, not a launch blocker. OCR is already partly done; embedding + VLM parsing follow once #1 and #3 are settled.
5. **Browser/WASM/WebGPU offload (§5.2) is greenfield** — scope it only after the handset path proves out; it is a web/desktop + iOS-hedge complement, not a replacement.
6. **Platform decision unchanged at launch** (Render). Offload improves *future* cost leverage (Fly 256 MB ~$4/mo) but does not overturn Render-now.

---

## 7. Open questions / next steps

- Q1. Does Supabase Storage egress already cover most of our traffic (making Cloudflare R2 a smaller win)? Measure real egress mix post-launch.
- Q2. Which embedding model will device + server share, and how do we pin/dimension-guard it (resolves audit #6)?
- Q3. Non-Latin script accuracy of SmolDocling / OvisOCR2 — needs a multilingual benchmark before global claims.
- Q4. iOS parsing lane: Core ML/MLX model availability + conversion effort for SmolDocling-class models.
- Q5. Cloudflare free-tier bandwidth throttle risk at scale — confirm enterprise terms if traffic grows.

## 8. Sources

- `mobile_on_device_parsing_research_2026-07-25.md` (handset research)
- `src/services/citation_verifier.py` (trust anchor; ADR-2026-07-19-11 Layer 3)
- `docs/audit/rag_mobile_best_practices_audit_2026-08-12.md` (on-device model SHA gap, verification-badge gap)
- `docs/planning/deployment/platform_decision_reassessment_2026-07-28.md` (launch = Render; Fly 256 MB ~$4/mo)
- Cloudflare egress/CDN 2026: `egresscost.com/cloudflare/`, `tech-insider.org/cloudflare-r2-vs-s3-vs-backblaze-b2-2026/`, `costbench.com/software/cdn-edge/cloudflare/`, `ecorpit.com/cloud-egress-fees-ai-inference-bill-comparison-2026/` (cross-checked, internally consistent; Tier-2 runtime measurement not performed)
