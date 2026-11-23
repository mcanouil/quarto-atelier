--- Atelier - Palette
--- @module "palette"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief The resolved Atelier colour tokens for one preset and one scheme.
--- @description Quarto compiles the Atelier SCSS for HTML only, so the formats
--- without Sass read their colours from this module. It ports the colour
--- functions of `html/chrome.scss`, the preset branches of `html/presets.scss`,
--- the dark page fallback of `html/dark.scss`, and the token chain of
--- `html/chrome.scss`, `html/theme.scss` and `html/content.scss`. A change to
--- one of these files needs the same change here; the palette parity test
--- compares the two.
---
--- A brand sets Sass variables in `defaults.bootstrap.defaults`. This module
--- reads these ones, and ignores the other `atelier-*` variables:
--- `atelier-preset`, `atelier-chrome`, `atelier-chrome-bg`, `atelier-chrome-fg`,
--- `atelier-chrome-muted`, `atelier-chrome-accent`,
--- `atelier-chrome-accent-soft-alpha`, `atelier-chrome-light-{bg,fg,accent}`,
--- `atelier-chrome-dark-{bg,fg,accent}`, `atelier-terminal-*` (colours),
--- `atelier-terminal-decoration`, `atelier-code-ink`, `atelier-text-muted`,
--- and the Bootstrap `body-bg`, `body-color`, `primary`, `secondary`,
--- `link-color`, `headings-color`, `blue`, `green`, `yellow`, `orange`, `red`.

local EXTENSION_NAME = 'atelier'

--- The directory of this file, so that the module loads its neighbours from
--- any filter that requires it.
local HERE = debug.getinfo(1, 'S').source:match('^@(.*[/\\])') or './'

local colour_mod = dofile(HERE .. '_vendor/quarto-lua-modules/colour.lua')
local log = dofile(HERE .. '_vendor/quarto-lua-modules/logging.lua')

local M = {}

-- ============================================================================
-- COLOURS
-- ============================================================================

--- A colour: red, green and blue from 0 to 255, which can be fractional as
--- in Dart Sass, and alpha from 0 to 1.
--- @alias Colour { r: number, g: number, b: number, a: number }

local BLACK = { r = 0, g = 0, b = 0, a = 1 }
local WHITE = { r = 255, g = 255, b = 255, a = 1 }

--- Build a colour from a hex string such as `#1b242e`, `#fff` or `#1b242e80`.
--- @param hex string
--- @return Colour|nil
local function from_hex(hex)
  local digits = hex:match('^#(%x+)$')
  if digits == nil then
    return nil
  end
  if #digits == 3 or #digits == 4 then
    digits = digits:gsub('.', '%0%0')
  end
  if #digits ~= 6 and #digits ~= 8 then
    return nil
  end
  local alpha = #digits == 8 and tonumber(digits:sub(7, 8), 16) / 255 or 1
  return {
    r = tonumber(digits:sub(1, 2), 16),
    g = tonumber(digits:sub(3, 4), 16),
    b = tonumber(digits:sub(5, 6), 16),
    a = alpha,
  }
end

--- Read one `rgb()` channel or the alpha: a number, or a percentage of `full`.
--- @param text string
--- @param full number The value of 100%
--- @return number|nil
local function channel(text, full)
  local number, percent = text:match('^([%d.]+)(%%?)$')
  if number == nil or tonumber(number) == nil then
    return nil
  end
  if percent == '%' then
    return tonumber(number) / 100 * full
  end
  return tonumber(number)
end

--- Build a colour from the arguments of `rgb()` or `rgba()`, with commas
--- (`16, 18, 22, 0.5`) or with spaces and a slash (`16 18 22 / 50%`).
--- @param arguments string
--- @return Colour|nil
local function from_rgb_arguments(arguments)
  local parts = {}
  for part in arguments:gsub('/', ' '):gsub(',', ' '):gmatch('%S+') do
    table.insert(parts, part)
  end
  if #parts ~= 3 and #parts ~= 4 then
    return nil
  end
  local r, g, b = channel(parts[1], 255), channel(parts[2], 255), channel(parts[3], 255)
  local a = parts[4] and channel(parts[4], 1) or 1
  if r == nil or g == nil or b == nil or a == nil then
    return nil
  end
  return { r = r, g = g, b = b, a = a }
