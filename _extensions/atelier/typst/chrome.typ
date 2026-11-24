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
#let atelier-page(title, body) = {
  let furniture(content) = text(size: 8pt, fill: atelier-colour("muted"), content)
  let kind() = atelier-surface-at(here().page())
  set page(
    fill: atelier-colour("bg"),
    header: context {
      if kind() == none and here().page() > 1 {
        block(
          width: 100%,
          inset: (bottom: 3pt),
          stroke: (bottom: 0.5pt + atelier-colour("border")),
          furniture(atelier-slots(left: title, right: atelier-chapter-title())),
        )
      }
    },
    footer: context {
      if kind() not in ("cover", "divider") {
        furniture(atelier-slots(right: atelier-page-number()))
      }
    },
  )
  body
}
