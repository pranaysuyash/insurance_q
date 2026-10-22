import pytest
from src.rag.umbrella_analyzer import (
    UmbrellaCoverageAnalyzer,
    PolicyCoverageProfile,
    parse_monetary_amount,
)

def test_parse_monetary_amount():
    assert parse_monetary_amount("₹5,00,000") == 500000.0
    assert parse_monetary_amount("5 Lakh") == 500000.0
    assert parse_monetary_amount("1 Cr") == 10000000.0
    assert parse_monetary_amount("50k") == 50000.0
    assert parse_monetary_amount(150000) == 150000.0
    assert parse_monetary_amount(None) is None
    assert parse_monetary_amount("") is None

def test_umbrella_coverage_seamless_topup():
    analyzer = UmbrellaCoverageAnalyzer()
    policies = [
        PolicyCoverageProfile(
            policy_id="pol-1",
            policy_name="Base Health",
            insurer="Star Health",
            policy_type="health",
            sum_insured=500000.0,
        ),
        PolicyCoverageProfile(
            policy_id="pol-2",
            policy_name="Super Top-up",
            insurer="HDFC ERGO",
            policy_type="health",
            sum_insured=2000000.0,
            is_top_up=True,
            top_up_threshold=500000.0,
        ),
        PolicyCoverageProfile(
            policy_id="pol-3",
            policy_name="Term Life",
            insurer="Tata AIA",
            policy_type="life",
            sum_insured=10000000.0,
        ),
    ]

    report = analyzer.analyze_portfolio(policies)
    assert report.policy_count == 3
    assert report.total_aggregate_sum_insured == 12500000.0
    assert report.by_category["health"] == 2500000.0
    assert report.by_category["life"] == 10000000.0
    assert report.top_up_coordination_status == "seamless"
    assert report.gap_amount == 0.0
    assert len(report.recommendations) >= 1
    assert "Seamless health umbrella coordination" in report.recommendations[0]

def test_umbrella_coverage_deductible_gap():
    analyzer = UmbrellaCoverageAnalyzer()
    policies = [
        PolicyCoverageProfile(
            policy_id="pol-1",
            policy_name="Base Retail Health",
            insurer="Star Health",
            policy_type="health",
            sum_insured=300000.0,
        ),
        PolicyCoverageProfile(
            policy_id="pol-2",
            policy_name="Super Top-up",
            insurer="ICICI Lombard",
            policy_type="health",
            sum_insured=2000000.0,
            is_top_up=True,
            top_up_threshold=500000.0,
        ),
    ]

    report = analyzer.analyze_portfolio(policies)
    assert report.policy_count == 2
    assert report.total_aggregate_sum_insured == 2300000.0
    assert report.top_up_coordination_status == "deductible_gap"
    assert report.gap_amount == 200000.0
    assert len(report.overlap_warnings) == 1
    assert "Deductible gap detected" in report.overlap_warnings[0]
