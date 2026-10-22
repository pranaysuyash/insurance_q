"""Multi-Policy Umbrella & Aggregate Coverage Analyzer.

Auditor Personas: PER-0914 (Insurance Ontologist), PER-0921 (Conflict Resolver).
Doctrinal Mandate: First-principles coverage roll-up, umbrella coordination,
and gap detection across personal and commercial policy portfolios.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


def parse_monetary_amount(val: Any) -> Optional[float]:
    """Parse string or numeric representation of monetary sum into float."""
    if val is None:
        return None
    if isinstance(val, (int, float)):
        return float(val)
    text = str(val).strip().replace(",", "")
    if not text:
        return None

    # Handle Indian currency abbreviations (Lakh, Crore)
    match_cr = re.search(r"(\d+(?:\.\d+)?)\s*(?:cr|crore|crores)", text, re.IGNORECASE)
    if match_cr:
        return float(match_cr.group(1)) * 10_000_000

    match_lakh = re.search(r"(\d+(?:\.\d+)?)\s*(?:l|lac|lakh|lakhs)", text, re.IGNORECASE)
    if match_lakh:
        return float(match_lakh.group(1)) * 100_000

    match_k = re.search(r"(\d+(?:\.\d+)?)\s*(?:k|thousand)", text, re.IGNORECASE)
    if match_k:
        return float(match_k.group(1)) * 1_000

    # Match raw digits
    match_num = re.search(r"(\d+(?:\.\d+)?)", text)
    if match_num:
        return float(match_num.group(1))

    return None


@dataclass
class PolicyCoverageProfile:
    policy_id: str
    policy_name: str
    insurer: str
    policy_type: str  # health, motor, life, travel, cyber, property
    sum_insured: float
    deductible: float = 0.0
    is_top_up: bool = False
    top_up_threshold: float = 0.0
    benefits: List[str] = field(default_factory=list)
    exclusions: List[str] = field(default_factory=list)


@dataclass
class UmbrellaCoordinationReport:
    total_aggregate_sum_insured: float
    effective_family_coverage: float
    policy_count: int
    by_category: Dict[str, float]
    top_up_coordination_status: str  # 'seamless', 'deductible_gap', 'none'
    gap_amount: float
    overlap_warnings: List[str] = field(default_factory=list)
    recommendations: List[str] = field(default_factory=list)


class UmbrellaCoverageAnalyzer:
    """Analyzes a portfolio of policies to compute aggregate protection,

    deductible coordination between base and top-up layers, and coverage gaps.
    """

    def analyze_portfolio(
        self, policies: List[PolicyCoverageProfile]
    ) -> UmbrellaCoordinationReport:
        if not policies:
            return UmbrellaCoordinationReport(
                total_aggregate_sum_insured=0.0,
                effective_family_coverage=0.0,
                policy_count=0,
                by_category={},
                top_up_coordination_status="none",
                gap_amount=0.0,
                overlap_warnings=[],
                recommendations=["No active policies available for umbrella aggregation."],
            )

        total_sum = sum(p.sum_insured for p in policies)
        by_cat: Dict[str, float] = {}
        for p in policies:
            cat = p.policy_type.lower()
            by_cat[cat] = by_cat.get(cat, 0.0) + p.sum_insured

        # Analyze health base + top-up coordination if multiple health policies exist
        health_policies = [p for p in policies if p.policy_type.lower() in ("health", "medical")]
        top_up_status = "none"
        gap_amount = 0.0
        warnings: List[str] = []
        recommendations: List[str] = []

        base_health = [p for p in health_policies if not p.is_top_up]
        top_up_health = [p for p in health_policies if p.is_top_up]

        if base_health and top_up_health:
            total_base_coverage = sum(p.sum_insured for p in base_health)
            min_top_up_deductible = min(p.top_up_threshold or p.deductible for p in top_up_health)

            if total_base_coverage >= min_top_up_deductible:
                top_up_status = "seamless"
                recommendations.append(
                    f"Seamless health umbrella coordination: Base coverage (₹{total_base_coverage:,.0f}) "
                    f"satisfies super top-up deductible (₹{min_top_up_deductible:,.0f})."
                )
            else:
                top_up_status = "deductible_gap"
                gap_amount = min_top_up_deductible - total_base_coverage
                warnings.append(
                    f"Deductible gap detected: Base health sum insured (₹{total_base_coverage:,.0f}) "
                    f"is ₹{gap_amount:,.0f} lower than super top-up deductible (₹{min_top_up_deductible:,.0f}). "
                    f"You may bear out-of-pocket expenses before top-up coverage triggers."
                )
                recommendations.append(
                    f"Increase base health policy coverage by ₹{gap_amount:,.0f} or align top-up deductible."
                )

        if len(health_policies) > 1 and not top_up_health:
            warnings.append(
                "Multiple standalone base health policies detected. Ensure hospital intimates both insurers "
                "to coordinate contribution clauses during cashless claims."
            )

        return UmbrellaCoordinationReport(
            total_aggregate_sum_insured=total_sum,
            effective_family_coverage=total_sum - gap_amount,
            policy_count=len(policies),
            by_category=by_cat,
            top_up_coordination_status=top_up_status,
            gap_amount=gap_amount,
            overlap_warnings=warnings,
            recommendations=recommendations,
        )
