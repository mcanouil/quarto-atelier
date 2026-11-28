// Atelier - Typst elements
// Quarto's elements in the Atelier look, every colour from the tokens:
// highlighting, inline code, code windows, callouts, quotes, tables,
// footnotes, term lists, highlights, theorems and proofs. Quarto's own
// definitions come before the template, so a function here with the same
// name, such as `callout` or a highlighting token, takes the place of Quarto's.
// Icons, glyphs and rules that only decorate are artefacts.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Corner radius of the boxes: the terminal preset is square, as in HTML.
#let atelier-radius = if atelier-preset == "terminal" { 0pt } else { 4pt }

// Width of the frame of a callout, as `--atelier-c3-border` (1.5 px).
#let atelier-frame-width = 1.125pt

// ===========================================================================
// HIGHLIGHTING
// ===========================================================================

// The surface that the code sits on: `page` for a code block or inline code,
// `terminal` inside a terminal block, which has its own colours.
#let atelier-code-scope = state("atelier-code-scope", "page")

// The ink of the line that a terminal block is drawing, or none. A token takes
// this ink in place of its class colour.
#let atelier-line-ink = state("atelier-line-ink", none)

// The prompt and continuation line numbers of the terminal block that is being
// drawn, or none outside a terminal block.
#let atelier-terminal-lines = state("atelier-terminal-lines", none)

// Answer a highlighted token in the colour of its class on the current
// surface. Each colour is held at 4.5:1 on that surface by the Lua filter.
// - name: name of the token function, such as "KeywordTok".
// - s: text of the token.
#let atelier-tok(name, s) = context {
  let ink = atelier-line-ink.get()
  let style = atelier-highlighting.at(atelier-code-scope.get()).at(name, default: none)
  if ink != none {
    text(fill: ink, raw(s))
  } else if style == none {
    raw(s)
  } else {
    let token = text(fill: style.fill, weight: style.weight, style: style.style, raw(s))
    if style.underline { underline(token) } else { token }
  }
}

#let AlertTok(s) = atelier-tok("AlertTok", s)
#let AnnotationTok(s) = atelier-tok("AnnotationTok", s)
#let AttributeTok(s) = atelier-tok("AttributeTok", s)
#let BaseNTok(s) = atelier-tok("BaseNTok", s)
#let BuiltInTok(s) = atelier-tok("BuiltInTok", s)
#let CharTok(s) = atelier-tok("CharTok", s)
#let CommentTok(s) = atelier-tok("CommentTok", s)
#let CommentVarTok(s) = atelier-tok("CommentVarTok", s)
#let ConstantTok(s) = atelier-tok("ConstantTok", s)
#let ControlFlowTok(s) = atelier-tok("ControlFlowTok", s)
#let DataTypeTok(s) = atelier-tok("DataTypeTok", s)
#let DecValTok(s) = atelier-tok("DecValTok", s)
#let DocumentationTok(s) = atelier-tok("DocumentationTok", s)
#let ErrorTok(s) = atelier-tok("ErrorTok", s)
#let ExtensionTok(s) = atelier-tok("ExtensionTok", s)
#let FloatTok(s) = atelier-tok("FloatTok", s)
#let FunctionTok(s) = atelier-tok("FunctionTok", s)
#let ImportTok(s) = atelier-tok("ImportTok", s)
#let InformationTok(s) = atelier-tok("InformationTok", s)
#let KeywordTok(s) = atelier-tok("KeywordTok", s)
#let NormalTok(s) = atelier-tok("NormalTok", s)
#let OperatorTok(s) = atelier-tok("OperatorTok", s)
#let OtherTok(s) = atelier-tok("OtherTok", s)
#let PreprocessorTok(s) = atelier-tok("PreprocessorTok", s)
#let RegionMarkerTok(s) = atelier-tok("RegionMarkerTok", s)
#let SpecialCharTok(s) = atelier-tok("SpecialCharTok", s)
#let SpecialStringTok(s) = atelier-tok("SpecialStringTok", s)
#let StringTok(s) = atelier-tok("StringTok", s)
#let VariableTok(s) = atelier-tok("VariableTok", s)
#let VerbatimStringTok(s) = atelier-tok("VerbatimStringTok", s)
#let WarningTok(s) = atelier-tok("WarningTok", s)

