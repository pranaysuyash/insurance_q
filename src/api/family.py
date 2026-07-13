"""Retired compatibility router.

The mobile family workspace is derived from policy holders and locally added
members. It has no canonical server-side persistence contract yet, so this
router is intentionally not mounted rather than returning a misleading empty
production response.
"""

from fastapi import APIRouter

router = APIRouter(prefix="/family", tags=["family"])
