# /// script
# requires-python = ">=3.11"
# dependencies = ["playwright"]
# ///
"""Capture the gallery screenshots that the manifest lists.

Run `uv run scripts/capture-gallery.py` to build the demos and write every image
of `docs/_samples/_screenshots.tsv` to `docs/assets/gallery/`, with the digest of
the inputs in `docs/assets/gallery/inputs.sha256`.
Pass `--only <name>...` to capture some shots only; the digest then stays as it is.
Pass `--browser <path>` to choose a Chromium-based browser.
"""

from __future__ import annotations

import argparse
import csv
import functools
import hashlib
import http.server
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, cast, get_args

from playwright.sync_api import Page, Response, sync_playwright
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError

ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = ROOT / "docs" / "_scripts" / "build-demos.sh"
OUTPUT = ROOT / "docs" / "assets" / "gallery"
MANIFEST = ROOT / "docs" / "_samples" / "_screenshots.tsv"
DIGEST_FILE = OUTPUT / "inputs.sha256"
INPUTS: tuple[Path, ...] = (
    ROOT / "_extensions" / "atelier",
    ROOT / "docs" / "_samples",
    ROOT / "docs" / "_demos",
    ROOT / "templates",
    Path(__file__).resolve(),
)
SKIPPED_DIRECTORIES = {".quarto", "__pycache__"}
SKIPPED_FILES = {".DS_Store"}
PREFIX = "/quarto-atelier"
VIEWPORT = {"width": 1440, "height": 900}
SCHEME_READY = "scheme => document.body.classList.contains(`quarto-${scheme}`)"
BROWSER_VARIABLES = ("CHROME_PATH", "QUARTO_CHROMIUM")
BROWSER_CANDIDATES = (
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
)

Kind = Literal["html", "revealjs", "typst"]
Scheme = Literal["light", "dark"]
COLUMNS = ("name", "source", "kind", "target", "scheme")


@dataclass(frozen=True)
class Shot:
    """One screenshot of the manifest.

    `source` is the path of the rendered file under the build root.
    `target` is `page` or a CSS selector for `html`, a slide hash for
    `revealjs`, and a page number for `typst`.
    """

    name: str
    source: str
    kind: Kind
    target: str
    scheme: Scheme


def read_manifest(path: Path = MANIFEST) -> list[Shot]:
    """Read the tab-separated manifest of shots.

    Args:
        path: Manifest file with the header `name source kind target scheme`.

    Returns:
        The shots, in manifest order.

    Raises:
        SystemExit: The header is wrong, or a line has a missing column, an
            unknown kind or scheme, or a name that an earlier line uses.
    """
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle, delimiter="\t"))
    if not rows or tuple(rows[0]) != COLUMNS:
        raise SystemExit(f"{path}: the header must be {' '.join(COLUMNS)} (tabs).")
    shots: list[Shot] = []
    names: set[str] = set()
    for number, row in enumerate(rows[1:], start=2):
        where = f"{path}, line {number}"
        if not row:
            continue
        if len(row) != len(COLUMNS) or not all(cell.strip() for cell in row):
            raise SystemExit(f"{where}: expected {len(COLUMNS)} non-empty columns.")
        name, source, kind, target, scheme = (cell.strip() for cell in row)
        if kind not in get_args(Kind):
            raise SystemExit(f"{where}: unknown kind {kind!r} for shot {name}.")
        if scheme not in get_args(Scheme):
            raise SystemExit(f"{where}: unknown scheme {scheme!r} for shot {name}.")
        if name in names:
            raise SystemExit(f"{where}: the name {name} is already used.")
        names.add(name)
        shots.append(Shot(name, source, cast(Kind, kind), target, cast(Scheme, scheme)))
    return shots


def _is_skipped(relative: Path) -> bool:
    parts = relative.parts
    if relative.name in SKIPPED_FILES:
        return True
    if any(part in SKIPPED_DIRECTORIES or part.startswith("_site") for part in parts):
        return True
    return any(
        parts[index : index + 2] == ("_extensions", "local")
        for index in range(len(parts) - 1)
    )


def _input_files(paths: Sequence[Path], root: Path) -> Iterator[Path]:
    for path in paths:
        candidates = path.rglob("*") if path.is_dir() else [path]
        for file in candidates:
            if file.is_file() and not _is_skipped(file.relative_to(root)):
                yield file


def input_digest(paths: Sequence[Path] = INPUTS, root: Path = ROOT) -> str:
    """Return the SHA-256 digest of the files that the screenshots depend on.

    Args:
        paths: Folders and files to read.
        root: Folder that the file paths in the digest are relative to.

    Returns:
        The hex digest of each file path relative to `root` and its bytes,
        sorted by path.
    """
    digest = hashlib.sha256()
    files = sorted(_input_files(paths, root), key=lambda f: f.relative_to(root))
    for file in files:
        digest.update(file.relative_to(root).as_posix().encode("utf-8") + b"\0")
        digest.update(file.read_bytes() + b"\0")
    return digest.hexdigest()


