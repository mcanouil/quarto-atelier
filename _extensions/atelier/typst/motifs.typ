// Atelier - Typst motifs
// The geometry of the corner motifs, drawn for the top right corner of a 100
// by 100 view box. No preset uses a motif yet: the choice of a motif for each
// preset comes with the workshop extras. A motif is decorative, so it is an
// artefact.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// Shapes of each motif. `points` holds the polygon corners as x, y pairs, the
// x, y, width and height of a rectangle, or the centre x, y and the radius of
// a circle. `opacity` is the opacity of the shape.
#let atelier-motif-geometry = (
  facets: (
    (kind: "polygon", points: (100, 0, 38, 0, 100, 62), opacity: 0.18),
    (kind: "polygon", points: (100, 0, 62, 0, 100, 40), opacity: 0.3),
    (kind: "polygon", points: (100, 0, 80, 0, 100, 46), opacity: 0.22),
    (kind: "polygon", points: (100, 0, 52, 0, 86, 20), opacity: 0.26),
    (kind: "polygon", points: (100, 0, 88, 0, 100, 18), opacity: 0.55),
  ),
  steps: range(4)
    .map(i => range(4 - i).map(j => (
      kind: "rect",
      points: (88 - 13 * i, 13 * j, 12, 12),
      opacity: calc.round(calc.max(0.75 - 0.16 * (i + j), 0.08), digits: 2),
    )))
    .flatten(),
  ribbon: ((0, 12, 0.55), (16, 22, 0.35), (26, 29, 0.25)).map(((a, b, o)) => (
    kind: "polygon",
    points: (40 + a, 0, 40 + b, 0, 100, 60 - b, 100, 60 - a),
    opacity: o,
  )),
  dots: range(10)
    .map(i => range(10).map(j => (i: i, j: j, o: 0.75 - calc.sqrt(i * i + j * j) * 0.085)))
    .flatten()
    .filter(it => it.o > 0.04)
    .map(it => (kind: "circle", points: (96 - it.i * 7, 4 + it.j * 7, 1.3), opacity: calc.round(it.o, digits: 2))),
)

// Answer the extent of the shapes of a motif, in the units of the view box:
// `left` is the least x and `bottom` the greatest y of any shape.
// - name: motif name, a key of atelier-motif-geometry.
#let atelier-motif-extent(name) = {
  let xs = ()
  let ys = ()
  for shape in atelier-motif-geometry.at(name) {
    let p = shape.points
    if shape.kind == "polygon" {
      xs += p.chunks(2).map(c => c.at(0))
      ys += p.chunks(2).map(c => c.at(1))
    } else if shape.kind == "rect" {
      xs += (p.at(0), p.at(0) + p.at(2))
      ys += (p.at(1), p.at(1) + p.at(3))
    } else {
      xs += (p.at(0) - p.at(2), p.at(0) + p.at(2))
      ys += (p.at(1) - p.at(2), p.at(1) + p.at(2))
    }
  }
  (left: calc.min(..xs), bottom: calc.max(..ys))
}

// Answer a corner motif in one colour, placed in its page corner so that it
// bleeds to both edges, and tagged as an artefact.
// - name: motif name, a key of atelier-motif-geometry.
// - corner: page corner, for example top + right; the drawing is mirrored for the others.
// - size: side of the square motif.
// - paint: colour of every shape.
#let atelier-motif(name, corner, size, paint) = {
  assert(
    name in atelier-motif-geometry,
    message: "Atelier: unknown motif \"" + name + "\". Use one of " + atelier-motif-geometry.keys().join(", ") + ".",
  )
  let unit = size / 100
  let shade(opacity) = paint.transparentize(100% - opacity * 100%)
  let draw(shape) = {
    let p = shape.points
    let fill = shade(shape.opacity)
    if shape.kind == "polygon" {
      place(top + left, polygon(fill: fill, stroke: none, ..p.chunks(2).map(((x, y)) => (x * unit, y * unit))))
    } else if shape.kind == "rect" {
      place(top + left, dx: p.at(0) * unit, dy: p.at(1) * unit, rect(width: p.at(2) * unit, height: p.at(3) * unit, stroke: none, fill: fill))
    } else {
      let r = p.at(2) * unit
      place(top + left, dx: (p.at(0) - p.at(2)) * unit, dy: (p.at(1) - p.at(2)) * unit, circle(radius: r, stroke: none, fill: fill))
    }
  }
  let drawing = box(width: size, height: size, atelier-motif-geometry.at(name).map(draw).join())
  let flipped = scale(
    x: if corner.x == left { -100% } else { 100% },
    y: if corner.y == bottom { -100% } else { 100% },
    drawing,
  )
  pdf.artifact(place(corner, flipped))
}
