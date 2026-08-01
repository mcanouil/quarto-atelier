# Atelier Extension for Quarto

`atelier` is an accessible, brand-driven documentation-website project type for Quarto.

It derives the navbar, the page footer, and a docked sidebar from one `_brand.yml`, in both colour schemes, and ships the accessibility scripts and social metadata a documentation site needs.

## Installation

```bash
quarto add mcanouil/quarto-atelier@0.10.2
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

```yaml
project:
  type: atelier
```

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-atelier/>, which is itself built with the project type.

## Licence

[MIT](https://github.com/mcanouil/quarto-atelier?tab=MIT-1-ov-file#readme).