end

--- Parse a CSS colour: hex, a named colour, `rgb()`, `rgba()`, `hsl()` or `hwb()`.
--- @param value any A string, or a value that is not a colour
--- @return Colour|nil The colour, or nil when the value is not a colour
function M.parse(value)
  if type(value) == 'table' and value.r ~= nil then
    return value
  end
  if type(value) ~= 'string' then
    return nil
  end
  local text = value:lower():gsub('^%s+', ''):gsub('%s+$', '')
  if text:match('^#') then
    return from_hex(text)
  end
  if colour_mod.is_named_colour(text) then
    return from_hex(colour_mod.named_to_HTML(text):lower())
  end
  local arguments = text:match('^rgba?%((.*)%)$')
  if arguments ~= nil then
    return from_rgb_arguments(arguments)
  end
  local converters = { hsl = colour_mod.HSL_to_HTML, hwb = colour_mod.HWB_to_HTML }
  local kind = text:match('^(%a+)%(')
  if converters[kind] then
    local ok, hex = pcall(converters[kind], text)
    if ok and hex then
      return from_hex(hex:lower())
    end
  end
  return nil
end

--- Round half up, as Sass `math.round()` does, with the Sass tolerance for
--- a value that sits a rounding error under the half.
--- @param x number
--- @return integer
local function round(x)
  return math.floor(x + 0.5 + 1e-11)
end

--- The colour with each channel rounded to a whole number, as the browser
--- paints it (`atelier-rendered()`).
--- @param c Colour
--- @return Colour
local function rendered(c)
  return { r = round(c.r), g = round(c.g), b = round(c.b), a = c.a }
end

--- The colour with another alpha (Sass `rgba($color, $alpha)`).
--- @param c Colour
--- @param alpha number
--- @return Colour
local function with_alpha(c, alpha)
  return { r = c.r, g = c.g, b = c.b, a = alpha }
end

--- Sass `mix()`: $weight of $c1 and the rest of $c2, with the alpha of each
--- weighting the channels, as Dart Sass does for legacy colours.
--- @param c1 Colour
--- @param c2 Colour
--- @param weight number From 0 to 1
--- @return Colour
function M.mix(c1, c2, weight)
  local scaled = weight * 2 - 1
  local alpha_delta = c1.a - c2.a
  local combined
  if scaled * alpha_delta == -1 then
    combined = scaled
  else
    combined = (scaled + alpha_delta) / (1 + scaled * alpha_delta)
  end
  local w1 = (combined + 1) / 2
  local w2 = 1 - w1
  return {
    r = c1.r * w1 + c2.r * w2,
    g = c1.g * w1 + c2.g * w2,
    b = c1.b * w1 + c2.b * w2,
    a = c1.a * weight + c2.a * (1 - weight),
  }
end

--- `atelier-mix()`: `mix()` rounded to whole channels.
local function mix_rendered(c1, c2, weight)
  return rendered(M.mix(c1, c2, weight))
end

