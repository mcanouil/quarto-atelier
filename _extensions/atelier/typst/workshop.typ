// Atelier - Typst workshop blocks
// The blocks of a workshop handout, as `workshop/typst.lua` writes them:
// prerequisites, objectives, checkpoints, exercises and answers, each a box with a head line that
// holds an icon, the title and the duration. The icons and the list boxes
// only decorate, so they are artefacts: the title names the block.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Corner radius of a workshop block, as the large Bootstrap radius of HTML.
#let atelier-ws-radius = if atelier-preset == "terminal" { 0pt } else { 8pt }

// Answer the icon of a block, drawn in the colour of its head.
// - kind: `prerequisites`, `objectives`, `checkpoint` or `exercise`.
// - ink: colour of the icon.
#let atelier-ws-icon(kind, ink) = {
  let size = 1em
  let pen = 1pt + ink
  let drawing = if kind == "objectives" {
    box(width: size, height: size, {
      place(center + horizon, circle(radius: size * 0.45, stroke: pen))
      place(center + horizon, circle(radius: size * 0.25, stroke: pen))
      place(center + horizon, circle(radius: size * 0.07, fill: ink, stroke: none))
    })
  } else if kind == "prerequisites" {
    box(width: size, height: size, {
      for row in range(3) {
        let y = size * (0.2 + 0.3 * row)
        place(top + left, line(start: (0pt, y), end: (size * 0.12, y + size * 0.1), stroke: pen))
        place(top + left, line(start: (size * 0.12, y + size * 0.1), end: (size * 0.25, y - size * 0.08), stroke: pen))
        place(top + left, line(start: (size * 0.4, y), end: (size, y), stroke: pen))
      }
    })
  } else if kind == "checkpoint" {
    box(width: size, height: size, {
      place(top + left, line(start: (size * 0.15, 0pt), end: (size * 0.15, size), stroke: pen))
      place(top + left, polygon(fill: ink, stroke: none, (size * 0.15, 0pt), (size * 0.95, size * 0.06), (size * 0.95, size * 0.5), (size * 0.15, size * 0.56)))
    })
  } else {
    box(width: size, height: size, {
      place(top + left, dy: size * 0.2, rect(width: size * 0.8, height: size * 0.8, radius: 1.5pt, stroke: pen))
      place(top + left, line(start: (size * 0.35, size * 0.65), end: (size * 0.95, size * 0.05), stroke: 1.4pt + ink))
    })
  }
  box(baseline: 0.15em, pdf.artifact(drawing))
}

// The fonts of the document, for the parts that need the monospace font.
#let atelier-document-fonts = state("atelier-document-fonts", (base: none, headings: none, monospace: none))

// Answer the duration of a block, in a pill, in the monospace font.
// - time: the duration text.
// - ink: colour of the pill.
#let atelier-ws-time(time, ink) = context {
  let monospace = atelier-document-fonts.get().monospace
  set text(font: monospace) if monospace != none
  box(inset: (x: 0.45em, y: 0.25em), radius: 99pt, stroke: 0.75pt + ink, text(size: 0.8em, weight: "medium", time))
}