def demo_ids(shots: Sequence[Shot]) -> list[str]:
    """Return the unique demo ids of the shots under `demos/`, in manifest order."""
    ids: list[str] = []
    for shot in shots:
        parts = Path(shot.source).parts
        if len(parts) > 1 and parts[0] == "demos" and parts[1] not in ids:
            ids.append(parts[1])
    return ids


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


def build_demos(output_dir: Path, ids: Sequence[str]) -> None:
    """Render the demo sites with the given ids into the output folder."""
    subprocess.run([str(BUILD_SCRIPT), str(output_dir), *ids], check=True)


def check_sources(build_root: Path, shots: Sequence[Shot]) -> None:
    """Stop on the first shot whose rendered source does not exist."""
    for shot in shots:
        if not (build_root / shot.source).is_file():
            raise SystemExit(
                f"Shot {shot.name}: the render did not produce {shot.source}. "
                f"Check the source column of {MANIFEST.relative_to(ROOT)}."
            )


def watch_failures(page: Page, origin: str) -> list[str]:
    """Collect the failed requests and the same-origin error responses of a page."""
    failures: list[str] = []

    def on_response(response: Response) -> None:
        if response.status >= 400 and response.url.startswith(origin):
            failures.append(f"{response.url} (HTTP {response.status})")

    page.on(
        "requestfailed",
        lambda request: failures.append(f"{request.url} ({request.failure})"),
    )
    page.on("response", on_response)
    return failures


def _capture_page(page: Page, origin: str, shot: Shot, out: Path) -> None:
    failures = watch_failures(page, origin)
    timeout: PlaywrightTimeoutError | None = None
    try:
        page.goto(f"{origin}{PREFIX}/{shot.source}", wait_until="networkidle")
        page.evaluate("document.fonts.ready")
        page.wait_for_function(SCHEME_READY, arg=shot.scheme)
    except PlaywrightTimeoutError as error:
        if not failures:
            raise
        timeout = error
    if failures:
        raise RuntimeError(
            f"Shot {shot.name} ({shot.source}) failed to load: " + ", ".join(failures)
        ) from timeout
    page.screenshot(path=str(out))


def capture(
    build_root: Path, browser: str, shots: Sequence[Shot], staging: Path
) -> None:
    """Serve the build folder and write `<name>.png` for each shot into staging."""
    handler = functools.partial(_Handler, directory=str(build_root))
    server = _Server(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    origin = f"http://127.0.0.1:{server.server_address[1]}"
    staging.mkdir(parents=True, exist_ok=True)
    try:
        with sync_playwright() as playwright:
            chromium = playwright.chromium.launch(executable_path=browser)
            for shot in shots:
                if shot.kind != "html" or shot.target != "page":
                    raise NotImplementedError(shot.kind)
                context = chromium.new_context(
                    viewport=VIEWPORT, color_scheme=shot.scheme
                )
                try:
                    out = staging / f"{shot.name}.png"
                    _capture_page(context.new_page(), origin, shot, out)
                finally:
                    context.close()
                print(f"[gallery] {shot.name}.png")
    finally:
        server.shutdown()
        server.server_close()


def publish(
    staging: Path, output: Path, shots: Sequence[Shot], digest: str | None
) -> None:
    """Move the staged images into the output folder, then write the digest.

    Args:
        staging: Folder with one `<name>.png` for each shot.
        output: Gallery folder that receives the images.
        shots: Shots of the run.
        digest: Input digest to write, or `None` to keep the old digest file.

    Raises:
        SystemExit: A shot has no image in staging. The output folder is then
            left as it was.
    """
    missing = [s.name for s in shots if not (staging / f"{s.name}.png").is_file()]
    if missing:
        raise SystemExit(
            "No image was captured for " + ", ".join(missing) + "; nothing replaced."
        )
    output.mkdir(parents=True, exist_ok=True)
    for shot in shots:
        shutil.move(staging / f"{shot.name}.png", output / f"{shot.name}.png")
    if digest is not None:
        (output / DIGEST_FILE.name).write_text(f"{digest}\n", encoding="utf-8")
    print(f"[gallery] {len(shots)} images in {output}")


def _select(shots: Sequence[Shot], only: Sequence[str] | None) -> list[Shot]:
    if not only:
        return list(shots)
    known = {shot.name for shot in shots}
    unknown = [name for name in only if name not in known]
    if unknown:
        raise SystemExit(
            f"Unknown shot name: {', '.join(unknown)}. "
            f"The names are in {MANIFEST.relative_to(ROOT)}."
        )
    return [shot for shot in shots if shot.name in only]


def main(argv: Sequence[str] | None = None) -> int:
    """Build the demos and capture the shots of the manifest."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--browser", help="path to a Chromium-based browser")
    parser.add_argument(
        "--only", nargs="+", metavar="NAME", help="capture only these shots"
    )
    args = parser.parse_args(argv)
    selected = _select(read_manifest(), args.only)
    browser = find_browser(args.browser)
    digest = None if args.only else input_digest()
    with tempfile.TemporaryDirectory() as directory:
        build_root = Path(directory) / "build"
        ids = demo_ids(selected)
        if ids:
            build_demos(build_root, ids)
        check_sources(build_root, selected)
        staging = Path(directory) / "staging"
        capture(build_root, browser, selected, staging)
        publish(staging, OUTPUT, selected, digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
