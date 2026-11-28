--- Atelier - Chrome Options Filter
--- @module "atelier-chrome"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Publish the page options that the chrome scripts read.
--- @description Writes one JSON block into the head of each HTML page. It
--- holds the version from `extensions.atelier.version` and the translated
--- labels: the `language` keys `atelier-<key>`, and the Quarto keys that the
--- scripts need. It also marks a hero whose image is wide, so the stylesheet
--- can put the image below the text.

--- Load modules
local meta_mod = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))
local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))
local palette = require(quarto.utils.resolve_path('palette.lua'):gsub('%.lua$', ''))

--- Keys of the labels, without the `atelier-` prefix, in output order.
--- The text comes from the `language` files.
--- @type table<integer, string>
local LABELS = {
  'announcement-info',
  'announcement-warning',
  'announcement-danger',
  'announcement-success',
  'announcement-notice',
  'announcement-region',
  'toc-reading-time',
  'toc-updated',
  'toc-copy-link',
  'toc-link-copied',
  'table-scroll',
  'previous',
  'next',
  'site-banner',
  'listing-filters',
  'page-metadata',
  'home',
  'logo-link',
  'footnote-back',
  'code-window',
  'version',
}

--- Version of the `site_libs` folder of the fonts, not of one package.
--- It changes when the vendored files change.
--- Sources: static files of `googlefonts/atkinson-hyperlegible-next`,
--- `googlefonts/atkinson-hyperlegible-next-mono`, and `undercasetype/Fraunces`,
--- and `@fontsource-variable/jetbrains-mono` 5.3.0 on npm.
local FONTS_VERSION = '6.0.0'

--- Font files that `fonts/fonts.css` refers to, relative to this file.
--- @type table<integer, { name: string, path: string }>
local FONT_FILES = {}
for _, file in ipairs({
  'AtkinsonHyperlegibleNext-Regular',
  'AtkinsonHyperlegibleNext-Italic',
  'AtkinsonHyperlegibleNext-Bold',
  'AtkinsonHyperlegibleNext-BoldItalic',
  'AtkinsonHyperlegibleMono-Regular',
  'AtkinsonHyperlegibleMono-Italic',
  'AtkinsonHyperlegibleMono-Bold',
  'Fraunces72ptSuperSoft-SemiBold',
  'Fraunces72ptSuperSoft-Bold',
  'jetbrains-mono-latin-wght-normal',
  'jetbrains-mono-latin-wght-italic',
}) do
  table.insert(FONT_FILES, { name = file .. '.woff2', path = 'fonts/' .. file .. '.woff2' })
end

--- Read the version from `extensions.atelier.version`.
--- @param meta table The document metadata
--- @return string|nil The version, or nil when it is unset or empty
local function read_version(meta)
  local options = meta_mod.get_extension_config(meta, 'atelier')
  if type(options) ~= 'table' or options.version == nil then
    return nil
  end
  local version = pandoc.utils.stringify(options.version)
  if version == '' then
    return nil
  end
  return version
end

--- Keys that Quarto translates, passed on under their own name.
--- @type table<integer, string>
local QUARTO_KEYS = {
  'toggle-dark-mode',
  'toggle-navigation',
  'search-label',
  'navigation-site-label',
  'toc-title-website',
}

--- Read one `language` value, or an empty string when it is missing.
--- @param language table The `language` table of the document
--- @param key string The full key
--- @return string The text
local function language_text(language, key)
  local value = language[key]
  if type(value) == 'string' then
    return value
  end
  return ''
end

--- Resolve every label from the `language` files and overrides.
--- @return table<string, string> The label text by key
local function resolve_labels()
  local language = quarto.doc.language or {}
  local labels = {}
  for _, key in ipairs(LABELS) do
    labels[key] = language_text(language, 'atelier-' .. key)
  end
  for _, key in ipairs(QUARTO_KEYS) do
    labels[key] = language_text(language, key)
  end
  return labels
end

--- Font files to preload, by the base font of a preset: the faces of the
--- body text in the announcement bar and the navbar.
--- @type table<string, table<integer, string>>
local PRELOAD_FILES = {
  ['Atkinson Hyperlegible Next'] = { 'AtkinsonHyperlegibleNext-Regular', 'AtkinsonHyperlegibleNext-Bold' },
  ['JetBrains Mono'] = { 'jetbrains-mono-latin-wght-normal' },
}

--- Preload links for the base font of the preset of each colour scheme,
--- unless the brand sets a base font for that scheme. A face that arrives
--- after the first paint can change where the announcement text wraps, which
--- changes the height of the header and moves the page content.
--- Quarto writes the path of a dependency stylesheet relative to each page,
--- and its `rel` attribute is replaced by the `rel` of `attribs`.
--- @return table<integer, table> The `stylesheets` entries of the preloads
local function preload_stylesheets()
  local entries = {}
  local seen = {}
  for _, scheme in ipairs({ 'light', 'dark' }) do
    local brand = quarto.brand.has_mode(scheme) and quarto.brand.get_typography(scheme, 'base')
    local fonts = palette.PRESET_FONTS[palette.preset(palette.painted_scheme(scheme))] or {}
    local files = not (brand and brand.family) and PRELOAD_FILES[fonts.base] or {}
    for _, file in ipairs(files) do
      if not seen[file] then
        seen[file] = true
        table.insert(entries, {
          name = file .. '.woff2',
          path = 'fonts/' .. file .. '.woff2',
          attribs = { rel = 'preload', as = 'font', type = 'font/woff2', crossorigin = '' },
        })
      end
    end
  end
  return entries