--- The relative luminance, as Quarto's `luminance()` computes it.
--- @param c Colour
--- @return number
local function luminance(c)
  local function linear(channel)
    local value = channel / 255
    if value < 0.03928 then
      return value / 12.92
    end
    return ((value + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
end

--- Quarto's `quarto-contrast()`: the WCAG contrast ratio of two colours.
--- @param a Colour
--- @param b Colour
--- @return number
function M.ratio(a, b)
  local la = luminance(a) + 0.05
  local lb = luminance(b) + 0.05
  return math.max(la, lb) / math.min(la, lb)
end

--- Quarto's `tone()`: `light` or `dark`.
--- @param c Colour
--- @return string
function M.tone(c)
  local with_white = M.ratio(c, WHITE)
  local with_black = M.ratio(c, BLACK)
  if with_white < 3.1 and with_black > with_white then
    return 'light'
  end
  return 'dark'
end

--- Quarto's `theme-contrast()` at a goal ratio: mix towards black on a light
--- background, or white on a dark one, one percent at a time.
local function theme_contrast(c, bg, goal)
  local mix_with = M.tone(bg) == 'light' and BLACK or WHITE
  local percent = 100
  local ratio = 0
  local result = nil
  while ratio < goal and percent > 0 do
    result = M.mix(c, mix_with, percent / 100)
    ratio = M.ratio(result, bg)
    percent = percent - 1
  end
  return result
end

--- `atelier-toward()`: black on a light background, white on a dark one.
local function toward(bg)
  return M.tone(bg) == 'light' and BLACK or WHITE
end

--- `atelier-contrast-on-tint()`.
local function contrast_on_tint(c, bg, alpha)
  local target = toward(bg)
  for step = 0, 100 do
    local candidate = mix_rendered(target, c, step / 100)
    if M.ratio(candidate, mix_rendered(candidate, bg, alpha)) >= 4.5 then
      return candidate
    end
  end
  return target
end

--- `atelier-contrast-all()`.
local function contrast_all(c, bgs, goal)
  local target = toward(bgs[1])
  local painted = {}
  for index, bg in ipairs(bgs) do
    painted[index] = rendered(bg)
  end
  for step = 0, 100 do
    local candidate = mix_rendered(target, c, step / 100)
    local passes = true
    for _, bg in ipairs(painted) do
      if M.ratio(candidate, bg) < goal then
        passes = false
      end
    end
    if passes then
      return candidate
    end
  end
  return target
end

--- `atelier-contrast()`.
local function contrast(c, bg, goal)
  return contrast_all(c, { bg }, goal)
end

--- `atelier-theme-contrast()`.
local function atelier_theme_contrast(c, bg)
  return contrast(theme_contrast(c, bg, 4.5), bg, 4.5)
end

--- `atelier-on()`.
local function on(fill, bg, fg, goal)
  local start = M.ratio(fg, fill) > M.ratio(bg, fill) and fg or bg
  local target = M.ratio(WHITE, fill) > M.ratio(BLACK, fill) and WHITE or BLACK
  local painted = rendered(fill)
  for step = 0, 100 do
    local candidate = mix_rendered(target, start, step / 100)
    if M.ratio(candidate, painted) >= goal then
      return candidate
    end
  end
  return target
end

--- `atelier-hue-border()` and `atelier-hue-ink()`.
local function hue_border(hue, bg)
  return M.mix(hue, bg, 0.6)
end

local function hue_ink(hue, fg, bg)
  return contrast(M.mix(hue, fg, 0.62), bg, 4.5)
end

-- ============================================================================
-- PRESETS
-- ============================================================================

--- The presets that `html/presets.scss` accepts.
--- @type table<string, boolean>
local PRESETS = { default = true, quarto = true, terminal = true }

--- The presets that paint both schemes with the dark bundle.
--- @type table<string, boolean>
local DARK_PINNED_PRESETS = { terminal = true }

--- The page background of each preset that paints the page, per scheme
--- (`$body-bg` in `html/presets.scss`).
--- @type table<string, table<string, string>>
local PRESET_PAGE_BACKGROUNDS = {
  quarto = { light = '#eef4fa', dark = '#0f1b2a' },
  terminal = { light = '#101216', dark = '#101216' },
}

--- The dark palette of `html/chrome.scss`.
local ATELIER_DARK = { bg = '#1b242e', fg = '#e8edf2', accent = '#7fa8c4' }

--- The Bootstrap colours that colour the callouts, and their defaults.
--- @type table<integer, { name: string, callout: string, default: string }>
local CALLOUT_HUES = {
  { name = 'blue', callout = 'note', default = '#0d6efd' },
  { name = 'green', callout = 'tip', default = '#198754' },
  { name = 'yellow', callout = 'warning', default = '#ffc107' },
  { name = 'orange', callout = 'caution', default = '#fd7e14' },
  { name = 'red', callout = 'important', default = '#dc3545' },
}

-- ============================================================================
-- RESOLUTION
-- ============================================================================

--- The brand values that `colour()` has warned about, so that each warns once.
--- @type table<string, boolean>
local warned = {}

--- A set of Sass variables, with `!default` semantics: a variable that holds
--- a value keeps it. Brand Bootstrap defaults can hold a value that is not a
--- colour, such as a Sass expression; `colour()` warns once and ignores it.
--- @param initial table<string, any>
--- @return table
local function variables(initial)
  local values = {}
  for name, value in pairs(initial) do
    values[name] = value
  end
  local env = {}
  function env.get(name)
    return values[name]
  end
  function env.set(name, value)
    values[name] = value
  end
  function env.default(name, value)
    if values[name] == nil then
      values[name] = value
    end
  end
  function env.colour(name)
    local value = values[name]
    if value == nil then
      return nil
    end
    local parsed = M.parse(value)
    if parsed == nil then
      local key = name .. '=' .. tostring(value)
      if not warned[key] then
        warned[key] = true
        log.log_warning(
          EXTENSION_NAME,
          'The brand value of "' .. name .. '" is not a colour that Atelier can read outside Sass: "' ..
          tostring(value) .. '". The formats without Sass ignore it. Use a hex, rgb() or named colour.'
        )
      end
      values[name] = nil
      return nil
    end
    values[name] = parsed
    return parsed
  end
  function env.number(name)
    return tonumber(values[name])
  end
  return env
end

--- Apply the preset branches of `html/presets.scss`.
--- @param v table The variables
--- @param preset string
--- @param scheme string
local function apply_preset(v, preset, scheme)
  if preset == 'quarto' then
    local brand_primary = v.colour('primary') ~= nil
    if scheme == 'dark' then
      if not brand_primary then
        v.default('atelier-chrome-accent', '#75aadb')
      end
      v.default('body-bg', PRESET_PAGE_BACKGROUNDS.quarto.dark)
      v.default('body-color', '#dbe6f0')
      v.default('primary', '#74aadb')
      v.default('atelier-chrome-bg', '#0a1524')
      v.default('atelier-chrome-fg', '#e8edf2')
      v.default('atelier-chrome-accent-soft-alpha', 0.16)
    else
      if not brand_primary then
        v.default('atelier-chrome-accent', '#ffffff')
        v.default('atelier-code-ink', '#325c83')
        v.default('link-color', '#406993')
      end
      v.default('body-bg', PRESET_PAGE_BACKGROUNDS.quarto.light)
      v.default('body-color', '#1f2a36')
      v.default('primary', '#47709a')
      v.default('atelier-chrome-bg', '#365f84')
      v.default('atelier-chrome-fg', '#ffffff')
      v.default('atelier-chrome-muted', '#f4f8fb')
      v.default('atelier-chrome-accent-soft-alpha', 0.12)
      if v.get('brand-yellow') == nil then
        v.default('yellow', '#b8860b')
      end
      if v.get('brand-orange') == nil then
        v.default('orange', '#e8590c')
      end
      if v.get('secondary') == nil then
        v.default('atelier-text-muted', '#55626f')
      end
    end
  elseif preset == 'terminal' then
    local green = '#7ee08a'
    local bg = '#16191e'
    local fg = '#d8dee9'
    v.default('body-bg', PRESET_PAGE_BACKGROUNDS.terminal[scheme])
    v.default('body-color', fg)
    v.default('primary', green)
    local terminal_hues = { blue = '#6cb6ff', green = green, red = '#ff7b72', orange = '#f0a35e', yellow = '#e3c45c' }
    for name, value in pairs(terminal_hues) do
      if v.get('brand-' .. name) == nil then
        v.default(name, value)
      end
    end
    v.default('atelier-chrome', 'dark')
    v.default('atelier-chrome-dark-bg', bg)
    v.default('atelier-chrome-dark-fg', fg)
    v.default('atelier-chrome-dark-accent', green)
    v.default('atelier-terminal-bg', bg)
    v.default('atelier-terminal-prompt', green)
  end
end

--- Apply the dark page fallback of `html/dark.scss`.
--- @param v table The variables
local function apply_dark_fallback(v)
  local bg = v.colour('body-bg')
  if bg ~= nil and M.tone(bg) ~= 'light' then
    return
  end
  local dark_bg = M.parse(ATELIER_DARK.bg)
  v.set('body-bg', dark_bg)
  v.set('body-color', M.parse(ATELIER_DARK.fg))
  local primary = v.colour('primary')
  if primary == nil then
    v.set('primary', M.parse(ATELIER_DARK.accent))
  else
    v.set('primary', atelier_theme_contrast(primary, dark_bg))
  end
  local link = v.colour('link-color')
  if link ~= nil then
    v.set('link-color', atelier_theme_contrast(link, dark_bg))
  end
end

--- Resolve the tokens from a set of inputs. This function does not read the
--- document, so a test can call it with any inputs.
--- @param inputs { scheme: string, preset: string|nil, variables: table<string, any> }
---   `variables` holds the Sass variables that the brand sets: its theme
---   colours (`body-bg`, `body-color`, `primary`, `secondary`, ...), its
---   palette as `brand-<name>`, and its Bootstrap defaults.
--- @return table<string, Colour>
function M.resolve(inputs)
  local scheme = inputs.scheme
  if scheme ~= 'light' and scheme ~= 'dark' then
    error('Atelier palette: the scheme must be light or dark, but was "' .. tostring(scheme) .. '".')
  end
  local v = variables(inputs.variables or {})
  local preset = inputs.preset or v.get('atelier-preset') or 'default'
  if not PRESETS[preset] then
    error('atelier-preset must be default, quarto, or terminal, but was ' .. tostring(preset) .. '.')
  end

  apply_preset(v, preset, scheme)
  if scheme == 'dark' then
    apply_dark_fallback(v)
  end

  -- html/chrome.scss: the brand palette names that colour the callouts.
  for _, hue in ipairs(CALLOUT_HUES) do
    if v.get('brand-' .. hue.name) ~= nil then
      v.default(hue.name, v.colour('brand-' .. hue.name))
    end
  end

  local chrome = v.get('atelier-chrome') or 'auto'
  if chrome ~= 'auto' and chrome ~= 'light' and chrome ~= 'dark' then
    error('$atelier-chrome must be auto, light, or dark, but was ' .. tostring(chrome) .. '.')
  end
  v.default('atelier-chrome-dark-bg', ATELIER_DARK.bg)
  v.default('atelier-chrome-dark-fg', ATELIER_DARK.fg)
  v.default('atelier-chrome-dark-accent', ATELIER_DARK.accent)
  v.default('atelier-chrome-light-bg', '#eef1f5')
  v.default('atelier-chrome-light-fg', '#1b242e')
  v.default('atelier-chrome-light-accent', '#1f5f80')

  local page_bg = v.colour('body-bg') or M.parse('#fff')
  local page_fg = v.colour('body-color') or M.parse('#212529')
  local page_accent = v.colour('primary') or M.parse('#0d6efd')
  local pinned = nil
  if chrome ~= 'auto' then
    pinned = {}
    for _, part in ipairs({ 'bg', 'fg', 'accent' }) do
      pinned[part] = v.colour('atelier-chrome-' .. chrome .. '-' .. part)
    end
  end

  local t = {}

  -- The chrome palette.
  local chrome_bg_source = pinned and pinned.bg or mix_rendered(page_bg, page_fg, 0.94)
  t['navbar-bg'] = v.colour('atelier-chrome-bg') or chrome_bg_source
  local chrome_fg_source = pinned and pinned.fg or page_fg
  t['navbar-fg'] = v.colour('atelier-chrome-fg') or atelier_theme_contrast(chrome_fg_source, t['navbar-bg'])
  t['navbar-surface'] = mix_rendered(t['navbar-bg'], t['navbar-fg'], 0.9)
  local soft_alpha = v.number('atelier-chrome-accent-soft-alpha') or 0.16
  local accent_source = v.colour('atelier-chrome-accent')
    or (pinned and pinned.accent)
    or page_accent
  t['navbar-accent'] = v.colour('atelier-chrome-accent')
    or contrast_on_tint(accent_source, t['navbar-surface'], soft_alpha)
  t['navbar-muted'] = v.colour('atelier-chrome-muted')
    or atelier_theme_contrast(M.mix(t['navbar-fg'], t['navbar-bg'], 0.65), t['navbar-surface'])
  t['navbar-accent-soft'] = with_alpha(t['navbar-accent'], soft_alpha)
  t['navbar-accent-mark'] = contrast(accent_source, t['navbar-surface'], 3)
  t['navbar-surface-strong'] = mix_rendered(t['navbar-bg'], t['navbar-fg'], 0.8)
  t['navbar-accent-fill'] = contrast_all(accent_source, { t['navbar-bg'], t['navbar-surface-strong'] }, 3)
  t['navbar-on-accent'] = on(t['navbar-accent-fill'], t['navbar-bg'], t['navbar-fg'], 4.5)
  t['navbar-border'] = with_alpha(t['navbar-fg'], 0.2)
  t['navbar-control-border'] = with_alpha(t['navbar-fg'], 0.55)

  -- The workshop bar.
  t['workshop-bar-bg'] = t['navbar-bg']
  t['workshop-bar-fg'] = t['navbar-fg']
  t['workshop-bar-muted'] = t['navbar-muted']
  t['workshop-bar-surface'] = t['navbar-surface']
  t['workshop-bar-track'] = mix_rendered(t['workshop-bar-bg'], t['workshop-bar-fg'], 0.8)
  t['workshop-bar-accent'] = contrast_all(accent_source, { t['workshop-bar-bg'], t['workshop-bar-track'] }, 3)
  t['workshop-bar-on-accent'] = on(t['workshop-bar-accent'], t['workshop-bar-bg'], t['workshop-bar-fg'], 4.5)
  t['workshop-bar-accent-text'] = t['navbar-accent']
  t['workshop-bar-border'] = t['navbar-border']

  -- The terminal block.
  local terminal = {
    bg = '#111418', fg = '#e6e8eb', muted = '#aeb6bf', border = '#2a3037',
    ['control-border'] = '#717a85', prompt = '#7cc4a3', dot = '#3a4048', highlight = '#1e252c',
  }
  for name, value in pairs(terminal) do
    t['terminal-' .. name] = v.colour('atelier-terminal-' .. name) or M.parse(value)
  end

  -- The page.
  t['bg'] = page_bg
  t['fg'] = page_fg
  t['surface'] = mix_rendered(page_bg, page_fg, 0.96)
  t['surface-strong'] = mix_rendered(page_bg, page_fg, 0.9)
  t['border'] = mix_rendered(page_fg, page_bg, 0.14)
  t['control-border'] = contrast(M.mix(page_fg, page_bg, 0.55), page_bg, 3)
  t['accent-soft'] = mix_rendered(page_accent, page_bg, 0.13)
  t['accent-ink'] = contrast(M.mix(page_accent, page_fg, 0.72), t['accent-soft'], 4.5)
  t['accent-mark'] = contrast(page_accent, page_bg, 3)
  t['accent-text'] = contrast(page_accent, page_bg, 4.5)
  t['accent-fill'] = t['accent-mark']
  t['on-accent'] = on(t['accent-fill'], page_bg, page_fg, 4.5)
  t['code-ink'] = v.colour('atelier-code-ink') or contrast(t['accent-text'], t['surface-strong'], 4.5)
  local heading_source = v.colour('headings-color') or page_fg
  t['heading'] = contrast(M.mix(heading_source, page_bg, 0.9), page_bg, 4.5)
  t['shadow'] = with_alpha(BLACK, 0.45)
  t['overlay'] = with_alpha(BLACK, 0.6)
  t['link'] = v.colour('link-color') or t['accent-text']
  t['link-hover'] = contrast(M.mix(page_fg, t['link'], 0.2), page_bg, 4.5)
  -- html/terminal.scss: the terminal decoration frames code in the control border.
  local decoration = v.get('atelier-terminal-decoration')
  if preset == 'terminal' and decoration ~= false and decoration ~= 'false' then
    t['code-border'] = t['control-border']
  else
    t['code-border'] = t['border']
  end
  -- `body-mix(95%)` of html/theme.scss: the landing cards and the band of a
  -- highlighted code line. Code blocks themselves sit on `surface`.
  local landing_surface = M.mix(page_bg, page_fg, 0.95)
  t['code-accent-mark'] = contrast_all(page_accent, { landing_surface, t['accent-soft'] }, 3)
  local muted_source = v.colour('secondary') or M.mix(page_fg, page_bg, 0.65)
  t['muted'] = v.colour('atelier-text-muted') or atelier_theme_contrast(muted_source, t['surface-strong'])

  -- html/theme.scss: the focus ring and the card link.
  t['focus'] = t['accent-ink']
  t['card-link'] = atelier_theme_contrast(t['link'], rendered(landing_surface))

  -- html/content.scss: the callouts.
  t['callout-border'] = hue_border(t['muted'], page_bg)
  t['callout-ink'] = hue_ink(t['muted'], page_fg, page_bg)
  for _, hue in ipairs(CALLOUT_HUES) do
    local colour = v.colour(hue.name) or M.parse(hue.default)
    t['callout-' .. hue.callout .. '-border'] = hue_border(colour, page_bg)
    t['callout-' .. hue.callout .. '-ink'] = hue_ink(colour, page_fg, page_bg)
  end

  return t
end

-- ============================================================================
-- BRAND
-- ============================================================================

-- Quarto's Lua `quarto.brand` API gives no access to the brand `defaults`, so
-- this reads the brand data from Quarto's internal `param('brand')`.
-- Upstream: https://github.com/quarto-dev/quarto-cli/issues/15383
-- Remove when: the minimum Quarto version includes the fix.

--- The brand of one scheme. A mode without its own brand uses the light
--- brand, as Quarto does.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return table|nil
local function brand_mode(scheme)
  if type(_G.param) ~= 'function' then
    return nil
  end
  local brand = _G.param('brand')
  return brand and (brand[scheme] or brand.light)
end

--- The brand of one scheme for its colours. Quarto adds a brand colour
--- layer to a bundle only when the brand has that mode.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return table|nil
local function brand_colour_mode(scheme)
  if type(_G.param) ~= 'function' then
    return nil
  end
  local brand = _G.param('brand')
  return brand and brand[scheme]
end

--- Read the Bootstrap defaults that the brand sets for one colour scheme.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return table The `defaults.bootstrap.defaults` table, empty when the brand sets none
function M.brand_defaults(scheme)
  local mode = brand_mode(scheme)
  local defaults = mode and mode.data and mode.data.defaults
  local bootstrap = defaults and defaults.bootstrap and defaults.bootstrap.defaults
  return type(bootstrap) == 'table' and bootstrap or {}
end

--- Turn a metadata value into a plain Lua value.
local function plain(value)
  if type(value) == 'table' or type(value) == 'userdata' then
    return pandoc.utils.stringify(value)
  end
  return value
end

--- The preset that the brand sets for one scheme, `default` when unset.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return string
function M.preset(scheme)
  local preset = plain(M.brand_defaults(scheme)['atelier-preset'])
  if preset == nil or preset == '' then
    return 'default'
  end
  return tostring(preset)
end

--- The Sass variables that the brand sets for one scheme: its Bootstrap
--- defaults first, then its colours, which win, as in the Sass layers.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return table<string, any>
local function brand_variables(scheme)
  local values = {}
  for name, value in pairs(M.brand_defaults(scheme)) do
    values[name] = plain(value)
  end
  local mode = brand_colour_mode(scheme)
  local processed = mode and mode.processedData
  local colours = processed and processed.color or {}
  local data_colour = mode and mode.data and mode.data.color or {}
  local palette = data_colour.palette or {}
  local theme_names = {
    background = 'body-bg', foreground = 'body-color', primary = 'primary', secondary = 'secondary',
    link = 'link-color',
  }
  for name, value in pairs(colours) do
    if palette[name] ~= nil then
      values['brand-' .. name:gsub('[^%w_-]+', '-')] = value
    end
  end
  for name, sass_name in pairs(theme_names) do
    if data_colour[name] ~= nil and colours[name] ~= nil then
      values[sass_name] = colours[name]
    end
  end
  local headings = processed and processed.typography and processed.typography.headings
  if type(headings) == 'table' and headings.color ~= nil then
    values['headings-color'] = colours[headings.color] or headings.color
  end
  return values
end

--- The scheme whose bundle paints the page: a preset that pins the page dark
--- paints both schemes with the dark bundle.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return string
function M.painted_scheme(scheme)
  if DARK_PINNED_PRESETS[M.preset(scheme)] then
    return 'dark'
  end
  return scheme
end

--- The page background that the bundle of one scheme is painted with, as
--- the brand or the preset writes it, so that a brand colour keeps its
--- spelling. The dark bundle replaces a missing or light-toned value with the
--- Atelier dark page colour, as `html/dark.scss` does.
--- @param scheme string The colour scheme, `light` or `dark`
--- A brand value that the module cannot read is kept, because Sass reads it.
--- @return string|nil The colour, or nil when the light bundle has none
function M.page_background(scheme)
  local background = plain(brand_variables(scheme)['body-bg'])
  if background == nil then
    local preset = PRESET_PAGE_BACKGROUNDS[M.preset(scheme)]
    background = preset and preset[scheme]
  end
  if scheme == 'dark' then
    if background == nil then
      return ATELIER_DARK.bg
    end
    local parsed = M.parse(background)
    if parsed ~= nil and M.tone(parsed) == 'light' then
      return ATELIER_DARK.bg
    end
  end
  return background
end

--- The resolved tokens of the document for one colour scheme.
--- @param scheme string The colour scheme, `light` or `dark`
--- @return table<string, Colour>
function M.tokens(scheme)
  local painted = M.painted_scheme(scheme)
  return M.resolve({ scheme = painted, preset = M.preset(painted), variables = brand_variables(painted) })
end

-- ============================================================================
-- SYNTAX HIGHLIGHTING
-- ============================================================================

--- The token styles of every highlighting theme, loaded on first use.
local highlighting_themes = nil

--- The token styles of the highlighting theme of one preset and scheme.
--- These are the colours of the `.theme` file. `html/highlighting.scss` also
--- holds each colour at 4.5:1 on the code backgrounds, so a caller that paints
--- code must do the same with the backgrounds it uses.
--- @param preset string `default`, `quarto` or `terminal`
--- @param scheme string `light` or `dark`
--- @return table<string, { color: string, bold: boolean, italic: boolean, underline: boolean }>
function M.highlighting(preset, scheme)
  highlighting_themes = highlighting_themes or dofile(HERE .. 'highlighting/tokens.lua')
  local styles = highlighting_themes[preset] and highlighting_themes[preset][scheme]
  if styles == nil then
    error('Atelier palette: no highlighting theme for preset "' .. tostring(preset) ..
      '" and scheme "' .. tostring(scheme) .. '".')
  end
  return styles
end

return M
