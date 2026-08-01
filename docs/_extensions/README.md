# Documentation website extensions

The extensions here fall into two groups, told apart by where they sit.

## Committed, under `mcanouil/`

`mcanouil/iconify`, `mcanouil/gitlink`, and `mcanouil/code-window` are dependencies of the website itself: the footer glyphs, the repository widget, and the code block decoration.
They are checked in like any other Quarto extension, and managed for you: [Quarto Wizard](https://m.canouil.dev/quarto-wizard) installs them, and the Quarto Extensions Updates workflow keeps them current by scanning this directory.

The other sites in this family also carry `mcanouil/atelier` for the project type and `mcanouil/pastel` for the shared palette.
This one carries neither: it publishes the project type, which comes from `local/` below, and it keeps a `_brand.yml` of its own, so the palette the project type derives is shown without a second stylesheet over it.

> [!IMPORTANT]
> Do not add or update them by hand with the Quarto CLI.
>
> `quarto add` and `quarto update` rewrite the manifest and drop the `source` and `source-type` fields, which are the only record of where each extension came from and at which version. An extension without them is invisible to the updater, and stays at whatever version it was left on.
>
> `quarto add` also fails here outright: `../_quarto.yml` declares `project: type: atelier`, and it builds a project context before installing anything, so it reports `Unsupported project type atelier` whenever the synced copy below is missing.

## Generated, under `local/`

`local/atelier/` is a copy of the extension this repository publishes, taken from `_extensions/` at the repository root.
It is ignored by Git and produced by `../_scripts/sync-extension.sh`, so the repository root stays the single source of truth, and the site is built by the version being released.
The `local` owner says where it came from, and keeps it clear of the vendored dependencies even when the extension is named after its owner.

Run the sync before previewing the site locally:

```bash
./docs/_scripts/sync-extension.sh
quarto render docs
```

The Pages workflow runs it before every render, so CI always builds the checked-out source.

A real copy is needed, rather than a symlink or a pre-render step.
Quarto builds its extension registry while reading `_quarto.yml`, before any pre-render script runs, and it does not follow symlinks.
