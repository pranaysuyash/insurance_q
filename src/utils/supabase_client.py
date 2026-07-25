"""Canonical Supabase client construction for the Python runtime.

Supabase Python 2.31 supports injecting an HTTPX client. Supplying one keeps
PostgREST on the supported configuration path instead of making the client
forward deprecated ``timeout``/``verify`` constructor keywords.
"""

from httpx import Client
from supabase import ClientOptions


def create_client(url: str, key: str):
    """Create a Supabase client through its supported HTTPX boundary."""
    http_client = Client(http2=True, timeout=120.0)
    options = ClientOptions(httpx_client=http_client)
    from supabase import create_client as native_create_client

    return native_create_client(url, key, options)
