--- Atelier - Logo
--- @module "logo"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Find the logo of a document, for every Atelier format.
--- @description A logo has a light image, a dark image and an alt text. The
--- logo of a document comes from the `logo` of the front matter, or else
--- from the `medium` or `small` logo of the brand. The logo of a website is
--- the logo of its navbar or of its sidebar, with `logo-alt`. A source with
--- one image gives that image for light and dark surfaces.

--- Load a module from a path relative to this file, so the module works for
--- a filter in any folder.
--- @param path string The path of the module, from the folder of this file
--- @return table
local function load_relative(path)
  local name = path:gsub('%.lua$', '')
  if not (debug and debug.getinfo) then
    return require(name)
  end
  local dir = debug.getinfo(1, 'S').source:sub(2):match('(.*[/\\])') or ''
  return require(dir .. name)
end

local meta_mod = load_relative('_vendor/quarto-lua-modules/metadata.lua')

local M = {}

--- Answer the text of a metadata value, or nil when it is empty.
--- @param value any
--- @return string|nil
local function text(value)
  if value == nil then
    return nil
  end
  local result = pandoc.utils.stringify(value)
  return result ~= '' and result or nil
end

--- Answer the path and the alt text of one image of a logo source: a path,
--- or a map with `path` and `alt`.
--- @param value any
--- @return string|nil path
--- @return string|nil alt
local function image(value)
  if value == nil then
    return nil, nil
  end
  if pandoc.utils.type(value) == 'table' and value.path ~= nil then
    return text(value.path), text(value.alt)
  end
  return text(value), nil
end

--- Answer the logo of a source in the `logo` shape: a path, or a map with
--- `light`, `dark` and `alt`, where each image is a path or a map with
--- `path` and `alt`.
--- @param value any
--- @param alt string|nil The alt text of the source, such as `logo-alt`
--- @return table|nil
local function from_source(value, alt)
  if value == nil then
    return nil
  end
  local light, light_alt, dark, dark_alt
  if pandoc.utils.type(value) == 'table' and (value.light ~= nil or value.dark ~= nil) then
    light, light_alt = image(value.light)
    dark, dark_alt = image(value.dark)
    alt = text(value.alt) or alt
  else
    light, light_alt = image(value)
  end
  light = light or dark
  dark = dark or light
  if light == nil then
    return nil
  end
  local shared = alt or light_alt or dark_alt or ''
  return {
    light = { path = light, alt = light_alt or shared },
    dark = { path = dark, alt = dark_alt or shared },
  }
end

--- Answer the logo of the brand, `medium` first, then `small`.
--- @return table|nil
local function from_brand()
  if quarto.brand == nil or quarto.brand.get_logo == nil then
    return nil
  end
  for _, size in ipairs({ 'medium', 'small' }) do
    local light = quarto.brand.get_logo('light', size)
    local dark = quarto.brand.get_logo('dark', size)
    if light ~= nil or dark ~= nil then
      return from_source({
        light = light and { path = light.path, alt = light.alt },
        dark = dark and { path = dark.path, alt = dark.alt },
      }, nil)
    end
  end
  return nil
end

--- The `website` map of the project, read once per render: false when the
--- document is not in a website.
--- @type table|false|nil
local website_cache

--- Answer the `website` map of the project. A filter does not get `website`
--- in the document metadata, so it comes from the project metadata that
--- Quarto writes for the render, merged with the profiles.
--- @return table|nil
local function project_website()
  if website_cache == nil then
    local project = meta_mod.get_project_metadata()
    website_cache = project ~= nil and project.website or false
  end
  return website_cache or nil
end

--- Answer true when the document belongs to a website.
--- @return boolean
function M.in_website()
  return project_website() ~= nil
end

--- Answer the logo of the navbar, or else of the sidebar, of a website,
--- with its `logo-alt`.
--- @return { light: { path: string, alt: string }, dark: { path: string, alt: string } }|nil
function M.site()
  local website = project_website()
  if website == nil then
    return nil
  end
  local navbar = website.navbar
  local found = from_source(navbar and navbar.logo, navbar and text(navbar['logo-alt']))
  if found ~= nil then
    return found
  end
  -- `website.sidebar` is one sidebar or a list of sidebars.
  local sidebars = website.sidebar
  if sidebars ~= nil and sidebars.logo == nil and #sidebars > 0 then
    for _, sidebar in ipairs(sidebars) do
      found = from_source(sidebar.logo, text(sidebar['logo-alt']))
      if found ~= nil then
        return found
      end
    end
    return nil
  end
  return from_source(sidebars and sidebars.logo, sidebars and text(sidebars['logo-alt']))
end

--- Answer the logo of the document: the front-matter `logo`, or else the
--- logo of the brand.
--- @param meta table The document metadata
--- @return { light: { path: string, alt: string }, dark: { path: string, alt: string } }|nil
function M.resolve(meta)
  return from_source(meta.logo, nil) or from_brand()
end

--- Write the logo into the metadata as `atelier-logo`, a map with the
--- `light` and `dark` paths and the `alt` text, for the templates.
--- @param meta table The document metadata
--- @param resolved table|nil The logo of `M.resolve`
--- @return table The metadata
function M.publish(meta, resolved)
  if resolved == nil then
    return meta
  end
  meta['atelier-logo'] = {
    light = resolved.light.path,
    dark = resolved.dark.path,
    alt = resolved.light.alt,
  }
  return meta
end

return M