// Answer inline code: the code ink on the strong surface, as in HTML.
// - s: the code.
#let atelier-inline-code(s) = box(
  fill: atelier-colour("surface-strong"),
  inset: (x: 0.3em, y: 0pt),
  outset: (y: 0.25em),
  radius: calc.min(atelier-radius, 3pt),
  text(fill: atelier-colour("code-ink"), raw(s)),
)

// ===========================================================================
// CODE WINDOWS
// ===========================================================================

// Answer the code-window theme of a surface: the code block surface and its
// border on the page, or the terminal colours.
// - scope: `page` or `terminal`.
#let atelier-code-window-theme(scope) = {
  let page = scope == "page"
  let surface = atelier-colour(if page { "surface" } else { "terminal-bg" })
  (
    radius: atelier-radius,
    stroke-thickness: 0.75pt,
    stroke-dash: if atelier-preset == "terminal" and page { "dashed" } else { none },
    fill: surface,
    surface: atelier-colour(if page { "surface-strong" } else { "terminal-highlight" }),
    border: atelier-colour(if page { "code-border" } else { "terminal-border" }),
    label: atelier-colour(if page { "muted" } else { "terminal-muted" }),
    muted: atelier-colour(if page { "muted" } else { "terminal-muted" }),
    traffic-light-size: 0.7em,
    traffic-light-gap: 0.35em,
    traffic-light-colours: if page {
      (rgb("#ff5f56"), rgb("#ffbd2e"), rgb("#27c93f"))
    } else {
      (atelier-colour("terminal-dot"),) * 3
    },
  )
}

// Answer one source line of a terminal block. A prompt line takes the prompt
// mark in the prompt colour and the command ink, a line that continues a
// command takes the command ink, and any other line is output in the muted
// ink. No token colours show in the line. Quarto gives its highlighter no line
// number, so `atelier-terminal-skylighting` passes the number here.
// - number: the number of the line.
// - line: the highlighted line.
#let atelier-terminal-line(number, line) = context {
  let terminal = atelier-terminal-lines.get()
  if terminal == none {
    line
  } else {
    let prompt = number in terminal.prompts
    let command = prompt or number in terminal.continuations
    if prompt {
      text(fill: atelier-colour("terminal-prompt"), raw("$$ "))
    }
    atelier-line-ink.update(atelier-colour(if command { "terminal-fg" } else { "terminal-muted" }))
    line
    atelier-line-ink.update(none)
  }
}

// Answer the Pandoc highlighter with each line passed through
// `atelier-terminal-line`. The call of a terminal block shadows `Skylighting`
// with it for the block only. Skylighting writes `Skylighting` for a document
// to style, and passes it the lines as one array, so the wrapper gives each
// line its number.
// Remove when: never.
// - original: the `Skylighting` function of Quarto.
#let atelier-terminal-skylighting(original) = (..args) => {
  let positional = args.pos()
  original(
    ..args.named(),
    ..positional.slice(0, -1),
    positional.last().enumerate().map(((index, line)) => atelier-terminal-line(index + 1, line)),
  )
}

// Answer a terminal: the code block in the terminal colours.
// - prompts: the numbers of the lines that had a dollar prompt.
// - continuations: the numbers of the lines that continue a command.
// - body: the code block.
#let atelier-terminal(prompts, continuations, body) = {
  atelier-code-scope.update("terminal")
  atelier-terminal-lines.update((prompts: prompts, continuations: continuations))
  state("code-window-theme").update(theme => theme + atelier-code-window-theme("terminal"))
  body
  atelier-terminal-lines.update(none)
  state("code-window-theme").update(theme => theme + atelier-code-window-theme("page"))
  atelier-code-scope.update("page")
}

// ===========================================================================
// CALLOUTS
// ===========================================================================

// Glyph of the icon of each callout type. The check of tip is drawn, as some
// fonts have no check mark.
#let atelier-callout-glyphs = (note: "i", tip: none, warning: "!", important: "!!", caution: "?")

