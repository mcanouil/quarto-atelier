# Atelier Extension for Quarto

A Quarto extension that provides an accessible, brand-driven documentation-website project type.
It packages a website configuration (dark-pinned navbar with search, page footer, repo actions, Open Graph, page navigation, back-to-top, `llms-txt`, and a styled 404 page), an HTML theme derived from your `_brand.yml`, and supporting scripts for accessibility (skip link, focus ring, navbar tooltips, external-link treatment, ordinal dates).
The theme also works around Quarto behaviours that break in dark mode: the baked light-grey code and tabset surfaces and the browser default scrollbar, so the sidebar, table-of-contents, code-copy button, footer, and announcement banner all stay legible in both colour schemes.

## Installation

```bash
quarto add mcanouil/quarto-atelier@0.7.1
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

### Setting format options

The project type sets `format: atelier-html`.
Configure that format by name; do not declare `html`.

```yaml
project:
  type: atelier
format:
  atelier-html:
    toc-depth: 4
```

Declaring `format: html` **replaces** `atelier-html` rather than configuring it, and Quarto reports nothing at render time.
Everything the format contributes is dropped: the skip link, the focus ring, the navbar tooltips, the external-link treatment, the ordinal dates, `lang: en-GB`, the syntax-highlighting pair, and the theme itself.
The symptom is a site that still looks broadly right, because the project type's `website:` configuration is unaffected, while none of the scripts run.

To check a project, look for the bundled scripts in any rendered page:

```bash
grep -c 'id="navbar-tooltips"' _site/index.html
```

### Adding a project stylesheet

Add your own file to `theme`, under `atelier-html`.
The extension stylesheet is still applied, and your file is appended after it, so your rules win the cascade:

```yaml
format:
  atelier-html:
    theme:
      light:
        - brand
        - assets/stylesheets/theme.scss
      dark:
        - brand
        - assets/stylesheets/theme.scss
```

Both lists are written out because a YAML anchor shared between them is rejected by the schema check.
Your stylesheet can use the theme's `body-mix()` function and the Sass variables generated from `_brand.yml` (a `midnight` palette entry becomes `$brand-midnight`), which keeps the palette in one place:

```scss
/*-- scss:rules --*/
:root {
  --atelier-navbar-bg: #{$brand-midnight};
  --atelier-navbar-accent: #{$brand-amber};
}

.my-card {
  border: 1px solid body-mix(85%);
  background: body-mix(97%);
}
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
The page footer surface and its links also follow the navbar tokens, so both dark-pinned bars share one palette, and the navbar's bottom edge and the footer's top edge are both drawn with `--atelier-navbar-border`.

A docked sidebar is the third dark-pinned bar, and each of its tokens defaults to the navbar token of the same name:

| Property                        | Default                        | Description                        |
| ------------------------------- | ------------------------------ | ---------------------------------- |
| `--atelier-sidebar-bg`          | `--atelier-navbar-bg`          | Sidebar background.                |
| `--atelier-sidebar-surface`     | `--atelier-navbar-surface`     | Search field and button surface.   |
| `--atelier-sidebar-fg`          | `--atelier-navbar-fg`          | Sidebar text.                      |
| `--atelier-sidebar-muted`       | `--atelier-navbar-muted`       | Group labels, chevrons, scrollbar. |
| `--atelier-sidebar-accent`      | `--atelier-navbar-accent`      | Hover, active, and focus accent.   |
| `--atelier-sidebar-accent-soft` | `--atelier-navbar-accent-soft` | Active item pill.                  |
| `--atelier-sidebar-border`      | `--atelier-navbar-border`      | Sidebar edge and dividers.         |

The sidebar's right edge is drawn with `--atelier-sidebar-border`, so by default it matches the navbar and footer edges.

Overriding the navbar palette therefore carries the sidebar with it; re-point the sidebar tokens only when the two should differ.

Additional tokens:

