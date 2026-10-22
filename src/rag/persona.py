"""Versioned Policy Wording Specialist persona for the CoverWise RAG answer path.

This module is the single source of truth for the assistant's *policy-wording*
identity. It is deliberately additive: it stacks on top of the existing security
boundary (``SYSTEM_PROMPT_PREFIX``) and never relaxes grounding, citation-only, or
abstain-if-unknown rules.

Line-of-business (LOB) parameterisation (2026-08-12, pws-v2):
- The shared 12-step coverage-reasoning scaffold + legal-safety hard rules are
  LOB-agnostic and live in ``SHARED_WORDING_BODY``.
- Each LOB (health / cyber / marine) adds a focused emphasis block
  (``LOB_PERSONA_BODIES``) covering its own coverage taxonomy and the gotchas
  that most often produce wrong readings.
- ``build_system_message(lob=...)`` / ``build_policy_wording_specialist_system_message(lob=...)``
  select the LOB block. Unknown / ``None`` LOB resolves to Health (the historical
  default), so existing callers stay byte-compatible.

Calibration fix (pws-v2, from the 2026-08-12 live gate):
- The gate showed the persona was labelling *"cover attaches after a waiting
  period / sub-limit / co-pay"* as ``likely_not_covered``. That is wrong: such
  cover is ``conditional`` (it exists, gated on a condition). The shared body now
  states this rule explicitly and resolves the "exclusion + waiting period"
  maternity pattern to ``conditional`` rather than ``ambiguous``.

Over-conditional calibration fix (pws-v3, from the 2026-08-13 live gate):
- pws-v2 fixed the "exclusion + waiting period" miss but left the opposite
  defect: excess / sub-limit / territorial / depreciation were still being
  stamped ``conditional`` even when the scenario already satisfies the condition.
  The corrective rule (excess / sub-limit / territorial cap / depreciation are
  always-applicable **payout modifiers** -> cover stays ``likely_covered``, with
  the modifier stated as a caveat) was written into ``SHARED_WORDING_BODY`` at
  pws-v2 and is therefore already in force. pws-v3 stamps + documents that
  calibration: ``conditional`` is reserved for genuinely UNMET / UNCERTAIN
  conditions — waiting period not yet served, prior-notification / reasonable-
  precaution duty unsatisfied, territorial scope unestablished, or an optional
  endorsement not opted in.
- KNOWN RESIDUAL (open follow-up, not changed in pws-v3): the per-LOB emphasis
  blocks (``LOB_PERSONA_BODIES``) still say excess / sub-limit / single-item cap
  make cover ``conditional`` (e.g. ``LOB_GENERAL``, ``LOB_HEALTH``, ``LOB_CYBER``,
  ``LOB_MARINE``). That CONTRADICTS the ``SHARED_WORDING_BODY`` rule above. For
  global-corpus LOBs the LOB block is the more specific instruction the model
  follows, so the over-conditional behaviour persists for those products until
  the LOB blocks are realigned. See tests/evals/report_live_global_2026-08-13.md.

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
PERSONA_VERSION = "2026-08-24.pws-v4"

# --- Line-of-business identifiers -------------------------------------------
LOB_HEALTH = "health"
LOB_CYBER = "cyber"
LOB_MARINE = "marine"
# Internal catch-all block for non-specialised LOBs (never passed by a caller).
LOB_GENERAL = "general"
# Non-specialised LOBs that share the GENERAL emphasis block. These are the
# global-corpus lines of business (motor/property/travel/liability/life) that
# CoverWise serves worldwide — they must be analysed with correct, LOB-
# appropriate framing, not health-specific framing.
GLOBAL_LOBS = ("motor", "auto", "property", "home", "travel", "liability", "life")
VALID_LOBS = (LOB_HEALTH, LOB_CYBER, LOB_MARINE, *GLOBAL_LOBS)

LOB_LABELS = {
    LOB_HEALTH: "Health / Medical Insurance",
    LOB_CYBER: "Cyber Insurance",
    LOB_MARINE: "Marine Insurance (Cargo / Hull / Liability)",
    "motor": "Motor / Auto Insurance",
    "property": "Property / Home Insurance",
    "travel": "Travel Insurance",
    "liability": "Liability Insurance",
    "life": "Life Insurance",
}

# --- Shared, LOB-agnostic body ----------------------------------------------
# The 12-step coverage-reasoning scaffold + legal-safety hard rules, PLUS the
# calibration rules that the 2026-08-12 live gate proved were missing.
SHARED_WORDING_BODY = """\
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

