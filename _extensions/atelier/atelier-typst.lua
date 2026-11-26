--- Atelier - Typst Document Filter
--- @module "atelier-typst"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Give the Typst partials the data of the document.
--- @description Quarto compiles no Sass for Typst, so this filter reads the
--- colours from `palette.lua` and writes them, with the fonts of the preset,
--- the labels, the five report switches, the authors and the workshop
--- motif of `motifs.lua`, into the
--- `atelier-typst-data` metadata. The `typst/tokens.typ` partial writes that
--- value in front of the template, so every partial can read it.
--- The filter also marks each callout with its type and appearance, ends
--- the page of each level-1 heading, marks each `.part` heading, and writes
--- inline code with the Atelier code colours.

local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))
local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local palette = require(quarto.utils.resolve_path('palette.lua'):gsub('%.lua$', ''))
local motifs = require(quarto.utils.resolve_path('motifs.lua'):gsub('%.lua$', ''))
local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))

--- Name that prefixes each warning.
--- @type string
local EXTENSION_NAME = 'atelier'

--- Keys of the labels, without the `atelier-` prefix.
--- The text comes from the `language` files.
--- @type table<integer, string>
local LABELS = {
  'chapter',
  'part',
  'in-this-chapter',
  'closing-contact',
  'closing-licence',
  'colophon',
  'colophon-typeset',
  'colophon-fonts',
  'author-orcid',
  'author-corresponding',
  'duration',
  'solution-page',
  'solutions-title',
}

--- The report switches under `extensions.atelier`, each `false` by default.
--- @type table<integer, string>
local SWITCHES = { 'cover', 'toc-page', 'chapter-dividers', 'chapter-contents', 'closing-page' }

--- The Typst function of each Pandoc highlighting class.
--- @type table<string, string>
local TOKEN_FUNCTIONS = {
  [''] = 'NormalTok', kw = 'KeywordTok', dt = 'DataTypeTok', dv = 'DecValTok', bn = 'BaseNTok',
  fl = 'FloatTok', cn = 'ConstantTok', ch = 'CharTok', sc = 'SpecialCharTok', st = 'StringTok',
  vs = 'VerbatimStringTok', ss = 'SpecialStringTok', im = 'ImportTok', co = 'CommentTok',
  ['do'] = 'DocumentationTok', an = 'AnnotationTok', cv = 'CommentVarTok', ot = 'OtherTok',
  fu = 'FunctionTok', va = 'VariableTok', cf = 'ControlFlowTok', op = 'OperatorTok',
  bu = 'BuiltInTok', ex = 'ExtensionTok', pp = 'PreprocessorTok', at = 'AttributeTok',
  re = 'RegionMarkerTok', ['in'] = 'InformationTok', wa = 'WarningTok', al = 'AlertTok',
  er = 'ErrorTok',
}

-- ============================================================================
-- TYPST VALUES
-- ============================================================================

--- A Typst string literal.
--- @param text string
--- @return string
local function typst_string(text)
  return '"' .. str.escape_typst_string(text) .. '"'
end

