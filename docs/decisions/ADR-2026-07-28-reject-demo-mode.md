# ADR-2026-07-28: Reject Demo/Sample Policy Mode — First-Principles Cold-Start Fix

**Status:** Accepted
**Date:** 2026-07-28
**Updated:** 2026-07-28 — Removed camera-to-answer option after founder challenge (digitally-delivered policies make camera a minority use case). Added share-sheet and auto-import approaches.

## Context

The product audit identified the "cold start crisis" as the #1 failure mode: the app is useless until a user uploads their real policy PDF, which requires 4+ steps and 2+ minutes. An initial recommendation proposed adding a pre-loaded "sample/demo policy" so new users could instantly explore Q&A with fake data.

The founder rejected this as not aligned with first-principles / motto_v4.

## Decision

**Do not build a demo/sample policy mode.** Demo mode:
1. **Teaches the wrong behaviour** — users learn to interact with a toy, not their real data
2. **Creates trust debt** — eventually the user must transition from demo to real, and that transition has the same friction as the original problem
3. **Doesn't solve the real problem** — the cold-start friction is about getting real documents in, not about having something to look at

## First-Principles Analysis: Where Does the Policy Actually Live?

The real problem: the user has their policy document somewhere, and needs to get it into CoverWise. The question is *where*.

In India (target market), insurance policies arrive as:

| Source | Prevalence | Notes |
|--------|-----------|-------|
| **Email attachment (PDF)** | Very high | Insurers email policy documents as PDF attachments. This is the primary delivery channel for digital purchases and renewals. |
| **Insurer customer portal** | High | Users log in to the insurer's website/app to download the PDF. |
| **WhatsApp** | Growing | Some insurers now deliver policy documents via WhatsApp. |
| **Files/Downloads folder** | High | After downloading from any of the above sources. |
| **Printed hard copy** | Low / decreasing | Only for agent-sold policies; increasingly replaced by digital. |

**A camera-to-answer flow solves a problem most users don't have.** Most policies never touch paper. A camera-first approach would be used only by the minority who have a printed copy — and even they likely also received a digital copy via email.

## Correct First-Principles Solutions

The principle: **meet the user where their document already lives.** Don't ask them to come to the app with a document. Make the document come to the app through the channel it already arrived in.

### Option A: Email-to-CoverWise (Recommended — Highest Alignment)

Every user gets a unique inbound email address (e.g., `user-abc123@inbound.coverwise.app`). Forward a policy PDF received from their insurer → auto-processed → push notification: "Your policy is ready — ask questions."

- **Why it fits:** Email is where the document naturally arrives. The user doesn't change their behaviour — they forward the email they were already going to read.
- **User flow:** Open email from insurer → tap Forward → type `inbound.coverwise.app` → done. Notification arrives on phone → open app → ask questions.
- **Engineering effort:** ~3 days (inbound email handler + user-specific routing + notification trigger)
- **Dependency:** Inbound email service (SendGrid Inbound Parse, Cloudflare Email Routing, or similar)

### Option B: Android/iOS Share Sheet ("Open in CoverWise")

Register CoverWise to appear in the system share sheet for PDF files. User is viewing their policy in email/WhatsApp/Files → taps Share → "Open in CoverWise" → imported instantly.

- **Why it fits:** Zero new user behaviour to learn. Every mobile OS user knows Share. The document goes directly from its current location to the app.
- **User flow:** Open PDF in any app → tap Share → tap CoverWise → done.
- **Engineering effort:** ~2 days (Android intent filter + iOS share extension + import handler)
- **Platform APIs:** Android: `Intent.ACTION_VIEW` + file provider. iOS: share extension + `UIDocumentPickerViewController`.

### Option C: Auto-Import from Email (Long-Term, Most Ambitious)

With user permission (OAuth), bind to Gmail/Outlook to auto-detect insurance policy PDFs and offer to import them. Uses ML to identify policy documents by pattern (policy number, insurer name sections, Sum Insured values).

- **Why it fits:** Zero user effort. The document is detected and imported before the user even opens the app.
- **User flow:** Nothing. Policy appears in the app automatically. User gets a notification: "Your HDFC Life policy is ready."
- **Engineering effort:** ~1-2 weeks (Gmail API integration + PDF classifier)
- **Dependency:** Google/Gmail API OAuth scopes
- **Risk:** Privacy perception — needs clear consent flow and data handling explanation

## Implementation Priority

1. **Share sheet / "Open in"** (2 days) — Quickest to ship, no external dependencies, pure platform API
2. **Email-to-CoverWise** (3 days after share sheet) — Highest-value, needs inbound email service
3. **Auto-import** (1-2 weeks, long-term) — Most ambitious, needs careful privacy design

## Consequences

- No short-term fake-data demo — the first-principles solutions are real-data, real-value
- Share sheet and email inbound compound in value — they work for every policy, every time, not just the first session
- Most importantly: **the user's first interaction with the app involves their actual policy**, building trust and immediate utility from moment one

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-28 | Initial ADR. Rejected demo/sample policy mode for launch. Removed camera-to-answer option after founder challenge. | Cold-start crisis analysis; founder first-principles challenge. |
| 2026-07-29 | **Reclassification per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) §4.9 and §4.10.** The demo-policy rejection and the camera-not-default stance are reclassified from permanent first-principles rejections to **strategy decisions revisitable through evidence**. (1) Demo policy: still rejected for launch (a clearly-labelled read-only marketing-site/onboarding-preview example remains an experiment, not a constitutional violation; must be isolated from real user data with no fake citations/persistence/analytics/ownership state). (2) Camera: direct digital import remains preferred; camera may remain an optional fallback for printed/inaccessible documents. **What remains valid:** the original rejection for launch stands; the reclassification only prevents these from becoming permanent constitutional bans. **Status:** Accepted for launch unchanged; strategy-decision classification added. No code authorized by this entry. | Operator direction: layered doctrine stack; ADR-2026-07-29-02 reconciliation. |
