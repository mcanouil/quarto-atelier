--- Atelier - Logo
--- @module "logo"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Find the logo of a document, for every Atelier format.
--- @description A logo has a light image, a dark image and an alt text. The
--- logo comes from the first source that has one: the `logo` of the front
--- matter, then, in a website, the logo of the navbar or of the sidebar with
--- `logo-alt`, then the `medium` or `small` logo of the brand. A source with
--- one image gives that image for light and dark surfaces.

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

--- Answer the `website` map of the project configuration: `_quarto.yml`,
--- then the file of each active profile, the later file winning per key of
--- the navbar and of the sidebar. A filter does not get `website` in the
--- document metadata, so this reads the files.
--- @return table|nil
local function project_website()
  local project = quarto.project
  if project == nil or project.directory == nil then
    return nil
  end
  local files = { '_quarto.yml' }
  for _, profile in ipairs(project.profile or {}) do
    files[#files + 1] = '_quarto-' .. profile .. '.yml'
  end
  local website
  for _, name in ipairs(files) do
    local handle = io.open(pandoc.path.join({ project.directory, name }), 'r')
    if handle ~= nil then
      local yaml = handle:read('a')
      handle:close()
      local config = pandoc.read('---\n' .. yaml .. '\n...\n', 'markdown').meta
      if config.website ~= nil then
        website = website or {}
        for _, part in ipairs({ 'navbar', 'sidebar' }) do
          if config.website[part] ~= nil then
            website[part] = website[part] or {}
            for key, value in pairs(config.website[part]) do
              website[part][key] = value
            end
          end
        end
      end
    end
  end
  return website
end

--- Answer the logo of the navbar, or else of the sidebar, of a website,
--- with its `logo-alt`.
--- @param meta table The document metadata
--- @return { light: { path: string, alt: string }, dark: { path: string, alt: string } }|nil
function M.site(meta)
  local website = meta.website or project_website()
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

--- Answer the logo of the document.
--- @param meta table The document metadata
--- @param options { website: boolean }|nil `website` is true for a page in a website
--- @return { light: { path: string, alt: string }, dark: { path: string, alt: string } }|nil
function M.resolve(meta, options)
  local found = from_source(meta.logo, nil)
  if found ~= nil then
    return found
  end
  if options ~= nil and options.website then
    found = M.site(meta)
    if found ~= nil then
      return found
    end
  end
  return from_brand()
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
