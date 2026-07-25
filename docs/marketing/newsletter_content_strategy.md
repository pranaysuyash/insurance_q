# CoverWise Newsletter Content Strategy

> **Goal:** Drive engagement retention by delivering actionable insurance intelligence to users' inboxes.
> **Strategy:** Personalise every edition using the user's own policy data. Educate, don't sell.
> **CoverWise is a policy information assistant — we help users understand their insurance, not buy new policies.**

---

## 1. Objectives

| Objective | Metric | Target |
|-----------|--------|--------|
| Retain active users | Newsletter open rate | >40% |
| Re-engage lapsed users | Return-to-app rate after newsletter | >15% |
| Increase Q&A usage | Q&A sessions within 7 days of newsletter | +20% |
| Grow policy library | New policy uploads within 7 days | +10% |
| Maintain trust | Unsubscribe rate | <1% per edition |

---

## 2. Audience Segments

### Segment A: New Users (0 policies)
**Goal:** Onboarding + first upload
**Content:** General insurance education, benefits of using CoverWise
**CTA:** Upload your first policy
**Frequency:** 1 email after 3 days of no upload, then move to Segment B

### Segment B: Active Users (1+ policies)
**Goal:** Deeper engagement, policy understanding
**Content:** Policy-specific insights, insurance education personalised to their coverage
**CTA:** Ask a question about your coverage
**Frequency:** Bi-weekly

### Segment C: Multiple Policy Users (3+ policies)
**Goal:** Cross-policy analysis, coverage gap discovery
**Content:** Comparison insights, gap analysis highlights
**CTA:** Check your coverage gaps
**Frequency:** Bi-weekly

### Segment D: Renewal-Near Users (within 60 days)
**Goal:** Renewal preparedness
**Content:** Renewal checklist, porting information, grace period reminders
**CTA:** Set a renewal reminder
**Frequency:** Weekly (3 emails before renewal date)

---

## 3. Editorial Calendar — First 10 Editions

| # | Theme | Tip Topic | Trivia | Target Segment |
|---|-------|-----------|--------|---------------|
| 1 | Getting Started | How to read your policy document | 70% of policyholders don't read their policy | A, B |
| 2 | Understanding Coverage | What "sum insured" really means | IRDAI's 1-hour cashless claim rule | B |
| 3 | Exclusions & Limitations | Common health insurance exclusions | Policy exclusions are not hidden — they're in Section 4 | A, B |
| 4 | Waiting Periods | Pre-existing disease waiting periods explained | You can port policies without losing waiting period credit | B, C |
| 5 | Deductibles & Co-pay | How deductibles affect your claim | Only 12% of policyholders understand their co-pay clause | B, C |
| 6 | Family Floater vs Individual | Which saves you more? | Family floaters cover 4 members at ~40% less than 4 individual plans | C |
| 7 | Renewal Season | What happens if you miss renewal | Most insurers offer a 15-30 day grace period | D |
| 8 | Add-ons & Riders | Are riders worth it? | Critical illness riders can double your coverage for ~15% extra premium | B, C |
| 9 | Claim Process | Cashless vs reimbursement | Document everything — photos, bills, discharge summary | B |
| 10 | Coverage Check | Annual policy health check | You should review your coverage every 12 months | All |

---

## 4. Content Rules

### Do
- Use plain language (9th-grade reading level)
- Anchor every tip in the user's own policy data
- Link back to the app for deeper actions (coverwise:// deep links)
- Keep each edition to 3 sections max
- Use the user's policy details for all personalisation fields

### Don't
- Recommend specific insurers or plans
- Use fear-based messaging ("You're not covered for X")
- Share user policy data between accounts
- Send more than 1 email per week per user
- Include affiliate or commission-based links

---

## 5. Personalisation Logic

```python
# Pseudocode for newsletter personalisation at send time

def personalise(user, policies):
    newsletter = NewsLetter()
    newsletter.greeting = f"Hi {user.first_name or 'there'},"

    if not policies:
        # Segment A: onboarding tip
        newsletter.headline = "Insurance doesn't have to be confusing"
        newsletter.section1 = onboarding_tip()
        newsletter.cta = ("Upload your first policy", "coverwise://upload")
    else:
        # Pick the policy closest to renewal or most recently uploaded
        primary = sorted(policies, key=lambda p: p.renewal_date or p.uploaded_on)[0]

        newsletter.policy_snapshot = format_policy(primary)
        newsletter.section1 = policy_insight(primary)

        # Pick tip based on rotation index
        newsletter.section2 = curated_tip(
            get_segment(primary, policies),
            edition_number
        )

        # Pick CTA based on user state
        newsletter.cta = pick_cta(policies)

        if any(p.days_to_renewal < 60 for p in policies):
            newsletter.section3 = RENEWAL_REMINDER

    newsletter.section3 = trivia_fact(edition_number)
    newsletter.unsubscribe_url = generate_unsubscribe_token(user.id)

    return newsletter
```

---

## 6. Key Principles

### Frequency over Perfection
- Bi-weekly is enough to stay top-of-mind without being intrusive
- Each edition improves as we learn what users open and click

### Personalisation is the Moat
- Generic insurance tips have low value — every user has 20 unread promotional emails
- Tips anchored in "your policy" cut through the noise because they're uniquely relevant
- Users who see their own policy data in an email are reminded that CoverWise has their data safe

### Trust > Conversion
- We do not recommend insurers or plans
- We do not share data
- Every email reinforces: "CoverWise is on your side"
- Newsletter is not a revenue channel — it's a retention and engagement channel

---

## 7. Measurement & Optimisation

### Tracked Events (via AnalyticsService)

| Event | Properties | Purpose |
|-------|------------|---------|
| `newsletter_open` | edition, segment | Open rate tracking |
| `newsletter_cta_click` | edition, cta_type | CTA effectiveness |
| `newsletter_unsubscribe` | edition | Churn tracking |
| `app_open_after_newsletter` | edition, hours_delayed | Re-engagement measurement |

### Optimisation Levers

| Lever | Test | Success Metric |
|-------|------|----------------|
| Subject line | Personalised vs generic | Open rate |
| Send time | Tuesday 10am vs Thursday 4pm | Open rate |
| CTA placement | Top vs bottom | Click-through rate |
| Tip length | 50 words vs 150 words | Read-to-bottom rate |
| Personalisation depth | Policy name only vs full snapshot | Engagement score |

---

## 8. Implementation Roadmap

### v1 (current — local only)
- [x] NewsletterService (Hive-backed email storage + consent)
- [x] NewsletterSignupSheet (UI for subscribe/unsubscribe)
- [x] Consent tracking via ConsentLedger.marketingEmails
- [ ] Newsletter content rendered in-app (viewable from settings)
- [ ] NewsletterContentService (selects tips based on user state)

### v2 (backend sync)
- [ ] Newsletter content generated server-side
- [ ] Email delivery via transactional email service
- [ ] Unsubscribe token management
- [ ] Open/click tracking

### v3 (personalised)
- [ ] Policy-specific insight section (uses extraction data)
- [ ] Renewal-triggered reminder emails
- [ ] Coverage gap-triggered education
- [ ] A/B testing framework

---

*Strategy version 1.0 | Last updated: July 2026*
