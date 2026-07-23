# CoverWise Newsletter Template

> **Status:** Draft v1
> **Frequency:** Bi-weekly (every other Tuesday)
> **Audience:** CoverWise Free users (opted in) — policyholders who want smarter insurance decisions

---

## Email Layout

```
┌─────────────────────────────────────┐
│  CoverWise                           │
│  Your insurance intelligence         │
├─────────────────────────────────────┤
│                                     │
│  [HEADLINE]                          │
│                                     │
│  [PERSONALIZED GREETING]             │
│                                     │
│  [SECTION 1 — INSIGHT]               │
│                                     │
│  [POLICY SNAPSHOT — if user has docs]│
│                                     │
│  [SECTION 2 — TIP]                   │
│                                     │
│  [SECTION 3 — DID YOU KNOW?]         │
│                                     │
│  [CTA]                               │
│                                     │
├─────────────────────────────────────┤
│  Quick links · Unsubscribe · Privacy │
│  © 2026 CoverWise                    │
└─────────────────────────────────────┘
```

---

## Template

**Subject line:** `{{subject_line}}`

### Hero / Headline

```markdown
# {{headline}}

{{subheadline}}
```

**Examples:**
- Subject: `Your health policy: what's really covered`
- Headline: **Do you know what your policy excludes?**
- Subheadline: *Most people discover exclusions only when they claim. Here's how to check yours in 2 minutes.*

### Personalized Greeting

```markdown
Hi {{first_name}},
```

Fallback: `Hello there,`

### Section 1 — Policy Insight (auto-generated)

Shows the user something relevant from their own policies.

```markdown
## 🔍 Your Policy at a Glance

**{{insurer_name}} — {{policy_type}}** (starts {{policy_start_date}})

- **Sum insured:** {{sum_insured}}
- **Coverage period:** {{start_date}} → {{end_date}}
- **Next renewal:** {{renewal_date}} ({{days_until_renewal}} days away)
- **Status:** {{status}}

{{policy_insight_tip}}
```

**Example output:**

```
## 🔍 Your Policy at a Glance

**ICICI Lombard — Health Insurance** (starts 15 Jan 2026)

- Sum insured: ₹5,00,000
- Coverage period: 15 Jan 2026 → 14 Jan 2027
- Next renewal: 14 Jan 2027 (175 days away)
- Status: Active

Your policy includes maternity cover after a 24-month waiting period.
```

### Section 2 — Insurance Tip (curated)

```markdown
## 💡 Insurance Tip

{{tip_title}}

{{tip_body}}

{{tip_action}}
```

**Content themes (rotated each edition):**

| Edition | Theme | Example Tip |
|---------|-------|-------------|
| 1 | Understanding deductibles | How deductibles affect your claim amount |
| 2 | Pre-existing conditions | Waiting periods explained |
| 3 | Riders & add-ons | Which riders are worth the extra premium? |
| 4 | Claim process | What to do immediately after a hospitalization |
| 5 | Network hospitals | Why staying in-network matters |
| 6 | Renewal grace period | What happens if you miss the renewal date |
| 7 | Co-pay clauses | How co-pay affects out-of-pocket costs |
| 8 | Family floater vs individual | Which one saves you more? |
| 9 | Porting your policy | When and how to switch insurers |
| 10 | Cashless vs reimbursement | Understanding the claim settlement process |

### Section 3 — Did You Know? (trivia)

```markdown
## ❓ Did You Know?

{{trivia_fact}}
```

**Examples:**
- "You can port your health insurance policy to a different insurer without losing waiting period credit."
- "IRDAI mandates insurers to settle cashless claims within 1 hour if all documents are in order."
- "A co-pay clause of 10% means you pay ₹10,000 of a ₹1,00,000 claim."

### Call-to-Action

```markdown
---
**[{{cta_text}}]({{cta_url}})**

_{{cta_subtext}}_
---
```

**CTA variants (rotated):**

| Context | CTA Text | URL | Subtext |
|---------|----------|-----|---------|
| New user | Upload your first policy | coverwise://upload | It takes 30 seconds |
| Has policies | Ask a question about your coverage | coverwise://qa | What's covered and what's not? |
| Has multiple | Compare your policies side-by-side | coverwise://compare | See your full coverage picture |
| Renewal near | Set a renewal reminder | coverwise://reminders | Never miss a renewal date |
| Gap detected | Check your coverage gaps | coverwise://gaps | Find uninsured risks |

### Footer

```markdown
---

*You received this email because you subscribed to CoverWise newsletter tips.*

**[Unsubscribe]({{unsubscribe_url}})** · **[Privacy Policy]({{privacy_url}})** · **[Manage Preferences]({{preferences_url}})**

© 2026 CoverWise. CoverWise is an insurance information service, not an insurer.
We do not sell insurance. Your data stays on your device and is never shared with third parties.
```

---

## Personalisation Fields

| Field | Source | Example |
|-------|--------|---------|
| `{{first_name}}` | User profile (optional) | "Pranay" |
| `{{insurer_name}}` | Extracted policy data | "ICICI Lombard" |
| `{{policy_type}}` | Extracted policy data | "Health Insurance" |
| `{{sum_insured}}` | Extracted policy data | "₹5,00,000" |
| `{{start_date}}` | Extracted policy data | "15 Jan 2026" |
| `{{end_date}}` | Extracted policy data | "14 Jan 2027" |
| `{{renewal_date}}` | Computed | "14 Jan 2027" |
| `{{days_until_renewal}}` | Computed | "175" |
| `{{status}}` | Computed | "Active" |
| `{{policy_insight_tip}}` | Generated | "Your policy includes maternity cover after a 24-month waiting period." |
| `{{subject_line}}` | Generated | "What your health policy really covers" |
| `{{headline}}` | Generated | "Do you know what your policy excludes?" |
| `{{subheadline}}` | Generated | "Most people discover exclusions only when they claim." |
| `{{tip_title}}` | Curated | "Understanding Waiting Periods" |
| `{{tip_body}}` | Curated | "Most health insurance policies have a 2-4 year waiting period..." |
| `{{tip_action}}` | Curated | "Open your policy in CoverWise to check your waiting period status." |
| `{{trivia_fact}}` | Curated | "You can port your policy without losing waiting period credit." |
| `{{cta_text}}` | Contextual | "Ask about your coverage" |
| `{{cta_url}}` | Contextual | "coverwise://qa" |
| `{{cta_subtext}}` | Contextual | "What's covered and what's not?" |

---

## Implementation Notes

1. **Dynamic fields** (`{{insurer_name}}`, `{{policy_type}}`, etc.) are populated at send time by reading the user's Hive-stored policy data via the existing `PolicyExtractionService`.

2. **Content rotation** of tips/trivia/CTAs is managed by a simple `NewsletterContentService` that selects from curated pools based on the user's policy count, upcoming renewals, and detected coverage gaps.

3. **Consent check** at send time — verify `ConsentLedger.hasConsent(ConsentPurpose.marketingEmails)` before queueing the email.

4. **Unsubscribe** is handled by the existing `NewsletterService.unsubscribe()` which revokes consent in the ledger.

5. **Delivery** — In the current version (v1), the newsletter content is generated and stored locally. The user can view it through the app. A future version will integrate with a transactional email service (or the user's own email client) for actual delivery.

---

*Template version 1.0 | Last updated: July 2026*
