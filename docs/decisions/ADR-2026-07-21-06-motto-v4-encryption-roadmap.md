# ADR-2026-07-21-06: MotoV4 Encryption Roadmap

## Context
- We're implementing principal-key encryption across all data domains
- Goal: Create climate-resistant, durable system that aligns with digital Bill of Rights
- Must follow motto_v4 principles: bold, durable, first-principles solutions

## Decision Drivers
| Driver | Requirement |
|--------|-------------|
| **Durability** | Zero decay over time, withstands technological changes |
| **Bias Resistance** | Rationale must survive adversarial review cycles |
| **Systemic Integrity** | No trading off one quality axis for another |
| **Forward Alignment** | Build roads that don't need tearing up |

## Capacity Allocation (20-year vision)
- **Decade 1-5**: Encryption infrastructure (completed)
- **Decade 5-10**: Intelligence orchestration (Option A)
- **Decade 10-15**: Economic resilience infrastructure (Option B)
- **Decade 15-20**: Governance permanence (Option C)

## Status: ACCEPTED
- Risk-Class: HIGH (non-negotiable core architecture)
- Evidence-Tier: 3 (provable via endured deployments)
- Motto-SHA256: f1e4b338f1e313b7701e796b099cd9024b81191f3fb4804bf44303785a9e3a94

## Consequences
1. **Bold Contract Architecture**: All services contract through evidence layer
2. **Durable Enum Hierarchy**: Future-proof capability classification
3. **First Principles Tokenomics**: Step rarity defines economic substance

---

### Implementation Approach

We'll implement strategic pillars in sequence:

1. **Pillar 1: Document Intelligence Pipeline** 
   - Wire document_intelligence_router + evidence_contract through principal-key encrypted storage
   - Implement model_run_results migration with DEK-scoped access
   - End-to-end test: upload → classify → extract → store encrypted → retrieve

2. **Pillar 2: Subscription/Billing Hardening**
   - Implement revenuecat_webhook_handler + subscription_writeback_handler with outbox pattern
   - Use principal-key DEK for billing ledger encryption at rest
   - Store idempotency keys in encrypted Hive box

3. **Pillar 3: Data Retention/Governance**
   - Execute governed_evaluation_and_retention_execution ADR
   - Implement automated TTL + legal hold on encrypted artifacts
   - Write audit trail to encrypted analytics buffer

Each pillar follows the same whenever-merit-debt structure:
1. Assess long-standing threat surfaces
2. Define minimal viable change
3. Execute boldly but durably
4. Verify with multi-turn evidence

Documentation must outlive implementations: every ADR must include climate-resistance rationale.

---