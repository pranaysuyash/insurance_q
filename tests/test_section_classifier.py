import pytest
from src.rag.pipeline import RAGPipeline

@pytest.fixture
def classifier():
    return object.__new__(RAGPipeline)

@pytest.mark.parametrize("text, expected_type", [
    ("This section defines what is covered. It means you are insured.", "definition"),
    ("The policy does not cover acts of war. This is an exclusion.", "exclusion"),
    ("You are entitled to a benefit if you are hospitalized.", "benefit"),
    ("Your claims are subject to a limit of $500.", "sub_limit"),
    ("Please refer to the premium schedule for more details.", "schedule"),
    ("There is a waiting period of 30 days from inception.", "waiting_period"),
    ("Call our toll free helpline for assistance.", "contact"),
    ("Policy Number 123456789", "general"),
    ("This is a general paragraph without specific keywords.", "general"),
])
def test_classify_section_type(classifier, text, expected_type):
    result = classifier._classify_section_type(text)
    assert result == expected_type