// Answer the drawn check mark of the tip icon.
// - size: side of the icon.
// - paint: colour of the mark.
#let atelier-callout-check(size, paint) = curve(
  stroke: (paint: paint, thickness: size * 0.12, cap: "round", join: "round"),
  curve.move((size * 0.27, size * 0.52)),
  curve.line((size * 0.43, size * 0.68)),
  curve.line((size * 0.74, size * 0.34)),
)

// Answer the icon of a callout: a ring in the label ink with the glyph in
// it, centred on the capitals of the label. The glyph is placed in the ring,
// so the ring box has no text baseline; it is shifted down by half of what
// its side exceeds the cap height of the label font. It is an artefact: the
// label names the type.
// - type: callout type.
// - ink: colour of the ring and the glyph.
// - size: side of the icon.
#let atelier-callout-icon(type, ink, size) = context {
  let cap = measure(text(top-edge: "cap-height", bottom-edge: "baseline", "H")).height
  let glyph = atelier-callout-glyphs.at(type)
  // The tick is drawn in the coordinates of the ring, so it is placed at the
  // top left. A glyph box spans the cap band and the advance of the glyph,
  // so it is centred; tracking would widen one side only.
  let mark = if glyph == none {
    place(top + left, atelier-callout-check(size, ink))
  } else {
    place(center + horizon, text(fill: ink, size: size * 0.6, weight: "black", top-edge: "cap-height", bottom-edge: "baseline", glyph))
  }
  let ring = box(width: size, height: size, radius: 50%, stroke: 1pt + ink, mark)
  box(baseline: (size - cap) / 2, pdf.artifact(ring))
}

// Answer the label of a callout: the icon, then the title in upper case, in
// the ink of the type.
// - type: callout type.
// - title: title of the callout.
// - icon: true to show the icon.
#let atelier-callout-label(type, title, icon) = {
  let ink = atelier-colour("callout-" + type + "-ink")
  set text(size: 0.76em, fill: ink, weight: "bold")
  set par(first-line-indent: 0pt, hanging-indent: 0pt)
  if icon {
    atelier-callout-icon(type, ink, 1.3em)
    h(0.4em)
  }
  text(tracking: 0.06em, upper(title))
}

// Answer a callout: an outline in the border colour of the type, with the
// label set into the top border on the page background, so the border breaks
// behind it. A minimal callout, or a simple one with no icon, is dashed. In
// the terminal preset the frame is dashed and its start side is a solid bar
// one character wide, as in HTML.
// - spec: type, appearance, titled, title, body and icon.
#let atelier-callout-box(spec) = {
  let type = spec.type
  let edge = atelier-colour("callout-" + type + "-border")
  let minimal = spec.appearance == "minimal"
  let terminal = atelier-preset == "terminal"
  let label = if minimal and not spec.titled { none } else {
    atelier-callout-label(type, spec.title, spec.icon and not minimal)
  }
  let body = if spec.body != none {
    set text(fill: atelier-colour("fg"))
    spec.body
  }
  let room = 1.15em
  let line = (paint: edge, thickness: atelier-frame-width, dash: if minimal or terminal { "dashed" } else { none })
  let frame = block(
    width: 100%,
    inset: (top: if label == none { 0.8em } else { room }, x: 1em, bottom: 0.8em),
    radius: atelier-radius,
    stroke: if terminal { (top: line, right: line, bottom: line) } else { line },
    {
      if label != none {
        let tag = box(fill: atelier-colour("bg"), inset: (x: 0.45em), label)
        context {
          let height = measure(tag).height
          place(top + left, dx: -0.65em, dy: -room - height / 2, tag)
        }
      }
      body
    },
  )
  // The label rises above the frame by half its height: the top padding keeps
  // it clear of the block above.
  pad(top: 0.45em, if terminal {
    grid(columns: (0.6em, 1fr), fill: (x, y) => if x == 0 { edge }, pdf.artifact[], frame)
  } else {
    frame
  })
}

// Answer whether content is the callout marker that `atelier-typst.lua`
// writes as the first block of the body.
#let atelier-is-callout-marker(it) = it.func() == metadata and type(it.value) == dictionary and "atelier-callout" in it.value

