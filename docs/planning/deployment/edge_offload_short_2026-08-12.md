# Edge Offload — SHORT Exploration (Handset / Browser)

**Date:** 2026-08-12 · **Status:** Exploration (not yet committed architecture) · **Evidence:** T1/T2

## TL;DR
Offloading OCR / embedding / local-LLM to the device or browser is **feasible and partly already built on the handset**, but it is an **optimization, not a launch blocker**, and it does **not** change the Render launch decision. The real work is a **trust-anchor pattern** (server re-verifies against the raw PDF in Supabase Storage) plus treating **Cloudflare as the egress/CDN layer** — both platform-independent and cheap. Scope must be **global**, not India-only.

## What we already have (NOT greenfield on handset)
- On-device OCR (ML Kit) — shipped (iOS pod + `ml_ocr_service.dart`).
- Offline LLM Q&A (Gemma via MediaPipe) — built, behind flag.
- SmolDocling-256M identified as the mobile VLM parsing answer — researched, not built.
- `tests/test_mobile_ocr_sidecar.py` exists.

## What is genuinely missing (this ADR fills it)
1. **Trust-anchor pattern** — `citation_verifier` anchors only on `source_text` and rejects `retrieval_text`. Device text cannot be the trust root; server must re-verify against the canonical PDF. *This is the real blocker.*
2. **Browser / WASM / WebGPU path** — entirely absent (greenfield). Viable for web/desktop + iOS hedge; slower to bootstrap than native ML.
3. **Global fragmentation** — prior research is India/Devanagari-centric. Global = more scripts (Arabic/CJK/Cyrillic…), wider low-end-Android spread *worldwide*, and an iOS Core ML/MLX lane the Android-centric stack lacks.
4. **Cloudflare egress/CDN** — not researched before; now covered below.

## Cloudflare vs platform egress (user-asked)
| Source | Egress $/GB |
|---|---|
| **Cloudflare R2** | **$0** |
| **Cloudflare CDN** | **$0** bandwidth (free tier) |
| Render | $0.15 |
| Fly | $0.02–0.12 |
| AWS | ~$0.09 |
| GCP | ~$0.12 |

Cloudflare is **strictly cheaper** than any platform-native egress **and** faster globally (300+ edge PoPs). It's a cross-cutting layer in front of Render/Fly — adopt now, reversible, independent of the launch decision.

## Platform math after offload
Thin 256 MB backend → Fly ~$4/mo vs Render still $14/mo (Starter min 512 MB). Offload improves **future** cost leverage; does **not** overturn Render-now (chosen for native worker + flat billing + solo DX).

## Worker
Outbox worker (`src/workers/outbox_worker.py`) stays **server-side** — device is ephemeral/offline; worker is the durable-work primitive.

## Privacy
On-device compute reduces server PII processing, but the raw PDF must still live in Supabase Storage as the trust root (§5.3) — so offload is "minimized compute," not "zero server PII." True zero-server-PII would break the citation grounding guarantee.

## Recommendation
1. Trust-anchor pattern = **hard prerequisite** (doc + enforce before device extraction).
2. Adopt **Cloudflare egress/CDN now**.
3. Widen mobile research **global** before building offload.
4. Schedule handset offload **post-launch**; browser path later.
5. Launch platform = **Render unchanged**.

→ Full write-up: `edge_offload_feasibility_2026-08-12.md`
