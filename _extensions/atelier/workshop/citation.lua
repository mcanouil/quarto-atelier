--- Atelier - Workshop Citation
--- @module "workshop/citation"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief The "cite as" entry of a page, from its `citation` key.
--- @description Builds the CSL item of the page from the `citation` key and
--- the page metadata, as Quarto does for its HTML appendix
--- (`src/quarto-core/attribution/document.ts`), then formats it with
--- citeproc and the page `csl`, so the PDF shows the same entry as the HTML
--- appendix. This module writes no output.

local M = {}

--- The id of the CSL item of the page.
--- @type string
local ITEM_ID = 'atelier-self'

--- The CSL type when `citation.type` is not set, as Quarto's HTML appendix.
--- @type string
local DEFAULT_TYPE = 'webpage'

--- Keys of `citation` that hold names.
--- @type table<string, boolean>
local NAME_KEYS = {}
for _, key in ipairs({
  'author', 'editor', 'chair', 'collection-editor', 'compiler', 'composer',
  'container-author', 'contributor', 'curator', 'director',
  'editorial-director', 'executive-producer', 'guest', 'host', 'interviewer',
  'illustrator', 'narrator', 'organizer', 'original-author', 'performer',
  'producer', 'recipient', 'reviewed-author', 'script-writer',
  'series-creator', 'translator',
}) do
  NAME_KEYS[key] = true
end

--- Keys of `citation` that hold dates.
--- @type table<string, boolean>
local DATE_KEYS = {
  ['issued'] = true,
  ['available-date'] = true,
  ['accessed'] = true,
  ['event-date'] = true,
  ['original-date'] = true,
  ['submitted'] = true,
}

--- Keys of `citation` that CSL writes in capitals, by their lower-case form.
--- @type table<string, string>
local UPPER_KEYS = {
  doi = 'DOI',
  url = 'URL',
  isbn = 'ISBN',
  issn = 'ISSN',
  pmcid = 'PMCID',
  pmid = 'PMID',
}

--- Keys of `citation` that are not CSL fields.
--- @type table<string, boolean>
local SKIP_KEYS = {
  ['id'] = true,
  ['pdf-url'] = true,
  ['abstract-url'] = true,
  ['eissn'] = true,
}

