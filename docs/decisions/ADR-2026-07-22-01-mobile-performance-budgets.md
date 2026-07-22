# ADR-2026-07-22-01: Mobile Performance Budgets

## Context
- CoverWise mobile app has 60+ dependencies (ML Kit, Supabase, RevenueCat, PDF, Hive, Riverpod)
- No performance regression gates exist in CI
- Flutter APK builds without minification/enableShrinkResources
- App must launch fast and stay small for user trust and retention

## Decision
Adopt a three-layer performance budget system:

| Layer | Metric | Budget | Enforcement |
|-------|--------|--------|-------------|
| **Size** | Release APK (Android) | < 60 MB compressed | CI gate |
| **Composition** | `--analyze-size` per commit | recorded, trended | CI artifact |
| **Startup** | Cold start time | < 3 s on reference device | integration benchmark |

### Size budget: 60 MB
- Flutter's empty-shell APK is ~15 MB; CoverWise's dep chain pushes this higher
- 60 MB is generous for the current stage; tighten to 45 MB after enabling minification
- Fails CI if exceeded; developers must triage by inspecting `--analyze-size` output

### Composition artifact
- Every CI build stores `build/app/outputs/flutter-apk/app-release.apk` size and
  `--analyze-size` JSON tree map as workflow artifacts
- Enables per-commit size regression tracking without a separate pipeline

### Startup benchmark
- Integration test measures cold start (app start → first frame rendered)
- Reference: Pixel 6 API 33 emulator baseline
- Not enforced in CI yet (no hardware emulator); gated on manual device run

## Decision Drivers
| Driver | How this ADR addresses it |
|--------|---------------------------|
| **User trust** | Fast startup + small download = higher conversion |
| **CI signal** | No more silent APK bloat; regression caught immediately |
| **Actionability** | Size composition tree shows exactly which module grew |
| **Gradual hardness** | Budgets tighten over time; never loosen |

## Status: ACCEPTED
- Risk-Class: LOW (no production behavior change)
- Evidence-Tier: 2 (script passes on current build)