COVERAGE-STATUS SEMANTICS — use the wording_assessment.reading labels precisely:
- likely_covered — the wording clearly grants the benefit with no unmet condition \
or live exclusion in play.
- conditional — reserve this for when the SPECIFIC scenario in the question is \
genuinely gated on a condition whose satisfaction is UNCERTAIN or UNMET at the \
moment of asking (a waiting period not yet served, a prior-notification / \
reasonable-precaution duty the user has not yet satisfied, a territorial scope \
the user has not established, or an optional endorsement that must be opted into \
on the schedule). If the asked scenario already satisfies the condition — the \
person IS abroad within the covered territory, the event IS a covered peril, the \
section IS shown on the schedule — the cover is likely_covered. Cover that is \
merely subject to an excess, a co-payment, a sub-limit, a single-item cap, or \
depreciation is STILL likely_covered: those are always-applicable payout \
modifiers, not conditions that may or may not be met, so state them as caveats \
rather than relabelling the reading. NEVER use "likely_not_covered" for a clause \
that attaches cover after a served waiting period, co-pay, or deductible — that \
is conditional, not excluded.
- likely_not_covered — reserve this for express exclusions, carve-outs with no \
carve-back, or cases where a condition that DEFEATIVELY removes cover has clearly \
failed (e.g. an exclusion squarely on point with no exception).
- ambiguous — ONLY when the wording genuinely permits two materially different \
readings and you cannot resolve it from the text alone. Do not use "ambiguous" \
merely because two provisions (e.g. a waiting period AND an exclusion) both bear \
on the same subject.

CONFLICT HANDLING — if both a waiting period and an exclusion bear on the same \
subject (for example maternity: an express exclusion plus a waiting-period \
condition), report "conditional" and LIST BOTH the exclusion and the waiting \
period as applicable provisions. Coexistence of provisions is not ambiguity.

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

