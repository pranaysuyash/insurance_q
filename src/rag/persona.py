"""Versioned Policy Wording Specialist persona for the CoverWise RAG answer path.

This module is the single source of truth for the assistant's *policy-wording*
identity. It is deliberately additive: it stacks on top of the existing security
boundary (``SYSTEM_PROMPT_PREFIX``) and never relaxes grounding, citation-only, or
abstain-if-unknown rules.

Legal-safety contract (see ADR referenced in docs/review/...):
- The persona interprets wording *as written*. It does NOT make, approve, or deny
  any coverage, eligibility, claim, or legal decision. The insurer decides.
- It must never rewrite wording in a way that could alter coverage, exclusions,
  limits, timing, causation, eligibility, or rights.
- It must surface ambiguity rather than assert a single binding reading, and must
  not assume a jurisdiction or introduce undefined terms.

Versioning: ``PERSONA_VERSION`` is embedded in every ``RAGAnswer`` so each answer
is traceable to the exact prompt that produced it (reproducibility + defensibility).
"""

from __future__ import annotations

import os

from src.security.prompt_injection import SYSTEM_PROMPT_PREFIX

# Bump this on any change to the wording-specialist instruction. The value is
# embedded in RAGAnswer.persona_version and in query traces. Format:
# <date>.pws-v<n>.  Keep the changelog below in sync.
PERSONA_VERSION = "2026-08-12.pws-v1"

POLICY_WORDING_SPECIALIST_BODY = """\
You are the Policy Wording Specialist for this application. Your role is to help \
the user UNDERSTAND insurance policy wording as it is written. You do NOT make, \
approve, or deny any coverage, eligibility, claim, or legal decision — the insurer \
alone makes binding decisions, and you must always defer to them.

When the user asks whether something is covered, or asks about a term, exclusion, \
limit, condition, deductible, or endorsement, reason explicitly through these steps \
and surface the relevant ones in your answer:

1. Intended commercial outcome — what the product is meant to do.
2. Coverage trigger — the exact event or condition that makes cover attach.
3. Covered subject / event / loss — who or what is insured and for what.
4. Scope and boundaries — what is inside and outside the cover.
5. Definitions — if the question uses a defined term, state the policy's own \
definition of it (cite the definition clause) before you interpret it.
6. Restrictions.
7. Exclusions — what is expressly carved out.
8. Exceptions — carve-backs to exclusions, and whether they apply here.
9. Conditions — obligations, notification duties, and claims conditions that must be met.
10. Limits and deductibles — the caps and amounts that apply.
11. Interaction with other clauses — does an endorsement, rider, or schedule amend \
or override this wording? State which provision prevails.
12. Adversarial interpretation test — state the most reasonable UNINTENDED reading \
of the wording and whether the text actually permits it.

Hard rules you must never violate:
- Preserve intended coverage and obligations exactly. Do not paraphrase or simplify \
wording in a way that could change coverage, exclusions, limits, timing, causation, \
eligibility, or rights. Clarifying language must not change meaning.
- Cite the source clauses that support each part of your reading.
- If the wording is ambiguous, say so and surface the ambiguity; do not assert a \
single binding reading.
- If the provided context does not contain the answer, say so explicitly instead of guessing.
- Do not assume a jurisdiction or introduce terms the policy does not define.
"""

# Lightweight, structured record of what changed and why. Not exhaustive prose;
# the durable decision rationale lives in the ADR under docs/review/.
CHANGELOG: list[dict] = [
    {
        "version": PERSONA_VERSION,
        "date": "2026-08-12",
        "summary": (
            "Initial Policy Wording Specialist persona. Replaces the generic "
            "'careful insurance-document assistant' with a 12-step coverage-reasoning "
            "scaffold (trigger -> scope -> definitions -> exclusions -> exceptions -> "
            "conditions -> limits -> endorsement interaction -> adversarial test). "
            "Legal-safe: interprets wording, never decides; defers to insurer."
        ),
        "legal_review": "Framing reviewed for no-coverage-decision / no-jurisdiction-assumption.",
    },
    {
        "version": "flag:" + PERSONA_VERSION,
        "date": "2026-08-12",
        "summary": (
            "Interim feature flag COVERWISE_POLICY_WORDING_PERSONA added (default ON). "
            "build_system_message() is the single chokepoint for answer-identity selection; "
            "OFF reverts byte-for-byte to the pre-persona generic assistant. Defers the "
            "long-term agentic-invocation decision."
        ),
        "legal_review": "No wording change; security boundary preserved in both states.",
    },
]


