--- Atelier - HTML Title Logo Filter
--- @module "atelier-html-logo"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Put the logo above the title of a standalone HTML document.
--- @description A document outside a website has no navbar, so the logo
--- goes into the title block. Quarto picks one of several title block
--- partials (default, banner, manuscript), so the filter writes the logo at
--- the start of the body, hidden, and `html/scripts/title-block.html` moves
--- it above the title. In a website, the navbar or the sidebar carries the
--- logo, and this filter does nothing. A document with no title has no title
--- block, so it gets no logo.

local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))
local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))

--- Write the logo of a standalone HTML document at the start of the body.
--- @param meta table
--- @return nil
local function publish(meta)
  if not quarto.doc.is_format('html') or meta.title == nil or logo.in_website() then
    return nil
  end
  local resolved = logo.resolve(meta)
  if resolved == nil then
    return nil
  end
  local image = function(entry, class)
    return string.format('<img src="%s" alt="%s" class="%s">', str.escape_attribute(entry.path), str.escape_attribute(entry.alt), class)
  end
  quarto.doc.include_text('before-body', table.concat({
    '<div class="atelier-title-logo" hidden>',
    image(resolved.light, 'light-content'),
    image(resolved.dark, 'dark-content'),
    '</div>',
  }))
  return nil
end

return {
  { Meta = publish },
}
