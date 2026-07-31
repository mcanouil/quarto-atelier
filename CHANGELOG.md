# Changelog

## Unreleased

## 0.8.0 (2026-07-31)

### New Features

- feat: dark-pinned docked sidebar, so a book-like `website.sidebar` with `style: docked` joins the navbar and the footer as one chrome in both colour schemes. Quarto derives that surface from the page instead, which alongside a navbar leaves the column following the body, and without one falls back to Bootstrap's `$light`, painting a near-white column beside a dark page.
- feat: `--atelier-sidebar-*` custom properties, each defaulting to its `--atelier-navbar-*` counterpart, driving the whole column: item ink, active item pill, section dividers, collapse chevrons, group labels, header and logo link, sidebar tools and their dropdown menus, sidebar search, the mobile bar carrying the sidebar toggle and the breadcrumbs, the sidebar edge, the sidebar scrollbar, and the focus ring. A `style: floating` sidebar keeps Quarto's page-coloured treatment, since it has no surface of its own.

### Bug Fixes

- fix: colour sidebar links, hover, and the active item from the sidebar accent instead of `$primary`, which with the default tokens was 3.2:1 against the dark column in the light scheme. The focus ring inside the sidebar takes the accent for the same reason.
- fix: ink the sidebar search field, caret, placeholder, and magnifier, and the overlay search button beside them. Quarto colours the field from `$body-color` and the button only inside `.sidebar-tools-*`, either of which can match the surface it sits on.
- fix: paint the mobile secondary navigation bar, which Quarto paints with the sidebar surface this theme replaces.
- fix: draw the sidebar's right edge and the footer's top edge from the border tokens, so all three bars carry the same hairline. Quarto draws both from its baked `#dee2e6`, the sidebar with `!important` since `sidebar.border` defaults to true when docked, and the footer through a `body`-prefixed rule that outranked the previous selector.

### Documentation

- docs: document the sidebar tokens, the book-like sidebar configuration, that `website.sidebar.background` and `foreground` have no effect on a docked sidebar, and that a project setting `navbar: false` renders no search until the sidebar asks for it.

## 0.7.1 (2026-07-27)

### Bug Fixes

- fix: keep a small gap between the colour-scheme toggle and the search button once they are grouped at the right edge of the collapsed navbar. Cancelling Quarto's automatic margin also removed every space between the two controls.

## 0.7.0 (2026-07-27)

### Bug Fixes

- fix: group the colour-scheme toggle with the search button at the right edge of the collapsed navbar and centre the brand. Quarto hands all the free space to the search button alone, which left the toggle stranded beside the brand and the search on its own at the far right.

## 0.6.0 (2026-07-26)

### Bug Fixes

- fix: build `og:url` from the page's output file rather than from its input name, so a page setting `output-file` no longer advertises a URL that does not exist and that disagrees with its own canonical link.
- fix: emit the canonical link through Quarto's own `canonical-url`, now on by default, instead of from the bundled filter. `canonical-url` is a render key and never reaches a Lua filter, so a project that set it shipped two `<link rel="canonical">` tags. Quarto builds the same directory URL for a directory index, so the tag itself is unchanged; set `canonical-url: false` on a page served from more than one URL, as the bundled 404 front matter now does.

### Documentation

- docs: add a reference page listing the website, format, and `extensions.atelier` options the project type contributes, which is also the demo site's first page below the site root.
- docs: correct the icon path note. Since 0.5.0 the filter writes each path exactly as configured and Quarto's resource resolver applies the page offset.
- docs: note that `sitemap.xml` lists a directory index as `index.html` while the canonical link uses the directory URL, that both serve the same page, and that the canonical is the stronger signal.

## 0.5.0 (2026-07-26)

### Bug Fixes

- fix: write the icon, Apple touch icon, and manifest `href` exactly as configured. Quarto's website resource resolver already prefixes each page's offset to the project root onto every `link[href]` it finds, so adding one in the filter doubled it and broke every icon on pages below the site root.
- fix: point `og:url` and `<link rel="canonical">` of a directory index at its directory rather than at `index.html`, since that is the URL the site serves and the one a scraper de-duplicates against.

## 0.4.0 (2026-07-26)

### New Features

- feat: bundled `social-metadata` filter emitting the head tags Quarto's website machinery has no configuration for: `og:type`, a per-page `og:url` and `<link rel="canonical">`, and `<meta name="description">` from the page's `description` or `subtitle` (Quarto never populates the pandoc `description-meta` variable its own HTML template reads).
- feat: `extensions.atelier` options for `icon`, `apple-touch-icon`, `manifest`, and a light and dark `theme-color`, each emitted only when set, with paths rewritten per page so they resolve under `quarto preview` and under a project-path prefix alike.
- feat: `og:locale` set to `en_GB` to match the format's `lang: en-GB`, and the Twitter card switched on as `summary_large_image`, which Quarto otherwise leaves off entirely.

### Documentation

- docs: document the social metadata and icon options, including the YAML anchor needed to reach `website.site-url` from a Lua filter, and the `project.resources` entries that get the icon and manifest files copied to the output directory.

## 0.3.0 (2026-07-26)

### Documentation

- docs: document that format options go under `atelier-html`, since declaring `html` replaces the format and silently drops the bundled scripts, `lang`, and the theme.
- docs: document how to add a project stylesheet, including the `body-mix()` function and the `$brand-*` variables generated from `_brand.yml`.
- docs: document which controls receive a tooltip, and that a navbar item with visible text is given an `aria-label` instead.

## 0.2.0 (2026-07-26)

### Bug Fixes

- fix: give icon-only navbar links a themed tooltip and an accessible name when the glyph is not an `iconify-icon`, such as an inline SVG or a CSS `mask-image` mark; the link previously kept the browser's unstyled tooltip and gained no label.

## 0.1.0 (2026-07-24)

### New Features

- feat: `atelier` project type providing a portable, accessible documentation-website foundation (dark-pinned navbar with search, page footer, repo actions, Open Graph, page navigation, back-to-top, and `llms-txt`).
- feat: dark-mode-correct code surfaces, tabset panels, and scrollbars derived from the brand palette through `body-mix()`, working around Quarto's baked light greys and the never-set `data-bs-theme` selector (Quarto marks the scheme with `body.quarto-dark` and swaps the stylesheet bundle).
- feat: accessibility scaffolding (keyboard-reachable skip link, visible focus outline, navbar tooltips, external-link treatment) and ordinal-date rendering via bundled scripts.
- feat: dark-pinned navbar tokens exposed as `--atelier-navbar-*` custom properties so a project can override the neutral-slate defaults to match its palette.
- feat: bridge the `--atelier-navbar-*` tokens onto the gitlink widget's `--gitlink-widget-*` custom properties so the navbar widget matches the dark-pinned navbar out of the box (inert without the extension).
- feat: sidebar, table-of-contents, and back-to-top styling; active links and the TOC border take the palette accent, and the back-to-top pill gains a `body-mix()` hairline.
- feat: palette-accent code-copy button, legible on the tinted code surface in both schemes.
- feat: heading letter-spacing exposed as `--atelier-heading-letter-spacing`.
- feat: dark-pinned footer repainted from the navbar tokens, including link colours.
- feat: scheme-stable announcement-banner colours pinned per alert type via `--atelier-announcement-*` custom properties.
- feat: styled 404 page pattern; `.atelier-404` ghost-numeral hero derived from `body-mix()`, demonstrated by the site's own `404.qmd` and documented in the README.
