# Social card

`og-image.png` is the Open Graph preview for this site, 1200x630, referenced from `website.image` in `_quarto.yml`.

It is not authored here.
The card comes from [quarto-social-cards](https://github.com/mcanouil/quarto-social-cards), a Typst template that renders one card per Quarto extension.
The catalogue entry for this extension is the `#social-card(...)` block with `extension-name: "atelier"`.

To regenerate, run `./export-cards.sh` in that repository, then resize its output into this directory:

```bash
magick social-cards/quarto-atelier.png -resize 1200x630 -alpha off -strip \
  -define png:compression-level=9 og-image.png
```

`-alpha off` is lossless here: the card is opaque everywhere, and dropping the constant alpha channel takes the file from 134 KB to 112 KB.

`export-cards.sh` renders the 1200x630 design at 144 PPI, so the exported PNG is 2400x1260.
The resize brings it back to the design size, which is what Open Graph consumers expect and what `og:image:width` and `og:image:height` report.