// Answer the marker of a callout body and the body without it, with no
// leading or trailing space or paragraph break. The body is none when nothing
// is left.
// - body: the body as Quarto passes it.
#let atelier-callout-split(body) = {
  let children = if body.has("children") { body.children } else { (body,) }
  let marker = children.find(atelier-is-callout-marker)
  let rest = children.filter(child => not atelier-is-callout-marker(child))
  let blank = ([ ].func(), parbreak)
  while rest.len() > 0 and rest.first().func() in blank {
    rest = rest.slice(1)
  }
  while rest.len() > 0 and rest.last().func() in blank {
    rest = rest.slice(0, -1)
  }
  (marker: if marker == none { none } else { marker.value }, body: if rest.len() == 0 { none } else { rest.join() })
}

// Quarto's callout call, in the Atelier look. Quarto passes no type, so the
// type, the appearance and whether the title is the callout's own come from
// the marker in the body; a body with no marker is a note. The colours that
// Quarto passes are not used. The specification goes in front of the callout
// as metadata, for the cross-reference show rule.
// - body, title, icon: as Quarto passes them; icon is none for no icon.
// - ..args: any other argument that a later Quarto passes.
// Upstream: https://github.com/quarto-dev/quarto-cli/issues/15414
// Remove when: the minimum Quarto version includes the fix.
#let callout(body: [], title: none, background_color: none, icon: none, icon_color: none, body_background_color: none, ..args) = {
  let parts = atelier-callout-split(body)
  let marker = if parts.marker == none { (atelier-callout: "note", appearance: "default", titled: true) } else { parts.marker }
  let type = marker.at("atelier-callout")
  // Quarto turns a minimal callout into a simple one with no icon, as the
  // HTML classes callout-style-simple and no-icon do.
  let minimal = marker.appearance == "minimal" or (marker.appearance == "simple" and icon == none)
  let spec = (
    type: type,
    appearance: if minimal { "minimal" } else { marker.appearance },
    titled: marker.titled,
    title: if title == none { upper(type.first()) + type.slice(1) } else { title },
    body: parts.body,
    icon: icon != none,
  )
  metadata((atelier-callout-spec: spec))
  atelier-callout-box(spec)
}

// Answer the specification of the callout in content, or none.
// - it: content.
#let atelier-find-callout(it) = {
  if type(it) != content { return none }
  if it.func() == metadata and type(it.value) == dictionary and "atelier-callout-spec" in it.value {
    return it.value.at("atelier-callout-spec")
  }
  if it.has("children") {
    for child in it.children {
      let found = atelier-find-callout(child)
      if found != none { return found }
    }
  }
  if it.has("body") { return atelier-find-callout(it.body) }
  if it.has("child") { return atelier-find-callout(it.child) }
  none
}

