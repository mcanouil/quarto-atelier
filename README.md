# Atelier Extension for Quarto

`atelier` is an accessible, brand-driven documentation-website project type for Quarto.

It derives the navbar, the page footer, and a docked sidebar from one `_brand.yml`, in both colour schemes, and ships the accessibility scripts and social metadata a documentation site needs.

## Installation

Atelier needs Quarto 1.12.1 or later.
Older releases drop the project's `extensions` options from any page that sets `extensions` in its own front matter, which breaks workshop mode.
They also draw the announcement dismiss control so that the keyboard cannot reach it.

```bash
quarto add mcanouil/quarto-atelier@0.15.1
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
quarto add mcanouil/quarto-atelier@0.15.1
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
| [code-window](https://github.com/mcanouil/quarto-code-window) | Shows a code block in a window frame with a title bar. |
| [toc-depth](https://github.com/mcanouil/quarto-toc-depth) | Sets the table of contents depth below a heading, with the `toc-depth` attribute. |
| [mobile-toc](https://github.com/mcanouil/quarto-mobile-toc) | Shows the table of contents in a bottom sheet on narrow screens, opened from a pill. |
| [collapse-output](https://github.com/mcanouil/quarto-collapse-output) | Puts cell output in a collapsible block, with the `output-fold` cell option. |
| [div-reuse](https://github.com/mcanouil/quarto-div-reuse) | Shows the content of one div again in another, with the `reuse` attribute. |
| [highlight-text](https://github.com/mcanouil/quarto-highlight-text) | Colours a span of text, with the `fg`, `bg`, and `bc` attributes. |
| [offset-headings](https://github.com/mcanouil/quarto-offset-headings) | Moves a heading and the headings below it up or down, with the `offset-headings-by` attribute. |
| [preview-colour](https://github.com/mcanouil/quarto-preview-colour) | Shows a swatch next to a colour in inline code, which copies the colour when you select it. |
| [prism](https://github.com/mcanouil/quarto-prism) | Applies an attribute in one format only, with a format prefix such as `atelier-html:style`. |
| [remember](https://github.com/mcanouil/quarto-remember) | Offers to return a reader to the place where they stopped, in a banner below the page title. |
| [veil](https://github.com/mcanouil/quarto-veil) | Shows or hides content by group, from a button on the page, with the `veil` class and the `group` attribute. |

Each one lives in `_extensions/atelier/_extensions/mcanouil/<name>/`, and its `_extension.yml` records the release it came from.
The [reference page](https://m.canouil.dev/quarto-atelier/reference.html) lists their options and the defaults that Atelier changes.

If your project has its own copy of one of them under `_extensions/`, and names it in its `filters` list, the embedded filters of that extension do not run, and only your copy runs.
A copy that the list does not name leaves the embedded filters on.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-atelier/>, which is itself built with the project type.

## Licence

[MIT](https://github.com/mcanouil/quarto-atelier?tab=MIT-1-ov-file#readme).
