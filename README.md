# Atelier Extension for Quarto

A Quarto extension that provides an accessible, brand-driven documentation-website project type.
It packages a website configuration (dark-pinned navbar with search, page footer, repo actions, Open Graph, page navigation, back-to-top, `llms-txt`, and a styled 404 page), an HTML theme derived from your `_brand.yml`, and supporting scripts for accessibility (skip link, focus ring, navbar tooltips, external-link treatment, ordinal dates).
The theme also works around Quarto behaviours that break in dark mode: the baked light-grey code and tabset surfaces and the browser default scrollbar, so the sidebar, table-of-contents, code-copy button, footer, and announcement banner all stay legible in both colour schemes.

## Installation

```bash
quarto add mcanouil/quarto-atelier@0.1.0
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

## Usage

Set the project type in your project's `_quarto.yml`, and provide a `_brand.yml` to drive the palette:

```yaml
project:
  type: atelier
```

The project type applies a website configuration (dark-pinned navbar with search, page footer, repository actions, Open Graph, page navigation, and `llms-txt`), an accessible, dark-mode-correct HTML theme, and the supporting scripts.
The theme derives its surfaces from the brand background and foreground, so code blocks, tabsets, and scrollbars stay correct in both light and dark schemes.

Your own `website:` metadata merges with the defaults:

```yaml
project:
  type: atelier
website:
  title: "My Docs"
  repo-url: https://github.com/owner/repo
  navbar:
    left:
      - href: index.qmd
        text: "Home"
```

## Configuration

The dark-pinned navbar surfaces are exposed as CSS custom properties with neutral-slate defaults.
Override them in a project stylesheet to match your palette:

| Property                       | Default                     | Description                        |
| ------------------------------ | --------------------------- | ---------------------------------- |
| `--atelier-navbar-bg`          | `#1b242e`                   | Navbar background.                 |
| `--atelier-navbar-surface`     | `#223041`                   | Dropdown and tool-pill surface.    |
| `--atelier-navbar-fg`          | `#e8edf2`                   | Navbar text.                       |
| `--atelier-navbar-muted`       | `#9db0c0`                   | Muted navbar text.                 |
| `--atelier-navbar-accent`      | `#7fa8c4`                   | Hover and active accent.           |
| `--atelier-navbar-accent-soft` | `rgba(127, 168, 196, 0.16)` | Accent tint for hover backgrounds. |
| `--atelier-navbar-border`      | `rgba(232, 237, 242, 0.14)` | Navbar and dropdown borders.       |

```css
:root {
  --atelier-navbar-bg: #101a33;
  --atelier-navbar-accent: #e2854e;
}
```

The theme bridges these tokens onto the [gitlink](https://github.com/mcanouil/quarto-gitlink) widget's `--gitlink-widget-*` custom properties, so the navbar widget matches the navbar with no extra CSS.
The bridge is inert when the gitlink extension is not installed.
The page footer surface and its links also follow the navbar tokens, so both dark-pinned bars share one palette.

Additional tokens:

| Property                            | Default                            | Description                                             |
| ----------------------------------- | ---------------------------------- | ------------------------------------------------------- |
| `--atelier-heading-letter-spacing`  | `0.012em`                          | Heading tracking; use a negative value for tight serifs. |
| `--atelier-announcement-bg`         | Derived per alert type.            | Announcement banner background.                          |
| `--atelier-announcement-border`     | Derived per alert type.            | Announcement banner border.                              |
| `--atelier-announcement-ink`        | Derived per alert type.            | Announcement banner text.                                |

The announcement tokens are set per `.alert-<type>` (from the Bootstrap theme colours) so the banner reads the same in both schemes; override them on `#quarto-announcement.alert-<type>` to re-pin a single type.

## 404 page

Quarto renders a root `404.qmd` to `404.html` and rewrites its links to absolute paths, so the page works from any URL depth.
The theme styles an opt-in `.atelier-404` wrapper as a centred ghost-numeral hero; copy this into a `404.qmd` at your project root:

````markdown
---
title: "Page not found"
toc: false
sidebar: false
---

::: {.atelier-404}

[404]{.atelier-404-code aria-hidden="true"}

The page you are looking for does not exist or has moved.

[Back to home](/){.atelier-404-home}

:::
````

Two requirements:

- Set `website.site-url` (or `site-path`) so the 404 page's links are rewritten with the correct site prefix.
- Add `404.qmd` to `project.render` if your project uses an explicit render list; Quarto does not auto-discover it there.

The 404 page is automatically excluded from search, the sitemap, and `llms.txt`.

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).

Rendered output:

- [HTML](https://m.canouil.dev/quarto-atelier/).
