# Atelier Extension for Quarto

A Quarto extension that provides an accessible, brand-driven documentation-website project type.
It packages a website configuration (navbar with search, page footer, repo actions, Open Graph, page navigation, back-to-top, `llms-txt`, and a styled 404 page), an HTML theme derived from your `_brand.yml`, and supporting scripts for accessibility (skip link, focus ring, navbar tooltips, external-link treatment, ordinal dates).
The navbar, the page footer, and a docked sidebar are treated as one chrome, drawn from a single palette that follows the colour scheme by default and can be pinned light or dark.
The theme also works around Quarto behaviours that break in dark mode: the baked light-grey code and tabset surfaces and the browser default scrollbar, so the sidebar, table-of-contents, code-copy button, footer, and announcement banner all stay legible in both colour schemes.

## Installation

```bash
quarto add mcanouil/quarto-atelier@0.9.0
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

## Usage

Set the project type in your project's `_quarto.yml`, and provide a `_brand.yml` to drive the palette:

```yaml
project:
  type: atelier
```

The project type applies a website configuration (navbar with search, page footer, repository actions, Open Graph, page navigation, and `llms-txt`), an accessible, dark-mode-correct HTML theme, and the supporting scripts.
The theme derives its surfaces from the brand background and foreground, so the chrome, code blocks, tabsets, and scrollbars stay correct in both light and dark schemes.

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
/*-- scss:defaults --*/
$atelier-chrome: dark;

/*-- scss:rules --*/
.my-card {
  border: 1px solid body-mix(85%);
  background: body-mix(97%);
}
```

## Chrome

The navbar, the page footer, and the sidebar are the chrome: the bars that frame the page rather than carry it.
All three are drawn from one palette, so they read as a single surface, and `$atelier-chrome` decides how that palette relates to the colour scheme:

| Value   | Behaviour                                                                       |
| ------- | ------------------------------------------------------------------------------- |
| `auto`  | Default. Derived from `_brand.yml`, so the bars follow the colour-scheme toggle. |
| `light` | Pinned to the light palette below, in both schemes.                             |
| `dark`  | Pinned to the dark palette below, in both schemes.                              |

Set it in the defaults block of a project stylesheet:

```scss
/*-- scss:defaults --*/
$atelier-chrome: dark;
```

In `auto` the bar is a light tint of the page rather than the page colour itself, so it still reads as a bar without a hard colour break, and the accent is your brand primary.
The pinned palettes are three colours each, everything else being derived from them:

| Variable                       | Default   |
| ------------------------------ | --------- |
| `$atelier-chrome-dark-bg`      | `#1b242e` |
| `$atelier-chrome-dark-fg`      | `#e8edf2` |
| `$atelier-chrome-dark-accent`  | `#7fa8c4` |
| `$atelier-chrome-light-bg`     | `#eef1f5` |
| `$atelier-chrome-light-fg`     | `#1b242e` |
| `$atelier-chrome-light-accent` | `#1f5f80` |

The resolved triple is `$atelier-chrome-bg`, `$atelier-chrome-fg`, and `$atelier-chrome-accent`, and setting any of those directly overrides the mode for that colour alone:

```scss
/*-- scss:defaults --*/
$atelier-chrome-bg: $brand-midnight;
$atelier-chrome-accent: $brand-amber;
```

The two inks are passed through Quarto's `theme-contrast()` at the AA level, which lifts a colour only when it falls under 4.5:1 against the bar and leaves it alone otherwise.
This matters in `auto`: a brand primary picked against the page can fall under the ratio on a tint of that page.
Setting `$atelier-chrome-fg` or `$atelier-chrome-accent` yourself skips the correction for that colour.

Prefer these Sass variables over the custom properties below whenever the whole bar is changing.
Quarto bakes the chrome foreground into markup that CSS cannot reach afterwards, including the collapsed navbar's toggler icon and the reader-mode toggle glyph, and contrasts the sidebar link, hover, and disabled colours against the chrome background; the Sass variables reach all of it, and the custom properties do not.

### Chrome tokens

