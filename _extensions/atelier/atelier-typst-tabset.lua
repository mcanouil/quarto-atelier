--- Atelier - Typst Tabset Filter
--- @module "atelier-typst-tabset"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Write each tabset of a Typst document as headings.
--- @description Quarto has no Typst rendering for a tabset: its fallback
--- warns, and keeps the tab headings at their level in the source, which can
--- skip a level. This filter runs before Quarto reads the tabsets. Each tab
--- heading becomes a direct child of the heading before the tabset, and the
--- highest heading inside the tabs becomes a direct child of a tab heading.
--- A tab heading is never above level 2, so a tabset does not start a
--- chapter. A nested tabset moves with the tabset around it, then under the
--- heading before it.
--- The tabset keeps its identifier and its other classes on a plain Div.

--- Class that marks a tabset.
--- @type string
local TABSET_CLASS = 'panel-tabset'

--- Highest level that a tab heading can take.
--- @type integer
local MIN_TAB_LEVEL = 2

--- Level of the last heading seen, in document order.
--- @type integer
local parent_level = 0

--- Record the level of each heading, for the tabsets that follow it.
--- @param header pandoc.Header
local function track_heading(header)
  parent_level = header.level
end

--- Tell whether a block is a tabset.
--- @param block pandoc.Block
--- @return boolean
local function is_tabset(block)
  return block.t == 'Div' and block.classes:includes(TABSET_CLASS)
end

--- Call a function on each heading of a tabset, outside its nested tabsets.
--- @param blocks pandoc.Blocks
--- @param fn function Called with each pandoc.Header
--- @return pandoc.Blocks
local function each_own_heading(blocks, fn)
  return blocks:walk({
    traverse = 'topdown',
    Div = function(div)
      if is_tabset(div) then
        return div, false
      end
    end,
    Header = function(header)
      return fn(header)
    end,
  })
end

--- Move the headings of a tabset under the heading before it, and remove
--- the tabset class.
--- @param div pandoc.Div
--- @return pandoc.Div|nil
local function flatten_tabset(div)
  if not is_tabset(div) then
    return nil
  end
  local first = div.content:find_if(function(block) return block.t == 'Header' end)
  if first == nil then
    return nil
  end
  local tab_level = first.level
  local new_tab_level = math.max(parent_level + 1, MIN_TAB_LEVEL)
  local min_content_level = nil
  each_own_heading(div.content, function(header)
    if header.level ~= tab_level then
      min_content_level = math.min(min_content_level or header.level, header.level)
    end
  end)
  local content_shift = min_content_level and (new_tab_level + 1 - min_content_level) or 0
  div.content = each_own_heading(div.content, function(header)
    if header.level == tab_level then
      header.level = new_tab_level
    else
      header.level = header.level + content_shift
    end
    return header
  end)
  div.classes = div.classes:filter(function(class) return class ~= TABSET_CLASS end)
  return div
end

return {
  {
    traverse = 'topdown',
    Header = track_heading,
    Div = flatten_tabset,
  },
}