// Answer a cross-referenced callout: the callout with the supplement and the
// number before its title, as Quarto's own show rule does.
// - it: the figure of the callout.
#let atelier-callout-figure(it) = {
  let spec = atelier-find-callout(it.body)
  if spec == none { return it }
  let number = it.counter.display(it.numbering)
  let title = if spec.titled and spec.title != none { [#it.supplement #number: #spec.title] } else { [#it.supplement #number] }
  align(left, atelier-callout-box(spec + (title: title, titled: true)))
}

// ===========================================================================
// QUOTES, THEOREMS AND PROOFS
// ===========================================================================

// Answer a block quote: the muted text after a bar in the accent mark colour.
// - it: the quote.
#let atelier-quote(it) = {
  if not it.block { return it }
  block(
    above: 1.2em,
    below: 1.2em,
    inset: (left: 1.2em, y: 0.2em),
    stroke: (left: 0.2em + atelier-colour("accent-mark")),
    {
      set text(fill: atelier-colour("muted"))
      it.body
      if it.attribution != none {
        block(above: 0.6em, text(size: 0.9em, [— #it.attribution]))
      }
    },
  )
}

// Theorem and proof kinds, as Quarto renders them with theorion.
#let atelier-theorem-kinds = ("theorem", "lemma", "corollary", "proposition", "conjecture", "definition", "example", "exercise", "algorithm")
#let atelier-proof-kinds = ("proof", "remark", "solution")

// ===========================================================================
// DOCUMENT
// ===========================================================================

// ===========================================================================
// TERMINAL DECORATION
// ===========================================================================
// The terminal preset marks the title with a prompt and a cursor, a heading
// of level 2 or 3 in the source with `##` or `###`, and a list item with `-`,
// as `html/terminal.scss` does. Quarto moves each heading of a document with a
// title up one level, so the marker has one `#` more than the Typst level. Each marker is an artefact, so a screen reader
// skips it. The cursor is steady, because a page has no animation. The
// `atelier-terminal-decoration` data is false for other presets and when the
// brand turns the decoration off.

// Answer a marker of the terminal decoration: text in a colour, as an artefact.
// - mark: the text of the marker.
// - ink: name of the colour token.
#let atelier-terminal-mark(mark, ink) = pdf.artifact(text(fill: atelier-colour(ink), mark))

// Answer a heading of Typst level 1 or 2 with its marker before it and its
// dashed rule under it. The marker sits next to the heading, not in its body, so
// the outline, the bookmarks and the running header do not hold it. The size
// of the marker is the default size of the heading.
// - it: the heading.
#let atelier-terminal-heading(it) = {
  let size = if it.level == 1 { 1.4em } else { 1.2em }
  let marker = range(it.level + 1).map(_ => "#").join() + " "
  block(above: 1.4em, below: 0.9em, width: 100%, {
    grid(
      columns: (auto, 1fr),
      column-gutter: 0pt,
      atelier-terminal-mark(text(size: size, weight: "bold", marker), "muted"),
      it,
    )
    v(0.35em, weak: true)
    pdf.artifact(line(length: 100%, stroke: (paint: atelier-colour("border"), thickness: 0.75pt, dash: "dashed")))
  })
}

// Answer a heading, with the terminal decoration when it is on.
// - it: the heading.
#let atelier-terminal-chapter(it) = if atelier-terminal-decoration { atelier-terminal-heading(it) } else { it }

// Style the elements of a document with the tokens.
// - body: the content of the document.
#let atelier-elements(body) = {
  state("code-window-theme").update(theme => theme + atelier-code-window-theme("page"))
  show raw.where(block: true): set block(
    fill: atelier-colour("surface"),
    stroke: 0.75pt + atelier-colour("code-border"),
    radius: atelier-radius,
    inset: 8pt,
    width: 100%,
  )
  show quote: atelier-quote
  show heading.where(level: 2): atelier-terminal-chapter
  set list(marker: atelier-terminal-mark("-", "accent-ink")) if atelier-terminal-decoration
  show figure: it => {
    if type(it.kind) != str {
      it
    } else if it.kind.starts-with("quarto-callout-") {
      atelier-callout-figure(it)
    } else if it.kind in atelier-theorem-kinds {
      show strong: set text(fill: atelier-colour("accent-text"))
      it
    } else if it.kind in atelier-proof-kinds {
      show emph: set text(fill: atelier-colour("muted"))
      it
    } else {
      it
    }
  }
  show figure.caption: set text(fill: atelier-colour("muted"))
  set table(
    stroke: (x, y) => (top: if y == 0 { 0.75pt + atelier-colour("border") }, bottom: 0.75pt + atelier-colour("border")),
    inset: (x: 0.7em, y: 0.5em),
  )
  set table.hline(stroke: 1.25pt + atelier-colour("control-border"))
  show table.cell.where(y: 0): set text(weight: "bold")
  set highlight(fill: atelier-colour("accent-soft"))
  show highlight: set text(fill: atelier-colour("fg"))
  set line(stroke: 0.75pt + atelier-colour("border"))
  set footnote.entry(separator: line(length: 30%, stroke: 0.75pt + atelier-colour("border")))
  show footnote.entry: set text(fill: atelier-colour("fg"))
  show terms.item: it => {
    block(above: 0.9em, below: 0.35em, sticky: true, text(weight: "bold", it.term))
    block(above: 0.35em, below: 0.9em, inset: (left: 0.9em, y: 0.1em), stroke: (left: 2pt + atelier-colour("border")), it.description)
  }
  body
}