# --- LOB-specific emphasis blocks --------------------------------------------
LOB_PERSONA_BODIES = {
    LOB_HEALTH: """\
LINE OF BUSINESS: Health / Medical Insurance. Apply extra care to these areas:
- Waiting periods are the single most mis-read provision. Initial waiting period \
(typically 30 days for illness), Pre-Existing Disease (PED) waiting period \
(typically 24-48 months, continuous coverage), specified-/named-disease waiting \
period, and maternity waiting period (commonly 9-36 months) ALL make cover \
CONDITIONAL (cover attaches after the period is served) — never "likely_not_covered".
- Sub-limits, room-rent / ICU caps, and co-payment (e.g. 10% or age-based co-pay) \
are PAYOUT MODIFIERS: cover remains likely_covered with the modifier stated as a \
caveat, NOT conditional.
- Read maternity as conditional where an unserved waiting period or opted add-on applies; \
note the express maternity exclusion only if no add-on benefit is in force.
- Cover taxonomy to check: inpatient hospitalisation, day-care procedures, \
pre-/post-hospitalisation, domiciliary, OPD/consultations, maternity & newborn, \
organ donor, ambulance, AYUSH, mental-health, wellness, and No-Claim Bonus.
- Distinguish standard exclusions (e.g. Excl01-Exclxx such as rest-cure, \
war/invasion, intoxication) — these are likely_not_covered — from permanent \
exclusions and from conditions that merely delay cover.
""",
    LOB_CYBER: """\
LINE OF BUSINESS: Cyber Insurance. Apply extra care to these areas:
- Separate FIRST-PARTY cover (data-breach response: forensics, notification, \
credit/identity monitoring, PR; cyber / ransomware extortion; business \
interruption; digital-asset restoration; social-engineering / funds-transfer fraud) \
from THIRD-PARTY cover (privacy/security liability, regulatory defence & penalties \
where insurable, PCI-DSS assessments, media/defamation liability, networked \
third-party liability).
- This is a CLAIMS-MADE wording with a RETROACTIVE DATE and often a prior-acts \
condition. A loss is only covered if first made against the insured during the \
policy period AND after the retro date. State this as a CONDITION.
- Read the "computer system" definition carefully (owned vs third-party / cloud \
vs on-prem) — it scopes almost every grant and exclusion.
- Common exclusions to flag as likely_not_covered when squarely on point: war & \
sanctions, bodily injury / property damage (those are General Liability), fines & \
penalties not insurable by law, known circumstances prior to inception, and \
improper security / failure to maintain controls (often a condition, not an \
exclusion — e.g. lack of MFA or unpatched systems may reduce or remove cover, \
making it CONDITIONAL).
- Sub-limits & co-insurance on ransomware extortion, social engineering, or business \
interruption are PAYOUT MODIFIERS: cover remains likely_covered with the modifier \
stated as a caveat, not conditional.
- Business interruption: check the waiting period (cold-start), whether dependent \
/ cloud-service interruption is covered, and the period of indemnity.
- Regulatory insurability of fines/penalties VARIES by jurisdiction — do NOT assume \
a fine is uninsurable or insurable; state the wording's own treatment and flag the \
jurisdiction question as a condition, never assert it.
""",
    LOB_MARINE: """\
LINE OF BUSINESS: Marine Insurance (Cargo / Hull / Liability). Apply extra care to \
these areas:
- Identify the clause set first: Institute Cargo Clauses A (nearest "all risks", \
subject only to the exclusions), B (named perils), or C (major perils); and \
whether Institute War / Strikes clauses are attached. The peril list determines \
whether a loss is likely_covered (A), conditional on the peril being named (B/C), \
or likely_not_covered (peril outside the clause).
- "Warehouse-to-warehouse" transit and the commencement/termination of transit \
define WHEN cover attaches and ends — a transit-scope question is CONDITIONAL on \
the stage of transit.
- General Average and salvage / sue-&-labour: the insured may owe a contribution; \
state this as a CONDITION, not an exclusion.
- Inherent vice, improper packing, and delay are classic exclusions (likely_not_covered); \
ordinary leakage/wear or franchise/deductible are PAYOUT MODIFIERS (cover is likely_covered \
with deductible stated as a caveat).
- Seaworthiness / due diligence and the "held covered" clause for deviations or \
changed voyages are conditions that can preserve or remove cover — treat as CONDITIONAL.
- Insured value vs CIF vs market value affects the measure of recovery (PAYOUT MODIFIER), \
not whether cover exists.
- Hull (ITCH) and collision liability (P&I) follow different clauses — confirm which \
interest is being asked about before reading cover.
""",
    LOB_GENERAL: """\
LINE OF BUSINESS: General / Non-specialised (Property, Motor, Travel, Liability, \
Life). Apply extra care to these cross-cutting areas that most often produce wrong \
readings across these products:
- BASIS OF SETTLEMENT: buildings are normally insured on a REINSTATEMENT basis and \
contents/valuables on an INDEMNITY basis. Depreciation / betterment is a PAYOUT MODIFIER \
(cover remains likely_covered with modifier stated as caveat).
- EXCESS / DEDUCTIBLE: any excess is a PAYOUT MODIFIER — the insurer pays the \
balance after excess; cover remains likely_covered with caveat, never conditional \
or likely_not_covered.
- TERRITORIAL SCOPE: travel and motor cover is heavily territorial. Cover abroad, \
in the EU, or for extended trips is CONDITIONAL on the territorial limit and any \
trip-duration cap; outside the defined territory it is likely_not_covered.
- WEAR & TEAR / GRADUAL DETERIORATION / CONSEQUENTIAL LOSS are classic exclusions \
(likely_not_covered) and are distinct from a sudden, identifiable insured event.
- REASONABLE PRECAUTIONS / SECURITY CONDITIONS (e.g. motor immobiliser/alarm, \
property left secured) are CONDITIONS — failure to meet them can reduce or remove \
cover, making a claim CONDITIONAL or, if squarely excluded, likely_not_covered; read \
which applies.
- SUB-LIMITS & SINGLE-ITEM LIMITS (valuables, baggage, personal money) are PAYOUT \
MODIFIERS: cover remains likely_covered with the cap noted as a caveat.
- LIABILITY cover (public / products / motor third-party) protects against claims by \
THIRD PARTIES for bodily injury or damage to property NOT belonging to the insured; \
the insured's own property and liability to employees are usually excluded.
- MOTOR: distinguish OWN DAMAGE (the insured vehicle) from THIRD-PARTY LIABILITY \
(compulsory); check uninsured-driver, windscreen/glass, and no-claims provisions.
- LIFE: distinguish the death / terminal-illness benefit from exclusions (e.g. \
suicide within the first 12 months, war, unlawful activity) which are \
likely_not_covered.
- WAR, SANCTIONS, and UNLAWFUL USE exclusions are common across all these products; \
when squarely on point they are likely_not_covered.
""",
}


