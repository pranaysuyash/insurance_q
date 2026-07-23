# Onboarding Flow Audit & Polish

**Date:** 2026-07-23  
**Audit scope:** Splash → Onboarding → First-run experience (first_upload_cta)  
**motto_v3 alignment:** Every screen must make the scope clear, build trust, and minimize friction.

---

## Current flow

```
SplashScreen (1100ms branded splash)
  → OnboardingScreen (3 page carousel)
      Page 1: "Turn policy pages into plain answers." + "We process it securely..."
      Page 2: "Ask your policy, not the internet." + clear answers from actual policy
      Page 3: "Know what needs attention next." + "without selling you another policy"
      [Last page footer]
        - Anonymous usage stats toggle (opt-in)
        - Privacy Policy / Terms of Service links
        - Terms acceptance checkbox (required)
        - "Add my first policy" button
  → FirstUploadCta (dashboard empty state, if user skips upload)
```

## Audit findings

### ✅ What's working well

| Item | Status | Detail |
|---|---|---|
| Splash branding | ✅ | CoverWise logo + tagline + animated entry |
| Value prop clarity | ✅ | 3 clear pages (Understand → Ask → Stay Ready) |
| Analytics consent | ✅ | Explicit opt-in toggle with explanation on last page |
| Privacy/ToS links | ✅ | Clickable links on last page |
| Terms checkbox | ✅ | Required before proceeding (compliance) |
| CTA directness | ✅ | "Add my first policy" goes straight to file picker |
| Reduced motion | ✅ | Supports text scaler and reduced motion |
| Dark mode | ✅ | Uses Theme.of(context) |

### ❌ Gaps found

| # | Gap | Severity | Suggested fix |
|---|---|---|---|
| 1 | **No scope disclaimer** — nowhere during onboarding does it explicitly say "CoverWise is an information broker, not an insurer." The third page says "without selling you another policy" but this is implicit, not a clear scope disclaimer. | **P0** | Add a visible info-broker scope disclaimer to the onboarding last page (below terms checkbox), and to the FirstUploadCta widget. |
| 2 | **Third page copy too vague** — "Know what needs attention next" describes staying on top of renewals/prep notes but doesn't mention the info broker role. | **P1** | Update third page description to include info-broker language. |
| 3 | **FirstUploadCta missing scope disclaimer** — the dashboard empty state shown after onboarding doesn't include any scope disclaimer either. | **P1** | Add disclaimer text to FirstUploadCta. |
| 4 | **Page 1 says "We process it securely"** but privacy consent is on last page — users might see processing language before understanding their privacy rights. | **P2** | Reorder page content or add privacy trust cues earlier. |

## Polish plan

### P0 (must fix)
1. Add scope disclaimer to onboarding last page: "CoverWise is an information broker, not an insurance provider or agent. All policy information is for reference only."
2. Add scope disclaimer to FirstUploadCta

### P1 (should fix)
3. Update third onboarding page description to be more explicit about info broker and reference-only nature
4. Update third page eyebrow from "STAY READY" to something more descriptive

### P2 (nice to have)
5. Add privacy trust indicator to first onboarding page

---

## Implementation notes

- Use `Text` widget with `style: theme.textTheme.bodySmall` for the disclaimer
- Position it below the terms checkbox on the last page
- Use muted color (onSurfaceVariant) to keep it readable but not alarmist
- Add same disclaimer to `first_upload_cta.dart` below the privacy reassurance row
- No new dependencies needed
