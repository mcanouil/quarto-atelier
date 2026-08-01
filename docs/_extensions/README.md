# Documentation website extensions

## Generated, at `_extensions/atelier/`

`atelier/` is a copy of the extension this repository publishes, taken from `_extensions/` at the repository root.
It is ignored by Git and produced by `../_scripts/sync-extension.sh`, so the repository root stays the single source of truth, and the site is built by the version being released.

Run the sync before previewing the site locally:

```bash
./docs/_scripts/sync-extension.sh
quarto render docs
```

The Pages workflow runs it before every render.

A real copy is needed, rather than a symlink or a pre-render step.
Quarto builds its extension registry while reading `_quarto.yml`, before any pre-render script runs, and it does not follow symlinks.

## No committed dependencies

Unlike the other documentation sites in this family, this one carries none.
It predates the shared scaffold and uses its own `_brand.yml`, navbar, and sidebar, which is deliberate: this repository publishes the project type those sites are built on, so its own site is the one place that theme is shown without anything layered on top.