| Property                           | Default                 | Description                                              |
| ---------------------------------- | ----------------------- | -------------------------------------------------------- |
| `--atelier-heading-letter-spacing` | `0.012em`               | Heading tracking; use a negative value for tight serifs. |
| `--atelier-announcement-bg`        | Derived per alert type. | Announcement banner background.                          |
| `--atelier-announcement-border`    | Derived per alert type. | Announcement banner border.                              |
| `--atelier-announcement-ink`       | Derived per alert type. | Announcement banner text.                                |

The announcement tokens are set per `.alert-<type>` (from the Bootstrap theme colours) so the banner reads the same in both schemes; override them on `#quarto-announcement.alert-<type>` to re-pin a single type.

### Book-like sidebar

A `website.sidebar` with `style: docked` gives the book-like layout, with or without a navbar:

```yaml
website:
  sidebar:
    style: docked
    collapse-level: 2
    contents:
      - href: index.qmd
        text: "Home"
      - text: "---"
      - section: "Part 1"
        contents:
          - href: chapters/01.qmd
          - href: chapters/02.qmd
```

Atelier pins a docked sidebar to the `--atelier-sidebar-*` tokens, so it joins the navbar and the footer as one dark chrome in both colour schemes.
Quarto would otherwise derive the sidebar surface from Bootstrap's `$light`, which `_brand.yml` never sets, and paint a near-white column beside a dark page.
The section dividers, the collapse chevrons, the active item, the mobile bar that carries the sidebar toggle, the sidebar search field, and the sidebar scrollbar all follow the same tokens.

A `style: floating` sidebar is left to Quarto: it has no surface of its own, so dark ink there would land on the page background.

> [!NOTE]
> The project type puts search in the navbar.
> A project that sets `navbar: false` therefore renders no search at all until the sidebar asks for it:
>
> ```yaml
> website:
>   navbar: false
>   sidebar:
>     search: true
> ```
>
> The overlay search then reaches the sidebar as a button; `search.type: textbox` gives an input field instead, and both are themed.

### Icon-only navbar links

A navbar link with no visible text takes its accessible name and its themed tooltip from the glyph inside it.
The glyph can be an `iconify-icon`, or any empty element carrying `aria-label` or `title`, which covers inline SVG and CSS `mask-image` marks:

```yaml
website:
  navbar:
    right:
      - text: '[]{.brand-mark title="Brand" aria-label="Brand"}'
        href: "https://example.org"
      - text: "{{< iconify octicon:mark-github-16 title='GitHub' >}}"
        href: "https://github.com/owner/repo"
```

The element must be empty; a labelled element that contains text is treated as content rather than as a glyph.
Atelier moves the label onto the link, hides the glyph from assistive technology so it is not announced twice, and drops its `title` so the browser's own tooltip does not appear alongside the themed one.
Links opening in a new tab have that appended to the accessible name.

Tooltips are limited to controls that carry no visible text: these icon-only links, the colour-scheme toggle, and the brand.
A navbar item with a text label is given an `aria-label` and no tooltip, since repeating the visible text adds nothing and doubles the screen-reader announcement.
That is expected behaviour rather than a tooltip failing to bind.

## Social metadata and icons

Quarto's own `open-graph` and `twitter-card` handling covers title, description, image, image dimensions, image alt, locale, and site name.
Atelier turns both on, with `og:locale` set to `en_GB` to match its `lang: en-GB` default and the Twitter card set to `summary_large_image`.
Override the two locale values together if you change `lang`.

A bundled filter adds what Quarto has no configuration for:

- `<meta property="og:type">`, always `website`.
- `<meta property="og:url">`, per page, matching the canonical URL Quarto builds.
- `<meta name="description">`, from the page's `description` or, failing that, its `subtitle`. Quarto never populates the pandoc `description-meta` variable that the HTML template reads, so without this every page ships without a plain description tag.
- `<link rel="icon">` for an SVG icon, `<link rel="apple-touch-icon">`, `<link rel="manifest">`, and `<meta name="theme-color">`, each emitted only when configured.

The canonical link is Quarto's own `canonical-url`, which the format turns on.
It builds the URL from `website.site-url` and gives a directory index the URL of its directory, so `index.qmd` answers at the site root and `reference/index.qmd` at `reference/`.
Set `canonical-url: false` on a page served from more than one URL.

