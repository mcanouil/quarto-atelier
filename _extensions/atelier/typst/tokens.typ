// Atelier - Typst data
// The data of the document, as `atelier-typst.lua` writes it: the preset,
// the scheme, the colour tokens of `palette.lua`, the highlighting colours,
// the fonts of the preset, the labels, the five report switches and the
// authors. No colour value is written in a partial; every colour comes from
// here.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

$atelier-typst-data$

// Answer the colour of a token.
// - name: name of the token, as `palette.lua` names it.
#let atelier-colour(name) = atelier-tokens.at(name)
