// Atelier - Typst motifs
// The corner motif of a workshop handout. `motifs.lua` holds the geometry of
// each motif and `atelier-typst.lua` writes the shapes of the preset into
// `atelier-motif`, drawn for the top right corner of a 100 by 100 view box.
// A motif is decorative, so it is an artefact.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

// The control distance of a cubic Bézier curve that draws a quarter circle.
#let atelier-quarter-control = 0.5523

// Answer a corner motif in one colour, its square placed flush in the page
// corner, and tagged as an artefact. The motif sets the space between its
// shapes and the edges.
// - shapes: array of shapes, each with kind (`rect`, `quarter` or `circle`),
//   x, y, size or r, and opacity.
// - corner: page corner, for example top + right; the drawing is mirrored for the others.
// - size: side of the square motif.
// - paint: colour of every shape.
// - factor: factor of every opacity, such as 85% on a light page.
#let atelier-motif(shapes, corner, size, paint, factor: 100%) = {
  let unit = size / 100
  let shade(opacity) = paint.transparentize(100% - opacity * factor)
  let draw(shape) = {
    let fill = shade(shape.opacity)
    let (x, y) = (shape.x * unit, shape.y * unit)
    if shape.kind == "rect" {
      place(top + left, dx: x, dy: y, rect(width: shape.size * unit, height: shape.size * unit, stroke: none, fill: fill))
    } else if shape.kind == "quarter" {
      let r = shape.r * unit
      let k = atelier-quarter-control * r
      place(top + left, curve(
        fill: fill,
        stroke: none,
        curve.move((x, y - r)),
        curve.cubic((x + k, y - r), (x + r, y - k), (x + r, y)),
        curve.line((x, y)),
        // A smooth close would bow the straight edge out of the disc.
        curve.close(mode: "straight"),
      ))
    } else {
      let r = shape.r * unit
      place(top + left, dx: x - r, dy: y - r, circle(radius: r, stroke: none, fill: fill))
    }
  }
  let drawing = box(width: size, height: size, shapes.map(draw).join())
  let flipped = scale(
    x: if corner.x == left { -100% } else { 100% },
    y: if corner.y == bottom { -100% } else { 100% },
    drawing,
  )
  pdf.artifact(place(corner, flipped))
}

// The space that the motif keeps clear of text, past the edge of its shapes.
#let atelier-motif-clearance = 2mm

// Answer how far from the right page edge the shapes of a motif reach in a
// band of the page, plus the clearance, or 0pt when no shape is in the band.
// The motif sits flush in the top right corner of the page.
// - shapes: the shapes of the motif, see atelier-motif().
// - size: side of the square motif.
// - top: top of the band, from the top edge of the page.
// - bottom: bottom of the band, from the top edge of the page.
#let atelier-motif-inset(shapes, size, top, bottom) = {
  let unit = size / 100
  let (from, to) = (top / unit, bottom / unit)
  let reach = none
  for shape in shapes {
    let left = none
    if shape.kind == "rect" {
      if shape.y < to and shape.y + shape.size > from { left = shape.x }
    } else if shape.kind == "quarter" {
      // The straight edge at x runs the whole height of the quarter.
      if shape.y - shape.r < to and shape.y > from { left = shape.x }
    } else {
      let gap = if from <= shape.y and shape.y <= to { 0 } else { calc.min(calc.abs(from - shape.y), calc.abs(to - shape.y)) }
      if gap < shape.r { left = shape.x - calc.sqrt(shape.r * shape.r - gap * gap) }
    }
    if left != none and (reach == none or left < reach) { reach = left }
  }
  if reach == none { 0pt } else { (100 - reach) * unit + atelier-motif-clearance }
}
