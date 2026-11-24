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

local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local palette = require(quarto.utils.resolve_path('palette.lua'):gsub('%.lua$', ''))

--- The fonts of each preset, as `html/presets.scss` sets them. A brand font
--- wins. The `default` preset sets none, so the deck keeps the theme fonts.
--- @type table<string, table<string, string>>
local PRESET_FONTS = {
  quarto = { base = 'Alegreya Sans', headings = 'Alegreya Sans', monospace = 'Fira Code' },
  terminal = { base = 'JetBrains Mono', headings = 'JetBrains Mono', monospace = 'JetBrains Mono' },
}

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

--- The scope of the deck tokens and of the dark slide tokens.
--- `:root:root` wins over the `:root` rules of the theme, whatever the order.
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

-- ============================================================================
-- CSS
-- ============================================================================

--- A palette colour as CSS: hex when opaque, `rgba()` when translucent.
--- @param colour table
--- @return string
local function css_colour(colour)
  if colour.a < 1 then
    local alpha = (string.format('%.3f', colour.a):gsub('0+$', ''))
    return string.format(
      'rgba(%d, %d, %d, %s)',
      math.floor(colour.r + 0.5),
      math.floor(colour.g + 0.5),
      math.floor(colour.b + 0.5),
      alpha
    )
  end
  return palette.hex(colour, colour)
end

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

