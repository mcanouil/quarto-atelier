// Atelier - Typst template
// The partials of the Atelier document, in the order that each needs the
// one before, and `atelier-document`, the one document type for both modes.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

$tokens.typ()$

$motifs.typ()$

$elements.typ()$

$chrome.typ()$

$title.typ()$

$toc.typ()$

$workshop.typ()$

#let atelier-body-font = state("atelier-body-font", ())

// Answer the document: the text, heading, code and link styles, the page
// set-up, then the title block or the cover, the table of contents, the
// body and the closing page, after the five report switches. Code has no
// ligatures and no contextual alternates, so it reads as typed.
// - meta: dictionary of the document: title, subtitle, date, duration,
//   date-modified, doi, abstract, licence, copyright, keywords, lang, region, fontsize,
//   linestretch, toc, toc-title, toc-depth, numbering, fonts (base,
//   headings, monospace, each an array or none), labels (authors,
//   published, modified, doi, keywords, abstract) and logo.
// - body: the content of the document.
#let atelier-document(meta, body) = {
  let fonts = meta.fonts
  let switches = atelier-switches
  set document(
    title: meta.title,
    author: atelier-people.authors.map(author => author.name),
    keywords: meta.keywords,
  )
  set text(lang: meta.lang, region: meta.region, fill: atelier-colour("fg"))
  set text(size: meta.fontsize) if meta.fontsize != none
  set par(leading: 0.65em * meta.linestretch) if meta.linestretch != none
  set text(font: fonts.base) if fonts.base != none
  show heading: set text(fill: atelier-colour("heading"))
  show heading: set text(font: fonts.headings) if fonts.headings != none
  // A heading below level 6 shows as bold body text, as in HTML, where it is
  // a `p.heading`. It keeps its label and its counter, so a reference to it
  // works, but it shows no number and has no outline entry. Quarto's brand
  // rule sets the heading font on every level, so the rule sets the body font
  // and colour again, from the font of the body that `atelier-body-font` keeps.
  // A selector cannot compare a level, so it lists the levels 7 to 20.
  // Remove when: never.
  context atelier-body-font.update(text.font)
  let deep-heading = selector.or(..range(7, 21).map(level => heading.where(level: level)))
  show deep-heading: set heading(outlined: false)
  show deep-heading: it => context block(
    above: par.spacing,
    below: par.spacing,
    sticky: true,
    text(font: atelier-body-font.get(), fill: atelier-colour("fg"), weight: "bold", it.body),
  )
  show raw: set text(ligatures: false, features: ("calt": 0))
  show raw: set text(font: fonts.monospace) if fonts.monospace != none
  show link: set text(fill: atelier-colour("link"))
  set heading(numbering: meta.numbering)
  atelier-document-fonts.update(fonts)
  show: atelier-elements
  show heading.where(level: 1): it => atelier-chapter(it, switches)
  let first-author = atelier-people.authors.at(0, default: none)
  let organisation = if first-author != none and first-author.affiliations.len() > 0 {
    first-author.affiliations.first()
  }
  let rights = (meta.copyright, meta.licence).filter(it => it != none)
  show: atelier-page.with(
    meta.title,
    logo: meta.logo,
    organisation: organisation,
    rights: if rights.len() > 0 { rights.join[ · ] },
  )
  if switches.at("cover") {
    atelier-cover(meta)
    atelier-abstract(meta)
  } else {
    atelier-title-block(meta)
    atelier-abstract(meta)
  }
  if meta.toc {
    if switches.at("toc-page") { pagebreak(weak: true) }
    atelier-contents(meta.toc-title, meta.toc-depth)
    if switches.at("toc-page") { pagebreak() }
  }
  body
  atelier-citation-section()
  if switches.at("closing-page") {
    atelier-closing-page(meta)
  }
}
