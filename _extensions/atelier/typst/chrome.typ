// Atelier - Typst page chrome
// The page set-up: the page colour, the header with the current chapter, the
// footer with the page number, and the surfaces, pages that a mark gives
// their own header and footer, such as the cover or a chapter divider.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Mark the page that holds the mark as a surface of a kind. atelier-page()
// gives that page the header and footer of the kind.
// - kind: `cover`, `divider`, `contents` or `closing`.
#let atelier-surface(kind) = [#metadata(kind)<atelier-surface>]

// Answer the surface kind of a page, from its first mark, or none.
// - page: page number.
#let atelier-surface-at(page) = {
  let marks = query(<atelier-surface>).filter(it => it.location().page() == page)
  if marks.len() > 0 { marks.first().value }
}

// Lay out a header or footer as three cells, aligned left, centred and
// aligned right. An empty cell renders nothing.
#let atelier-slots(left: none, centre: none, right: none) = grid(
  columns: (1fr, auto, 1fr),
  column-gutter: 1em,
  align: (std.left, std.center, std.right),
  left, centre, right,
)

// Answer the page number as "n / total", with tabular figures.
#let atelier-page-number() = context text(number-width: "tabular")[
  #counter(page).get().first() / #counter(page).final().first()
]

// Answer the title of the chapter of the page: the last level-1 heading on
// this page or on an earlier one, with its number when it has one.
#let atelier-chapter-title() = context {
  let number = here().page()
  let in-force = query(heading.where(level: 1)).filter(it => it.location().page() <= number)
  if in-force.len() > 0 {
    let chapter = in-force.last()
    if chapter.numbering != none {
      numbering(chapter.numbering, ..counter(heading).at(chapter.location()))
      h(0.5em)
    }
    chapter.body
  }
}

// Set up the pages of a document: the page colour, and the header and
// footer of each page, after its surface. The header has the document title
// and the current chapter; the footer has the page number. A cover and a
// divider have neither; a closing page has the footer only.
// - title: the document title, or none.
// - body: the content of the document.
// - logo: the logo, a dictionary with `path` and `alt`, or none.
// - organisation: the organisation, or none.
// - rights: the copyright and the licence, or none.
//
// The header has the title and the chapter, on the pages after the first,
// on ordinary pages and on the "In this chapter" pages. The footer has, on
// one line, the organisation, the rights and the logo, and the page number
// below. A cover, a divider and the closing page have no header and no
// footer, but the rights show where the first line of the footer sits. The
// header and the footer only decorate, so they are artefacts.
#let atelier-page(title, body, logo: none, organisation: none, rights: none) = {
  let furniture(content) = text(size: 8pt, fill: atelier-colour("muted"), content)
  let kind() = atelier-surface-at(here().page())
  let framed() = kind() in (none, "contents")
  let mark = if logo != none { image(logo.path, height: 9pt, alt: logo.alt) }
  set page(
    fill: atelier-colour("bg"),
    // The workshop motif sits in the top right corner of the first page,
    // with the title block or the cover.
    background: context {
      let motif = atelier-motif-data
      if motif != none and here().page() == 1 {
        atelier-motif(motif.shapes, top + right, 45mm, motif.paint, factor: motif.factor)
      }
    },
    header: context {
      if framed() and here().page() > 1 {
        pdf.artifact(block(
          width: 100%,
          inset: (bottom: 3pt),
          stroke: (bottom: 0.5pt + atelier-colour("border")),
          furniture(atelier-slots(left: title, right: atelier-chapter-title())),
        ))
      }
    },
    footer: context {
      let first-line = grid(
        columns: (1fr, auto, 1fr),
        column-gutter: 1em,
        align: (left + horizon, center + horizon, right + horizon),
        organisation, rights, mark,
      )
      if framed() {
        let has-line = organisation != none or rights != none or mark != none
        pdf.artifact(furniture(stack(
          spacing: 7pt,
          ..if has-line { (first-line,) },
          align(center, atelier-page-number()),
        )))
      } else if rights != none {
        pdf.artifact(furniture(align(center, rights)))
      }
    },
  )
  body
}
