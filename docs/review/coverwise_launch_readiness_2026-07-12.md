# CoverWise Launch Readiness

**Target:** late July 2026  
**Product:** CoverWise  
**Purpose:** single launch handoff for the website, Play Store, acquisition copy, analytics, trust language, and release gates.

## Launch thesis

Insurance documents are difficult to use when people need answers quickly. CoverWise turns a policy document into a plain-language reference: what is covered, what is excluded, what evidence matters, and what to ask next.

The product should earn trust through grounded explanations, visible source context, and careful language. It must not imply that an insurer has approved a claim, that coverage is guaranteed, or that CoverWise replaces the policy or professional advice.

## Completed in the local app

- Branded CoverWise homepage and product positioning.
- SEO title, description, canonical URL support, Open Graph, Twitter cards, favicon, sitemap, and robots file.
- Structured data for the web application and FAQ content.
- Upload-and-question demo flow on the live frontend.
- Play Store listing and launch asset copy.
- Branded social preview and favicon assets.
- README, documentation landing page, and user guide alignment.

## Release blockers requiring owner input

These are intentionally not fabricated in code or copy:

| Item | Required value | Owner | Closure evidence |
|---|---|---|---|
| Production URL | Final HTTPS public origin | Product/engineering | `PUBLIC_SITE_URL` set and production sitemap checked |
| Legal identity | Company/operator name and jurisdiction | Product/legal | Approved privacy policy and terms |
| Support channel | Monitored support email or help URL | Product/operations | Support link tested end to end |
| Data retention | Upload retention, deletion, and account policy | Product/legal/engineering | Approved policy matches runtime behavior |
| Store account | Play Console app identity and signing configuration | Release owner | Internal test build uploaded |
| App screenshots | Real device captures from the release build | Product/design | Required Play Console sizes present |
| Analytics destination | Measurement ID/provider and privacy settings | Product/engineering | Events visible in a test property |

## Definition of launch-ready

- A new visitor understands the product, its limits, and the first action within five seconds.
- Every customer-facing protection or insurance statement is conditional and evidence-based.
- Upload, extraction, question answering, failure, and retry states are understandable to the user.
- The public origin, support route, privacy policy, terms, and deletion path are real and tested.
- The Android build uses the same CoverWise name, promise, icon, and tone as the website.
- Store metadata fits the actual release build and does not promise unsupported capabilities.
- Analytics can distinguish landing, upload start, upload success, first question, answer view, and support intent without logging document contents.
- A rollback/recovery owner exists for upload or extraction failures.

## July execution sequence

### Week 1: truth and trust

- Freeze the product promise and prohibited claims.
- Supply the production URL, legal identity, support route, and retention policy.
- Approve privacy and terms copy.
- Confirm the release build's actual file types, limits, languages, and account requirements.

### Week 2: conversion and proof

- Connect analytics using the event spec in `coverwise_analytics_event_spec.md`.
- Capture real mobile screenshots for the Play Store listing.
- Run a five-person comprehension test: ask users what CoverWise does, what it cannot do, and what happens to their document.
- Fix any mismatch between the homepage, app UI, API errors, and store listing.

### Week 3: release candidate

- Run the full upload-to-answer flow with representative policy PDFs.
- Test invalid files, empty files, OCR failure, timeout, retry, and refresh behavior.
- Submit an internal Play test build.
- Check public metadata from the production origin.

### Final days: staged launch

- Publish the website first and monitor upload success, answer success, and support contacts.
- Release to a small Play test cohort.
- Review user questions and failure logs daily.
- Expand distribution only after the release owner signs the acceptance checklist below.

## Final acceptance checklist

- [ ] Production URL is configured and HTTPS works.
- [ ] Privacy policy is public, linked, and matches actual data handling.
- [ ] Terms are public, linked, and reviewed.
- [ ] Support channel is monitored.
- [ ] Website copy is approved.
- [ ] Play Store title, short description, full description, and screenshots are approved.
- [ ] App icon and social preview are approved.
- [ ] Upload and question flows are tested with real representative documents.
- [ ] Failure and retry states are tested.
- [ ] Analytics events are visible without sensitive document text.
- [ ] Crash/error monitoring is enabled.
- [ ] Internal Play test is complete.
- [ ] Product owner approves staged public launch.

## Known limitation

This document cannot certify production readiness for legal, store, analytics, or deployment items that depend on credentials, real identity, or external console access. Those items have explicit owners and evidence requirements above.
