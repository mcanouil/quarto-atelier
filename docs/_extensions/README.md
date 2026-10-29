# Documentation website extensions

The website uses one extension: `local/atelier/`, a copy of the extension that this repository publishes.

Atelier embeds the other extensions that the website uses, such as iconify, gitlink and code-window, under `_extensions/atelier/_extensions/mcanouil/` at the repository root.
The website uses those embedded copies, so this directory has no copy of its own.
The repository README tells how to update them.

## Generated, under `local/`

`local/atelier/` is a copy of `_extensions/atelier/` at the repository root.
Git ignores it, and `../_scripts/sync-extension.sh` makes it.
Thus the repository root stays the single source of truth, and the website is built with the version that is released.
The `local` owner tells where the copy comes from.

Run the sync before you preview the website locally:

```bash
./docs/_scripts/sync-extension.sh
quarto render docs
```

The Pages workflow runs the sync before each render, so CI always builds the checked-out source.

The website needs a real copy.
A symlink or a pre-render step does not work, because Quarto reads its extensions from `_quarto.yml` before a pre-render script runs, and it does not follow symlinks.

> [!IMPORTANT]
> Do not install an extension here with `quarto add`.
>
> `../_quarto.yml` declares `project: type: atelier`, and `quarto add` builds a project context before it installs anything.
> If the synced copy is missing, it stops with `Unsupported project type atelier`.
