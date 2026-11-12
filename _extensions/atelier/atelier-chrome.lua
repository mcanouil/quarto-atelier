--- Atelier - Chrome Options Filter
--- @module "atelier-chrome"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Publish the page options that the chrome scripts read.
--- @description Writes one JSON block into the head of each HTML page. It
--- holds the version from `extensions.atelier.version` and the translated
--- labels: the `language` keys `atelier-<key>`, and the Quarto keys that the
--- scripts need.

--- Load modules
local meta_mod = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))

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
}

--- Version of the `site_libs` folder of the fonts, not of one package.
--- It changes when the vendored files change.
--- Vendored packages, all at 5.3.0 on npm:
--- `@fontsource/alegreya-sans`, `@fontsource-variable/fira-code`,
--- `@fontsource-variable/jetbrains-mono`.
local FONTS_VERSION = '5.3.0'

--- Font files that `fonts/fonts.css` refers to, relative to this file.
--- @type table<integer, { name: string, path: string }>
local FONT_FILES = {}
for _, file in ipairs({
  'alegreya-sans-latin-400-normal',
  'alegreya-sans-latin-400-italic',
  'alegreya-sans-latin-500-normal',
  'alegreya-sans-latin-700-normal',
  'fira-code-latin-wght-normal',
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

--- Add the font stylesheet and the font files that the presets use.
--- @return nil
local function add_fonts()
  quarto.doc.add_html_dependency({
    name = 'atelier-fonts',
    version = FONTS_VERSION,
    stylesheets = { 'fonts/fonts.css' },
    resources = FONT_FILES,
  })
end

--- Add the options block to the head.
--- @param meta table The document metadata
--- @return nil
local function publish_options(meta)
  if not quarto.doc.is_format('html') then
    return nil
  end
  -- The preset is a Sass default, which Lua cannot read, so every page ships the fonts. The browser downloads a face only when a stylesheet names it.
  add_fonts()
  local options = { labels = resolve_labels(), version = read_version(meta) }
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
  if not quarto.doc.is_format('html') then
    return nil
  end
  local spec = read_line_spec(block)
  if spec == nil then
    return nil
  end
  block.attributes['atelier-highlight'] = spec
  return block
end

return {
  { Meta = publish_options, CodeBlock = copy_line_spec },
}
