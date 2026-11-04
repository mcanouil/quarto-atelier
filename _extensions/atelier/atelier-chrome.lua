--- Atelier - Chrome Options Filter
--- @module "atelier-chrome"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Publish the page options that the chrome scripts read.
--- @description Writes one JSON block into the head of each HTML page. It
--- holds the version from `extensions.atelier.version` and the translated
--- labels. A label is the default text, or the `language` key `atelier-<key>`
--- when the project or the page sets one.

--- Load modules
local meta_mod = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))

--- Labels and their default text, in output order.
--- @type table<integer, { key: string, default: string }>
local LABELS = {
  { key = 'search', default = 'Search' },
  { key = 'announcement-info', default = 'Info' },
  { key = 'announcement-warning', default = 'Warning' },
  { key = 'announcement-danger', default = 'Danger' },
  { key = 'announcement-success', default = 'Success' },
  { key = 'announcement-notice', default = 'Notice' },
  { key = 'announcement-region', default = 'Announcement' },
  { key = 'announcement-dismiss', default = 'Dismiss the announcement' },
  { key = 'toc-reading-time', default = '{n} min read' },
  { key = 'toc-updated', default = 'Updated {date}' },
  { key = 'toc-copy-link', default = 'Copy link' },
  { key = 'toc-link-copied', default = 'Link copied' },
}

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

--- Resolve every label, taking a non-empty `language` override over the default.
--- @return table<string, string> The label text by key
local function resolve_labels()
  local language = quarto.doc.language or {}
  local labels = {}
  for _, label in ipairs(LABELS) do
    local value = language['atelier-' .. label.key]
    if type(value) == 'string' and value ~= '' then
      labels[label.key] = value
    else
      labels[label.key] = label.default
    end
  end
  return labels
end

--- Add the options block to the head.
--- @param meta table The document metadata
--- @return nil
local function publish_options(meta)
  if not quarto.doc.is_format('html') then
    return nil
  end
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
