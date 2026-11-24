// Atelier - Typst title block
// The authors and the title block of the first page: brand logo, title,
// subtitle, authors with their affiliations, the date and duration lines,
// and the abstract. The cover page shows the same block on a page of its own.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Path data of the ORCID glyph and of its disc, in a 32 by 32 view box.
#let atelier-orcid-disc = "M32 16c0 8.837-7.163 16-16 16-8.838 0-16-7.163-16-16C0 7.162 7.162 0 16 0c8.837 0 16 7.162 16 16Z"
#let atelier-orcid-glyph = "M18.813 9.637h-5.45v13.9h5.474c4.555 0 7.35-3.378 7.35-6.95 0-1.635-.562-3.372-1.77-4.704-1.215-1.336-3.065-2.246-5.605-2.246ZM18.6 21.3h-2.813v-9.425H18.5c1.823 0 3.12.552 3.96 1.4.842.849 1.252 2.021 1.252 3.312 0 .784-.239 1.967-.993 2.948-.745.969-2.01 1.765-4.119 1.765ZM8.363 9.675v13.887h2.425V9.675H8.363ZM9.575 8.65c.84 0 1.513-.689 1.513-1.513 0-.823-.673-1.512-1.513-1.512-.838 0-1.512.674-1.512 1.513 0 .823.672 1.512 1.512 1.512Z"

// Answer an ORCID badge that links to the record: an accent disc with the
// glyph in the page colour, whose alternative text is "ORCID <id>".
// - id: the ORCID identifier.
#let atelier-orcid-badge(id) = {
  let svg = (
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 32\">",
    "<path fill=\"" + atelier-colour("accent-text").to-hex() + "\" d=\"" + atelier-orcid-disc + "\"/>",
    "<path fill=\"" + atelier-colour("bg").to-hex() + "\" fill-rule=\"evenodd\" d=\"" + atelier-orcid-glyph + "\"/>",
    "</svg>",
  ).join()
  link("https://orcid.org/" + id, box(
    height: 0.8em,
    baseline: 0.1em,
    image(bytes(svg), format: "svg", alt: atelier-labels.at("author-orcid") + " " + id),
  ))
}

// Answer the line of one author: the name, the degrees, the affiliation
// numbers, a mark for the corresponding author, and the ORCID badge.
// - author: dictionary with name, degrees, affiliations, orcid, email and corresponding.
#let atelier-author-line(author) = {
  let parts = (
    text(weight: "bold", author.name),
    if author.degrees.len() > 0 { text(size: 0.8em, fill: atelier-colour("muted"), author.degrees.join(", ")) },
    if author.affiliations.len() > 0 { super(author.affiliations.map(str).join(",")) },
    if author.corresponding { super[\*] },
    if author.orcid != "" { atelier-orcid-badge(author.orcid) },
  )
  parts.filter(part => part != none).join(h(0.25em))
}

// Answer the numbered affiliation lines.
// - affiliations: array of affiliation names.
#let atelier-affiliation-lines(affiliations) = (
  affiliations.enumerate(start: 1).map(((number, name)) => [#super(str(number)) #name]).join(linebreak())
)

// Answer the legend of the corresponding author, or none.
// - authors: array of author dictionaries.
#let atelier-author-legend(authors) = {
  let corresponding = authors.filter(author => author.corresponding)
  if corresponding.len() == 0 { return none }
  let emails = corresponding.map(author => author.email).filter(email => email != "")
  let address = if emails.len() > 0 { [: #emails.map(email => link("mailto:" + email, email)).join(", ")] }
  [\* #atelier-labels.at("author-corresponding")#address]
}

// Answer a label and its value as one line of the title block, such as
// "Instructors" and the names, in the muted colour.
// - label: the label, or none.
// - value: the value.
#let atelier-meta-line(label, value) = {
  if label != none and label != [] {
    text(size: 0.75em, weight: "bold", tracking: 0.08em, fill: atelier-colour("muted"), upper(label))
    linebreak()
  }
  value
}

// Answer the title block.
// - meta: the document, see atelier-document().
// - title-size: size of the title.
#let atelier-title-block(meta, title-size: 2em) = {
  let muted(content) = text(size: 0.85em, fill: atelier-colour("muted"), content)
  let headings(content) = if meta.fonts.headings != none { text(font: meta.fonts.headings, content) } else { content }
  let logo = meta.at("logo", default: none)
  if logo != none {
    block(below: 1.2em, image(logo.path, height: 2.2em, alt: logo.at("alt", default: none)))
  }
  if meta.title != none {
    block(below: 0.5em, text(size: title-size, weight: "bold", fill: atelier-colour("heading"), headings(meta.title)))
  }
  block(below: 0.9em, pdf.artifact(line(length: 30%, stroke: 2pt + atelier-colour("accent-mark"))))
  if meta.subtitle != none {
    block(below: 1.2em, text(size: 1.2em, fill: atelier-colour("muted"), headings(meta.subtitle)))
  }
  let people = atelier-people
  if people.authors.len() > 0 {
    block(below: 0.8em, atelier-meta-line(meta.labels.authors, stack(spacing: 0.45em, ..people.authors.map(atelier-author-line))))
    if people.affiliations.len() > 0 {
      block(below: 0.4em, muted(atelier-affiliation-lines(people.affiliations)))
    }
    let legend = atelier-author-legend(people.authors)
    if legend != none {
      block(below: 0.8em, muted(legend))
    }
  }
  let dates = ()
  if meta.date != none {
    dates.push(atelier-meta-line(meta.labels.published, meta.date))
  }
  if meta.duration != none {
    dates.push(atelier-meta-line(atelier-labels.at("duration"), meta.duration))
  }
  if dates.len() > 0 {
    block(below: 1em, grid(columns: dates.len(), column-gutter: 2.5em, ..dates))
  }
}

// Answer the abstract: a tinted outline with its title.
// - meta: the document, see atelier-document().
#let atelier-abstract(meta) = {
  if meta.abstract == none { return }
  block(
    width: 100%,
    above: 1.2em,
    below: 1.5em,
    inset: 1em,
    radius: atelier-radius,
    stroke: atelier-frame-width + atelier-colour("border"),
    {
      text(size: 0.76em, weight: "bold", tracking: 0.06em, fill: atelier-colour("accent-text"), upper(meta.labels.abstract))
      parbreak()
      meta.abstract
    },
  )
}

// Answer the cover page: the title block in the lower half of a page of its
// own, with no header and no footer.
// - meta: the document, see atelier-document().
#let atelier-cover(meta) = {
  atelier-surface("cover")
  v(1fr)
  atelier-title-block(meta, title-size: 2.8em)
  v(0.5fr)
  pagebreak()
}
