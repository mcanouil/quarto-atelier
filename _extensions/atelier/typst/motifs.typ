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
