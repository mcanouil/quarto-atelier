--- Atelier - Workshop Reveal.js Writer
--- @module "workshop/revealjs"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Write the workshop parts of a Reveal.js deck.
--- @description The title slide gets the authors, each with the photo of
--- the native author key `photo`, and in workshop mode the session duration
--- and the workshop labels. The blocks of `workshop/core.lua` become blocks
--- with a head line, as in HTML. A deck has no interaction for the
--- objectives, so each objective has a box glyph in place of a checkbox. An
--- answer is a block too, in the Veil group `answers`, which this writer
--- declares hidden, so the reader shows the answers with the Veil controls.
--- An answer with its own `.veil` class or `group` keeps them, and a deck
--- that declares the group keeps its own declaration. Quarto's own solutions
--- stay as Quarto writes them. This writer runs before Veil, in the same
--- stage, so Veil finds the class. A `.terminal` code block becomes a
--- terminal in both modes, with its `$` prompts in the text.

local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local html = require(quarto.utils.resolve_path('workshop/html.lua'):gsub('%.lua$', ''))

local M = {}

--- The Veil group of the answers.
--- @type string
local GROUP = 'answers'

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

--- Declare the group of the answers, hidden, unless the deck declares it.
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
  local label = language_text('answers-title')
  groups:insert({
    name = pandoc.MetaString(GROUP),
    shown = false,
    label = pandoc.MetaString(label ~= '' and label or GROUP),
  })
  meta.extensions.veil.groups = groups
end

--- Set the authors of the title slide in every mode. In workshop mode, also
--- set the workshop labels and the duration.
--- @param meta table The document metadata
--- @param model table The page model of `core.page`
--- @return table The changed metadata
function M.publish(meta, model)
  local authors = core.authors(meta, model.labels)
  if #authors > 0 then
    meta['atelier-authors'] = core.authors_meta(authors, model.labels, core.photo_uri)
  end
  if model.mode ~= core.MODE_WORKSHOP then
    return meta
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

--- Turn an answer into a block in the Veil group `answers`, so Veil hides
--- it until the reader shows the group. An answer with its own `.veil` class
--- keeps its group.
--- The head line shows the own title of the answer, else "Answer".
--- @param answer table The answer of `core.answer`
--- @param model table The page model
--- @return pandoc.Div
local function answer_block(answer, model)
  local result = block(answer.div, 'answer', nil, answer.title or language_text('answer-title'), nil, answer.blocks)
  if not result.classes:includes('veil') then
    result.classes:insert('veil')
    if result.attributes.group == nil then
      result.attributes.group = GROUP
      model.answers_used = true
    end
  end
  return result
end

--- Turn the objectives div, the answer div and the divs of `core.BLOCKS`
--- into blocks.
--- @param div pandoc.Div The div
--- @param model table The page model
--- @return pandoc.Div|nil
function M.div(div, model)
  local answer = core.answer(div, model)
  if answer ~= nil then
    return answer_block(answer, model)
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

--- Make the heading of a part of the end matter. The deck has `slide-level: 2`,
--- so a part on the closing slide has an `h3`, and a part on a slide of its
--- own has an `h2` slide title.
--- @param level integer The heading level
--- @param id string The heading identifier
--- @param title string The resolved title
--- @return pandoc.Header
local function end_heading(level, id, title)
  return pandoc.Header(level, pandoc.Inlines(title), pandoc.Attr(id, { 'unnumbered' }))
end

--- Build the funding part: its heading, then the statements and the awards.
--- @param funding table The funding of `core.funding`
--- @param model table The page model
--- @param level integer The heading level
--- @return pandoc.Blocks
local function funding_part(funding, model, level)
  local blocks = pandoc.Blocks({ end_heading(level, 'atelier-funding-title', model.labels['funding-title']) })
  blocks:insert(pandoc.Div(core.funding_blocks(funding, model.labels), pandoc.Attr('', { 'atelier-funding' })))
  return blocks
end

--- Build the CRediT part: its heading, then the table.
--- @param credit table The table of `core.credit`
--- @param model table The page model
--- @param level integer The heading level
--- @return pandoc.Blocks
local function credit_part(credit, model, level)
  local blocks = pandoc.Blocks({ end_heading(level, 'atelier-credit-title', model.labels['credit-title']) })
  blocks:insert(pandoc.Div({ core.credit_table(credit, model.labels) }, pandoc.Attr('', { 'atelier-credit' })))
  return blocks
end

--- Finish a deck after its blocks: declare the group of the answers when the
--- deck has answers, then add the end slides.
--- With a closing: a references slide when the deck cites the bibliography and
--- has no `#refs` div, then the closing slide with the closing parts, the
--- funding and the CRediT table, so the closing is the last slide.
--- Without a closing: one end slide (`#atelier-end-slide`) for the funding and
--- the CRediT table, then the references slide. A deck with no closing, no
--- funding and no roles gets no slide from Atelier.
--- @param doc pandoc.Pandoc The document
--- @param model table The page model
--- @return pandoc.Pandoc|nil
function M.finish(doc, model)
  -- Only a deck with answers declares their group, so Veil does not warn
  -- about a declared group that no element uses.
  if model.answers_used then
    declare_group(doc.meta)
  end
  local closing = core.closing(doc.meta, model)
  local credit = core.credit(doc.meta, model)
  local funding = core.funding(doc.meta)
  if closing == nil and credit == nil and funding == nil then
    return model.answers_used and doc or nil
  end
  local cites, refs = references(doc)
  local function references_slide()
    if cites and not refs then
      local title = (quarto.doc.language or {})['section-title-references']
      doc.blocks:insert(pandoc.Header(2, pandoc.Inlines(type(title) == 'string' and title or ''),
        pandoc.Attr('atelier-references', { 'unnumbered' })))
      doc.blocks:insert(pandoc.Div({}, pandoc.Attr('refs')))
    end
  end
  if closing == nil then
    local first = funding ~= nil and 'funding' or 'credit'
    doc.blocks:insert(end_heading(2, 'atelier-end-slide', model.labels[first .. '-title']))
    if funding ~= nil then
      doc.blocks:insert(pandoc.Div(core.funding_blocks(funding, model.labels), pandoc.Attr('', { 'atelier-funding' })))
    end
    if credit ~= nil then
      if funding ~= nil then
        doc.blocks:extend(credit_part(credit, model, 3))
      else
        doc.blocks:insert(pandoc.Div({ core.credit_table(credit, model.labels) }, pandoc.Attr('', { 'atelier-credit' })))
      end
    end
    references_slide()
    return doc
  end
  references_slide()
  doc.blocks:insert(pandoc.Header(2, closing.title, pandoc.Attr('atelier-closing', { 'atelier-closing', 'unnumbered' })))
  doc.blocks:extend(core.closing_parts(closing))
  if funding ~= nil then
    doc.blocks:extend(funding_part(funding, model, 3))
  end
  if credit ~= nil then
    doc.blocks:extend(credit_part(credit, model, 3))
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
