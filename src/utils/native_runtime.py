"""Configure discoverable native library paths before optional imports.

The Python packages used for OCR/PDF rendering rely on GLib, Pango, Cairo,
and GDK-Pixbuf. Homebrew installs these libraries correctly, but macOS does
not include Homebrew prefixes in the dynamic-loader search path by default.
This setup is intentionally additive and no-ops on Linux/CI/container hosts.
"""

from __future__ import annotations

import os
import platform
from pathlib import Path


def configure_native_library_paths() -> None:
    if platform.system() != "Darwin":
        return

    prefixes = (
        Path("/opt/homebrew/opt/glib/lib"),
        Path("/opt/homebrew/opt/pango/lib"),
        Path("/opt/homebrew/opt/cairo/lib"),
        Path("/opt/homebrew/opt/gdk-pixbuf/lib"),
        Path("/opt/homebrew/opt/libffi/lib"),
        Path("/opt/homebrew/opt/harfbuzz/lib"),
        Path("/opt/homebrew/opt/fontconfig/lib"),
        Path("/opt/homebrew/opt/freetype/lib"),
    )
    existing = [str(path) for path in prefixes if path.is_dir()]
    if not existing:
        return

    joined = os.pathsep.join(existing)
    for variable in ("DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH"):
        current = os.environ.get(variable, "")
        os.environ[variable] = joined + (os.pathsep + current if current else "")