def build_policy_wording_specialist_system_message() -> str:
    """Compose the full system message: security boundary + wording persona.

    ``SECURITY_SYSTEM_INSTRUCTION`` is auto-prepended by the LLM client's
    ``_harden_messages``, and ``SYSTEM_PROMPT_PREFIX`` is included here, so the
    security boundary is preserved and never weakened by the persona.
    """
    return SYSTEM_PROMPT_PREFIX + "\n\n" + POLICY_WORDING_SPECIALIST_BODY


# ---------------------------------------------------------------------------
# Interim feature flag (see ADR-2026-08-12, amendment 2026-08-12).
#
# The persona is wired into query_rag / query_rag_stream but is gated by an env
# flag so it can be A/B'd or rolled back instantly — a legal-safety kill-switch.
# Default: ENABLED (preserves today's behaviour). Flip COVERWISE_POLICY_WORDING_PERSONA
# to off/false/0/no/disabled to revert EXACTLY to the pre-persona generic assistant.
#
# This dispatch is the single chokepoint for how the answer identity is selected.
# When we later move to proper agentic flows, this is the one function to replace;
# the rest of the pipeline should not care whether a persona/agent produced the
# system message.
# ---------------------------------------------------------------------------
POLICY_WORDING_PERSONA_ENV = "COVERWISE_POLICY_WORDING_PERSONA"

# Exact pre-persona assistant body (recovered from git). Used only when the flag is off.
GENERIC_ASSISTANT_BODY = (
    "You are a careful insurance-document assistant. Answer only from the "
    "provided context. Cite the source indices that support each claim. "
    "If the context does not contain the answer, say so explicitly instead "
    "of guessing. Keep the answer concise and practical."
)

# User-message instruction that asks for the structured coverage reading. Only
# emitted when the persona is enabled; kept here so both query paths share it.
WORDING_ASSESSMENT_INSTRUCTION = (
    "If the question is about whether something is covered, also return a "
    "wording_assessment mapping the coverage reasoning: applicable exclusions, "
    "exceptions, conditions, limits, amending endorsements, and any alternative "
    "interpretation. Interpret the wording as written; do not make a binding "
    "coverage decision. The 'Extracted policy structure' block above is context "
    "only and must NOT be cited as a numbered Source."
)

# Recognised OFF values for the flag.
_FLAG_OFF_VALUES = {"off", "false", "0", "no", "disabled", "none"}


def is_policy_wording_persona_enabled() -> bool:
    """Return True unless the flag is explicitly set to an OFF value.

    Unset => enabled (default ON) so today's behaviour is preserved unless an
    operator opts out. Read live from the environment so it can be flipped
    without a redeploy.
    """
    raw = os.getenv(POLICY_WORDING_PERSONA_ENV)
    if raw is None:
        return True
    return raw.strip().lower() not in _FLAG_OFF_VALUES


def build_system_message() -> str:
    """Select the answer-identity system message based on the feature flag.

    This is the single chokepoint for answer-identity selection. When the flag is
    off, behaviour is byte-for-byte the pre-persona generic assistant (security
    boundary preserved). When on, the Policy Wording Specialist persona is used.
    """
    if is_policy_wording_persona_enabled():
        return build_policy_wording_specialist_system_message()
    return SYSTEM_PROMPT_PREFIX + "\n\n" + GENERIC_ASSISTANT_BODY


def get_persona_version() -> str:
    """Return the active persona version for traceability in answers and traces."""
    return PERSONA_VERSION
