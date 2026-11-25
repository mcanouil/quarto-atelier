# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow", "playwright"]
# ///
"""Capture the gallery screenshots that the manifest lists.

Run `uv run scripts/capture-gallery.py` to build the demos, render the samples of
`docs/_samples/`, and write every image of `docs/_samples/_screenshots.tsv` to
`docs/assets/gallery/`, with the digest of the inputs in
`docs/assets/gallery/inputs.sha256`.
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

from PIL import Image, ImageChops
from playwright.sync_api import Page, Response, sync_playwright
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError

ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = ROOT / "docs" / "_scripts" / "build-demos.sh"
SYNC_SCRIPT = ROOT / "docs" / "_scripts" / "sync-extension.sh"
SAMPLES = ROOT / "docs" / "_samples"
FONTS = ROOT / "_extensions" / "atelier" / "fonts"
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
DECK_VIEWPORT = {"width": 1280, "height": 720}
TYPST_PPI = 110
CROP_SUFFIX = "+trim"
FONT_WARNING = "unknown font family"
DECK_READY = "() => window.Reveal !== undefined && window.Reveal.isReady()"
GO_TO_SLIDE = """target => new Promise(resolve => {
  Reveal.on("slidetransitionend", () => resolve());
  setTimeout(resolve, 1000);
  location.hash = target;
})"""
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


def _sample_stem(shot: Shot) -> str | None:
    parts = Path(shot.source).parts
    if len(parts) > 1 and parts[0] == "samples":
        return Path(parts[1]).stem
    return None


def sample_stems(shots: Sequence[Shot]) -> list[str]:
    """Return the unique sample stems of the shots under `samples/`, in order."""
    stems: list[str] = []
    for shot in shots:
        stem = _sample_stem(shot)
        if stem is not None and stem not in stems:
            stems.append(stem)
    return stems


def check_samples(shots: Sequence[Shot]) -> None:
    """Stop when a sample has no shot, or a shot names a sample that does not exist.

    Args:
        shots: Every shot of the manifest.

    Raises:
        SystemExit: A `.qmd` file of `SAMPLES` without a leading underscore has
            no shot, or a shot under `samples/` has no `.qmd` file.
    """
    samples = {p.stem for p in SAMPLES.glob("*.qmd") if not p.name.startswith("_")}
    for shot in shots:
        stem = _sample_stem(shot)
        if stem is not None and stem not in samples:
            raise SystemExit(
                f"Shot {shot.name}: {shot.source} has no sample {stem}.qmd "
                f"in {SAMPLES}."
            )
    orphans = sorted(f"{stem}.qmd" for stem in samples - set(sample_stems(shots)))
    if orphans:
        raise SystemExit(
            f"No shot uses the sample {', '.join(orphans)} in {SAMPLES}. "
            f"Add a line to {MANIFEST.name}, or remove the sample."
        )


def render_samples(build_root: Path, stems: Sequence[str]) -> None:
    """Render the samples with the given stems into `build_root / "samples"`.

    The samples render in a copy of `SAMPLES`, with a copy of the extension in
    `_extensions/local/`, because Quarto does not follow symlinks to extensions.
    The outputs stay next to the copied sources, so their relative paths hold.

    Raises:
        SystemExit: A render fails; the message holds the Quarto log.
    """
    work = build_root / "samples"
    shutil.copytree(SAMPLES, work)
    subprocess.run(
        [str(SYNC_SCRIPT), str(work / "_extensions" / "local")],
        check=True,
        capture_output=True,
    )
    for stem in stems:
        print(f"[samples] Rendering {stem}.qmd")
        result = subprocess.run(
            ["quarto", "render", f"{stem}.qmd"],
            cwd=work,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise SystemExit(
                f"quarto render {stem}.qmd failed in a copy of {SAMPLES}:\n"
                f"{result.stdout}{result.stderr}"
            )


def parse_typst_target(target: str) -> tuple[int, bool]:
    """Return the page number of a Typst target, and whether to trim the page.

    Raises:
        SystemExit: The target is not a page number from 1, with an optional
            `+trim` suffix.
    """
    number = target.removesuffix(CROP_SUFFIX)
    if not number.isdecimal() or int(number) < 1:
        raise SystemExit(
            f"Typst target {target!r} must be a page number from 1, "
            f"with an optional {CROP_SUFFIX} suffix."
        )
    return int(number), target.endswith(CROP_SUFFIX)


def capture_typst(typ: Path, page: int, out: Path) -> None:
    """Compile one page of a Typst file to a PNG, with the fonts of the extension.

    Raises:
        SystemExit: The compile fails, or Typst does not find a font and would
            use a fallback font.
    """
    command = [
        "quarto",
        "typst",
        "compile",
        str(typ),
        str(out),
        "--format",
        "png",
        "--pages",
        str(page),
        "--ppi",
        str(TYPST_PPI),
        "--font-path",
        str(FONTS),
        "--root",
        str(typ.parent),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    log = f"{result.stdout}{result.stderr}"
    if result.returncode != 0 or FONT_WARNING in log or not out.is_file():
        raise SystemExit(f"quarto typst compile {typ.name}, page {page}:\n{log}")


def trim(path: Path, margin: int = 24) -> None:
    """Crop a PNG to the pixels that differ from its top-left corner, plus a margin.

    Raises:
        SystemExit: Every pixel has the colour of the corner.
    """
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        corner = Image.new("RGB", rgb.size, rgb.getpixel((0, 0)))
        box = ImageChops.difference(rgb, corner).getbbox()
        if box is None:
            raise SystemExit(f"{path} is blank: there is nothing to trim to.")
        left, top, right, bottom = box
        cropped = image.crop(
            (
                max(left - margin, 0),
                max(top - margin, 0),
                min(right + margin, image.width),
                min(bottom + margin, image.height),
            )
        )
    cropped.save(path)


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


def screenshot_element(page: Page, shot: Shot, out: Path) -> None:
    """Write a PNG of the one element that the CSS selector of the shot matches.

    Raises:
        SystemExit: The selector matches no element, or more than one.
    """
    locator = page.locator(shot.target)
    count = locator.count()
    if count != 1:
        raise SystemExit(
            f"Shot {shot.name}: the selector {shot.target!r} matches {count} "
            f"elements in {shot.source}; it must match exactly one."
        )
    locator.screenshot(path=str(out))


def _load(page: Page, origin: str, shot: Shot) -> None:
    failures = watch_failures(page, origin)
    timeout: PlaywrightTimeoutError | None = None
    try:
        page.goto(f"{origin}{PREFIX}/{shot.source}", wait_until="networkidle")
        if shot.kind == "revealjs":
            page.wait_for_function(DECK_READY)
        page.evaluate("document.fonts.ready")
        if shot.kind == "html":
            page.wait_for_function(SCHEME_READY, arg=shot.scheme)
    except PlaywrightTimeoutError as error:
        if not failures:
            raise
        timeout = error
    if failures:
        raise RuntimeError(
            f"Shot {shot.name} ({shot.source}) failed to load: " + ", ".join(failures)
        ) from timeout


def _capture_browser(page: Page, origin: str, shot: Shot, out: Path) -> None:
    _load(page, origin, shot)
    if shot.kind == "revealjs":
        page.evaluate(GO_TO_SLIDE, shot.target)
        page.screenshot(path=str(out))
    elif shot.target == "page":
        page.screenshot(path=str(out))
    else:
        screenshot_element(page, shot, out)


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
                out = staging / f"{shot.name}.png"
                if shot.kind == "typst":
                    page_number, trimmed = parse_typst_target(shot.target)
                    capture_typst(build_root / shot.source, page_number, out)
                    if trimmed:
                        trim(out)
                    print(f"[gallery] {shot.name}.png")
                    continue
                viewport = DECK_VIEWPORT if shot.kind == "revealjs" else VIEWPORT
                context = chromium.new_context(
                    viewport=viewport, color_scheme=shot.scheme
                )
                try:
                    _capture_browser(context.new_page(), origin, shot, out)
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
    """Build the demos, render the samples and capture the shots of the manifest."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--browser", help="path to a Chromium-based browser")
    parser.add_argument(
        "--only", nargs="+", metavar="NAME", help="capture only these shots"
    )
    args = parser.parse_args(argv)
    shots = read_manifest()
    selected = _select(shots, args.only)
    check_samples(shots)
    browser = find_browser(args.browser)
    digest = None if args.only else input_digest()
    with tempfile.TemporaryDirectory() as directory:
        build_root = Path(directory) / "build"
        ids = demo_ids(selected)
        if ids:
            build_demos(build_root, ids)
        stems = sample_stems(selected)
        if stems:
            render_samples(build_root, stems)
        check_sources(build_root, selected)
        staging = Path(directory) / "staging"
        capture(build_root, browser, selected, staging)
        publish(staging, OUTPUT, selected, digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
