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

// Answer the document: the text, heading, code and link styles, the page
// set-up, then the title block or the cover, the table of contents, the
// body and the closing page, after the five report switches. Code has no
// ligatures and no contextual alternates, so it reads as typed.
// - meta: dictionary of the document: title, subtitle, date, duration,
//   abstract, licence, copyright, keywords, lang, region, fontsize,
//   linestretch, toc, toc-title, toc-depth, numbering, fonts (base,
//   headings, monospace, each an array or none), labels (authors,
//   published, abstract) and logo.
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
  show raw: set text(ligatures: false, features: ("calt": 0))
  show raw: set text(font: fonts.monospace) if fonts.monospace != none
  show link: set text(fill: atelier-colour("link"))
  set heading(numbering: meta.numbering)
  atelier-document-fonts.update(fonts)
  show: atelier-elements
  show heading.where(level: 1): it => atelier-chapter(it, switches)
  show: atelier-page.with(meta.title)
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
  if switches.at("closing-page") {
    atelier-closing-page(meta)
  } else {
    atelier-closing-section()
  }
}
