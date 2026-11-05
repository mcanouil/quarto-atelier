# /// script
# requires-python = ">=3.11"
# ///
"""Generate the Sass token map of the highlighting themes.

Run `uv run scripts/generate-highlighting.py` to write the partial.
Run it with `--check` to exit 1 and print a diff when the partial is stale.
"""

from __future__ import annotations

import argparse
import difflib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXTENSION = ROOT / "_extensions" / "atelier"
PRESETS = ("default", "quarto", "terminal")
SCHEMES = ("light", "dark")
COMMAND = "uv run scripts/generate-highlighting.py"

CLASSES = {
    "Normal": "",
    "Keyword": "kw",
    "DataType": "dt",
    "DecVal": "dv",
    "BaseN": "bn",
    "Float": "fl",
    "Constant": "cn",
    "Char": "ch",
    "SpecialChar": "sc",
    "String": "st",
    "VerbatimString": "vs",
    "SpecialString": "ss",
    "Import": "im",
    "Comment": "co",
    "Documentation": "do",
    "Annotation": "an",
    "CommentVar": "cv",
    "Other": "ot",
    "Function": "fu",
    "Variable": "va",
    "ControlFlow": "cf",
    "Operator": "op",
    "BuiltIn": "bu",
    "Extension": "ex",
    "Preprocessor": "pp",
    "Attribute": "at",
    "RegionMarker": "re",
    "Information": "in",
    "Warning": "wa",
    "Alert": "al",
    "Error": "er",
}


def colour_of(name: str, style: dict[str, object]) -> str:
    colour = style["text-color"]
    if not isinstance(colour, str):
        raise SystemExit(f"{name}: text-color must be a string, got {colour!r}.")
    return colour.lower()


def style_entry(name: str, style: dict[str, object]) -> str:
    flags = ", ".join(
        f'"{flag}": {str(bool(style[flag])).lower()}'
        for flag in ("bold", "italic", "underline")
    )
    return (
        f'        "{CLASSES[name]}": ("color": {colour_of(name, style)}, {flags}), '
        f"// {name}"
    )


def read_styles(themes: Path, preset: str, scheme: str) -> dict[str, dict[str, object]]:
    path = themes / f"atelier-{preset}-{scheme}.theme"
    if not path.is_file():
        raise SystemExit(f"Missing theme file: {path}.")
    styles = json.loads(path.read_text(encoding="utf-8"))["text-styles"]
    missing = sorted(set(CLASSES) - set(styles))
    if missing:
        raise SystemExit(f"{path.name}: missing token types {', '.join(missing)}.")
    return styles


def render(themes: Path) -> str:
    lines = [
        "// Generated file. Do not edit.",
        f"// Regenerate it with `{COMMAND}`.",
        "/*-- scss:defaults --*/",
        "",
        "$atelier-highlighting: (",
    ]
    sentinels = []
    for preset in PRESETS:
        lines.append(f'  "{preset}": (')
        for scheme in SCHEMES:
            styles = read_styles(themes, preset, scheme)
            lines.append(f'    "{scheme}": (')
            lines.extend(style_entry(name, styles[name]) for name in CLASSES)
            lines.append("    ),")
            comment = colour_of("Comment", styles["Comment"])
            function = colour_of("Function", styles["Function"])
            sentinels.append(f'  "{preset}-{scheme}": ({comment}, {function}),')
        lines.append("  ),")
    lines.append(") !default;")
    lines.append("")
    lines.append("$atelier-highlighting-sentinels: (")
    lines.extend(sentinels)
    lines.append(") !default;")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check", action="store_true", help="Exit 1 if the partial is stale."
    )
    parser.add_argument("--themes", type=Path, default=EXTENSION / "highlighting")
    parser.add_argument(
        "--output", type=Path, default=EXTENSION / "html" / "highlighting-tokens.scss"
    )
    args = parser.parse_args()

    generated = render(args.themes)
    if args.check:
        current = (
            args.output.read_text(encoding="utf-8") if args.output.is_file() else ""
        )
        if current == generated:
            return 0
        diff = difflib.unified_diff(
            current.splitlines(keepends=True),
            generated.splitlines(keepends=True),
            fromfile=f"{args.output} (on disk)",
            tofile=f"{args.output} (generated)",
        )
        sys.stdout.writelines(diff)
        print(f"Stale partial. Run `{COMMAND}`.", file=sys.stderr)
        return 1
    args.output.write_text(generated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