end

--- Add the font stylesheet and the font files that the presets use.
--- @param preload boolean Whether to preload the base font of the preset
--- @return nil
local function add_fonts(preload)
  local stylesheets = preload and preload_stylesheets() or {}
  table.insert(stylesheets, 'fonts/fonts.css')
  quarto.doc.add_html_dependency({
    name = 'atelier-fonts',
    version = FONTS_VERSION,
    stylesheets = stylesheets,
    resources = FONT_FILES,
  })
end

--- Add the options block to the head.
--- @param meta table The document metadata
--- @return nil
local function publish_options(meta)
  if quarto.doc.is_format('revealjs') then
    add_fonts(false)
    return nil
  end
  if not quarto.doc.is_format('html') then
    return nil
  end
  -- Every page ships the font files of all presets, because a project can also set the preset in its own Sass, which Lua cannot read. The browser downloads a face only when a stylesheet names it or a preload link asks for it.
  add_fonts(true)
  local options = { labels = resolve_labels(), version = read_version(meta) }
  -- With a light and a dark logo, Quarto drops `logo-alt` and writes `alt=""`
  -- on both images. The options carry each logo with its `logo-alt` for
  -- `a11y-fixes.html`.
  -- Upstream: https://github.com/quarto-dev/quarto-cli/issues/15165
  -- Remove when: the minimum Quarto version includes the fix.
  local logos = {}
  for _, found in ipairs(logo.site_logos()) do
    if found.light.alt ~= '' then
      logos[#logos + 1] = { light = found.light.path, dark = found.dark.path, alt = found.light.alt }
    end
  end
  if #logos > 0 then
    options.logos = logos
  end
  local json = quarto.json.encode(options):gsub('</', '<\\/')
  quarto.doc.include_text(
    'in-header',
    '<script type="application/json" id="atelier-options">' .. json .. '</script>'
  )
  return nil
end

--- Read the line spec of a block as Code Window reads it.
--- `code-window-lines` comes first. `code-line-numbers` is used when it holds
--- a line spec and not `true` or `false`.
--- @param block table The code block
--- @return string|nil The line spec, or nil when the block has none
local function read_line_spec(block)
  local spec = block.attributes['code-window-lines']
  if spec ~= nil and spec ~= '' then
    return spec
  end
  spec = block.attributes['code-line-numbers']
  if spec == nil or spec == '' or spec == 'true' or spec == 'false' then
    return nil
  end
  return spec
end

--- Copy the line spec of a block to `atelier-highlight`.
--- Quarto documents line highlighting for Reveal.js only, so in HTML it keeps
--- just the `number-lines` class. The code-blocks script marks the lines.
--- @param block table The code block
--- @return table|nil The block with the attribute, or nil when it has no line spec
local function copy_line_spec(block)
  if not quarto.doc.is_format('html') or quarto.doc.is_format('revealjs') then
    return nil
  end
  local spec = read_line_spec(block)
  if spec == nil then
    return nil
  end
  block.attributes['atelier-highlight'] = spec
  return block
end

--- The width-to-height ratio from which a hero image counts as wide.
--- A social card is about 1.9.
--- @type number
local WIDE_RATIO = 1.5

--- Read a size attribute in pixels, such as `600` or `600px`.
--- @param value string|nil
--- @return number|nil The size, or nil for a missing or relative size
local function pixels(value)
  if value == nil then
    return nil
  end
  return tonumber((value:gsub('px$', '')))
end

--- Tell whether an image has a wide shape from its `width` and `height`.
--- @param image table The image
--- @return boolean
local function is_wide(image)
  local width = pixels(image.attributes['width'])
  local height = pixels(image.attributes['height'])
  return width ~= nil and height ~= nil and height > 0 and width / height >= WIDE_RATIO
end

--- Mark a hero whose figure holds a wide image with `atelier-wide-figure`,
--- and the wide image with `atelier-wide-image`. The stylesheet puts that
--- figure below the text, and the wide image at the full width of the hero,
--- as the text of a wide image such as a social card is only readable at
--- that size. Other images in the figure keep their cap.
--- @param div table The div
--- @return table|nil The marked hero, or nil when nothing changes
local function mark_wide_hero(div)
  if not quarto.doc.is_format('html') or quarto.doc.is_format('revealjs') or not div.classes:includes('atelier-hero') then
    return nil
  end
  local wide = false
  for index, block in ipairs(div.content) do
    if block.t == 'Div' and block.classes:includes('atelier-hero-figure') then
      div.content[index] = block:walk({
        Image = function(image)
          if is_wide(image) then
            wide = true
            image.classes:insert('atelier-wide-image')
            return image
          end
        end,
      })
    end
  end
  if not wide then
    return nil
  end
  div.classes:insert('atelier-wide-figure')
  return div
end

return {
  { Meta = publish_options, CodeBlock = copy_line_spec, Div = mark_wide_hero },
}