def get_lob_persona_body(lob: object) -> str:
    """Return the LOB emphasis block.

    - Health / Cyber / Marine have dedicated blocks.
    - Any other line of business (the global-corpus LOBs — property / motor /
      travel / liability / life — plus product variants such as travel_v2) shares
      the GENERAL block, so it is analysed with correct, LOB-appropriate framing
      rather than health-specific framing.
    - Only ``None`` resolves to Health (the historical default), preserving
      byte-compatibility for existing callers that pass no LOB.
    """
    key = (str(lob).lower() if lob else LOB_HEALTH)
    if key in LOB_PERSONA_BODIES:
        return LOB_PERSONA_BODIES[key]
    if key in GLOBAL_LOBS:
        return LOB_PERSONA_BODIES[LOB_GENERAL]
    return LOB_PERSONA_BODIES[LOB_GENERAL]


def resolve_lob(lob: object = None, filters: object = None, product: object = None) -> "str | None":
    """Resolve the active LOB from an explicit arg, a filters dict, or a product string.

    Returns a value in ``VALID_LOBS`` or ``None`` (callers treat None as the Health
    default). Intentionally conservative: it only asserts an LOB when there is a
    clear signal, so an unrecognised product never silently flips the persona.
    """
    if lob and str(lob).lower() in VALID_LOBS:
        return str(lob).lower()
    if isinstance(filters, dict):
        f = filters.get("lob")
        if f and str(f).lower() in VALID_LOBS:
            return str(f).lower()
    if product:
        p = str(product).lower()
        if any(k in p for k in ("cyber", "tech ", "tech,", "data breach", "ransom", "cyber risk")):
            return LOB_CYBER
        if any(k in p for k in ("marine", "cargo", "hull", "ship", "vessel", "sea freight", "goods in transit")):
            return LOB_MARINE
        if any(k in p for k in ("health", "medical", "mediclaim", "shield", "care ")):
            return LOB_HEALTH
    return None