--- A Typst dictionary of `name: value` entries, sorted by name.
--- @param entries table<string, string> Each value is already Typst code
--- @return string
local function typst_dict(entries)
  local names = {}
  for name in pairs(entries) do
    names[#names + 1] = name
  end
  table.sort(names)
  if #names == 0 then
    return '(:)'
  end
  local parts = {}
  for _, name in ipairs(names) do
    parts[#parts + 1] = typst_string(name) .. ': ' .. entries[name]
  end
  return '(' .. table.concat(parts, ', ') .. ')'
end

--- A Typst array of values that are already Typst code.
--- @param items string[]
--- @return string
local function typst_array(items)
  if #items == 0 then
    return '()'
  end
  return '(' .. table.concat(items, ', ') .. ',)'
end

--- A Typst colour from a palette colour.
--- @param colour table
--- @param bg table The background under a translucent colour
--- @return string
local function typst_colour(colour, bg)
  return 'rgb("' .. palette.hex(colour, bg) .. '")'
end

-- ============================================================================
-- DOCUMENT DATA
-- ============================================================================

--- The five switches, as a Typst dictionary of booleans. A value that is not
--- a boolean logs a warning and counts as `false`.
--- @param options table The `extensions.atelier` options
--- @return string
local function switches_code(options)
  local switches = {}
  for _, name in ipairs(SWITCHES) do
    local value = options[name]
    if value == nil or type(value) == 'boolean' then
      switches[name] = value == true and 'true' or 'false'
    else
      log.log_warning(
        EXTENSION_NAME,
        'extensions.atelier.' .. name .. ' must be true or false, but was "' .. str.stringify(value) ..
        '" in ' .. (quarto.doc.input_file or '') .. ', so it is off. Write `' .. name .. ': true` to turn it on.'
      )
      switches[name] = 'false'
    end
  end
  return typst_dict(switches)
end

--- The colour tokens, as a Typst dictionary.
--- @param tokens table<string, table>
--- @return string
local function tokens_code(tokens)
  local entries = {}
  for name, colour in pairs(tokens) do
    entries[name] = typst_colour(colour, tokens.bg)
  end
  return typst_dict(entries)
end

--- The highlighting of one surface: the style of each token function, each
--- colour held at 4.5:1 on the backgrounds, as `html/highlighting.scss` does.
--- @param styles table The token styles of a highlighting theme
--- @param bgs table[] The backgrounds of the code
--- @return string
local function highlighting_code(styles, bgs)
  local entries = {}
  for class, style in pairs(styles) do
    local name = TOKEN_FUNCTIONS[class]
    local held = palette.held_style(style, bgs)
    if name ~= nil and held ~= nil then
      entries[name] = typst_dict({
        fill = 'rgb("' .. held.colour .. '")',
        weight = typst_string(held.bold and 'bold' or 'regular'),
        style = typst_string(held.italic and 'italic' or 'normal'),
        underline = held.underline and 'true' or 'false',
      })
    end
  end
  return typst_dict(entries)
end

--- The font families of the preset, as a Typst dictionary of arrays. A brand
--- font is set by the template from the brand data, so it wins.
--- @param preset string
--- @return string
local function fonts_code(preset)
  local fonts = palette.PRESET_FONTS[preset] or {}
  local entries = {}
  for _, role in ipairs({ 'base', 'headings', 'monospace' }) do
    entries[role] = fonts[role] and typst_array({ typst_string(fonts[role]) }) or 'none'
  end
  return typst_dict(entries)
end

--- The labels of the document language, as a Typst dictionary of strings.
--- @return string
local function labels_code()
  local language = quarto.doc.language or {}
  local entries = {}
  for _, key in ipairs(LABELS) do
    local value = language['atelier-' .. key]
    entries[key] = typst_string(type(value) == 'string' and value or '')
  end
  return typst_dict(entries)
end

--- The plain text of a metadata value, or an empty string.
--- @param value any
--- @return string
local function text_of(value)
  if value == nil then
    return ''
  end
  return str.stringify(value)
end

--- The authors of the document, with their affiliations as numbers into the
--- list of affiliations, and, in workshop mode, the photo of each speaker
--- from `extensions.atelier.speakers`, as a Typst dictionary.
--- @param meta table
--- @param model table The mode and the `extensions.atelier` options
--- @return string
local function authors_code(meta, model)
  local photos = {}
  for _, speaker in ipairs(core.speakers(meta, model)) do
    if speaker.photo ~= nil then
      photos[speaker.index] = speaker
    end
  end
  local affiliations = {}
  local numbers = {}
  for _, affiliation in ipairs(meta['by-affiliation'] or {}) do
    local name = text_of(affiliation.name)
    if name ~= '' then
      affiliations[#affiliations + 1] = typst_string(name)
      numbers[text_of(affiliation.id)] = #affiliations
    end
  end
  local authors = {}
  for index, author in ipairs(meta['by-author'] or {}) do
    local name = core.author_name(author)
    if name ~= '' then
      local own = {}
      for _, affiliation in ipairs(author.affiliations or {}) do
        local number = numbers[text_of(affiliation.ref or affiliation.id)]
        if number ~= nil then
          own[#own + 1] = tostring(number)
        end
      end
      local attributes = author.attributes or {}
      local degrees = {}
      for _, degree in ipairs(author.degrees or {}) do
        degrees[#degrees + 1] = typst_string(text_of(degree))
      end
      authors[#authors + 1] = typst_dict({
        name = typst_string(name),
        degrees = typst_array(degrees),
        affiliations = typst_array(own),
        orcid = typst_string(text_of(author.orcid)),
        email = typst_string(text_of(author.email)),
        corresponding = attributes.corresponding == true and 'true' or 'false',
        photo = photos[index] and typst_string(photos[index].photo) or 'none',
        alt = photos[index] and photos[index].alt ~= '' and typst_string(photos[index].alt) or 'none',
      })
    end
  end
  return typst_dict({ authors = typst_array(authors), affiliations = typst_array(affiliations) })
end

--- The corner motif of a workshop handout, as a Typst dictionary of its
--- shapes, colour and opacity factor, or `none` outside workshop mode. On a
--- light page the motif takes the accent mark at 85% of its opacities, and on
--- a dark page the accent ink.
--- @param model table The mode and the `extensions.atelier` options
--- @param preset string
--- @param tokens table<string, table>
--- @return string
local function motif_code(model, preset, tokens)
  if model.mode ~= core.MODE_WORKSHOP then
    return 'none'
  end
  local dark = palette.tone(tokens.bg) == 'dark'
  return typst_dict({
    shapes = motifs.typst(motifs.name(preset)),
    paint = typst_colour(tokens[dark and 'accent-ink' or 'accent-mark'], tokens.bg),
    factor = dark and '100%' or string.format('%g%%', motifs.LIGHT_OPACITY * 100),
  })
end

--- Answer the logo of the document as Typst: its image for the tone of the
--- page, with the alt text, or `none`.
--- @param meta table
--- @param tokens table<string, table>
--- @return string
local function logo_code(meta, tokens)
  local resolved = logo.resolve(meta)
  if resolved == nil then
    return 'none'
  end
  local image = palette.tone(tokens.bg) == 'dark' and resolved.dark or resolved.light
  return typst_dict({ path = typst_string(image.path), alt = typst_string(image.alt) })
end

--- Write the document data into `atelier-typst-data`.
--- @param meta table
--- @return table
local function publish(meta)
  local options = core.read_options(meta)
  local model = { mode = core.read_mode(meta, quarto.doc.input_file or '', true), options = options }
  local scheme = palette.document_scheme(meta)
  local painted = palette.painted_scheme(scheme)
  local preset = palette.preset(painted)
  local tokens = palette.tokens(scheme)
  local styles = palette.highlighting(preset, painted)
  local terminal_styles = palette.highlighting(preset, 'dark')
  local lines = {
    '#let atelier-preset = ' .. typst_string(preset),
    '#let atelier-tokens = ' .. tokens_code(tokens),
    '#let atelier-highlighting = ' .. typst_dict({
      page = highlighting_code(styles, { tokens.surface }),
      terminal = highlighting_code(terminal_styles, { tokens['terminal-bg'], tokens['terminal-highlight'] }),
    }),
    '#let atelier-preset-fonts = ' .. fonts_code(preset),
    '#let atelier-labels = ' .. labels_code(),
    '#let atelier-switches = ' .. switches_code(options),
    '#let atelier-people = ' .. authors_code(meta, model),
    '#let atelier-motif-data = ' .. motif_code(model, preset, tokens),
    '#let atelier-logo = ' .. logo_code(meta, tokens),
  }
  meta['atelier-typst-data'] = pandoc.MetaBlocks({ pandoc.RawBlock('typst', table.concat(lines, '\n')) })
  return meta
end

-- ============================================================================
-- ELEMENTS
-- ============================================================================

-- Quarto's Typst `callout()` call carries no type and no appearance, so each
-- callout gets a marker as the first block of its body, which the `callout`
-- function of `typst/elements.typ` reads.
-- Upstream: https://github.com/quarto-dev/quarto-cli/issues/15414
-- Remove when: the minimum Quarto version includes the fix.

--- Put the type marker in front of the body of a callout.
--- @param callout table The Quarto callout node
--- @return table The callout
local function mark_callout(callout)
  local titled = callout.title ~= nil and not quarto.utils.is_empty_node(callout.title)
  local marker = string.format(
    '#metadata((atelier-callout: %s, appearance: %s, titled: %s))',
    typst_string(callout.type or 'note'),
    typst_string(callout.appearance or 'default'),
    titled and 'true' or 'false'
  )
  local content = pandoc.Blocks({ pandoc.RawBlock('typst', marker) })
  if callout.content ~= nil then
    content:extend(quarto.utils.as_blocks(callout.content))
  end
  callout.content = content
  return callout
end

--- Follow each level-1 heading with the call that ends the page it starts,
--- after the switches. A `.part` heading is a book part: it has no number,
--- and the template gives it a part divider.
--- @param header pandoc.Header
--- @return pandoc.Blocks|nil
local function mark_chapter(header)
  if header.level ~= 1 then
    return nil
  end
  local blocks = pandoc.Blocks({})
  if header.classes:includes('part') then
    if not header.classes:includes('unnumbered') then
      header.classes:insert('unnumbered')
    end
    blocks:insert(pandoc.RawBlock('typst', '#atelier-part-next.update(true)'))
  end
  blocks:insert(header)
  blocks:insert(pandoc.RawBlock('typst', '#atelier-chapter-end()'))
  return blocks
end

--- Write inline code with the Atelier code colours.
--- @param code pandoc.Code
--- @return pandoc.RawInline
local function inline_code(code)
  return pandoc.RawInline('typst', '#atelier-inline-code(' .. typst_string(code.text) .. ')')
end


return {
  { Meta = publish },
  { Callout = mark_callout, Header = mark_chapter, Code = inline_code },
}
