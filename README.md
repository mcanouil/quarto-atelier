# Atelier Extension for Quarto

`atelier` is an accessible, brand-driven documentation-website project type for Quarto.

It derives the navbar, the page footer, and a docked sidebar from one `_brand.yml`, in both colour schemes, and ships the accessibility scripts and social metadata a documentation site needs.

## Installation

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

Atelier ships with five extensions inside it, so you don't install them yourself: [iconify](https://github.com/mcanouil/quarto-iconify), [gitlink](https://github.com/mcanouil/quarto-gitlink), [code-window](https://github.com/mcanouil/quarto-code-window), [toc-depth](https://github.com/mcanouil/quarto-toc-depth) and [collapse-output](https://github.com/mcanouil/quarto-collapse-output).
They live in `_extensions/atelier/_extensions/mcanouil/`, and each `_extension.yml` records the release it came from.
Atelier needs Quarto 1.11.9 or later, the first stable 1.11 release.
Older releases drop the project's `extensions` options on any page that sets its own `extensions` in its front matter.

If your project already has its own copy of one of them, remove it from `_extensions/` and drop its name from your `filters` list.
Otherwise both copies run, and your copy's shortcodes replace the embedded ones.

A monthly workflow opens a pull request when one of them has a new release.
To bring them up to date by hand, run the [Quarto Wizard](https://github.com/mcanouil/quarto-wizard) updater from a checkout of that repository:

```bash
npm run extensions:update -- /path/to/quarto-atelier/_extensions/atelier --apply
```

Leave out `--apply` to see what would change.
Don't use `quarto add` or `quarto update` here: they drop the `source` field the updater relies on.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-atelier/>, which is itself built with the project type.

## Licence

[MIT](https://github.com/mcanouil/quarto-atelier?tab=MIT-1-ov-file#readme).
