# Product Identity and Positioning Statement

> **Status:** Operating reference (consolidates positioning from multiple source documents)
> **Date:** 2026-07-29
> **Source:** Founder clarification — reiterated multiple times across sessions. The positioning was scattered across wedge docs, legal docs, play store listing, and campaign copy. This doc consolidates it into one canonical reference.
> **Evidence tier:** Founder directive (Tier 0)
> **Related:** [Product Constitution](PRODUCT_FIRST_PRINCIPLES.md), [Product Wedge](../../architecture/FIRST_PRINCIPLES_WEDGE.md), [Campaign Copy](../../review/coverwise_campaign_copy_pack.md)

---

## 1. Canonical One-Liner

> **CoverWise helps you understand your insurance policy — that's all.**
> We do not sell, broker, recommend, or process insurance. We are not an insurer, broker, TPA, or financial advisor. We are a comprehension tool for policies you already own.

---

## 2. What CoverWise IS

| Attribute | Statement |
|-----------|-----------|
| **Product type** | Personal insurance knowledge workspace / comprehension tool |
| **What it does** | Upload a policy PDF → see what it covers → ask questions with cited answers |
| **Who it's for** | Individual consumers (solo use) with insurance policies who want to understand them |
| **Value prop** | Every answer cites its source. No hallucination. No legalese to dig through. |
| **Tone** | Honest, grounded, transparent. Shows what it knows AND what it doesn't know. |
| **Scale** | Solo-operator product. No enterprise features, no SSO, no ISO certifications. |
| **Business model** | Freemium — comprehension is free; convenience and depth are paid |

---

## 3. What CoverWise is NOT

This section is important — it defines the boundaries that the product refuses to cross.

### 3.1 Not an Insurer, Broker, or TPA

> CoverWise does not sell insurance, process claims, provide financial advice, or act as an insurer, insurance agent, broker, or TPA (Third Party Administrator).

This is the foundational boundary. Every screen, prompt, and marketing claim must reflect this. The disclaimer appears in:
- Terms of Service (ToS)
- Privacy Policy
- Play Store listing description
- Campaign copy
- App footer (`profileFooter` in ARB: "CoverWise आपकी पॉलिसियों को समझने में मदद करता है। यह बीमा नहीं बेचता।")

### 3.2 Not Enterprise

> CoverWise is a solo/consumer product. No enterprise features.

| Feature | Status | Reason |
|---------|--------|--------|
| SSO/SAML | ❌ Not building | Enterprise-only feature; solo product doesn't need it |
| Team/org accounts | ❌ Not building | Multi-user org management is outside the wedge |
| Role-based access control | ❌ Not building | Single user, single principal |
| ISO 27001 / SOC 2 | ❌ Not pursuing | Enterprise compliance certifications are irrelevant for a consumer app |
| Audit trails for compliance | ❌ Not building beyond what the product needs | The consent ledger and operator-trust model exist for product integrity, not enterprise compliance |

**This does not mean the product quality is lower.** The product follows rigorous engineering (700+ tests, grounded RAG, citation verification, encrypted storage, consent ledger). But it does not chase enterprise certifications or features that only serve org buyers.

### 3.3 Not Financial Advice

> CoverWise provides explanations of what a policy document says. It does not tell you what to do, what to buy, or whether your coverage is adequate.

- **Prohibited:** "You should increase your sum insured" / "You are underinsured" / "This policy is not right for you"
- **Allowed:** "Your policy shows a sum insured of ₹5,00,000. The policy does not mention flood coverage."
- **The hard rule:** Absence of extraction is not absence of coverage. "Not found in the uploaded policy" is not the same as "not covered."

### 3.4 Not a Generic AI Document Reader

> CoverWise is insurance-specific. It understands policy types (health, motor, life, home, travel, marine) and extracts type-specific fields. It is not a "upload any document and chat about it" tool.

### 3.5 Not a Shopping or Comparison Tool

> CoverWise does not help users buy insurance, compare insurers, find the best policy, or switch providers. Neutral, source-cited comparison of policies the user already owns is allowed. Shopping comparison is not.

### 3.6 Not a Claims Processor

> CoverWise shows what the policy says about claims procedures and provides helpline numbers from the policy document. It does not file, adjudicate, or represent claims.

### 3.7 Not a Medical Record System

> While health insurance policies include medical information, CoverWise is not a medical records platform. Health data is processed only as part of policy comprehension and is subject to the same deletion/export/access controls as any other policy data.

---

## 4. Identity Hierarchy

```
Personal insurance comprehension tool
├── NOT an insurer, broker, TPA, or financial advisor
├── NOT enterprise software
├── NOT a generic document reader
├── NOT a shopping/comparison engine
├── NOT a claims processor
└── NOT a medical records system
```

## 5. Marketing Claims That Are Always True

These claims are safe to make (they map to verified implementation):

- ✅ "Every answer cites its source" — citation verification with `fully_backed` / `partially_backed` / `abstained` badges
- ✅ "Understand your policy in plain language" — type-specific extraction + coverage summary
- ✅ "Available in Hindi, Gujarati, Marathi" — M10 implemented
- ✅ "We do not sell insurance" — constitutional boundary
- ✅ "Your data is encrypted" — AES-256 for local metadata; TLS in transit
- ✅ "You can delete your account and data" — full deletion endpoint tested

## 6. Marketing Claims That Must NEVER Be Made

| Claim | Why It's Prohibited |
|-------|---------------------|
| "Best insurance policy" | Implies recommendation |
| "We'll get your claim approved" | Implies claims processing |
| "You're underinsured" | Implies adequacy judgement |
| "Bank-grade security" | Overclaim — AES-256 only on metadata DEK, not source files |
| "Instant insurer decision" | CoverWise doesn't make insurer decisions |
| "Never pay out of pocket" | Financial advice / guarantee |
| "We replace your insurer" | Plain false — CoverWise is a comprehension tool, not insurance |
| "Compare and save" | Implies shopping comparison |

## 7. Source Documents

This identity statement is derived from and consistent with:

| Source | Key Section |
|--------|-------------|
| `PRODUCT_FIRST_PRINCIPLES.md` §1, §3, §4 | Canonical product statement, Gate C (product role), Principle 4 |
| `FIRST_PRINCIPLES_WEDGE.md` §1, §4 | Wedge definition, rejected features |
| `coverwise_campaign_copy_pack.md` | Prohibited claims list, support response baseline |
| `coverwise_play_store_listing.md` §3 | Full description disclaimer |
| `terms_of_service.md` | "We are not an insurer..." clause |
| `privacy_policy.md` | "We do not sell insurance..." clause |

## 8. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — consolidated positioning from 7 source documents | Exhaustive documentation audit per §0.3.1 — founder repeatedly clarified "we are not an insurer/broker/tpa, no enterprise, solo only" across multiple sessions with no single reference document |
