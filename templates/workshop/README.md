# Workshop template

This template gives you a workshop website on the Atelier project type.
It has no navbar.
The sidebar lists the modules, and a bar above each page shows the module and a timer.

## Use the template

You need Quarto 1.11.9 or later.
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

## How the files fit together

- `_quarto.yml` holds the title, the description, and the repository address.
- `_sidebars.yml` holds the sidebar and the list of modules.
- `workshop/_metadata.yml` turns on the workshop mode for every page in the folder `workshop`, and sets the labels of the title block.
- `_brand.yml` holds the colours.
  Each key has a comment that says what it changes.

The page `index.qmd` sits outside the folder `workshop`, so it turns on the workshop mode in its own front matter.

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
