--- Atelier - Workshop Reveal.js Writer
--- @module "workshop/revealjs"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Write the workshop parts of a Reveal.js deck.
--- @description In workshop mode, the title slide gets the session duration
--- and the speakers, each with the photo of `extensions.atelier.speakers`,
--- and the blocks of `workshop/core.lua` become blocks with a head line, as
--- in HTML. A deck has no interaction for the objectives, so each objective
--- has a box glyph in place of a checkbox. A solution is a block too, in the
--- Veil group `solutions`, which this writer declares hidden, so the reader
--- shows the solutions with the Veil controls. A solution with its own
--- `.veil` class or `group` keeps them, and a deck that declares the group
--- keeps its own declaration. This writer runs before Veil, in the same
--- stage, so Veil finds the class. A `.terminal` code block becomes a
--- terminal in both modes, with its `$` prompts in the text.

local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local html = require(quarto.utils.resolve_path('workshop/html.lua'):gsub('%.lua$', ''))

local M = {}

--- The Veil group of the workshop solutions.
--- @type string
local GROUP = 'solutions'

--- The box glyph before each objective. It is decoration.
--- @type string
local BOX = '<span class="atelier-box" aria-hidden="true">☐</span> '

--- The text of a key of the `language` files.
--- @param key string The key without the `atelier-` prefix
--- @return string
local function language_text(key)
  local value = (quarto.doc.language or {})['atelier-' .. key]
  return type(value) == 'string' and value or ''
end

--- Declare the group of the solutions, hidden, unless the deck declares it.
--- Veil reads `extensions.veil.groups`.
--- @param meta table The document metadata
local function declare_group(meta)
  meta.extensions = meta.extensions or {}
  meta.extensions.veil = meta.extensions.veil or {}
  local groups = meta.extensions.veil.groups or pandoc.List({})
  for _, group in ipairs(groups) do
    if group.name ~= nil and pandoc.utils.stringify(group.name) == GROUP then
      return
    end
  end
  local label = language_text('solutions-title')
  groups:insert({
    name = pandoc.MetaString(GROUP),
    shown = false,
    label = pandoc.MetaString(label ~= '' and label or GROUP),
  })
  meta.extensions.veil.groups = groups
end

--- Set the duration of a workshop deck for the title slide, and declare the
--- group of the solutions.
--- @param meta table The document metadata
--- @param model table The page model of `core.page`
--- @return table|nil The changed metadata of a workshop deck, or nil
function M.publish(meta, model)
  if model.mode ~= core.MODE_WORKSHOP then
    return nil
  end
  declare_group(meta)
  local speakers = pandoc.List({})
  for _, speaker in ipairs(core.speakers(meta, model)) do
    speakers:insert({
      name = pandoc.MetaString(speaker.name),
      degrees = #speaker.degrees > 0 and pandoc.MetaString(table.concat(speaker.degrees, ', ')) or nil,
      affiliation = speaker.affiliation and pandoc.MetaString(speaker.affiliation) or nil,
      photo = speaker.photo and pandoc.MetaString(core.photo_uri(speaker.photo)) or nil,
      alt = pandoc.MetaString(speaker.alt),
    })
  end
  if #speakers > 0 then
    meta['atelier-speakers'] = speakers
  end
  core.apply_title_labels(meta, model.labels)
  if model.duration ~= nil then
    meta['atelier-duration'] = pandoc.MetaInlines({ pandoc.Str(core.format_duration(model.duration, model.labels)) })
    meta['atelier-duration-label'] = pandoc.MetaInlines({ pandoc.Str(language_text('duration')) })
  end
  return meta
end

--- Build a block: the head line and the body, with the markup of the HTML
--- writer, so the two formats share it.
--- @param div pandoc.Div The div of the author
--- @param class string The class of the div, such as `exercise`
--- @param icon string|nil The Bootstrap Icons name, which the deck draws as a mask
--- @param title string The title
--- @param time string|nil The duration text
--- @param body pandoc.Blocks The content
--- @return pandoc.Div
local function block(div, class, icon, title, time, body)
  return pandoc.Div(
    { html.block_head(icon, title, time), html.block_body(body) },
    html.block_attr(div, class)
  )
end

