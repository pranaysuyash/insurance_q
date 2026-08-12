# Motto v5 Review — Commit Attestation

**Risk class:** standard
**Review started:** 2026-08-12T05:31:25+00:00
**Sections reviewed:** 54 / 54

---

## §0.0.1 Whole-Answer Mandate (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Reviewed full staged diff: 7 AWS deploy scripts/config removed, 4 obsolete June-2025 AWS docs moved to docs/archive/, README historical AWS section stripped (archived), reingest_documents.py App Runner URL de-hardcoded. Scoped deploy-hygiene + doc-archive commit only. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0 Boldness and Long-Term Build Mandate

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Kept the bolder long-term path: removed the dead AWS App Runner deploy entirely, preserved canonical Cloud Run (tools/deploy_cloud_run.sh). Bold but safe because canonical path already exists. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §full Integrated full-motto audit (cross-section findings vs staged diff)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Cross-section integrated audit of this commit: staged 14 paths touching deploy scripts (aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh), config (rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml), README.md, reingest_documents.py, and docs/archive/. Motive: user confirmed AWS is dead path; canonical = Cloud Run+Supabase+pgvector. Section 3 git safety: used git rm/git mv, no --force, history preserved. Section 9 artifact handling: removed dead deploy artifacts, archived obsolete docs, staged explicit paths (no blind git add -A). Section 0.13 scope: stayed within AWS-removal blast radius; did NOT touch canonical Cloud Run scripts or unrelated code. Section 0.11.1 launch-claim: removed README misleading 'Fully Operational on AWS App Runner' historical block. Section 0.2 honesty: live Redis liveness unverified from sandbox (probe inconclusive); this commit is deploy-hygiene only. Section 20: no AI co-author trailer; motto attestation trailers added. Canonical Cloud Run deploy path confirmed intact before deletion. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.1.1 'Anything Else?' Standing Review Prompt (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Ran anything-else: confirmed canonical Cloud Run path (tools/deploy_cloud_run.sh, launch_playbook) intact so deletion leaves a deploy path; flagged Redis-coupled render.yaml/docker-compose remain (separate ADR-2026-08-12-01). | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.16 Instruction Surface Freshness Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Refreshed motto attestation (attest_motto.py) for current motto_v5.md before commit; README now points only to canonical path. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.17 One Canonical Motto Rule (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Single canonical doctrine (motto_v5.md). Removed AWS deploy that contradicted README canonical Cloud Run claim; no parallel doctrine introduced. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.1 Missed-Anything Sweep

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:11+00:00

Swept staged paths + docs/archive + README for stray AWS deploy references; only intended files touched. reingest_documents.py URL de-hardcoded. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.2.1 Agent Time-Frame Honesty (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:12+00:00

Stated in-session: probe of live endpoints done this session; deletion is immediate hygiene, not a future promise. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.2 Confidence Honesty Standard

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:12+00:00

Confidence: HIGH that AWS scripts are dead (user-confirmed) and Cloud Run path intact (verified gcloud run refs). LOW/UNVERIFIED on live Redis leak (sandbox probe inconclusive) - stated, not overclaimed. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.3.1 Everything Is a Documentation Candidate (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:12+00:00

Obsolete June-2025 AWS docs treated as documentation candidates: archived (docs/archive/) rather than deleted, per user instruction. README historical section archived too. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.3 Documentation Continuity

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:12+00:00

Documentation continuity: README AWS section moved to docs/archive/README_aws_legacy_section.md with provenance note; canonical docs (launch_playbook Cloud Run) untouched. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.4.1 Completion Confidence Gate

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:12+00:00

Completion gate: this commit is a scoped removal, not a feature completion; no overclaim of production readiness. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.4.2 Multi-Pass Review

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:12+00:00

Multi-pass: (1) enumerated AWS artifacts via grep/find, (2) verified coupling of each candidate, (3) confirmed canonical Cloud Run path, (4) archived docs per user, (5) motto attestation. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.4 Acceptance Contract Before Done

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:13+00:00

Acceptance: deletion reversible via git history; canonical deploy path preserved; user approved plan. Not marking any feature done. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.5.1 Test Sensitivity Tiers (Required)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:13+00:00

N/A: no tests added/changed in this diff; change surface is deploy scripts/config + docs only. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.5 Evidence Tiers

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:13+00:00

Evidence Tier 3: verified Cloud Run canonical path exists (tools/deploy_cloud_run.sh gcloud run deploy), confirmed each deleted file AWS coupling, probed live endpoints earlier. Some claims (Redis leak) explicitly unverified. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.6 Risk-Based Verification

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:13+00:00

Risk: deleting deploy scripts could orphan deployment. Mitigated: verified canonical Cloud Run deploy path intact before deletion. Public-Redis pre-existing risk addressed separately (priority 1 probe done; ADR-2026-08-12-01). | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.7 AI Output Boundary Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:13+00:00

N/A: no AI-generated content shipped; only removed dead scripts and archived docs. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.8 Data Layer and Configuration Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:13+00:00

Config change: rag-service-config-mumbai-v6-public-redis.json (App Runner + public Redis + GCP Qdrant) deleted; reingest_documents.py URL now env-configurable (API_BASE_URL). No secret committed. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.9 Prompt, Model, and Routing Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:14+00:00

N/A: no prompt/model/routing change in this diff. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.10 Observability Is Delivery

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:14+00:00

N/A: no observability/instrumentation change; deploy scripts removed do not alter runtime telemetry. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §10 Pattern & Related-Issue Search

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:14+00:00

Pattern search: searched repo for AppRunner/elasticache/aws refs; enumerated all AWS-coupled files; excluded venv deps + Flutter appRunner false positive. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.11.1 Launch-Claim Registry (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:14+00:00

Launch-claim: removed README 'Fully Operational on AWS App Runner / 100% operational' historical block (misleading for solo launch); archived with provenance. No new launch claim added. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.11 Customer-Facing Claims Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:14+00:00

N/A: no customer-facing claim added/changed in this diff; historical AWS claim removed from README. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §11 Engineering Standards

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:14+00:00

Engineering: used git rm/git mv (safe, history-preserving), explicit staging (no blind add -A), canonical path verified before delete. Clean removal. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.12.1 Decision Records Are Appends, Not Edits (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:15+00:00

Decision log: ADR-2026-08-12-01 already records AWS-removal + Cloud Run canon; this commit executes that decision. Day-log updated. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.12.2 ADR-First Process (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:15+00:00

ADR-First: AWS removal was decided via ADR-2026-08-12-01 (Proposed) before any working-tree deletion. This commit is execution of that ADR. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.12.3 Pattern Families (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:15+00:00

N/A: no new pattern family introduced; removal follows existing deploy-hygiene pattern. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.12.4 Cut/Keep/Finish Anchored to Product Shape (v5)

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:15+00:00

Product shape: AWS App Runner deploy was not part of solo-launch product shape; Cloud Run+Supabase is. Removal aligns repo to product shape. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.12 Decision Record Requirement

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:15+00:00

Decision recorded in ADR-2026-08-12-01; commit message references it. No edit-to-record, append-only log updated. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §12 Product & Domain Alignment

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:15+00:00

Product/domain: insurance RAG; deploy target changed AWS to Cloud Run. Domain logic untouched. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §13 Analysis Expectations

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:16+00:00

Analysis: probed live endpoints (Qdrant live, Redis inconclusive) to inform removal safety; enumerated AWS coupling precisely. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.13 Scope Expansion Control

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:16+00:00

Scope control: stayed strictly within AWS-removal blast radius; did NOT modify canonical Cloud Run scripts, mobile app, or backend RAG code. Redis/Azure render.yaml left for separate ADR. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.14 Product Reality and Operator Workflow

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:16+00:00

N/A: no operator-workflow change; this is repo hygiene, deploy target swap already decided by user. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §14 Validation Rules

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:16+00:00

Validation: grep/find enumeration, per-file coupling check, Cloud Run path existence check, live-endpoint probe. No unit tests (none applicable to doc/script removal). | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §15 Documentation Rules

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:16+00:00

Documentation: archived obsolete AWS docs + README section with provenance; kept canonical Cloud Run docs. Updated day-log. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §0.15 Third-Layer Rule: Models, Pipeline, Data

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:16+00:00

N/A: no model/pipeline/data layer change; deploy scripts removed do not alter RAG pipeline. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §16 Branch / Review Branch Rules

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:17+00:00

Branch: committing to main per established workflow; this is a hygiene commit, not a feature branch. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §17 Cleanup Rules

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:17+00:00

Cleanup: removed dead AWS deploy artifacts + archived obsolete docs; left canonical path + Redis-ADR items for separate handling. Section 9 compliant. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §18 Communication Rules

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:17+00:00

Communication: summarized plan, got user approval (incl. doc-archive modification) before executing. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §19 Primary Goal

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:17+00:00

Primary goal: align repo deploy path to canonical Cloud Run, remove dead AWS artifacts, preserve history via archive. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §1 Core Context Requirements

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:17+00:00

Core context: user confirmed AWS is obsolete dead path; canonical = Cloud Run+Supabase+pgvector. Live RAG deploy confirmed up (Qdrant). This commit executes AWS removal. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §20 Commit Attribution Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:17+00:00

No AI co-author trailer (motto 20). Attestation trailers (Motto-Reviewed/SHA256/Evidence-Tier/Risk-Class) added per commit-msg gate. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §21 Code Is Evidence, Not a Boundary

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:18+00:00

Code evidence: reingest_documents.py L12 changed from hardcoded awsapprunner.com URL to os.environ.get('API_BASE_URL', localhost). Concrete, reviewable. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §22 Automated Checks Are Advisory, Not Authority

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:18+00:00

N/A: no CI/automated check changed; removal is manual hygiene. Hook-enforced motto gate still applies. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §23 Parallel-Authoring, Long-Term Continuity, and Contested Runtime Boundaries

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:18+00:00

Parallel continuity: executed per user direction in this session; day-log updated for continuity. No parallel-agent conflict. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §2 Global Working Style: Parallel Agents, Main First

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:18+00:00

N/A: single-agent execution this turn; earlier parallel-agent audit preserved via owner commit 3e170a6. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §3 Git Safety Rules

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:18+00:00

Git safety: used git rm/git mv (no --force, no reset, no push). All deletions recoverable from history. Canonical Cloud Run path verified before any deletion. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §4 Local Work Preservation Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:18+00:00

Local work preservation: staged explicit paths only (no blind git add -A); the previously-staged scripts/recovered-off-repo-work deletions kept staged separately for a later commit (not bundled here). | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §5 Stale State Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:19+00:00

Stale state: removed stale AWS deploy config that contradicted README canonical path; archived June-2025 docs no longer reflective of current architecture. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §6 'Pre-existing' Is Not an Excuse

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:19+00:00

Pre-existing not an excuse: the public-Redis misconfig was pre-existing, but this commit still removes the AWS deploy that relied on it; Redis hardening tracked in ADR-2026-08-12-01. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §7 Supersession / Canonical Replacement Rule

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:19+00:00

Supersession: AWS App Runner deploy superseded by Cloud Run (user decision + ADR). Removed the superseded artifacts; canonical path retained. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §8 Group-by-Group Preservation

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:19+00:00

Group preservation: the deferred scripts/recovered-off-repo-work deletions remain staged (not bundled); this commit is purely the AWS-removal group, isolated for clean history. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/

## §9 Artifact Handling

**Status:** PASS
**Reviewed at:** 2026-08-12T05:35:19+00:00

Artifact handling: classified each removed file - dead deploy scripts/config (deleted, recoverable), obsolete docs (archived to docs/archive/, not deleted per user), README section (archived). Staged explicit paths; no blind git add -A of tool output. | diff surface: aws_deployment.sh, deploy_aws_multiarch.sh, deploy_enhanced_rag.sh, aws_ecs_simple.sh, check_multiarch_compatibility.sh, rag-service-config-mumbai-v6-public-redis.json, infra/aws/document-storage.yaml, README.md, reingest_documents.py, docs/archive/