--- The declarations of the tokens of one scheme, with the Reveal.js and
--- Quarto properties that the theme paints from.
--- @param tokens table<string, table>
--- @return string[]
local function token_declarations(tokens)
  local lines = {}
  for _, name in ipairs(sorted_keys(tokens)) do
    lines[#lines + 1] = '  --atelier-' .. name .. ': ' .. css_colour(tokens[name]) .. ';'
  end
  local reveal = {
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
  }
  for _, property in ipairs(sorted_keys(reveal)) do
    lines[#lines + 1] = '  ' .. property .. ': var(--atelier-' .. reveal[property] .. ');'
  end
  return lines
end

--- The rules of one highlighting map under a scope. Each colour is held at
--- 4.5:1 on every background, as `html/highlighting.scss` does.
--- @param styles table The token styles of a highlighting theme
--- @param scope string The selector of the code
--- @param bgs table[] The backgrounds of the code, of one tone
--- @param normal boolean Write the Normal colour on every span
--- @return string[]
local function highlighting_rules(styles, scope, bgs, normal)
  local rules = {}
  for _, class in ipairs(sorted_keys(styles)) do
    local style = styles[class]
    local parsed = palette.parse(style.color)
    if parsed ~= nil and (class ~= '' or normal) then
      local selector = scope .. ' code span' .. (class ~= '' and ('.' .. class) or '')
      local declarations = { 'color: ' .. palette.hex(palette.contrast_all(parsed, bgs, 4.5), bgs[1]) }
      if class ~= '' then
        declarations[#declarations + 1] = 'background-color: transparent'
        declarations[#declarations + 1] = 'font-weight: ' .. (style.bold and 'bold' or 'normal')
        declarations[#declarations + 1] = 'font-style: ' .. (style.italic and 'italic' or 'normal')
        declarations[#declarations + 1] = 'text-decoration: ' .. (style.underline and 'underline' or 'none')
      end
      rules[#rules + 1] = selector .. ' { ' .. table.concat(declarations, '; ') .. '; }'
    end
  end
  return rules
end

--- The highlighting of one scheme: the page map on the code surfaces, and
--- the dark map on the terminal surfaces.
--- @param scope string The scope of the scheme
--- @param scheme string `light` or `dark`
--- @return string[]
local function scheme_highlighting(scope, scheme)
  local painted = palette.painted_scheme(scheme)
  local preset = palette.preset(painted)
  local tokens = palette.tokens(scheme)
  local rules = highlighting_rules(
    palette.highlighting(preset, painted),
    scope .. ' pre',
    { tokens.surface, tokens['surface-strong'], tokens.bg, tokens['accent-soft'] },
    true
  )
  -- The page map paints every span with its Normal colour, so the lines of a
  -- terminal take the terminal ink back. Its token rules outrank this one.
  rules[#rules + 1] = scope .. ' pre.atelier-terminal code span { color: ' ..
    palette.hex(tokens['terminal-fg'], tokens['terminal-bg']) .. '; }'
  for _, rule in ipairs(highlighting_rules(
    palette.highlighting(preset, 'dark'),
    scope .. ' pre.atelier-terminal',
    { tokens['terminal-bg'], tokens['terminal-highlight'] },
    false
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
  local fonts = PRESET_FONTS[palette.preset(palette.painted_scheme(scheme))] or {}
  local lines = {}
  for _, role in ipairs({ 'base', 'headings', 'monospace' }) do
    if fonts[role] ~= nil and not brand_sets_font(scheme, role) then
      lines[#lines + 1] = string.format('  --atelier-font-%s: "%s", %s;', role, fonts[role], FALLBACK_FONTS[role])
    end
  end
  return lines
end

--- The style element of the deck.
--- @param scheme string The scheme of the deck
--- @return string
local function deck_style(scheme)
  local lines = { '<style id="atelier-deck-tokens">', ROOT_SCOPE .. ' {' }
  for _, line in ipairs(token_declarations(palette.tokens(scheme))) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(font_declarations(scheme)) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  lines[#lines + 1] = DARK_SCOPE .. ',\n' .. DARK_FRAME_SCOPE .. ' {'
  for _, line in ipairs(token_declarations(palette.tokens('dark'))) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '}'
  for _, rule in ipairs(scheme_highlighting('.reveal .slides', scheme)) do
    lines[#lines + 1] = rule
  end
  for _, rule in ipairs(scheme_highlighting(DARK_SCOPE, 'dark')) do
    lines[#lines + 1] = rule
  end
  lines[#lines + 1] = '</style>'
  return table.concat(lines, '\n')
end

-- ============================================================================
-- DECK
-- ============================================================================

--- The state of the deck, which the block handlers read.
--- @type table
local deck = { scheme = 'light', tokens = nil, dark = nil, title = nil }

--- Add the deck style and read the deck state.
--- @param meta table
--- @return nil
local function publish(meta)
  deck.scheme = palette.document_scheme(meta)
  deck.tokens = palette.tokens(deck.scheme)
  deck.dark = palette.tokens('dark')
  deck.title = meta.title and str.stringify(meta.title) or ''
  quarto.doc.include_text('in-header', deck_style(deck.scheme))
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

--- Mark the section slides and the dark slides. Reveal.js paints the
--- background of a slide on its own layer, so each one gets its colour.
--- @param header pandoc.Header
--- @return pandoc.Header|nil
local function mark_slide(header)
  if header.level == 1 then
    add_class(header.attr, SECTION_CLASS)
    add_state(header.attr, SECTION_STATE)
    if header.attributes['background-color'] == nil then
      header.attributes['background-color'] = palette.hex(deck.tokens['navbar-bg'], deck.tokens.bg)
    end
    if palette.tone(deck.tokens['navbar-bg']) == 'dark' then
      add_class(header.attr, DARK_BACKGROUND_CLASS)
    end
    return header
  end
  if header.classes:includes(DARK_CLASS) then
    if header.attributes['background-color'] == nil then
      header.attributes['background-color'] = palette.hex(deck.dark.bg, deck.dark.bg)
    end
    add_class(header.attr, DARK_BACKGROUND_CLASS)
    add_state(header.attr, DARK_STATE)
    return header
  end
  return nil
end

--- Fill the footer slots. The footer of the author goes in the centre slot,
--- the title of the deck in the left one. The slide number of Reveal.js sits
--- in the right corner.
--- @param div pandoc.Div The `footer-default` div
--- @return pandoc.Div
local function fill_footer(div)
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

--- Find the footer that Quarto adds to the deck.
--- @param div pandoc.Div
--- @return pandoc.Div|nil
local function footer(div)
  if div.classes:includes('footer-default') then
    return fill_footer(div)
  end
  return nil
end

if not quarto.doc.is_format('revealjs') then
  return {}
end

return {
  { Meta = publish },
  { Header = mark_slide, Div = footer },
}