> [!NOTE]
> Give every page a `description` or a `subtitle`.
> Quarto falls back to `website.description` for `og:description`, but the filter cannot: `website` never reaches a Lua filter, so a page with neither key gets no `<meta name="description">` at all while its `og:description` still carries the site text.
> A distinct one-sentence description per page is what stops every link preview looking the same anyway.

Nothing here needs configuration except the paths you want emitted:

```yaml
extensions:
  atelier:
    icon: assets/icons/icon.svg
    apple-touch-icon: assets/icons/apple-touch-icon.png
    manifest: site.webmanifest
    theme-color:
      light: "#F5F7FA"
      dark: "#0B1220"
```

| Option             | Description                                                                         |
| ------------------ | ----------------------------------------------------------------------------------- |
| `site-url`         | Base URL for `og:url`. See the note below.                                          |
| `icon`             | Path to an SVG icon, emitted as `rel="icon"` with `type="image/svg+xml"`.           |
| `apple-touch-icon` | Path to a 180x180 PNG, emitted as `rel="apple-touch-icon"`.                         |
| `manifest`         | Path to a web app manifest, emitted as `rel="manifest"`.                            |
| `theme-color`      | `light` and `dark` colours, each emitted with a `prefers-color-scheme` media query. |

Paths are relative to the site root.
The filter writes them exactly as configured and Quarto's website resource resolver prefixes each page's offset to the project root, so one value resolves at the site root, from a subdirectory, under `quarto preview` at the server root, and under a GitHub Pages project prefix alike.
On `404.html` Quarto rewrites them to site-absolute paths instead, since that page is served from any URL depth.

> [!IMPORTANT]
> Quarto keeps the `website` block out of the metadata it hands to Lua filters, so the filter cannot read `website.site-url`.
> Anchor the value instead of writing it twice:
>
> ```yaml
> website:
>   site-url: &site-url https://example.com/my-project
> extensions:
>   atelier:
>     site-url: *site-url
> ```
>
> Without `extensions.atelier.site-url` the filter emits everything except `og:url`.
> The canonical link is unaffected, since Quarto reads `website.site-url` itself.

The 404 page gets neither tag: it answers for every missing path, so it has no URL of its own.
The filter skips it, and the front matter below switches the canonical link off.

> [!NOTE]
> Quarto's `sitemap.xml` lists a directory index as `<directory>/index.html` while the canonical link and `og:url` use `<directory>/`.
> Both URLs serve the same page and a crawler follows the canonical, which is the stronger signal.
> The two forms come from different parts of Quarto and neither is configurable.

Per-page images are left alone.
Set `website.image` and `website.image-alt` for the site-wide social card; Quarto resolves a leading `/` against `website.site-url` and measures the file to fill the image width and height tags.

Icon and manifest files are not copied to the output directory by convention.
Quarto copies only `project.resources` globs plus files it finds behind an `href` or `src` in the rendered HTML, and a manifest names its icons in JSON, which is not scanned:

```yaml
project:
  resources:
    - site.webmanifest
    - assets/icons/*.png
```

## 404 page

Quarto renders a root `404.qmd` to `404.html` and rewrites its links to absolute paths, so the page works from any URL depth.
The theme styles an opt-in `.atelier-404` wrapper as a centred ghost-numeral hero; copy this into a `404.qmd` at your project root:

````markdown
---
title: "Page not found"
toc: false
sidebar: false
canonical-url: false
---

::: {.atelier-404}

[404]{.atelier-404-code aria-hidden="true"}

The page you are looking for does not exist or has moved.

[Back to home](/){.atelier-404-home}

:::
````

Three requirements:

- Set `website.site-url` (or `site-path`) so the 404 page's links are rewritten with the correct site prefix.
- Add `404.qmd` to `project.render` if your project uses an explicit render list; Quarto does not auto-discover it there.
- Keep `canonical-url: false`, since the page answers for every missing path and has no canonical URL of its own.

The 404 page is automatically excluded from search, the sitemap, and `llms.txt`.

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).

Rendered output:

- [HTML](https://m.canouil.dev/quarto-atelier/).