The resolved palette is republished as CSS custom properties, which is what a project overrides for a single part of a bar:

| Property                          | Description                              |
| --------------------------------- | ---------------------------------------- |
| `--atelier-navbar-bg`             | Navbar background.                       |
| `--atelier-navbar-surface`        | Dropdown and tool-pill surface.          |
| `--atelier-navbar-fg`             | Navbar text.                             |
| `--atelier-navbar-muted`          | Muted navbar text.                       |
| `--atelier-navbar-accent`         | Hover and active accent.                 |
| `--atelier-navbar-accent-soft`    | Accent tint for hover backgrounds.       |
| `--atelier-navbar-border`         | Navbar and dropdown borders.             |
| `--atelier-navbar-control-border` | Search field and widget pill boundaries. |

The two border tokens do different jobs.
`--atelier-navbar-border` is a hairline between two surfaces, at 20% of the chrome foreground, while `--atelier-navbar-control-border` outlines a boxed control at 55%, which clears the 3:1 that [WCAG 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) asks of a user-interface component on a light bar as well as a dark one.

The theme bridges these tokens onto the [gitlink](https://github.com/mcanouil/quarto-gitlink) widget's `--gitlink-widget-*` custom properties, so the navbar widget matches the navbar with no extra CSS.
The widget's own border comes from `--atelier-navbar-control-border`, since its trigger is a pill rather than a hairline, and from `--atelier-sidebar-control-border` when the widget is a sidebar tool.
Atelier sizes the navbar controls itself, from the control tokens under [Configuration](#configuration), and the defaults match the widget's own numbers, so the two agree; the widget keeps the pill visuals.
The bridge is inert when the gitlink extension is not installed.
The page footer surface and its links also follow the navbar tokens, and the navbar's bottom edge and the footer's top edge are both drawn with `--atelier-navbar-border`.

The sidebar is the third bar, and each of its tokens defaults to the navbar token of the same name:

| Property                           | Default                           | Description                              |
| ---------------------------------- | --------------------------------- | ---------------------------------------- |
| `--atelier-sidebar-bg`             | `--atelier-navbar-bg`             | Sidebar background.                      |
| `--atelier-sidebar-surface`        | `--atelier-navbar-surface`        | Search field and button surface.         |
| `--atelier-sidebar-fg`             | `--atelier-navbar-fg`             | Sidebar text.                            |
| `--atelier-sidebar-muted`          | `--atelier-navbar-muted`          | Group labels, chevrons, scrollbar.       |
| `--atelier-sidebar-accent`         | `--atelier-navbar-accent`         | Hover, active, and focus accent.         |
| `--atelier-sidebar-accent-soft`    | `--atelier-navbar-accent-soft`    | Active item pill.                        |
| `--atelier-sidebar-border`         | `--atelier-navbar-border`         | Sidebar edge and dividers.               |
| `--atelier-sidebar-control-border` | `--atelier-navbar-control-border` | Search field and widget pill boundaries. |

The sidebar's right edge is drawn with `--atelier-sidebar-border`, so by default it matches the navbar and footer edges.

Overriding the navbar tokens therefore carries the sidebar with it; re-point the sidebar tokens only when the two should differ.

## Configuration

Tokens outside the chrome:

| Property                             | Default                 | Description                                              |
| ------------------------------------ | ----------------------- | -------------------------------------------------------- |
| `--atelier-heading-letter-spacing`   | `0.012em`               | Heading tracking; use a negative value for tight serifs. |
| `--atelier-navbar-control-size`      | `2rem`                  | Navbar control box: search button, tools, toggle.        |
| `--atelier-navbar-control-icon-size` | `1rem`                  | Glyph inside that box.                                   |
| `--atelier-navbar-search-icon-size`  | Icon size times 1.2.    | Search glyph, which underfills its own viewBox.          |
| `--atelier-navbar-control-gap`       | `0.4rem`                | Space between the navbar-right controls.                 |
| `--atelier-announcement-bg`          | Derived per alert type. | Announcement banner background.                          |
| `--atelier-announcement-border`      | Derived per alert type. | Announcement banner border.                              |
| `--atelier-announcement-ink`         | Derived per alert type. | Announcement banner text.                                |

Quarto gives the overlay search button a 40px box with a 26px glyph, the colour-scheme toggle no height of its own, and a navbar tool the link font size; the control tokens put all three on one box.
The defaults are the numbers the gitlink widget uses, so the bar reads the same whether or not that extension is installed.
The search glyph takes a token of its own because it draws in 20 units of a 24-unit viewBox, where the other glyphs paint edge to edge; the 1.2 scale is what makes the ink match rather than the box.

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

Atelier gives the sidebar the chrome palette, so it joins the navbar and the footer as one surface.
Quarto derives that surface from the page instead, so alongside a navbar the column follows the body and the chrome does not read as one bar; without a navbar it falls back to Bootstrap's `$light`, which `_brand.yml` never sets, and paints a near-white column beside a dark page.
The section dividers, the collapse chevrons, the active item, the sidebar edge, the mobile bar that carries the sidebar toggle, the sidebar search field, and the sidebar scrollbar all follow the `--atelier-sidebar-*` tokens.

A `style: floating` sidebar takes the chrome background and foreground, and nothing else: it has no surface of its own, so the rest of the treatment above would have nowhere to land.

Because the column is repainted, `website.sidebar.background` and `website.sidebar.foreground` have no effect on it; set `$atelier-chrome` or the tokens instead.

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

Without a navbar, Quarto renders the sidebar tools (the colour-scheme toggle, the reader-mode toggle, any `sidebar.tools` entries, and an overlay search button) inside the sidebar title, which leaves the toggle sharing the title's line.
Atelier gives that row a line of its own, below the title and above the search field, following `sidebar.align`.
When the gitlink widget is one of those tools, the extension stacks the row into a column and orders itself between the icon tools and the search; Atelier leaves that ordering alone.

This repository ships that layout as a Quarto profile, `_quarto-sidebar.yml`, which renders the demo site with no navbar and the docked sidebar carrying the navigation and the search:

```bash
quarto preview --profile sidebar
```

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
- `<link rel="icon">` for an SVG icon, `<link rel="apple-touch-icon">`, and `<link rel="manifest">`, each emitted only when configured, and `<meta name="theme-color">`, emitted when configured or when the brand supplies a background.

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
```

| Option             | Description                                                                         |
| ------------------ | ----------------------------------------------------------------------------------- |
| `site-url`         | Base URL for `og:url`. See the note below.                                          |
| `icon`             | Path to an SVG icon, emitted as `rel="icon"` with `type="image/svg+xml"`.           |
| `apple-touch-icon` | Path to a 180x180 PNG, emitted as `rel="apple-touch-icon"`.                         |
| `manifest`         | Path to a web app manifest, emitted as `rel="manifest"`.                            |
| `theme-color`      | Browser UI tint, one colour per scheme. Defaults to the brand background.            |

Paths are relative to the site root.
The filter writes them exactly as configured and Quarto's website resource resolver prefixes each page's offset to the project root, so one value resolves at the site root, from a subdirectory, under `quarto preview` at the server root, and under a GitHub Pages project prefix alike.
On `404.html` Quarto rewrites them to site-absolute paths instead, since that page is served from any URL depth.

`theme-color` colours the browser's own chrome around the page, not anything the theme draws: the Safari toolbar, the Chrome address bar on Android, and the title bar and task-switcher entry of an installed web app.
Each scheme is emitted with a `prefers-color-scheme` media query, and each falls back to `color.background` of the `_brand.yml` for that mode, which is the value Quarto compiles into `$body-bg` for the matching bundle and so the colour the page is actually painted with.
A site with a brand background therefore needs no configuration here at all; set a scheme only to override it, and set both to move the tint off the page background:

```yaml
extensions:
  atelier:
    theme-color:
      light: "#F5F7FA"
      dark: "#0B1220"
```

A brand with no dark colours gives both schemes the same value, which is what the dark bundle paints in that configuration.
Without a brand background and without the option, no tag is emitted.

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
