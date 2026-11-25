--- Atelier - Motifs
--- @module "motifs"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief The geometry of the corner motif of each preset.
--- @description One source for the motifs of every format. Each motif is a
--- set of flat shapes in a 100 by 100 view box, drawn for the top right
--- corner, each with its own opacity. HTML and Reveal.js draw a motif as a
--- CSS mask from `M.mask`, in a colour from the palette; Typst draws the
--- shapes of `M.typst`. A motif only decorates.

local M = {}

--- The factor of every opacity of a motif on a light surface. On a dark
--- surface the opacities stay as they are. `html/workshop.scss` holds the
--- same value, as Sass cannot read this module.
--- @type number
M.LIGHT_OPACITY = 0.85

--- The motif of each preset.
--- @type table<string, string>
local PRESET_MOTIFS = {
  default = 'steps',
  quarto = 'quadrants',
  terminal = 'dots',
}

--- Round a number to two decimals.
--- @param value number
--- @return number
local function round(value)
  return math.floor(value * 100 + 0.5) / 100
end

--- Write a number with no trailing zeros, such as `74.4` or `12`.
--- @param value number
--- @return string
local function number(value)
  return string.format('%g', round(value))
end

--- The opacity of the cell of the grid in column `i` and row `j`, from the
--- corner, as `steps` and `quadrants` share it.
--- @param i integer
--- @param j integer
--- @return number
local function grid_opacity(i, j)
  return round(math.max(0.75 - 0.16 * (i + j), 0.08))
end

--- The shapes of each motif. A `rect` has `x`, `y` and `size`; a `quarter`
--- has the corner `x`, `y` of its right angle and the radius `r`, with its
--- arc to the top right; a `circle` has the centre `x`, `y` and the radius
--- `r`. Each shape has an `opacity`.
--- @type table<string, fun(): table[]>
local GEOMETRY

--- The cells of the four-column grid of `steps` and `quadrants`: 4, 3, 2
--- and 1 cells from the corner, each made by `make`.
--- @param make fun(i: integer, j: integer, opacity: number): table The shape of the cell in column `i` and row `j`
--- @return table[]
local function grid(make)
  local shapes = {}
  for i = 0, 3 do
    for j = 0, 3 - i do
      shapes[#shapes + 1] = make(i, j, grid_opacity(i, j))
    end
  end
  return shapes
end

GEOMETRY = {
  steps = function()
    return grid(function(i, j, opacity)
      return { kind = 'rect', x = 88 - 13 * i, y = 13 * j, size = 12, opacity = opacity }
    end)
  end,
  -- The quarter discs take only the geometry of the Quarto icon. Every disc
  -- turns the same way, so the four-disc icon never forms.
  quadrants = function()
    return grid(function(i, j, opacity)
      return { kind = 'quarter', x = round(88 - 13.6 * i), y = round(13.6 * j + 12), r = 12, opacity = opacity }
    end)
  end,
  -- The space from the outer dots to the top and right edges is the space
  -- between two dots, so each format puts the motif in its corner as is.
  dots = function()
    local pitch, r = 7, 1.3
    local gap = pitch - 2 * r
    local shapes = {}
    for i = 0, 9 do
      for j = 0, 9 do
        local opacity = 0.75 - math.sqrt(i * i + j * j) * 0.085
        if opacity > 0.04 then
          shapes[#shapes + 1] = {
            kind = 'circle',
            x = round(100 - gap - r - i * pitch),
            y = round(gap + r + j * pitch),
            r = r,
            opacity = round(opacity),
          }
        end
      end
    end
    return shapes
  end,
}

--- Answer the motif of a preset.
--- @param preset string `default`, `quarto` or `terminal`
--- @return string The motif name
function M.name(preset)
  return PRESET_MOTIFS[preset] or PRESET_MOTIFS.default
end

--- Answer the shapes of a motif.
--- @param name string A motif name of `M.name`
--- @return table[]
function M.shapes(name)
  return GEOMETRY[name]()
end

--- Answer the SVG of a motif, with every shape in black at its opacity, as
--- a mask needs.
--- @param name string A motif name of `M.name`
--- @return string
local function svg(name)
  local parts = { '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" data-motif="' .. name .. '">' }
  for _, shape in ipairs(M.shapes(name)) do
    local opacity = ' fill-opacity="' .. number(shape.opacity) .. '"/>'
    if shape.kind == 'rect' then
      parts[#parts + 1] = string.format('<rect x="%s" y="%s" width="%s" height="%s"', number(shape.x), number(shape.y),
        number(shape.size), number(shape.size)) .. opacity
    elseif shape.kind == 'quarter' then
      parts[#parts + 1] = string.format('<path d="M%s %sV%sA%s %s 0 0 1 %s %sZ"', number(shape.x), number(shape.y),
        number(shape.y - shape.r), number(shape.r), number(shape.r), number(shape.x + shape.r), number(shape.y)) .. opacity
    else
      parts[#parts + 1] = string.format('<circle cx="%s" cy="%s" r="%s"', number(shape.x), number(shape.y),
        number(shape.r)) .. opacity
    end
  end
  parts[#parts + 1] = '</svg>'
  return table.concat(parts)
end

--- Answer the CSS value that draws a motif as a mask.
--- @param name string A motif name of `M.name`
--- @return string Such as `url("data:image/svg+xml,...")`
function M.mask(name)
  local encoded = svg(name):gsub('[^%w%-%._~/:=,]', function(char)
    return string.format('%%%02X', string.byte(char))
  end)
  return 'url("data:image/svg+xml,' .. encoded .. '")'
end

--- Answer the shapes of a motif as a Typst array of dictionaries, which
--- `typst/motifs.typ` draws.
--- @param name string A motif name of `M.name`
--- @return string
function M.typst(name)
  local items = {}
  for _, shape in ipairs(M.shapes(name)) do
    local fields = { 'kind: "' .. shape.kind .. '"' }
    for _, key in ipairs({ 'x', 'y', 'size', 'r', 'opacity' }) do
      if shape[key] ~= nil then
        fields[#fields + 1] = key .. ': ' .. number(shape[key])
      end
    end
    items[#items + 1] = '(' .. table.concat(fields, ', ') .. ')'
  end
  return '(' .. table.concat(items, ', ') .. ',)'
end

return M