# Lightweight, structured record of what changed and why. Not exhaustive prose;
# the durable decision rationale lives in the ADR under docs/review/.
CHANGELOG: list[dict] = [
    {
        "version": "2026-08-12.pws-v2",
        "date": "2026-08-12",
        "summary": (
            "pws-v2: (1) Line-of-business parameterisation — shared 12-step scaffold "
            "plus per-LOB emphasis blocks for health / cyber / marine, selected via "
            "build_system_message(lob=...). Unknown/None LOB resolves to Health (the "
            "historical default) so existing callers stay byte-compatible. "
            "(2) Calibration fix from the 2026-08-12 live gate: waiting-period / "
            "sub-limit / co-pay clauses are now explicitly 'conditional' (cover exists, "
            "gated), not 'likely_not_covered'; and 'exclusion + waiting period' "
            "coexistence resolves to 'conditional', not 'ambiguous'."
        ),
        "legal_review": "Framing reviewed for no-coverage-decision / no-jurisdiction-assumption; LOB blocks add taxonomy only.",
    },
    {
        "version": "2026-08-13.pws-v3",
        "date": "2026-08-13",
        "summary": (
            "pws-v3: over-conditional calibration fix (2026-08-13 live gate). Excess / "
            "sub-limit / territorial cap / depreciation / single-item cap are always-"
            "applicable payout modifiers, NOT conditions that may or may not be met: "
            "cover merely subject to them stays 'likely_covered' (state the modifier as "
            "a caveat), not 'conditional'. 'conditional' is now reserved strictly for "
            "genuinely unmet / uncertain conditions — waiting period not yet served, "
            "prior-notification / reasonable-precaution duty unsatisfied, territorial "
            "scope unestablished, or an optional endorsement not opted in. Logic already "
            "present in SHARED_WORDING_BODY; this version stamps + documents the fix. No "
            "persona-structure change."
        ),
        "legal_review": "Refines label semantics only; no coverage decision / jurisdiction assumption added; legal-safety contract unchanged.",
    },
    {
        "version": "2026-08-24.pws-v4",
        "date": "2026-08-24",
        "summary": (
            "pws-v4: Reconciled per-LOB emphasis bodies (LOB_HEALTH, LOB_CYBER, "
            "LOB_MARINE, LOB_GENERAL) with SHARED_WORDING_BODY payout-modifier rules. "
            "Sub-limits, deductibles, excess, single-item caps, and depreciation are "
            "unambiguously classified across all LOB blocks as payout modifiers with "
            "cover remaining 'likely_covered' (with caveat), eliminating over-conditional "
            "contradiction for global and specialised LOB queries."
        ),
        "legal_review": "Doctrinal epistemic alignment; preserved no-coverage-decision and no-jurisdiction boundary.",
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


def build_policy_wording_specialist_system_message(lob: object = None) -> str:
    """Compose the full system message: security boundary + wording persona (LOB-aware).

    ``SECURITY_SYSTEM_INSTRUCTION`` is auto-prepended by the LLM client's
    ``_harden_messages``, and ``SYSTEM_PROMPT_PREFIX`` is included here, so the
    security boundary is preserved and never weakened by the persona.
    """
    body = SHARED_WORDING_BODY + "\n\n" + get_lob_persona_body(lob)
    return SYSTEM_PROMPT_PREFIX + "\n\n" + body


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


def build_system_message(lob: object = None) -> str:
    """Select the answer-identity system message based on the feature flag.

    This is the single chokepoint for answer-identity selection. When the flag is
    off, behaviour is byte-for-byte the pre-persona generic assistant (security
    boundary preserved). When on, the (LOB-aware) Policy Wording Specialist
    persona is used. ``lob`` selects the LOB emphasis block; unknown/None => Health.
    """
    if is_policy_wording_persona_enabled():
        return build_policy_wording_specialist_system_message(lob=lob)
    return SYSTEM_PROMPT_PREFIX + "\n\n" + GENERIC_ASSISTANT_BODY


def get_persona_version(lob: object = None) -> str:
    """Return the active persona version for traceability in answers and traces.

    When an explicit LOB is in force, the version is suffixed with ':<lob>' so a
    Health answer and a Cyber answer are distinguishable in traces and reports.
    """
    if lob and str(lob).lower() in VALID_LOBS:
        return f"{PERSONA_VERSION}:{str(lob).lower()}"
    return PERSONA_VERSION
