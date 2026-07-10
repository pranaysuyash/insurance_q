# Policy Demo Verification

Verified on the Android emulator in `insurance_app`.

## Final evidence

- Video: `docs/review/evidence/coverwise_full_demo_v3.mp4`
- Contact sheet: `docs/review/evidence/coverwise_full_demo_v3_contact_sheet.png`
- QA history screenshot: `docs/review/evidence/v3_history.png`
- Compare sheet screenshot: `docs/review/evidence/v3_compare_after_terms.png`
- Terminology modal screenshot: `docs/review/evidence/v3_compare.png`

## What was verified

- Dashboard renders with the current policy library state.
- QA history shows answered policy questions and answer snippets.
- Compare Policies opens a real policy comparison bottom sheet.
- Insurance Terms opens a real terminology modal.

## Notes

- The QA flow is guarded so it stops when the QA screen is no longer active.
- The app still falls back to local policy answers when the backend returns quota/embedding errors, but the user-visible answer remains populated.
