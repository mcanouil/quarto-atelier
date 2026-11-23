# /// script
# requires-python = ">=3.11"
# ///
"""Generate the token maps of the highlighting themes, for Sass and for Lua.

Run `uv run scripts/generate-highlighting.py` to write the Sass partial and the Lua table.
Run it with `--check` to exit 1 and print a diff when one of them is stale.
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
ARROW_SENTINELS = {
    "arrow-light": ("#5e5e5e", "#4758ab"),
    "arrow-dark": ("#f8f8f2", "#ffa07a"),
}
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


Styles = dict[tuple[str, str], dict[str, dict[str, object]]]


def flags_of(style: dict[str, object], template: str) -> str:
    """Write the bold, italic and underline flags, each one with ``template``."""
    return ", ".join(
        template.format(flag=flag, value=str(bool(style[flag])).lower())
        for flag in ("bold", "italic", "underline")
    )


def style_entry(name: str, style: dict[str, object]) -> str:
    flags = flags_of(style, '"{flag}": {value}')
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


def read_all(themes: Path) -> Styles:
    return {
        (preset, scheme): read_styles(themes, preset, scheme)
        for preset in PRESETS
        for scheme in SCHEMES
    }


def render(all_styles: Styles) -> str:
    lines = [
        "// Generated file. Do not edit.",
        f"// Regenerate it with `{COMMAND}`.",
        "/*-- scss:defaults --*/",
        "",
        "$atelier-highlighting: (",
    ]
    sentinels = []
    owners = {pair: name for name, pair in ARROW_SENTINELS.items()}
    for preset in PRESETS:
        lines.append(f'  "{preset}": (')
        for scheme in SCHEMES:
            styles = all_styles[(preset, scheme)]
            lines.append(f'    "{scheme}": (')
            lines.extend(style_entry(name, styles[name]) for name in CLASSES)
            lines.append("    ),")
            comment = colour_of("Comment", styles["Comment"])
            function = colour_of("Function", styles["Function"])
            name = f"atelier-{preset}-{scheme}"
            if (comment, function) in owners:
                raise SystemExit(
                    f"{name}.theme: the (Comment, Function) pair {comment}, {function} "
                    f"equals {owners[(comment, function)]}, which html/highlighting.scss "
                    "checks. Change one of the two colours."
                )
            owners[(comment, function)] = name
            sentinels.append(f'  "{preset}-{scheme}": ({comment}, {function}),')
        lines.append("  ),")
    lines.append(") !default;")
    lines.append("")
    lines.append("$atelier-highlighting-sentinels: (")
    lines.extend(sentinels)
    lines.append(") !default;")
    return "\n".join(lines) + "\n"


def render_lua(all_styles: Styles) -> str:
    lines = [
        "-- Generated file. Do not edit.",
        f"-- Regenerate it with `{COMMAND}`.",
        "-- The token styles of each highlighting theme, read by `palette.lua`.",
        "return {",
    ]
    for preset in PRESETS:
        lines.append(f"  {preset} = {{")
        for scheme in SCHEMES:
            styles = all_styles[(preset, scheme)]
            lines.append(f"    {scheme} = {{")
            for name, css_class in CLASSES.items():
                style = styles[name]
                flags = flags_of(style, "{flag} = {value}")
                lines.append(
                    f'      ["{css_class}"] = {{ color = "{colour_of(name, style)}", '
                    f"{flags} }}, -- {name}"
                )
            lines.append("    },")
        lines.append("  },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def is_stale(path: Path, generated: str) -> bool:
    current = path.read_text(encoding="utf-8") if path.is_file() else ""
    if current == generated:
        return False
    diff = difflib.unified_diff(
        current.splitlines(keepends=True),
        generated.splitlines(keepends=True),
        fromfile=f"{path} (on disk)",
        tofile=f"{path} (generated)",
    )
    sys.stdout.writelines(diff)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check", action="store_true", help="Exit 1 if the partial is stale."
    )
    parser.add_argument("--themes", type=Path, default=EXTENSION / "highlighting")
    parser.add_argument(
        "--output", type=Path, default=EXTENSION / "html" / "highlighting-tokens.scss"
    )
    parser.add_argument(
        "--output-lua", type=Path, default=EXTENSION / "highlighting" / "tokens.lua"
    )
    args = parser.parse_args()

    all_styles = read_all(args.themes)
    outputs = {
        args.output: render(all_styles),
        args.output_lua: render_lua(all_styles),
    }
    if args.check:
        stale = [path for path, text in outputs.items() if is_stale(path, text)]
        if stale:
            print(f"Stale output. Run `{COMMAND}`.", file=sys.stderr)
            return 1
        return 0
    for path, text in outputs.items():
        path.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
