--- Atelier - HTML Title Logo Filter
--- @module "atelier-html-logo"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Put the logo above the title of a standalone HTML document.
--- @description A document outside a website has no navbar, so the logo
--- goes into the title block. Quarto picks one of several title block
--- partials, so the filter writes the logo as the metadata
--- `atelier-title-logo`, and `html/title-block.html` puts it above the title,
--- in the default and the banner title block, with no script. In a website,
--- the navbar or the sidebar carries the logo, and this filter does nothing. A document with no title, or with
--- `title-block-style: none`, has no title block, so it gets no logo.

local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))

--- Write the logo of a standalone HTML document into the metadata.
--- @param meta table
--- @return nil
local function publish(meta)
  local no_title_block = meta.title == nil or pandoc.utils.stringify(meta['title-block-style'] or '') == 'none'
  if not quarto.doc.is_format('html') or no_title_block or logo.in_website() then
    return nil
  end
  local resolved = logo.resolve(meta)
  if resolved == nil then
    return nil
  end
  meta['atelier-title-logo'] = pandoc.MetaInlines({
    pandoc.RawInline('html', logo.images_html(resolved, 'light-content', 'dark-content')),
  })
  return meta
end

return {
  { Meta = publish },
}
