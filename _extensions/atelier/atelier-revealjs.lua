--- Atelier - Reveal.js Deck Filter
--- @module "atelier-revealjs"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Give a Reveal.js deck the Atelier tokens and the Atelier slide types.
--- @description Quarto gives the Sass of a Reveal.js theme no brand
--- `defaults.bootstrap.defaults`, so the deck Sass cannot read the preset,
--- and it cannot read `brand-mode` either. This filter reads the colours from
--- `palette.lua` and writes them as `--atelier-*` custom properties: once for
--- the deck, in the scheme of `brand-mode`, and once for the slides with the
--- `dark` class, in the dark scheme. It also writes the fonts of the preset
--- and the highlighting colours, held at 4.5:1 on the code surfaces.
--- The rules of `revealjs/deck.scss` read these properties.
--- The filter gives each level-1 heading the section slide class, each
--- `.dark` slide its background, the title slide its class, and the footer
--- its slots: the title on the left, the footer of the author in the centre,
--- and the slide number of Reveal.js on the right.

local palette = require(quarto.utils.resolve_path('palette.lua'):gsub('%.lua$', ''))
local motifs = require(quarto.utils.resolve_path('motifs.lua'):gsub('%.lua$', ''))
local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))

--- The fallback family of each font role.
--- @type table<string, string>
local FALLBACK_FONTS = { base = 'sans-serif', headings = 'sans-serif', monospace = 'monospace' }

--- The brand typography roles that set each font role.
--- @type table<string, string[]>
local BRAND_FONT_ROLES = {
  base = { 'base' },
  headings = { 'headings' },
  monospace = { 'monospace', 'monospace-block', 'monospace-inline' },
}

--- The Reveal.js, Quarto and a11y plugin properties that the theme paints
--- from, and the token of each.
--- @type table<string, string>
local THEME_PROPERTIES = {
  ['--r-background-color'] = 'bg',
  ['--r-main-color'] = 'fg',
  ['--r-heading-color'] = 'heading',
  ['--r-link-color'] = 'link',
  ['--r-link-color-hover'] = 'link-hover',
  ['--r-link-color-dark'] = 'link',
  ['--r-selection-background-color'] = 'accent-fill',
  ['--r-selection-color'] = 'on-accent',
  ['--quarto-body-bg'] = 'bg',
  ['--quarto-body-color'] = 'fg',
  ['--quarto-text-muted'] = 'muted',
  ['--quarto-border-color'] = 'border',
  ['--a11y-accent'] = 'focus',
}

--- The scope of the deck tokens and of the dark slide tokens.
--- `:root:root` wins over the `:root` rules of the theme and of the plugins,
--- whatever the order.
--- @type string
local ROOT_SCOPE = ':root:root'

--- @type string
local DARK_SCOPE = '.reveal .slides section.dark'

--- The frame around the deck on a dark slide: Reveal.js puts the
--- `data-state` of the current slide on the viewport.
--- @type string
local DARK_FRAME_SCOPE = '.atelier-dark-state .reveal > :is(.footer, .slide-number, .controls, .progress, .slide-menu-button)'

--- The `data-state` of a dark slide and of a section slide.
--- @type string
local DARK_STATE = 'atelier-dark-state'

--- @type string
local SECTION_STATE = 'atelier-section-state'

--- The class of a slide in the dark scheme.
--- @type string
local DARK_CLASS = 'dark'

--- The class that tells Reveal.js and Quarto that a slide has a dark
--- background, so the controls and the footer follow.
--- @type string
local DARK_BACKGROUND_CLASS = 'has-dark-background'

--- The class of a section slide.
--- @type string
local SECTION_CLASS = 'atelier-section'

--- The attribute that marks a slide that shows the motif, in workshop mode.
--- Reveal.js writes it with the `data-` prefix.
--- @type string
local MOTIF_ATTRIBUTE = 'atelier-motif'

-- ============================================================================
-- CSS
-- ============================================================================

