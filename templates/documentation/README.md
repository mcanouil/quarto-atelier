# Documentation template

This template gives you a documentation website on the Atelier project type.
It has a navbar, a docked sidebar, and five sample pages that you replace with your own.

## Use the template

You need Quarto 1.12.1 or later.
Make an empty folder and run the two commands in this order, from inside the folder.

```bash
quarto add mcanouil/quarto-atelier
quarto use template mcanouil/quarto-atelier/templates/documentation
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

Quarto opens the site in your browser and updates it each time you save a file.

## Other formats

The home page, `index.qmd`, lists three formats in its front matter: the web page, a PDF made with Typst, and a Reveal.js deck.
Quarto shows the PDF and the deck in the "Other Formats" list of the page.
The deck has its own file name, `index-slides.html`, because a page and a deck cannot both be `index.html`.
To offer the formats on another page, copy the `format` block of `index.qmd` and change the file name of the deck.
To drop them, delete the block.

To make the links of the PDF and the deck work outside the site, set `website.site-url` in `_quarto.yml` to the address of your site.
Then remove the `portable-links` lines from `extensions`, which switch the link change off until you do this.
With a `site-url`, the 404 page also loads its files from that address, so set it when you publish.

## Files to edit first

- `_quarto.yml` holds the title, the description, the repository address, and the navigation.
- `_brand.yml` holds the colours.
  Each key has a comment that says what it changes.

Then replace the text of the pages with your own.
The page `guides/writing.qmd` shows each element that you can use, so keep it as a copy source until you no longer need it.

To report a problem with the template, open an issue on the [quarto-atelier repository](https://github.com/mcanouil/quarto-atelier/issues).
