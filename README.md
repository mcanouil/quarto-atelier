# Atelier Extension for Quarto

`atelier` is an accessible, brand-driven documentation-website project type for Quarto.

It derives the navbar, the page footer, and a docked sidebar from one `_brand.yml`, in both colour schemes, and ships the accessibility scripts and social metadata a documentation site needs.

## Installation

```bash
quarto add mcanouil/quarto-atelier@0.10.7
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

```yaml
project:
  type: atelier
```

## Embedded extensions

Atelier ships with six extensions inside it, so you don't install them yourself: [iconify](https://github.com/mcanouil/quarto-iconify), [gitlink](https://github.com/mcanouil/quarto-gitlink), [code-window](https://github.com/mcanouil/quarto-code-window), [badge](https://github.com/mcanouil/quarto-badge), [toc-depth](https://github.com/mcanouil/quarto-toc-depth) and [collapse-output](https://github.com/mcanouil/quarto-collapse-output).
They live in `_extensions/atelier/_extensions/mcanouil/`, and each `_extension.yml` records the release it came from.
Atelier's minimum Quarto version follows theirs: it is the highest version any of them needs.

If your project already has its own copy of one of them, remove it from `_extensions/` and drop its name from your `filters` list.
Otherwise both copies run, and your copy's shortcodes replace the embedded ones.

To bring them up to date, run the [Quarto Wizard](https://github.com/mcanouil/quarto-wizard) updater from a checkout of that repository:

```bash
npm run extensions:update -- /path/to/quarto-atelier/_extensions/atelier --apply
```

Leave out `--apply` to see what would change.
Don't use `quarto add` or `quarto update` here: they drop the `source` field the updater relies on.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-atelier/>, which is itself built with the project type.

## Licence

[MIT](https://github.com/mcanouil/quarto-atelier?tab=MIT-1-ov-file#readme).
