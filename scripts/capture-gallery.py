# /// script
# requires-python = ">=3.11"
# dependencies = ["playwright"]
# ///
"""Capture the gallery screenshots of the demo sites.

Run `uv run scripts/capture-gallery.py` to build the demos and write the images
to `docs/assets/gallery/`.
Pass `--browser <path>` to choose a Chromium-based browser.
"""

from __future__ import annotations

import argparse
import functools
import http.server
import os
import subprocess
import sys
import tempfile
import threading
from collections.abc import Sequence
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = ROOT / "docs" / "_scripts" / "build-demos.sh"
OUTPUT = ROOT / "docs" / "assets" / "gallery"
PREFIX = "/quarto-atelier"
VIEWPORT = {"width": 1440, "height": 900}
WORKSHOP_PAGE = "workshop/first-site/index.html"
DOCS_PAGE = "get-started.html"
DEMOS = {
    "workshop-sidebar": (WORKSHOP_PAGE, ("light", "dark")),
    "workshop-navbar": (WORKSHOP_PAGE, ("light", "dark")),
    "docs-navbar": (DOCS_PAGE, ("light", "dark")),
    "docs-sidebar": (DOCS_PAGE, ("light", "dark")),
    "preset-default": (DOCS_PAGE, ("light", "dark")),
    "preset-quarto": (DOCS_PAGE, ("light", "dark")),
    "preset-terminal": (DOCS_PAGE, ("dark",)),
}
SCHEME_READY = """
scheme => document.body.classList.contains(`quarto-${scheme}`)
    && [...document.styleSheets].every(sheet => {
        try { return sheet.cssRules !== null; } catch { return false; }
    })
"""
BROWSER_VARIABLES = ("CHROME_PATH", "QUARTO_CHROMIUM")
BROWSER_CANDIDATES = (
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
)


class _Server(http.server.ThreadingHTTPServer):
    """Threading server whose backlog holds a page's burst of stylesheet requests.

    With the default backlog of 5, some requests are dropped, those stylesheets
    never load, and the page never reaches the colour scheme it was asked for.
    """

    request_queue_size = 128


class _Handler(http.server.SimpleHTTPRequestHandler):
    """Static handler that maps the deployed sub-path to the build folder."""

    def translate_path(self, path: str) -> str:
        """Strip the site prefix before resolving the file."""
        if path.startswith(PREFIX + "/"):
            path = path[len(PREFIX) :]
        return super().translate_path(path)

    def log_message(self, format: str, *args: object) -> None:
        """Discard request logs."""


def find_browser(explicit: str | None) -> str:
    """Return the browser path from the option, the environment or the usual places."""
    candidates = [
        explicit,
        *(os.environ.get(name) for name in BROWSER_VARIABLES),
        *BROWSER_CANDIDATES,
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise SystemExit(
        "No Chromium-based browser found. Pass --browser <path> or set CHROME_PATH."
    )


def build_demos(output_dir: Path) -> None:
    """Render the demo sites into the output folder."""
    subprocess.run([str(BUILD_SCRIPT), str(output_dir), *DEMOS], check=True)


def capture(output_dir: Path, browser: str) -> None:
    """Serve the build folder and write one screenshot per demo and scheme."""
    handler = functools.partial(_Handler, directory=str(output_dir))
    server = _Server(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    port = server.server_address[1]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    try:
        with sync_playwright() as playwright:
            chromium = playwright.chromium.launch(executable_path=browser)
            for demo, (page_path, schemes) in DEMOS.items():
                for scheme in schemes:
                    context = chromium.new_context(
                        viewport=VIEWPORT, color_scheme=scheme
                    )
                    page = context.new_page()
                    page.goto(
                        f"http://127.0.0.1:{port}{PREFIX}/demos/{demo}/{page_path}",
                        wait_until="networkidle",
                    )
                    page.evaluate("document.fonts.ready")
                    page.wait_for_function(SCHEME_READY, arg=scheme)
                    target = OUTPUT / f"{demo}-{scheme}.png"
                    page.screenshot(path=str(target))
                    context.close()
                    print(f"[gallery] {target.relative_to(ROOT)}")
            chromium.close()
    finally:
        server.shutdown()


def main(argv: Sequence[str] | None = None) -> int:
    """Build the demos and capture the screenshots."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--browser", help="path to a Chromium-based browser")
    args = parser.parse_args(argv)
    browser = find_browser(args.browser)
    with tempfile.TemporaryDirectory() as directory:
        build_demos(Path(directory))
        capture(Path(directory), browser)
    return 0


if __name__ == "__main__":
    sys.exit(main())
