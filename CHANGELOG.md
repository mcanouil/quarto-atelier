# Changelog

## Unreleased

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
