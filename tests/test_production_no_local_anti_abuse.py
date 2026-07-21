import ast
from pathlib import Path


def test_production_startup_guards_legacy_sqlite_anti_abuse_initialization():
    source = Path("src/app/main.py").read_text()
    tree = ast.parse(source)
    function = next(node for node in tree.body if isinstance(node, ast.AsyncFunctionDef) and node.name == "lifespan")
    text = ast.get_source_segment(source, function)
    assert "if not is_production" in text
    assert "Production anti-abuse uses canonical Supabase rate-limit RPCs" in text
