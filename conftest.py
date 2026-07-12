"""Test bootstrap for local package imports.

Pytest in this repo is often invoked from the checkout root, so we make sure
`src` resolves without requiring callers to export PYTHONPATH manually.
"""

from __future__ import annotations

import sys
from contextlib import ExitStack
from unittest.mock import AsyncMock, MagicMock, Mock, patch
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parent
ROOT_STR = str(ROOT)

if ROOT_STR not in sys.path:
    sys.path.insert(0, ROOT_STR)


@pytest.fixture
def mocker():
    """Minimal pytest-mock compatible fixture for this repo's tests."""

    class _Mocker:
        AsyncMock = AsyncMock
        MagicMock = MagicMock
        Mock = Mock

        def __init__(self):
            self._stack = ExitStack()

        def patch(self, target, *args, **kwargs):
            return self._stack.enter_context(patch(target, *args, **kwargs))

        def patch_object(self, target, attribute, *args, **kwargs):
            return self._stack.enter_context(patch.object(target, attribute, *args, **kwargs))

        def stop(self):
            self._stack.close()

    helper = _Mocker()
    try:
        yield helper
    finally:
        helper.stop()
