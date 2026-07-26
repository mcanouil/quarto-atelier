# Social card

`og-image.png` is the Open Graph preview for this site, 1200x630, referenced from `website.image` in `_quarto.yml`.

It is not authored here.
The card comes from [quarto-social-cards](https://github.com/mcanouil/quarto-social-cards), a Typst template that renders one card per Quarto extension.
The catalogue entry for this extension is the `#social-card(...)` block with `extension-name: "atelier"`.

To regenerate, run the export in that repository and copy the result back:

```bash
./export-cards.sh
magick social-cards/quarto-atelier.png -resize 1200x630 -strip \
  ../../quarto-extensions/quarto-atelier/assets/social/og-image.png
```

`export-cards.sh` renders the 1200x630 design at 144 PPI, so the exported PNG is 2400x1260.
The resize brings it back to the design size, which is what Open Graph consumers expect and what `og:image:width` and `og:image:height` report.
