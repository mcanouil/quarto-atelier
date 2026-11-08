# Atelier Extension for Quarto

`atelier` is an accessible, brand-driven documentation-website project type for Quarto.

It derives the navbar, the page footer, and a docked sidebar from one `_brand.yml`, in both colour schemes, and ships the accessibility scripts and social metadata a documentation site needs.

## Installation

Atelier needs Quarto 1.11.9 or later, which is the first stable 1.11 release.
Older releases drop the project's `extensions` options from any page that sets `extensions` in its own front matter, which breaks workshop mode.

```bash
quarto add mcanouil/quarto-atelier@0.11.0
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

```yaml
project:
  type: atelier
```

## Starter templates

Two templates give you a working site to start from: `documentation`, with a navbar and a docked sidebar, and `workshop`, with the sidebar only and workshop mode turned on.
Run the two commands in an empty folder, in this order:

```bash
quarto add mcanouil/quarto-atelier
quarto use template mcanouil/quarto-atelier/templates/documentation
```

Swap `documentation` for `workshop` to get the workshop.
When Quarto asks whether to create a subdirectory for the template, answer No, so the files land next to the extension.
The order matters: the templates don't carry the extension, and if you run `quarto use template` first, `quarto add` stops with `ERROR: Unsupported project type atelier`.

The [templates page](https://m.canouil.dev/quarto-atelier/templates.html) lists the files of each template and what to edit first.

## Embedded extensions

Atelier ships with the extensions below, so you don't install them yourself.

| Extension | What it does |
| --- | --- |
| [iconify](https://github.com/mcanouil/quarto-iconify) | Adds the `{{< iconify >}}` shortcode, for icons from the Iconify sets. |
| [gitlink](https://github.com/mcanouil/quarto-gitlink) | Shows a repository widget in place of a navbar item or sidebar tool with the href `#gitlink-widget`. |
| [code-window](https://github.com/mcanouil/quarto-code-window) | Shows a code block that has a `filename` in a window frame with a title bar. |
| [toc-depth](https://github.com/mcanouil/quarto-toc-depth) | Sets the table of contents depth below a heading, with the `toc-depth` attribute. |
| [mobile-toc](https://github.com/mcanouil/quarto-mobile-toc) | Shows the table of contents in a bottom sheet on narrow screens, opened from a pill. |
| [collapse-output](https://github.com/mcanouil/quarto-collapse-output) | Puts cell output in a collapsible block, with the `output-fold` cell option. |

Each one lives in `_extensions/atelier/_extensions/mcanouil/<name>/`, and its `_extension.yml` records the release it came from.
The [reference page](https://m.canouil.dev/quarto-atelier/reference.html) lists their options and the defaults that Atelier changes.

If your project already has its own copy of one of them, remove it from `_extensions/` and drop its name from your `filters` list.
Otherwise both copies run, and your copy's shortcodes replace the embedded ones.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-atelier/>, which is itself built with the project type.

## Licence

[MIT](https://github.com/mcanouil/quarto-atelier?tab=MIT-1-ov-file#readme).
