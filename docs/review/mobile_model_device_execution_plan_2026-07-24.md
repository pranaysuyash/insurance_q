# CoverWise mobile model execution plan (Android/iOS, 2026-07-24)

This is the ready-to-run operational plan now that the evaluated-vs-not matrix is closed.

## Immediate constraint (current session)

- We now have an attached iPhone simulator (`iPhone 17`, iOS 26.2), plus macOS and Chrome.
- Mobile LLM runtime execution still did not proceed because no approved `.task` artifact/config was enabled for a full generation run in this session.

## Goal

Move from **`SCaffold-only`** to **`EVAL`** for at least one local mobile generation lane with full telemetry and fallback behavior.

## Execution backlog (in order)

### T1 — Device matrix + capability probe

- Start target devices: one supported Android emulator/device, one unsupported tier Android, one iPhone (if available).
- Capture capability probe:
  - `supports_gpu_or_delegate`
  - `supports_download_cache`
  - `available_disk_space`
  - `thermal_state_start`
- Pass criteria: capability results + fallback path captured in logs.

### T2 — Gemma 3n baseline lane (first mobile candidate)

- Build with local path flags (example):
  - `ON_DEVICE_INFERENCE_ENABLED=true`
  - `ON_DEVICE_MODEL_URL=<https://.../gemma_3n_e2b.task>`
- Install/run and execute:
  - cold install path
  - warm query path
  - cancellation path (user abort during response)
  - timeout path
- Metrics to collect per run:
  - p50/p95 latency
  - RSS memory
  - download duration/retry/fallback
  - thermal trend + throttling
  - unsupported-field refusal rate
  - citation/schema validation pass

### T2A — Concrete command bundle for the first Android/iOS on-device proof (template)

Use the artifact manifest from `docs/review/evidence/mobile-model-artifacts/` after it exists.

1. Ensure model artifact:
   - `mkdir -p ~/Library/Caches/coverwise/models && ls -lh <artifact>.task`
   - Verify checksum hash against manifest:
     - `shasum -a 256 <artifact>.task`
2. Run guard tests (baseline):
   - `cd mobile && flutter test test/on_device_inference_service_test.dart`
3. Run first real device install/load/ask attempt (one device only):
   - `cd mobile && flutter test test/on_device_inference_service_test.dart --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=<https://.../gemma...>.task -d <device_id>`
4. Capture:
   - simulator/device log file
   - `flutter run`/test stdout
   - memory/thermal telemetry from platform logs
   - failure reason + retry count + cancel path

Pass criteria for T2 completion:
- install/load/ask completes at least once on a supported device
- output can be validated as non-empty refusal-safe response under our schema gate
- manifest records artifact URL/hash + device + pass/fail reasons

### T3 — Policy-grounded smoke on mobile

- Use fixed fixture:
  - 20 exact-field policy questions
  - 6 visual/failure pages
  - 6 negative/abuse prompts
- Compare against hosted baseline:
  - pass@k acceptance gate
  - citation completeness
  - false-positive/unsupported refusal behavior

### T4 — Managed native probes (optional parallel after T2/T3)

- Android: Gemini Nano / AICore route check.
- iOS: Foundation Models route check.
- Capture support-by-device matrix and refusal behavior.

### T5 — Comparator run (only if T2/T3 pass)

- Run one compact comparator from:
  - Qwen3 1.7B (if export available)
  - or EmbeddingGemma + Gemma 3n local-RAG variant
- Only compare if telemetry and output quality are valid.

## Required evidence bundle for handoff

- `run_manifest.json` with:
  - device model/OS/ranking tier
  - artifact hash/url
  - provider/model/temperature/timeout
  - failure/refusal reasons
  - memory/thermal/latency summary
  - citation/schema audit snapshot

## Open questions to lock before T1

1. Confirm approved `.task` artifact for first candidate (hash + source + checksum).
2. Confirm signed model delivery channel and update/revoke path.
3. Confirm timeout/cancellation UX copy for unsupported devices.