--- A metadata value as plain Lua data for CSL JSON: text for inlines, a
--- boolean, an array for a list, and a table for a map.
--- @param value any A metadata value
--- @return any
local function plain(value)
  local kind = pandoc.utils.type(value)
  if kind == 'boolean' or kind == 'string' or kind == 'number' then
    return value
  elseif kind == 'List' then
    local items = {}
    for _, item in ipairs(value) do
      items[#items + 1] = plain(item)
    end
    return items
  elseif kind == 'table' then
    local map = {}
    for key, item in pairs(value) do
      map[key] = plain(item)
    end
    return map
  end
  return pandoc.utils.stringify(value)
end

--- One CSL name: the given and the family name of a name map, or a name
--- written as text, split at its first space as Quarto does.
--- @param value any A name: text, a name map, or an author with a `name`
--- @return table|nil
local function csl_name(value)
  if pandoc.utils.type(value) == 'table' and value.name ~= nil then
    value = value.name
  end
  if pandoc.utils.type(value) == 'table' then
    if value.family ~= nil or value.given ~= nil then
      return {
        family = value.family and pandoc.utils.stringify(value.family) or nil,
        given = value.given and pandoc.utils.stringify(value.given) or nil,
      }
    end
    if value.literal ~= nil then
      return { literal = pandoc.utils.stringify(value.literal) }
    end
    return nil
  end
  local text = pandoc.utils.stringify(value)
  local given, family = text:match('^(%S+)%s+(.+)$')
  if given == nil then
    return text ~= '' and { family = text } or nil
  end
  return { given = given, family = family }
end

--- The CSL names of a name value: one name or a list of names.
--- @param value any The value of a name key
--- @return table[]|nil The names, or nil when no name has a text
local function csl_names(value)
  local list = pandoc.utils.type(value) == 'List' and value or { value }
  local names = {}
  for _, item in ipairs(list) do
    local name = csl_name(item)
    if name ~= nil then
      names[#names + 1] = name
    end
  end
  return #names > 0 and names or nil
end

--- A CSL date from a date map that has `date-parts`, or from an ISO date
--- such as `2026`, `2026-03` or `2026-03-04`.
--- @param value any The value of a date key
--- @return table|nil
local function csl_date(value)
  local parts = {}
  if pandoc.utils.type(value) == 'table' and value['date-parts'] ~= nil then
    for _, part in ipairs(value['date-parts'][1] or {}) do
      parts[#parts + 1] = tonumber(pandoc.utils.stringify(part))
    end
  else
    for part in pandoc.utils.stringify(value):gmatch('%d+') do
      parts[#parts + 1] = tonumber(part)
      if #parts == 3 then break end
    end
  end
  if #parts == 0 then
    return nil
  end
  return { ['date-parts'] = { parts } }
end

--- The CSL item of the page: the keys of `citation`, with the title, the
--- authors, the language and the DOI of the page where `citation` has none.
--- @param meta pandoc.Meta The document metadata
--- @return table|nil The CSL item, or nil when `citation` is absent or false
function M.item(meta)
  local citation = meta.citation
  if citation == nil or citation == false then
    return nil
  end
  if pandoc.utils.type(citation) ~= 'table' then
    citation = {}
  end
  local item = { id = ITEM_ID }
  for key, value in pairs(citation) do
    if NAME_KEYS[key] then
      item[key] = csl_names(value)
    elseif DATE_KEYS[key] then
      item[key] = csl_date(value)
    elseif not SKIP_KEYS[key] then
      item[UPPER_KEYS[key:lower()] or key] = plain(value)
    end
  end
  item.type = item.type or DEFAULT_TYPE
  if item.title == nil and meta.title ~= nil then
    item.title = pandoc.utils.stringify(meta.title)
  end
  if item.author == nil then
    item.author = csl_names(meta['by-author'] or {})
  end
  if item.language == nil and meta.lang ~= nil then
    item.language = pandoc.utils.stringify(meta.lang)
  end
  if item.DOI == nil and meta.doi ~= nil then
    item.DOI = pandoc.utils.stringify(meta.doi)
  end
  if item.abstract == nil and meta.abstract ~= nil then
    item.abstract = pandoc.utils.stringify(meta.abstract)
  end
  if item.page == nil and item['page-first'] ~= nil then
    item.page = item['page-first'] .. (item['page-last'] and (' - ' .. item['page-last']) or '')
  end
  return item
end

--- The "cite as" entry of the page: the CSL item formatted by citeproc with
--- the page `csl`, or the default style of citeproc. A number or a label in
--- the margin of the entry is left out, as Quarto's HTML appendix does.
--- @param meta pandoc.Meta The document metadata
--- @return pandoc.Inlines|nil The entry, or nil when the page has no citation
function M.text(meta)
  local item = M.item(meta)
  if item == nil then
    return nil
  end
  local doc = pandoc.read(pandoc.json.encode({ item }), 'csljson')
  if meta.csl ~= nil then
    doc.meta.csl = meta.csl
  end
  local entry
  pandoc.utils.citeproc(doc).blocks:walk({
    Div = function(div)
      if entry == nil and div.classes:includes('csl-entry') then
        entry = div
      end
    end,
  })
  if entry == nil or entry.content[1] == nil then
    return nil
  end
  local inlines = pandoc.utils.blocks_to_inlines(entry.content)
  return inlines:walk({
    Span = function(span)
      if span.classes:includes('csl-left-margin') then
        return {}
      elseif span.classes:includes('csl-right-inline') then
        return span.content
      end
    end,
  })
end

return M
