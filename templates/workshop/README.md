# Workshop template

This template gives you a workshop website on the Atelier project type.
It has no navbar.
The sidebar lists the modules, and a bar above each page shows the module and a timer.

## Use the template

You need Quarto 1.12.1 or later.
Make an empty folder and run the two commands in this order, from inside the folder.

```bash
quarto add mcanouil/quarto-atelier
quarto use template mcanouil/quarto-atelier/templates/workshop
```

When Quarto asks whether to create a subdirectory, answer No.
The template then lands in the current folder, next to the extension.

Order matters.
If you run `quarto use template` first, the second command fails with `ERROR: Unsupported project type atelier`.
Start again in an empty folder and run `quarto add` first.

## Preview the site

```bash
quarto preview
```

## Other formats

The home page, `index.qmd`, lists three formats in its front matter: the web page, a PDF made with Typst, and a Reveal.js deck.
Quarto shows the PDF and the deck in the "Other Formats" list of the page.
The deck has its own file name, `index-slides.html`, because a page and a deck cannot both be `index.html`.
To offer the formats on another page, copy the `format` block of `index.qmd` and change the file name of the deck.
To drop them, delete the block.

To make the links of the PDF and the deck work outside the site, set `website.site-url` in `_quarto.yml` to the address of your site.
Then remove the `portable-links` lines from `extensions`, which switch the link change off until you do this.
With a `site-url`, the 404 page also loads its files from that address, so set it when you publish.

## How the files fit together

- `_quarto.yml` holds the title, the description, the repository address, and `mode: workshop`, which turns on the workshop mode for every page.
- `_sidebars.yml` holds the sidebar and the list of modules.
- `_brand.yml` holds the colours.
  Each key has a comment that says what it changes.

Keep the anchor `&workshop` and the alias `*workshop` in the same file, `_sidebars.yml`.
If you move the alias into `_quarto.yml`, Quarto stops with `YAMLException: unidentified alias`.
The `id` of the sidebar is the key that stores the progress of each learner in the browser, so change it only when you want everyone to start again.

## Add a module

1. Add a section to `contents` in `_sidebars.yml`, and list its pages by name.
2. Add the page files, and give each page a `duration` in its front matter, for example `duration: 25 min`.

The timer and the time of each module come from the durations that you write.
A page without a `duration` gets no timer.
The entries `auto` and globs in `contents` give no durations, so list the pages one by one.

To report a problem with the template, open an issue on the [quarto-atelier repository](https://github.com/mcanouil/quarto-atelier/issues).
