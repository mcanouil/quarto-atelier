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
--- one row of slots: the title on the left, the footer of the author in the
--- centre, and the logo slot on the right.

local palette = require(quarto.utils.resolve_path('palette.lua'):gsub('%.lua$', ''))
local motifs = require(quarto.utils.resolve_path('motifs.lua'):gsub('%.lua$', ''))
local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))
local icons = require(quarto.utils.resolve_path('icons.lua'):gsub('%.lua$', ''))

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
local DARK_FRAME_SCOPE = '.atelier-dark-state .reveal > :is(.footer, .slide-number, .controls, .progress, .slide-menu-button, .slide-chalkboard-buttons)'

--- The `data-state` of a dark slide and of a section slide.
--- @type string
local DARK_STATE = 'atelier-dark-state'

--- @type string
local SECTION_STATE = 'atelier-section-state'

--- The `data-state` of the title slide and of the section slides, which
--- hide part of the bottom row: the title slide keeps only the centre slot
--- of the footer, and both show no slide number.
--- @type string
local TITLE_STATE = 'atelier-title-state'

--- @type string
local NO_NUMBER_STATE = 'atelier-no-number-state'

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

--- The class of a slide that shows the motif, in workshop mode: the title
--- slide and the section slides. Reveal.js copies the classes of a slide to
--- its background, which covers the window and moves with the slide, and
--- which the PDF export draws on each page, so the motif sits on it.
--- @type string
local MOTIF_CLASS = 'atelier-motif'

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