// Answer a workshop block: a box with a head line and a body.
// - kind: `prerequisites`, `objectives`, `checkpoint`, `exercise` or `answer`.
// - title: title of the block.
// - time: duration text, or none.
// - body: content of the block.
#let atelier-ws-block(kind, title, time, body) = {
  let head-fill = (
    prerequisites: atelier-colour("surface-strong"),
    objectives: atelier-colour("accent-soft"),
    checkpoint: none,
    exercise: atelier-colour("workshop-bar-bg"),
    answer: none,
  ).at(kind)
  let head-ink = (
    prerequisites: atelier-colour("fg"),
    objectives: atelier-colour("accent-ink"),
    checkpoint: atelier-colour("callout-tip-ink"),
    exercise: atelier-colour("workshop-bar-fg"),
    answer: atelier-colour("accent-ink"),
  ).at(kind)
  let answer = kind == "answer"
  block(
    width: 100%,
    above: 1em,
    below: 1em,
    breakable: true,
    clip: true,
    radius: atelier-ws-radius,
    stroke: {
      let edge = (
        paint: atelier-colour(if answer { "control-border" } else { "border" }),
        thickness: 0.75pt,
        dash: if answer { "dashed" } else { none },
      )
      if kind == "checkpoint" {
        (rest: edge, left: 3pt + atelier-colour("callout-tip-border"))
      } else { edge }
    },
    {
      block(
        width: 100%,
        below: 0pt,
        fill: head-fill,
        inset: (x: 1em, y: 0.6em),
        sticky: true,
        text(fill: head-ink, weight: "bold", size: 0.95em, context grid(
          columns: (auto, 1fr, auto),
          column-gutter: 0.6em,
          align: horizon,
          if not answer { atelier-ws-icon(kind, head-ink) },
          title,
          if time != none { atelier-ws-time(time, head-ink) },
        )),
      )
      block(width: 100%, above: 0pt, inset: (x: 1em, top: 0.8em, bottom: 0.9em), {
        set text(size: 0.95em)
        body
      })
    },
  )
}

// Answer the objectives list: each item after an empty box, with no
// interaction. The box is an artefact.
// - body: the list.
#let atelier-ws-objectives(body) = {
  let mark = pdf.artifact(box(
    width: 0.75em,
    height: 0.75em,
    baseline: 0.1em,
    radius: calc.min(atelier-radius, 2pt),
    stroke: 1pt + atelier-colour("control-border"),
  ))
  set list(marker: mark, body-indent: 0.6em)
  body
}

// Answer the link from an exercise to its answer at the end:
// "Answer: page n".
// - target: label of the answer heading.
#let atelier-ws-answer-link(target) = context {
  let number = counter(page).at(target).first()
  block(above: 0.8em, link(target, atelier-labels.at("answer-page").replace("{page}", str(number))))
}

// Answer the heading of the answers at the end of a handout, on a new page.
#let atelier-ws-answers-heading() = {
  pagebreak(weak: true)
  heading(level: 1, atelier-labels.at("answers-title"))
}

// Answer the funding section: a heading of the level of the CRediT heading,
// then the statements and the awards.
// - title: the heading.
// - body: the content of the section.
#let atelier-ws-funding(title, body) = {
  heading(level: 1, numbering: none, title)
  atelier-chapter-end()
  body
}

// The citation of a handout, from its `citation` key: a dictionary of
// title, label and body, or none. The template shows it after the
// bibliography.
#let atelier-citation-data = state("atelier-citation-data", none)

// Answer the citation section: a heading of the level of the CRediT heading,
// the "cite as" label in the muted colour, then the formatted entry.
// - title: the heading.
// - label: the line before the entry.
// - body: the entry.
#let atelier-ws-citation(title, label, body) = {
  heading(level: 1, numbering: none, title)
  atelier-chapter-end()
  block(below: 0.6em, text(fill: atelier-colour("muted"), label))
  body
}

// Answer the citation section, where the template calls it after the
// bibliography, when the handout has a citation.
#let atelier-citation-section() = context {
  let data = atelier-citation-data.final()
  if data != none { atelier-ws-citation(data.title, data.label, data.body) }
}

// Answer the CRediT table: the contribution of each author to each role,
// under a heading of its own level, as the answers have. The first column
// names the role.
// - title: the heading.
// - head: the header row, the role label then the author names.
// - rows: one array for each role, the role then the degree for each author.
#let atelier-ws-credit(title, head, rows) = {
  heading(level: 1, numbering: none, title)
  atelier-chapter-end()
  set text(size: 0.9em)
  table(
    columns: (1fr,) + (auto,) * (head.len() - 1),
    align: (col, _) => if col == 0 { left } else { center },
    inset: (x: 0.6em, y: 0.45em),
    stroke: (x: none, y: 0.5pt + atelier-colour("border")),
    table.header(..head.map(cell => text(weight: "bold", cell))),
    ..rows.flatten(),
  )
}
