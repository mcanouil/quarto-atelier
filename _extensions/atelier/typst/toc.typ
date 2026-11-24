// Atelier - Typst contents, dividers and closing page
// The table of contents of the document, the divider page of a chapter or a
// book part, the contents page of a chapter, and the closing page. Every
// contents entry links to its heading; the dot leaders and the rules are
// artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Whether the next level-1 heading is a book part: `atelier-typst.lua` sets
// it before a `.part` heading, and the heading clears it.
#let atelier-part-next = state("atelier-part-next", false)

// Answer dot leaders that fill the rest of a line, as an artefact.
#let atelier-leaders() = box(width: 1fr, pdf.artifact(text(fill: atelier-colour("muted"), repeat[.#h(0.3em)])))

// Answer a decorative rule in the accent mark colour.
// - length: length of the rule.
#let atelier-rule(length) = pdf.artifact(line(length: length, stroke: 2pt + atelier-colour("accent-mark")))

// Answer a kicker: a short upper-case line above a title.
// - content: the text.
#let atelier-kicker(content) = text(size: 0.75em, weight: "bold", tracking: 0.08em, fill: atelier-colour("accent-text"), upper(content))

// Answer the table of contents of the document.
// - title: title of the contents, from Quarto's `toc-title`.
// - depth: deepest heading level that it lists.
#let atelier-contents(title, depth) = {
  show outline.entry.where(level: 1): set block(above: 1.1em)
  show outline.entry.where(level: 1): set text(weight: "bold")
  set outline.entry(fill: atelier-leaders())
  outline(title: title, depth: depth)
}

// Answer the headings that the contents of a chapter list: those under the
// chapter and before the next level-1 heading, down to a depth.
// - chapter: the level-1 heading.
// - depth: how many levels under the chapter it lists.
#let atelier-chapter-entries(chapter, depth) = {
  let next = query(heading.where(level: 1).after(chapter.location(), inclusive: false))
  let scope = selector(heading).after(chapter.location(), inclusive: false)
  if next.len() > 0 {
    scope = scope.before(next.first().location(), inclusive: false)
  }
  query(scope).filter(it => it.outlined and it.level > 1 and it.level <= depth + 1)
}

// Answer the contents of a chapter: the "In this chapter" heading, then one
// linked entry for each section, with dot leaders and the page number.
// - chapter: the level-1 heading.
// - depth: how many levels under the chapter it lists.
#let atelier-chapter-contents(chapter, depth) = {
  let entries = atelier-chapter-entries(chapter, depth)
  if entries.len() == 0 { return }
  let entry(it) = {
    let level = it.level - 1
    let number = if it.numbering != none {
      text(fill: atelier-colour("accent-text"), numbering(it.numbering, ..counter(heading).at(it.location())))
      h(0.6em)
    }
    let page = text(number-width: "tabular", str(counter(page).at(it.location()).first()))
    let line = [#number#it.body#h(0.4em)#atelier-leaders()#h(0.4em)#page]
    block(
      above: if level == 1 { 0.9em } else { 0.45em },
      below: 0pt,
      inset: (left: (level - 1) * 1.6em),
      link(it.location(), if level == 1 { text(weight: "bold", line) } else { text(fill: atelier-colour("muted"), line) }),
    )
  }
  atelier-surface("contents")
  heading(level: 2, numbering: none, outlined: false, bookmarked: false, atelier-labels.at("in-this-chapter"))
  block(above: 0.6em, below: 1em, atelier-rule(30%))
  for it in entries {
    entry(it)
  }
}

// Answer the label of a chapter, such as "Chapter 3", or the part label.
// - it: a level-1 heading.
// - part: true for a book part.
#let atelier-chapter-label(it, part) = {
  if part { return atelier-labels.at("part") }
  let label = atelier-labels.at("chapter")
  if it.numbering != none {
    label + " " + numbering(it.numbering, ..counter(heading).at(it.location()))
  } else {
    label
  }
}

// Answer a level-1 heading of the body, after the switches. A heading that
// is not outlined, such as the title of the table of contents, stays as it
// is. With `chapter-dividers`, a chapter or a book part starts a divider
// page; with `chapter-contents` only, a chapter starts a new page.
// atelier-chapter-end() follows each level-1 heading and ends that page.
// - it: the heading.
// - switches: the five report switches.
#let atelier-chapter(it, switches) = {
  if not it.outlined { return it }
  let dividers = switches.at("chapter-dividers")
  if not dividers and not switches.at("chapter-contents") { return it }
  pagebreak(weak: true)
  if not dividers { return it }
  atelier-surface("divider")
  v(28%)
  context block(below: 0.8em, atelier-kicker(atelier-chapter-label(it, atelier-part-next.get())))
  block(text(size: 2.4em, weight: "bold", fill: atelier-colour("heading"), it.body))
}

// End the page that a level-1 heading starts: the rule of a divider page,
// then the contents page of a chapter with `chapter-contents`, and the page
// break before the body. `atelier-typst.lua` writes the call after each
// level-1 heading. It does nothing after a heading that is not outlined.
// The contents of a chapter list two levels under it.
#let atelier-chapter-end() = context {
  let switches = atelier-switches
  let depth = 2
  let chapter = query(heading.where(level: 1).before(here())).last()
  let part = atelier-part-next.get()
  let dividers = switches.at("chapter-dividers")
  let contents = switches.at("chapter-contents") and not part
  if chapter.outlined {
    if dividers {
      block(above: 1em, atelier-rule(35%))
      pagebreak()
    }
    if contents and atelier-chapter-entries(chapter, depth).len() > 0 {
      atelier-chapter-contents(chapter, depth)
      pagebreak()
    }
  }
  atelier-part-next.update(false)
}

// Answer the closing page: the contact of each author, the licence and the
// colophon.
// - meta: the document, see atelier-document().
#let atelier-closing-page(meta) = {
  let part(label, content) = block(above: 1.6em, {
    block(below: 0.6em, atelier-kicker(label))
    content
  })
  pagebreak(weak: true)
  atelier-surface("closing")
  v(1fr)
  atelier-rule(30%)
  let contacts = atelier-people.authors.filter(it => it.email != "" or it.orcid != "")
  if contacts.len() > 0 {
    part(atelier-labels.at("closing-contact"), stack(spacing: 0.6em, ..contacts.map(it => {
      let parts = (text(weight: "bold", it.name),)
      if it.email != "" { parts.push(link("mailto:" + it.email, it.email)) }
      if it.orcid != "" { parts.push([#atelier-orcid-badge(it.orcid) #it.orcid]) }
      parts.join(h(0.8em))
    })))
  }
  if meta.licence != none or meta.copyright != none {
    part(atelier-labels.at("closing-licence"), (meta.copyright, meta.licence).filter(it => it != none).join(linebreak()))
  }
  let families = (meta.fonts.base, meta.fonts.headings, meta.fonts.monospace)
    .filter(it => it != none)
    .map(it => it.first())
    .dedup()
  part(atelier-labels.at("colophon"), {
    atelier-labels.at("colophon-typeset")
    if families.len() > 0 {
      linebreak()
      [#atelier-labels.at("colophon-fonts"): #families.join(", ").]
    }
  })
}
