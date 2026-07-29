# M10 Multi-Language Localization: Architecture and Approach

> **Status:** Implemented (complete — 3 languages, all screens migrated)
> **Date:** 2026-07-29
> **Source session:** M10 implementation sprint — multi-language support with flutter_localizations
> **Evidence tier:** Verified against source code (Tier 1)
> **Related:** [GO_LIVE_GAP_ANALYSIS](../planning/GO_LIVE_GAP_ANALYSIS.md), [App Store Listing HI](../review/coverwise_play_store_listing_hi.md)

---

## 1. Overview

M10 implemented complete multi-language support for CoverWise using Flutter's standard `flutter_localizations` + `intl` toolchain with ARB (Application Resource Bundle) files.

**Supported languages:**
1. English (en) — primary, 467+ keys
2. Hindi (hi) — 467+ keys
3. Gujarati (gu) — 467+ keys
4. Marathi (mr) — 467+ keys

**Migration status:** All screens migrated from the legacy `S.xxx` static class to ARB-based `l10n.xxx` lookups. The legacy `app_localizations.dart` (S class) was deleted. No remaining `S.xxx` references in the codebase.

## 2. Architecture

### File Structure

```
mobile/
├── lib/
│   ├── l10n/                          # Generated localization code
│   │   ├── app_localizations.dart      # Generated base class
│   │   ├── app_localizations_gen.dart  # Generated lookup methods
│   │   ├── app_localizations_gen_en.dart
│   │   ├── app_localizations_gen_hi.dart
│   │   ├── app_localizations_gen_gu.dart
│   │   └── app_localizations_gen_mr.dart
│   ├── app.dart                        # MaterialApp with localizationsDelegates
│   └── ...
├── lib/l10n/                          # ARB source files
│   ├── app_en.arb                     # English — source of truth (467 keys)
│   ├── app_hi.arb                     # Hindi
│   ├── app_gu.arb                     # Gujarati
│   └── app_mr.arb                     # Marathi
├── l10n.yaml                          # Code generation configuration
└── pubspec.yaml                       # Flutter localization dependencies
```

### Code Generation Flow

```
app_en.arb (source of truth)
    │
    ├──→ flutter gen-l10n
    │       │
    │       ├──→ app_localizations_gen.dart      (generated lookup)
    │       ├──→ app_localizations_gen_en.dart    (English values)
    │       ├──→ app_localizations_gen_hi.dart    (Hindi values)
    │       ├──→ app_localizations_gen_gu.dart    (Gujarati values)
    │       └──→ app_localizations_gen_mr.dart    (Marathi values)
    │
    └──→ app_localizations.dart (hand-written wrapper)
            └──→ AppLocalizationsOf(context) — typed accessor
```

### Key Files

| File | Purpose |
|------|---------|
| `app_en.arb` | **Source of truth** — all keys defined here first. Other locales translate from this. |
| `l10n.yaml` | Configures `flutter gen-l10n`: `arb-dir`, `output-dir`, `template-arb-file`, `output-localization-file`, `prefer-relative-imports` |
| `app_localizations.dart` | Wrapper that provides `AppLocalizationsGen.of(context)` accessor. Kept minimal — most calls go through the generated class. |

## 3. How Screens Access Translations

**Before (legacy S.xxx):**
```dart
Text(S.settingsTitle)
```

**After (ARB-based l10n):**
```dart
Text(l10n.settingsTitle)
```

**Getting the l10n object:**
```dart
final l10n = AppLocalizationsGen.of(context);
```

The `l10n` variable is obtained via `BuildContext` at the top of each build method and passed down. This is the standard Flutter pattern for scoped localization.

## 4. ARB File Format

Each `.arb` file is a JSON object with:
- `@@locale` — the locale tag (e.g., "hi")
- `@@last_modified` — date of last update
- Key-value pairs for each translatable string
- ICU MessageFormat support for plurals: `{count, plural, =1{...} other{...}}`

