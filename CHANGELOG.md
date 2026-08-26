# Changelog

## Unreleased

### Bug Fixes

- fix: Paint the Bootstrap close button from the page text colour, so it reads on the dark surface of a modal or a toast. Bootstrap swaps in the light icon only under `[data-bs-theme="dark"]`, which Quarto never sets.

## 0.10.2 (2026-08-01)

### Bug Fixes

- fix: keep the [gitlink](https://github.com/mcanouil/quarto-gitlink) widget's menu inside the sidebar, so a docked sidebar carrying it no longer has a permanent horizontal scrollbar. Quarto gives the column `overflow-y: auto` and leaves `overflow-x` at `visible`, which computes to `auto`, so anything wider scrolls it sideways rather than being clipped; the menu is anchored to its trigger's left edge and sized to its content, and the theme centres the tools row, so it ran past the right edge. It raised the scrollbar even while shut, because it is hidden with `visibility` and so still takes part in layout. It is now anchored to the tools row, which spans the column.

### Documentation

- docs: Move the website into `docs/`, matching the layout every other extension in the family now uses, so the release workflow detects it and the Pages workflow deploys it from the release tag.
- docs: Generate a changelog page from `CHANGELOG.md`, through the shared pre-render and post-render scripts.
- docs: Build the site from the copy of the extension synced from the repository root, so it is rendered by the version being released.
- docs: Trim `README.md` to a landing page pointing at the website.
- docs: Add the Pages workflow and the Quarto Extensions Updates workflow.
- docs: Serve the site in the book-like layout the rest of the family uses: no navbar, with the docked sidebar carrying the navigation, the search, and the repository widget, and a three-part footer. `--profile navbar` renders the same pages with the navbar the project type ships by default.
- docs: Rename `example.qmd` to `examples.qmd` and `reference/index.qmd` to `reference.qmd`, so the pages are named as they are everywhere else.
- docs: Pin the installs the site offers to the release tag it is built from, and offer them from the editor through Quarto Wizard.

## 0.10.1 (2026-08-01)

### Bug Fixes

- fix: frame an `.embed-art` card at the dimensions of what it holds rather than at a fixed shape. An `<img>` is framed at its own dimensions and an `<embed>` at the `width` and `height` given on the image, so the padding stays the same on all four sides; anything that did not match the old fixed 1.5 was letterboxed inside it, which read as a band of padding down one axis and none on the other. `--atelier-embed-art-width` and `--atelier-embed-art-ratio` now apply only to an `<embed>` given no size of its own, which is the one case with nothing to follow.

## 0.10.0 (2026-08-01)

### New Features

- feat: `.embed-art`, a utility class that frames an embedded document or an image as a tilted, centred card. The class goes on the image itself, so no wrapper div is needed. `--atelier-embed-art-width`, `--atelier-embed-art-ratio`, and `--atelier-embed-art-tilt` resize or straighten it, and the card holds its resting angle under `prefers-reduced-motion: reduce`.

### Bug Fixes

- fix: cancel the tabset link colour transition under `prefers-reduced-motion: reduce`. It was the one motion the theme introduced that the guard did not cover.

## 0.9.0 (2026-07-31)

### Breaking Changes

- The navbar, the page footer, and the sidebar now follow the colour scheme by default rather than staying dark in both. Set `$atelier-chrome: dark;` in the defaults block of a project stylesheet to keep the previous appearance.
- `website.navbar.background`, `website.navbar.foreground`, `website.page-footer.background`, and `website.page-footer.foreground` no longer have any effect: the chrome palette sets `$navbar-bg`, `$navbar-fg`, `$footer-bg`, and `$footer-fg` from a layer Quarto evaluates first. The project type no longer sets them either.

### New Features

- feat: `$atelier-chrome`, taking `auto`, `light`, or `dark`, which decides whether the chrome follows the colour scheme or is pinned to one palette in both. The three bars are drawn from one triple, `$atelier-chrome-bg`, `$atelier-chrome-fg`, and `$atelier-chrome-accent`, each of which can be set on its own; the two pinned palettes are `$atelier-chrome-dark-*` and `$atelier-chrome-light-*`. An unknown value fails the render with a named error rather than compiling to something arbitrary.
- feat: hand the resolved palette to Quarto's own `$navbar-*`, `$sidebar-*`, and `$footer-*` variables from a defaults layer evaluated after `_brand.yml`. This is what puts the colours Quarto bakes into its own markup, which CSS cannot reach afterwards, on the same palette as everything else, and it retires most of the `!important` repainting the theme carried.
- feat: `--atelier-navbar-control-border` and `--atelier-sidebar-control-border`, the boundary of a boxed control, at 55% of the chrome foreground. The existing border tokens stay the hairline between two surfaces, which is what the sidebar edge, the section dividers, and the navbar and footer edges want.
- feat: `--atelier-navbar-control-size`, `--atelier-navbar-control-icon-size`, `--atelier-navbar-search-icon-size`, and `--atelier-navbar-control-gap`, the one box the navbar-right controls are drawn in. The defaults are the numbers the [gitlink](https://github.com/mcanouil/quarto-gitlink) widget uses, so the bar reads the same whether or not that extension is installed.
- feat: fall back per scheme to the brand background for `extensions.atelier.theme-color`, so a site with a `_brand.yml` gets both `<meta name="theme-color">` tags without restating colours it has already declared. The value is the one Quarto compiles into `$body-bg` for that bundle, which is the colour the page is painted with; an explicit `theme-color` still wins, scheme by scheme, and a site with neither still emits nothing.

### Bug Fixes

- fix: ink the reader-mode toggle from the chrome foreground. Quarto bakes `$sidebar-fg` into the glyph's SVG markup, which on the sidebar was the page ink and could match the column it sat on.
- fix: run the chrome foreground and accent through Quarto's `theme-contrast()` at the AA level, which lifts either only when it falls under 4.5:1 against the bar. A brand primary picked against the page can fall under the ratio on a tint of that page.
- fix: draw the sidebar search field and the gitlink widget pill from the new control-border tokens. Both took the hairline token, which against the bars is around 1.5:1 and reads as no border at all, where [WCAG 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) asks 3:1 of a user-interface component; 55% clears it on a light bar as well as a dark one.
- fix: size the navbar search button, the colour-scheme toggle, and the navbar tools from one control box, so the bar carries one set of controls rather than three. Quarto draws the search as a 40px button with a 26px glyph, leaves the toggle an inline link with no height of its own, and gives a tool icon the link font size. The search's `margin-left: auto` is replaced by the control gap at every width, which also retires the collapsed-navbar rule that did the same for small screens alone. The magnifier itself sat in a block wrapper whose height was a line box rather than the icon, which left uneven space above and below it and dropped the glyph off the button's centre, and it draws in 20 units of a 24-unit viewBox, so at the shared icon size it painted a sixth shorter than the colour-scheme glyph beside it.
- fix: give the sidebar tools their own line, below the title and above the search field, following `sidebar.align`. Quarto renders them inside the sidebar title whenever a titled sidebar has no navbar, as an inline row pulled up six pixels, which left the colour-scheme toggle trailing the title text. The rule forces nothing the gitlink extension sets, so a sidebar tool widget keeps its column layout and its ordering between the icon tools and the search.

### Documentation

- docs: document the chrome as one palette across the three bars: the `$atelier-chrome` modes, the pinned palettes, the resolved triple, and when to reach for the Sass variables rather than the custom properties.
- docs: add a `sidebar` Quarto profile to the demo site, rendering it with `navbar: false` and a pinned, docked sidebar carrying the navigation and a `location: sidebar`, `type: textbox` search, which is the book-like layout the README describes. Run it with `quarto preview --profile sidebar`.

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
