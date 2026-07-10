# CoverWise Play Store Launch Assets

This note collects the repo-local evidence and launch artifacts produced from the `policy.pdf` test flow.

## Source Data

- Policy file: [`policy.pdf`](/Users/pranay/Projects/medpiper/insurance_app/policy.pdf)
- Bundled app asset: [`mobile/assets/demo/policy.pdf`](/Users/pranay/Projects/medpiper/insurance_app/mobile/assets/demo/policy.pdf)

## Evidence Bundle

- Demo video: [`docs/review/evidence/coverwise-policy-demo/coverwise_policy_demo.mp4`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/evidence/coverwise-policy-demo/coverwise_policy_demo.mp4)
- Full navigation demo: [`docs/review/evidence/coverwise-policy-demo/coverwise_full_demo_2026-07-09.mp4`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/evidence/coverwise-policy-demo/coverwise_full_demo_2026-07-09.mp4)
- Demo frame check: [`docs/review/evidence/coverwise-policy-demo/coverwise_policy_demo_frame.png`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/evidence/coverwise-policy-demo/coverwise_policy_demo_frame.png)
- QA answer evidence: [`docs/review/evidence/coverwise-policy-demo/coverwise_qa_answer.png`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/evidence/coverwise-policy-demo/coverwise_qa_answer.png)
- Late QA evidence: [`docs/review/evidence/coverwise-policy-demo/coverwise_qa_late.png`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/evidence/coverwise-policy-demo/coverwise_qa_late.png)
- Live QA state: [`docs/review/evidence/coverwise-policy-demo/coverwise_live.png`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/evidence/coverwise-policy-demo/coverwise_live.png)

## Verified App Flow

- The policy file loads in-app on the Documents screen without invoking the Android Files picker in demo mode.
- The QA screen auto-selects the policy document.
- The Q&A flow produces answers from the uploaded policy content.
- Manual screenshots confirm the live UI state during the flow.
- The Home dashboard, Documents, QA, Family, and More surfaces all render from the live app.
- The Family screen shows the seeded policy holders from the provided policy data.
- The crash caused by leaving QA mid-demo has been fixed and re-tested in the live emulator.

## Coverage Matrix

| Flow | Status | Evidence |
| --- | --- | --- |
| Home dashboard | Verified live | `coverwise_back_home.png` |
| Documents upload panel | Verified live | `coverwise_policy_demo_frame.png`, `coverwise_fresh.png` |
| QA custom question flow | Verified live | `coverwise_qa_answer.png`, `coverwise_qa_late.png`, flutter logs |
| QA demo sequence continuation after navigation | Verified live after fix | flutter logs, post-navigation screenshots |
| Family members | Verified live | `coverwise_family_try.png` |
| More options | Verified live | `coverwise_more_try.png` |
| Compare Policies quick action | Verified live | `coverwise_compare_exact.png` |
| Insurance Terms quick action | Verified live | `coverwise_terms_exact.png` |
| App launch stability after leaving QA mid-demo | Verified live after fix | flutter logs, `coverwise_after_leave_qa.png` |

## Policy Data Confirmed

- Policy number: `4214i/CPHSR/407834350/00/000`
- Policy period: `27-Aug-2025` to `26-Aug-2026`
- Insurer: `ICICI Lombard General Insurance Company Limited`
- Premium: `₹31,705`
- Policy holders: `Pranay Suyash`, `Diksha Sinha`, `Advay Sinha`

## Launch Notes

- The app branding is now `CoverWise`.
- The video and screenshots are stored in the repo so they can be reused for Play Store submission materials.
- The curated launch bundle lives in `docs/review/play_store_launch_assets/`.
- The QA screen now guards against disposal crashes during the bootstrap demo sequence.
- The Home quick actions have been verified live with exact hit-box screenshots.

## Launch Bundle

- Feature graphic: [`docs/review/play_store_launch_assets/feature_graphic.png`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/play_store_launch_assets/feature_graphic.png)
- Curated screenshot set: [`docs/review/play_store_launch_assets/screenshots/`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/play_store_launch_assets/screenshots/)
- Demo video copy: [`docs/review/play_store_launch_assets/policy_demo.mp4`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/play_store_launch_assets/policy_demo.mp4)
- Full navigation video copy: [`docs/review/play_store_launch_assets/coverwise_full_demo_2026-07-09.mp4`](/Users/pranay/Projects/medpiper/insurance_app/docs/review/play_store_launch_assets/coverwise_full_demo_2026-07-09.mp4)
- Release bundle: [`mobile/build/app/outputs/bundle/release/app-release.aab`](/Users/pranay/Projects/medpiper/insurance_app/mobile/build/app/outputs/bundle/release/app-release.aab)