**Example entry:**
```json
{
  "appName": "CoverWise",
  "policyCount": "{count, plural, =1{1 पॉलिसी} other{{count} पॉलिसियाँ}}",
  "qaScreenTitle": "CoverWise से पूछें"
}
```

## 5. MaterialApp Configuration

```dart
MaterialApp(
  locale: _locale,           // from LocaleProvider
  supportedLocales: const [
    Locale('en'),
    Locale('hi'),
    Locale('gu'),
    Locale('mr'),
  ],
  localizationsDelegates: const [
    AppLocalizationsGen.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
)
```

## 6. Locale Switching

Locale switching is managed by `LocaleNotifier` (in `locale_provider.dart`):

```dart
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  void setLocale(Locale locale) {
    state = locale;
    // Persist to SharedPreferences
  }
}
```

The locale preference is persisted using `SharedPreferences` and restored on app restart. The `LocaleProvider` reads the saved preference before `runApp()` to prevent the flash-of-English on startup.

## 7. Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ARB format vs raw JSON | ARB | Standard Flutter toolchain, code generation, ICU MessageFormat for plurals |
| Generated code vs manual | Generated via `flutter gen-l10n` | Type-safe, compile-time checks, auto-updates on ARB changes |
| Locale initialization in Provider | Before `runApp()` via pre-warm | Prevents locale flash (app shows English then switches to user's saved locale) |
| fallback locale handling | `flutter gen-l10n` default | If a key is missing in a locale, English value is used. Graceful degradation. |
| Plural support | ICU MessageFormat | CoverWise has 363+ plural keys (policy count, question count, days remaining) |
| Key naming convention | `snake_case` | Consistent with Dart conventions, readable in ARB JSON |
| Brand name localization | Kept as "CoverWise" in all locales | International apps keep brand in English; confirmed in rename strategy |

## 8. Migration Summary

| Batch | Screens Migrated | S.xxx Calls Affected |
|-------|-----------------|---------------------|
| Batch 1 | Settings screen | ~55 |
| Batch 2 | Family screen | ~30 |
| Batch 3 | Profile screen | ~60 |
| Batch 4 | Documents screen | ~28 |
| Batch 5 | Q&A screen | ~55 |
| Batch 6 | Renewal calendar screen | ~31 |
| Batch 7 | Insurance cards screen | ~22 |
| Batch 8 | All remaining small screens (family_visualization, qa_packs, coverage_details_summary, privacy_security) | ~15 |
| **Total** | **All screens** | **~296 S.xxx calls migrated** |

## 9. Adding a New Locale

To add a new language (e.g., Tamil):

1. Copy `app_en.arb` → `app_ta.arb`
2. Translate all values
3. Update `@@locale` to "ta"
4. Add `Locale('ta')` to `supportedLocales` in `app.dart`
5. Run `flutter gen-l10n` to regenerate code
6. Add language option to the locale switcher UI

**Effort per locale:** ~2-3 hours (file creation + translation generation + code generation + UI update)

## 10. Known Gaps

| Gap | Impact | Status |
|-----|--------|--------|
| Localized screenshot callouts for Play Store | Per-locale screenshots improve conversion | Hindi done, Gu/Mr pending |
| Tamil & Bengali (next priority) | Large Indian-language user bases | Awaiting user geography data |
| Right-to-left (RTL) language support | Urdu, Arabic | Not needed for current locale set |

## 11. Relation to Other Documents

- [App Store Listing (Hindi)](../review/coverwise_play_store_listing_hi.md) — per-locale submission reference
- [Rename Strategy](../planning/naming/rename_strategy_and_inventory_2026-07-28.md) — includes localization rename guidance (§4.7)
- [GO_LIVE_GAP_ANALYSIS](../planning/GO_LIVE_GAP_ANALYSIS.md) — M10 marked complete

## 12. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — M10 localization architecture documented | Exhaustive documentation audit per §0.3.1 |