--- Sorted keys of a table.
--- @param entries table
--- @return string[]
local function sorted_keys(entries)
  local names = {}
  for name in pairs(entries) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

--- The declarations of the tokens of one scheme, with the properties that
--- the theme paints from.
--- @param tokens table<string, table>
--- @return string[]
local function token_declarations(tokens)
  local lines = {}
  for _, name in ipairs(sorted_keys(tokens)) do
    lines[#lines + 1] = '  --atelier-' .. name .. ': ' .. palette.css(tokens[name]) .. ';'
  end
  for _, property in ipairs(sorted_keys(THEME_PROPERTIES)) do
    lines[#lines + 1] = '  ' .. property .. ': var(--atelier-' .. THEME_PROPERTIES[property] .. ');'
  end
  return lines
end

--- The rules of one highlighting map under a scope. Each colour is held at
--- 4.5:1 on every background, as `html/highlighting.scss` does. The Normal
--- colour goes on every span, and the class rules outrank it.
--- @param styles table The token styles of a highlighting theme
--- @param scope string The selector of the code
--- @param bgs table[] The backgrounds of the code, of one tone
--- @param normal string|nil The Normal colour, which replaces the one of the map
--- @return string[]
local function highlighting_rules(styles, scope, bgs, normal)
  local rules = {}
  for _, class in ipairs(sorted_keys(styles)) do
    local held = palette.held_style(styles[class], bgs)
    if held ~= nil then
      local declarations
      if class == '' then
        declarations = { 'color: ' .. (normal or held.colour) }
      else
        declarations = {
          'color: ' .. held.colour,
          'background-color: transparent',
          'font-weight: ' .. (held.bold and 'bold' or 'normal'),
          'font-style: ' .. (held.italic and 'italic' or 'normal'),
          'text-decoration: ' .. (held.underline and 'underline' or 'none'),
        }
      end
      local selector = scope .. ' code span' .. (class ~= '' and ('.' .. class) or '')
      rules[#rules + 1] = selector .. ' { ' .. table.concat(declarations, '; ') .. '; }'
    end
  end
  return rules
end

--- The highlighting of one scheme: the page map on the code surfaces, and
--- the dark map on the terminal surfaces, with the terminal ink as Normal.
--- @param scope string The scope of the scheme
--- @param scheme string `light` or `dark`
--- @param tokens table<string, table> The tokens of the scheme
--- @return string[]
local function scheme_highlighting(scope, scheme, tokens)
  local painted = palette.painted_scheme(scheme)
  local preset = palette.preset(painted)
  local rules = highlighting_rules(
    palette.highlighting(preset, painted),
    scope .. ' pre',
    { tokens.surface, tokens['surface-strong'], tokens.bg, tokens['accent-soft'] },
    nil
  )
  for _, rule in ipairs(highlighting_rules(
    palette.highlighting(preset, 'dark'),
    scope .. ' pre.atelier-terminal',
    { tokens['terminal-bg'], tokens['terminal-highlight'] },
    palette.hex(tokens['terminal-fg'], tokens['terminal-bg'])
  )) do
    rules[#rules + 1] = rule
  end
  return rules
end

--- Tell whether the brand of a scheme sets a font role. Quarto gives the
--- deck Sass the brand of `brand-mode` only, with no fallback to the light
--- brand, so this reads that brand only.
--- @param scheme string `light` or `dark`
--- @param role string `base`, `headings` or `monospace`
--- @return boolean
local function brand_sets_font(scheme, role)
  if not quarto.brand.has_mode(scheme) then
    return false
  end
  for _, name in ipairs(BRAND_FONT_ROLES[role]) do
    local typography = quarto.brand.get_typography(scheme, name)
    if typography ~= nil and typography.family ~= nil then
      return true
    end
  end
  return false
end

--- The font declarations of the preset, for the roles that the brand does
--- not set.
--- @param scheme string `light` or `dark`
--- @return string[]
local function font_declarations(scheme)
  local fonts = palette.PRESET_FONTS[palette.preset(palette.painted_scheme(scheme))] or {}
  local lines = {}
  for _, role in ipairs({ 'base', 'headings', 'monospace' }) do
    if fonts[role] ~= nil and not brand_sets_font(scheme, role) then
      lines[#lines + 1] = string.format('  --atelier-font-%s: "%s", %s;', role, fonts[role], FALLBACK_FONTS[role])
    end
  end
  return lines
end

--- The custom properties of the motif in one scope: the colour and the
--- opacity, after the tone of the surface. A light surface takes the mark at
--- 85%, a dark one the ink.
--- @param surface table The colour under the motif
--- @param light string The token on a light surface
--- @param dark string The token on a dark surface
--- @return string[]
local function motif_paint(surface, light, dark)
  local is_dark = palette.tone(surface) == 'dark'
  return {
    '  --atelier-motif-paint: var(--atelier-' .. (is_dark and dark or light) .. ');',
    '  --atelier-motif-opacity: ' .. (is_dark and '1' or '0.85') .. ';',
  }
end

--- The rules of the motif of a workshop deck: the mask of the preset, and
--- its colour on the page, on the dark slides and on the section slides.
--- @param scheme string The scheme of the deck
--- @param tokens table<string, table> The tokens of the deck
--- @param dark table<string, table> The tokens of the dark slides
--- @return string[]
local function motif_rules(scheme, tokens, dark)
  local preset = palette.preset(palette.painted_scheme(scheme))
  local lines = { ROOT_SCOPE .. ' {', '  --atelier-motif: ' .. motifs.mask(motifs.name(preset)) .. ';' }
  for _, line in ipairs(motif_paint(tokens.bg, 'accent-mark', 'accent-ink')) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  lines[#lines + 1] = DARK_SCOPE .. ' {'
  for _, line in ipairs(motif_paint(dark.bg, 'accent-mark', 'accent-ink')) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  lines[#lines + 1] = '.reveal .slides section.' .. SECTION_CLASS .. ' {'
  for _, line in ipairs(motif_paint(tokens['navbar-bg'], 'navbar-accent-mark', 'navbar-accent-mark')) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  return lines
end

--- The style element of the deck.
--- @param scheme string The scheme of the deck
--- @param tokens table<string, table> The tokens of the deck
--- @param dark table<string, table> The tokens of the dark slides
--- @param workshop boolean True in workshop mode, which adds the motif
--- @return string
local function deck_style(scheme, tokens, dark, workshop)
  local lines = { '<style id="atelier-deck-tokens">', ROOT_SCOPE .. ' {' }
  for _, line in ipairs(token_declarations(tokens)) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(font_declarations(scheme)) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  lines[#lines + 1] = DARK_SCOPE .. ',\n' .. DARK_FRAME_SCOPE .. ' {'
  for _, line in ipairs(token_declarations(dark)) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  for _, rule in ipairs(scheme_highlighting('.reveal .slides', scheme, tokens)) do
    lines[#lines + 1] = rule
  end
  for _, rule in ipairs(scheme_highlighting(DARK_SCOPE, 'dark', dark)) do
    lines[#lines + 1] = rule
  end
  if workshop then
    for _, line in ipairs(motif_rules(scheme, tokens, dark)) do
      lines[#lines + 1] = line
    end
  end
  lines[#lines + 1] = '</style>'
  return table.concat(lines, '\n')
end

-- ============================================================================
-- DECK
-- ============================================================================

--- What the block handlers read: the title of the deck, the background of
--- the section slides and whether it is dark, and the backgrounds of the dark
--- slides and of the dark section slides. `publish` fills it.
--- @type table
local deck = {}

--- Add the deck style and read the deck state. A workshop deck marks its
--- title slide for the motif.
--- @param meta table
--- @return table|nil The changed metadata of a workshop deck, or nil
local function publish(meta)
  local scheme = palette.document_scheme(meta)
  local tokens = palette.tokens(scheme)
  local dark = palette.tokens('dark')
  deck.title = meta.title and pandoc.utils.stringify(meta.title) or ''
  deck.section_bg = palette.hex(tokens['navbar-bg'], tokens.bg)
  deck.section_dark = palette.tone(tokens['navbar-bg']) == 'dark'
  deck.dark_bg = palette.hex(dark.bg, dark.bg)
  deck.dark_section_bg = palette.hex(dark['navbar-bg'], dark.bg)
  deck.workshop = core.read_mode(meta, quarto.doc.input_file or '', true) == core.MODE_WORKSHOP
  quarto.doc.include_text('in-header', deck_style(scheme, tokens, dark, deck.workshop))
  if deck.workshop then
    local attributes = meta['title-slide-attributes'] or {}
    attributes['data-' .. MOTIF_ATTRIBUTE] = pandoc.MetaString('')
    meta['title-slide-attributes'] = attributes
    return meta
  end
  return nil
end

--- Add a class to an attribute set once.
--- @param attr pandoc.Attr
--- @param class string
local function add_class(attr, class)
  if not attr.classes:includes(class) then
    attr.classes:insert(class)
  end
end

--- Add a state to the `data-state` of a slide, after the states of the author.
--- @param attr pandoc.Attr
--- @param state string
local function add_state(attr, state)
  local states = attr.attributes['data-state'] or attr.attributes['state'] or ''
  for name in states:gmatch('%S+') do
    if name == state then
      return
    end
  end
  attr.attributes['state'] = nil
  attr.attributes['data-state'] = (states == '' and state) or (states .. ' ' .. state)
end

--- Give a slide its background colour, unless the author set one.
--- @param attr pandoc.Attr
--- @param colour string
local function set_background(attr, colour)
  if attr.attributes['background-color'] == nil then
    attr.attributes['background-color'] = colour
  end
end

--- Mark the section slides and the dark slides. Reveal.js paints the
--- background of a slide on its own layer, so each one gets its colour. A
--- section slide with the `dark` class takes the dark tokens, so it gets the
--- section colour of the dark scheme.
--- @param header pandoc.Header
--- @return pandoc.Header|nil
local function mark_slide(header)
  local dark = header.classes:includes(DARK_CLASS)
  if header.level == 1 then
    add_class(header.attr, SECTION_CLASS)
    if deck.workshop then
      header.attributes[MOTIF_ATTRIBUTE] = ''
    end
    add_state(header.attr, dark and DARK_STATE or SECTION_STATE)
    set_background(header.attr, dark and deck.dark_section_bg or deck.section_bg)
    if dark or deck.section_dark then
      add_class(header.attr, DARK_BACKGROUND_CLASS)
    end
    return header
  end
  if dark then
    set_background(header.attr, deck.dark_bg)
    add_class(header.attr, DARK_BACKGROUND_CLASS)
    add_state(header.attr, DARK_STATE)
    return header
  end
  return nil
end

--- Fill the slots of the footer that Quarto adds to the deck. The footer of
--- the author goes in the centre slot, the title of the deck in the left one.
--- The slide number of Reveal.js sits in the right corner.
--- @param div pandoc.Div
--- @return pandoc.Div|nil
local function fill_footer(div)
  if not div.classes:includes('footer-default') then
    return nil
  end
  local own = pandoc.utils.blocks_to_inlines(div.content)
  div.content = pandoc.Blocks({
    pandoc.Plain({
      pandoc.Span(pandoc.Inlines(deck.title), pandoc.Attr('', { 'atelier-slot', 'atelier-slot-left' })),
      pandoc.Span(own, pandoc.Attr('', { 'atelier-slot', 'atelier-slot-centre' })),
    }),
  })
  add_class(div.attr, 'atelier-footer')
  return div
end

if not quarto.doc.is_format('revealjs') then
  return {}
end

return {
  { Meta = publish },
  { Header = mark_slide, Div = fill_footer },
}
