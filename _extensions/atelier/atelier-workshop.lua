--- Atelier - Workshop Options Filter
--- @module "atelier-workshop"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Publish the workshop mode, page duration, and blocks of a page.
--- @description Reads the page model with `workshop/core.lua` in every
--- format, then gives the page and its blocks to the writer of the format:
--- `workshop/html.lua` for HTML, `workshop/revealjs.lua` for Reveal.js, and
--- `workshop/typst.lua` for Typst. In the other formats, the blocks stay as
--- they are.

local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local html = require(quarto.utils.resolve_path('workshop/html.lua'):gsub('%.lua$', ''))
local typst = require(quarto.utils.resolve_path('workshop/typst.lua'):gsub('%.lua$', ''))
local revealjs = require(quarto.utils.resolve_path('workshop/revealjs.lua'):gsub('%.lua$', ''))

--- The page model that the block handlers read.
--- `publish_workshop` fills it in the first filter pass.
--- @type table|nil
local model = nil

--- The writer of the format, or nil when the format has none.
--- @type table|nil
local writer = nil

--- Choose the writer of the format.
--- In Quarto, `is_format('html')` is true for Reveal.js too.
--- @return table|nil The writer, or nil when the format has none
local function format_writer()
  if quarto.doc.is_format('revealjs') then
    return revealjs
  elseif quarto.doc.is_format('html') then
    return html
  elseif quarto.doc.is_format('typst') then
    return typst
  end
  return nil
end

--- Read the page model, then let the writer publish the page.
--- @param meta table The document metadata
--- @return table|nil The changed metadata, or nil
local function publish_workshop(meta)
  model = core.page(meta)
  writer = format_writer()
  if writer == nil then
    return nil
  end
  return writer.publish(meta, model)
end

--- Filter tables run one after the other: pandoc finishes the `Meta` pass
--- before the `Div` pass starts, so the model is complete when the block
--- handlers read it. One table gives no such order between element types.
--- A writer can also finish the document after the blocks.
return {
  { Meta = publish_workshop },
  {
    Div = function(div)
      return writer and writer.div(div, model)
    end,
    Proof = function(proof)
      return writer and writer.proof(proof, model)
    end,
    CodeBlock = function(block)
      return writer and writer.code_block(block, model)
    end,
  },
  {
    Pandoc = function(doc)
      return writer and writer.finish and writer.finish(doc, model)
    end,
  },
}