--- The rules of the motif of a workshop deck: the mask of the preset, and
--- its colour and opacity on the title slide, on the section slides and on
--- the dark section slides, after the surface that `mark_slide` paints. A
--- light surface takes the mark at `motifs.LIGHT_OPACITY`, and a dark one the
--- ink, or the chrome mark on a section slide. The motif sits on the slide
--- background, outside the slide, so the colours are written as they resolve,
--- not as the tokens of a slide.
--- @param scheme string The scheme of the deck
--- @param tokens table<string, table> The tokens of the deck
--- @param dark table<string, table> The tokens of the dark slides
--- @return string[]
local function motif_rules(scheme, tokens, dark)
  local preset = palette.preset(palette.painted_scheme(scheme))
  local background = '.reveal .slide-background.' .. MOTIF_CLASS
  local lines = { background .. ' {', '  --atelier-motif: ' .. motifs.mask(motifs.name(preset)) .. ';', '}' }
  local surfaces = {
    { scope = background, palette = tokens, surface = 'bg', light = 'accent-mark', dark = 'accent-ink' },
    { scope = background .. '.' .. SECTION_CLASS, palette = tokens, surface = 'navbar-bg', light = 'navbar-accent-mark', dark = 'navbar-accent-mark' },
    { scope = background .. '.' .. SECTION_CLASS .. '.' .. DARK_CLASS, palette = dark, surface = 'navbar-bg', light = 'navbar-accent-mark', dark = 'navbar-accent-mark' },
  }
  for _, entry in ipairs(surfaces) do
    local values = entry.palette
    local is_dark = palette.tone(values[entry.surface]) == 'dark'
    local paint = values[is_dark and entry.dark or entry.light]
    lines[#lines + 1] = entry.scope .. ' {'
    lines[#lines + 1] = '  --atelier-motif-paint: ' .. palette.hex(paint, values[entry.surface]) .. ';'
    lines[#lines + 1] = '  --atelier-motif-opacity: ' .. (is_dark and '1' or string.format('%g', motifs.LIGHT_OPACITY)) .. ';'
    lines[#lines + 1] = '}'
  end
  return lines
end

--- Answer true when an option is off, or is a map whose `key` is false.
--- @param value any
--- @param key string
--- @return boolean
local function turned_off(value, key)
  return value == false or (type(value) == 'table' and value[key] == false)
end

--- The number of buttons at the left of the bottom row. Quarto draws the
--- menu button unless `menu` or `menu.openButton` is false, and the two
--- chalkboard buttons when `chalkboard` is set and `chalkboard.buttons` is
--- not false.
--- @param meta table
--- @return integer
local function left_buttons(meta)
  local count = turned_off(meta.menu, 'openButton') and 0 or 1
  if meta.chalkboard and not turned_off(meta.chalkboard, 'buttons') then
    count = count + 2
  end
  return count
end

--- The rules that show the dark image of the logo on dark surfaces: every
--- slide of a dark deck, or else a `.dark` slide and, when its background
--- is dark, a section slide. In a dark deck, light section slides keep the
--- light image.
--- @param page_dark boolean True when the deck is dark
--- @param section_dark boolean True when the section slides are dark
--- @return string[]
local function logo_rules(page_dark, section_dark)
  local show = function(scope, shown, hidden)
    return {
      scope .. ' .reveal .atelier-logo-' .. hidden .. ' { display: none; }',
      scope .. ' .reveal .atelier-logo-' .. shown .. ' { display: block; }',
    }
  end
  if not page_dark then
    return show(':is(.' .. DARK_STATE .. (section_dark and (', .' .. SECTION_STATE) or '') .. ')', 'dark', 'light')
  end
  local rules = show(':root', 'dark', 'light')
  if not section_dark then
    -- A light chrome keeps the section slides light in a dark deck.
    for _, rule in ipairs(show('.' .. SECTION_STATE, 'light', 'dark')) do
      rules[#rules + 1] = rule
    end
  end
  return rules
end

--- The style element of the deck: the tokens, the block geometry and the
--- masks of the block icons.
--- @param scheme string The scheme of the deck
--- @param tokens table<string, table> The tokens of the deck
--- @param dark table<string, table> The tokens of the dark slides
--- @param state { workshop: boolean, logo: table|nil, section_dark: boolean } The deck state
--- @param buttons integer The number of buttons at the left of the bottom row
--- @return string
local function deck_style(scheme, tokens, dark, state, buttons)
  local lines = { '<style id="atelier-deck-tokens">', ROOT_SCOPE .. ' {' }
  lines[#lines + 1] = '  --atelier-row-buttons: ' .. buttons .. ';'
  local geometry = palette.geometry(palette.preset(palette.painted_scheme(scheme)))
  lines[#lines + 1] = string.format('  --atelier-block-radius: %gpx;', geometry['block-radius'])
  lines[#lines + 1] = string.format('  --atelier-checkpoint-bar: %gpx;', geometry['checkpoint-bar'])
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
  for _, name in ipairs(sorted_keys(icons.PATHS)) do
    lines[#lines + 1] = '.reveal .slides .atelier-block-head .bi-' .. name .. ' { mask-image: ' .. icons.mask(name) .. '; }'
  end
  for _, rule in ipairs(scheme_highlighting('.reveal .slides', scheme, tokens)) do
    lines[#lines + 1] = rule
  end
  for _, rule in ipairs(scheme_highlighting(DARK_SCOPE, 'dark', dark)) do
    lines[#lines + 1] = rule
  end
  if state.workshop then
    for _, line in ipairs(motif_rules(scheme, tokens, dark)) do
      lines[#lines + 1] = line
    end
  end
  if state.logo ~= nil then
    for _, line in ipairs(logo_rules(palette.tone(tokens.bg) == 'dark', state.section_dark)) do
      lines[#lines + 1] = line
    end
    -- The logo takes the bottom-right corner, so the slide number goes to the
    -- top-right corner, as Quarto does with `has-logo`. Quarto adds that class
    -- only when it draws its own logo, which it does not for every logo that
    -- Atelier draws, so the rule keys on the logo of Atelier.
    lines[#lines + 1] = ':root:root .reveal.reveal .slide-number { top: 8px; right: 8px; bottom: auto; height: auto; padding: 5px; }'
    lines[#lines + 1] = ':root:root .reveal.reveal :is(.slide-number, .slide-number a) { line-height: normal; }'
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

--- Add the deck style and read the deck state. Give the title slide its
--- state, and in a workshop deck mark it for the motif.
--- @param meta table
--- @return table The metadata, with the state of the title slide
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
  deck.logo = logo.resolve(meta)
  if deck.logo ~= nil then
    deck.logo_html = logo.images_html(deck.logo, 'atelier-logo-light', 'atelier-logo-dark')
    meta['atelier-logo-html'] = pandoc.RawInline('html', deck.logo_html)
  end
  quarto.doc.include_text('in-header', deck_style(scheme, tokens, dark, deck, left_buttons(meta)))
  if palette.terminal_decoration(scheme) then
    quarto.doc.include_file('in-header', 'revealjs/terminal-decoration.html')
    meta['atelier-terminal-cursor'] = true
  end
  if meta.chalkboard then
    quarto.doc.include_file('after-body', 'revealjs/chalkboard-buttons.html')
  end
  local attributes = meta['title-slide-attributes'] or {}
  local states = attributes['data-state'] and pandoc.utils.stringify(attributes['data-state']) or ''
  attributes['data-state'] = (states == '' and TITLE_STATE) or (states .. ' ' .. TITLE_STATE)
  meta['title-slide-attributes'] = attributes
  if deck.workshop then
    -- `revealjs/title-slide.html` adds the motif class to the title slide.
    meta['atelier-motif'] = true
  end
  return meta
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
    add_state(header.attr, dark and DARK_STATE or SECTION_STATE)
    add_state(header.attr, NO_NUMBER_STATE)
    if deck.workshop then
      add_class(header.attr, MOTIF_CLASS)
    end
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

--- Answer the light and the dark image of the logo, for the logo slot of the
--- footer, or nothing when the deck has no logo. The images are raw HTML:
--- Pandoc writes a `data-src` for a deck image, which Reveal.js loads only
--- inside a slide, and the footer is outside the slides.
--- @return pandoc.Inlines
local function logo_images()
  if deck.logo == nil then
    return pandoc.Inlines({})
  end
  return pandoc.Inlines({ pandoc.RawInline('html', deck.logo_html) })
end

--- Fill the slots of the footer that Quarto adds to the deck. The footer of
--- the author goes in the centre slot, the title of the deck in the left one,
--- and the logo slot stays at the right. The slots sit in one row inside the
--- footer, so Quarto can still show or hide the footer itself.
--- @param div pandoc.Div
--- @return pandoc.Div|nil
local function fill_footer(div)
  -- The footer of one slide replaces the footer of the deck on that slide.
  -- With a logo, it takes the same row, so the logo stays on that slide.
  local own_footer = div.classes:includes('footer') and deck.logo ~= nil
  if not div.classes:includes('footer-default') and not own_footer then
    return nil
  end
  local own = pandoc.utils.blocks_to_inlines(div.content)
  local slot = function(name, content)
    return pandoc.Span(content, pandoc.Attr('', { 'atelier-slot', 'atelier-slot-' .. name }))
  end
  -- A slot can cut its text, so the text sits in a span that takes hover and
  -- carries the full text as its title.
  local text = function(content)
    if #content == 0 then
      return {}
    end
    local plain = pandoc.utils.stringify(content)
    return { pandoc.Span(content, pandoc.Attr('', { 'atelier-slot-text' }, { title = plain })) }
  end
  div.content = pandoc.Blocks({
    pandoc.Div(
      pandoc.Plain({
        slot('left', text(pandoc.Inlines(deck.title))),
        slot('centre', text(own)),
        slot('logo', logo_images()),
      }),
      pandoc.Attr('', { 'atelier-footer-row' })
    ),
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