--- Put the box glyph before each objective.
--- @param list pandoc.BulletList
--- @return pandoc.BulletList
local function objective_list(list)
  local items = {}
  for _, item in ipairs(list.content) do
    local inlines, rest = core.objective_text(item)
    local first = pandoc.Inlines({ pandoc.RawInline('html', BOX) })
    first:extend(inlines)
    local blocks = pandoc.Blocks({ pandoc.Plain(first) })
    for position = rest, #item do
      blocks:insert(item[position])
    end
    items[#items + 1] = blocks
  end
  return pandoc.BulletList(items)
end

--- Turn the objectives div and the divs of `core.BLOCKS` into blocks, in
--- workshop mode only.
--- @param div pandoc.Div The div
--- @param model table The page model
--- @return pandoc.Div|nil
function M.div(div, model)
  if model.mode ~= core.MODE_WORKSHOP then
    return nil
  end
  if div.classes:includes('objectives') then
    local read = core.objectives(div, model)
    local body = pandoc.Blocks({})
    for position, content in ipairs(read.blocks) do
      body:insert(position == read.list and objective_list(content) or content)
    end
    return block(div, 'objectives', 'bullseye', read.title, read.time, body)
  end
  local kind = core.block_kind(div)
  if kind ~= nil then
    local read = core.block(div, kind, model)
    return block(div, kind, core.BLOCKS[kind], read.title, read.time, read.blocks)
  end
  return nil
end

--- Turn a workshop solution into a block in the Veil group `solutions`, so
--- Veil hides it until the reader shows the group. A solution with its own
--- `.veil` class keeps its group. A solution with a `sol-` identifier is a
--- cross-reference target: Quarto writes it, and it stays shown, as in HTML.
--- @param proof table The `Proof` node
--- @param model table The page model
--- @return pandoc.Div|nil
function M.proof(proof, model)
  local solution = core.solution(proof, model)
  if solution == nil then
    return nil
  end
  local title = proof.div.attributes.title or pandoc.utils.stringify(proof.name or '')
  if title == '' then
    title = language_text('solution-title')
  end
  local result = block(solution.div, 'solution', nil, title, nil, solution.div.content)
  -- Quarto moves the identifier of the div to the `Proof` node.
  result.identifier = solution.identifier
  if not result.classes:includes('veil') then
    result.classes:insert('veil')
    if result.attributes.group == nil then
      result.attributes.group = GROUP
    end
  end
  return result
end

--- The prefixes of Quarto cross-reference identifiers. A citation with
--- another identifier cites the bibliography.
--- @type table<string, boolean>
local CROSSREF = {
  fig = true, tbl = true, lst = true, sec = true, eq = true, thm = true, lem = true,
  cor = true, prp = true, cnj = true, def = true, exm = true, exr = true, sol = true,
  rem = true, nte = true, tip = true, wrn = true, imp = true, cau = true,
}

--- Tell whether a deck cites the bibliography, and whether it has a `#refs`
--- div of its own.
--- @param doc pandoc.Pandoc
--- @return boolean cites
--- @return boolean refs
local function references(doc)
  local cites, refs = false, false
  if doc.meta.bibliography == nil and doc.meta.references == nil then
    return cites, refs
  end
  doc:walk({
    Cite = function(cite)
      for _, citation in ipairs(cite.citations) do
        if not CROSSREF[citation.id:match('^(%a+)%-') or ''] then
          cites = true
        end
      end
    end,
    Div = function(div)
      if div.identifier == 'refs' then
        refs = true
      end
    end,
  })
  return cites, refs
end

--- Finish a workshop deck after its blocks: a references slide when the
--- deck cites the bibliography and has no `#refs` div, then the closing
--- slide, with the links, the licence and the CRediT table.
--- @param doc pandoc.Pandoc The document
--- @param model table The page model
--- @return pandoc.Pandoc|nil
function M.finish(doc, model)
  local closing = core.closing(doc.meta, model)
  if closing == nil then
    return nil
  end
  local cites, refs = references(doc)
  if cites and not refs then
    local title = (quarto.doc.language or {})['section-title-references']
    doc.blocks:insert(pandoc.Header(2, pandoc.Inlines(type(title) == 'string' and title or ''),
      pandoc.Attr('atelier-references', { 'unnumbered' })))
    doc.blocks:insert(pandoc.Div({}, pandoc.Attr('refs')))
  end
  doc.blocks:insert(pandoc.Header(2, closing.title, pandoc.Attr('atelier-closing', { 'atelier-closing', 'unnumbered' })))
  doc.blocks:extend(core.closing_parts(closing))
  local credit = core.credit(doc.meta, model)
  if credit ~= nil then
    doc.blocks:insert(pandoc.Div({
      pandoc.Para({ pandoc.Strong(pandoc.Inlines(model.labels['credit-title'])) }),
      core.credit_table(credit, model.labels),
    }, pandoc.Attr('', { 'atelier-credit' })))
  end
  return doc
end

--- Draw a `.terminal` code block as a terminal, in both modes. The prompts
--- stay in the text, as in Typst: the deck has no script that draws them.
--- @param code pandoc.CodeBlock The code block
--- @param model table The page model
--- @return pandoc.CodeBlock|nil
function M.code_block(code, model)
  if core.terminal(code) == nil then
    return nil
  end
  code.classes:insert('atelier-terminal')
  if (code.attributes['code-window-auto-label'] or '') == '' then
    code.attributes['code-window-auto-label'] = model.labels.terminal
  end
  return code
end

return M
