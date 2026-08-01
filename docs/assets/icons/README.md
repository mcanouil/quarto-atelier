# Icons

Everything here derives from `icon.svg`, the hand-authored master: a page frame with a pinned navbar, which is what the extension does.
Nothing is traced, upscaled, or model-generated, so the whole set is reproducible from source.

`icon.svg` carries an inline `@media (prefers-color-scheme: dark)` rule, so browsers that load it directly flip it with the theme.
The colours come from `../../_brand.yml`.

## Rasters

The rasters sit on the paper-dark background, matching the navbar, which is dark in both schemes.
librsvg does not evaluate `prefers-color-scheme`, so `raster-dark.css` forces the dark variant.

Tools: `rsvg-convert` (librsvg) for the vector to raster step, `magick` (ImageMagick 7) for padding, flattening, and `.ico` assembly.
Neither is a build dependency; the commands are run by hand when the master changes.

Run from this directory.

```bash
for size in 32 144 154 410; do
  rsvg-convert -s raster-dark.css -w "${size}" -h "${size}" icon.svg -o "/tmp/icon-${size}.png"
done

magick /tmp/icon-32.png -background '#14181C' -flatten -strip /tmp/icon-32-flat.png
magick /tmp/icon-32-flat.png -define icon:format=png ../../favicon.ico
magick /tmp/icon-144.png -background '#14181C' -gravity center -extent 180x180 -flatten apple-touch-icon.png
magick /tmp/icon-154.png -background '#14181C' -gravity center -extent 192x192 -flatten icon-192.png
magick /tmp/icon-410.png -background '#14181C' -gravity center -extent 512x512 -flatten icon-512.png
```

The favicon is flattened to an opaque PNG before the `.ico` is written.
Writing the `.ico` straight from the transparent render makes ImageMagick store an uncompressed 32-bit bitmap, 4,286 bytes for the same 32x32 pixels; going through the flat PNG lets it pick a palette instead, at 766 bytes and byte-for-byte identical output.

| File                   | Size    | Purpose                                                    |
| ---------------------- | ------- | ---------------------------------------------------------- |
| `icon.svg`             | vector  | `extensions.atelier.icon`, and the source for the rest     |
| `../../favicon.ico`    | 32x32   | `website.favicon`, for clients that ignore the SVG         |
| `apple-touch-icon.png` | 180x180 | `extensions.atelier.apple-touch-icon`, opaque, 10% padding |
| `icon-192.png`         | 192x192 | `../../site.webmanifest`                                    |
| `icon-512.png`         | 512x512 | `../../site.webmanifest`                                    |

There is no maskable icon: this is a documentation site, not an installable application.
