--- Atelier - Workshop Typst Writer
--- @module "workshop/typst"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Write the workshop parts of a Typst handout.
--- @description In workshop mode, the title block gets the workshop labels
--- and the session duration, and the blocks of `workshop/core.lua` become the
--- `atelier-ws-block` calls of `typst/workshop.typ`. Typst has no disclosure,
--- so `extensions.atelier.answers` places each answer: `end` (the default)
--- collects the answers at the end behind an "Answer: page n" link, `inline`
--- keeps each answer in place, and `hide` leaves them out. The answers are
--- numbered in order. Quarto's own solutions stay as Quarto writes them. A
--- `.terminal` code block becomes a terminal in its code window, with its `$`
--- prompts.

local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))
local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local citation = require(quarto.utils.resolve_path('workshop/citation.lua'):gsub('%.lua$', ''))

local M = {}

--- Name that prefixes each warning.
--- @type string
local EXTENSION_NAME = 'atelier'

--- Values of `extensions.atelier.answers`, the default first.
--- @type string[]
local PLACEMENTS = { 'end', 'inline', 'hide' }

--- The label of a numbered answer, such as "Answer 1". The text comes from
--- the `language` files.
--- @param number integer The number of the answer
--- @return string
local function answer_name(number)
  local value = (quarto.doc.language or {})['atelier-answer-title']
  return (type(value) == 'string' and value or '') .. ' ' .. tostring(number)
end

--- A Typst string literal.
--- @param text string
--- @return string
local function typst_string(text)
  return '"' .. str.escape_typst_string(text) .. '"'
end

--- Read `extensions.atelier.answers`. An unknown value logs a warning and
--- gives the default.
--- @param options table The `extensions.atelier` options
--- @return string
local function read_placement(options)
  local value = options.answers
  if value == nil then
    return PLACEMENTS[1]
  end
  local text = core.strip_rewrite(str.stringify(value))
  for _, placement in ipairs(PLACEMENTS) do
    if text == placement then
      return placement
    end
  end
  log.log_warning(
    EXTENSION_NAME,
    'extensions.atelier.answers must be end, inline, or hide, but was "' .. text .. '" in ' ..
    (quarto.doc.input_file or '') .. ', so the answers go to the end.'
  )
  return PLACEMENTS[1]
end

--- Add the answer state to the page model: where the answers go, the
--- answers to write at the end, and their count. Set the workshop labels and
--- the duration of a workshop handout.
--- @param meta table The document metadata
--- @param model table The page model of `core.page`
--- @return table|nil The changed metadata of a workshop page, or nil
function M.publish(meta, model)
  model.answers = { placement = read_placement(model.options), collected = {}, count = 0 }
  if model.mode ~= core.MODE_WORKSHOP then
    return nil
  end
  core.apply_title_labels(meta, model.labels)
  if model.duration ~= nil then
    meta['atelier-duration'] = pandoc.MetaInlines({ pandoc.Str(core.format_duration(model.duration, model.labels)) })
  end
  return meta
end

--- Wrap blocks in a call of a Typst function that takes content.
--- @param call string The call without its content, such as `#atelier-terminal`
--- @param blocks pandoc.Blocks The content
--- @param label string|nil A Typst label to attach, such as `<atelier-answer-1>`
--- @return pandoc.Blocks
local function wrap(call, blocks, label)
  local result = pandoc.Blocks({ pandoc.RawBlock('typst', call .. '[') })
  result:extend(blocks)
  result:insert(pandoc.RawBlock('typst', ']' .. (label and (' ' .. label) or '')))
  return result
end

--- The call of a workshop block, without its content.
--- @param kind string `objectives`, `answer`, or a key of `core.BLOCKS`
--- @param title string The title
--- @param time string|nil The duration text
--- @return string
local function block_call(kind, title, time)
  return string.format(
    '#atelier-ws-block(%s, %s, %s)',
    typst_string(kind),
    typst_string(title),
    time and typst_string(time) or 'none'
  )
end

--- Place an answer after `extensions.atelier.answers`: in place, at the end
--- behind a link, or nowhere. Its label is "Answer 1", and its own title
--- after a colon.
--- @param answer table The answer of `core.answer`
--- @param model table The page model
--- @return pandoc.Blocks
local function answer_blocks(answer, model)
  local page = model.answers
  page.count = page.count + 1
  local number = page.count
  local title = answer_name(number)
  if answer.title then
    title = title .. ': ' .. answer.title
  end
  local target = '<' .. (answer.identifier ~= '' and answer.identifier or ('atelier-answer-' .. number)) .. '>'
  if page.placement == 'hide' then
    return pandoc.Blocks({})
  elseif page.placement == 'inline' then
    return wrap(block_call('answer', title, nil), answer.blocks, target)
  end
  page.collected[#page.collected + 1] = { title = title, target = target, content = answer.blocks }
  return pandoc.Blocks({ pandoc.RawBlock('typst', '#atelier-ws-answer-link(' .. target .. ')') })
end

--- Turn the objectives div, the answer div and the divs of `core.BLOCKS`
--- into blocks.
--- @param div pandoc.Div The div
--- @param model table The page model
--- @return pandoc.Blocks|nil
function M.div(div, model)
  local answer = core.answer(div, model)
  if answer ~= nil then
    return answer_blocks(answer, model)
  end
  if div.classes:includes('objectives') then
    local block = core.objectives(div, model)
    local body = pandoc.Blocks({})
    for position, content in ipairs(block.blocks) do
      if position == block.list then
        body:extend(wrap('#atelier-ws-objectives', pandoc.Blocks({ content })))
      else
        body:insert(content)
      end
    end
    return wrap(block_call('objectives', block.title, block.time), body)
  end
  local kind = core.block_kind(div)
  if kind ~= nil then
    local block = core.block(div, kind, model)
    return wrap(block_call(kind, block.title, block.time), block.blocks)
  end
  return nil
end

--- The Typst code of the CRediT table: a call of `atelier-ws-credit` with
--- the title, the header row and the rows.
--- @param credit table The table of `core.credit`
--- @param labels table<string, string> The resolved labels
--- @return string
local function credit_call(credit, labels)
  local function row(cells)
    local items = {}
    for _, text in ipairs(cells) do
      items[#items + 1] = typst_string(text)
    end
    return '(' .. table.concat(items, ', ') .. ',)'
  end
  local head = { labels['credit-role'] }
  for _, name in ipairs(credit.authors) do
    head[#head + 1] = name
  end
  local rows = {}
  for _, entry in ipairs(credit.rows) do
    local cells = { entry.role }
    for _, text in ipairs(entry.cells) do
      cells[#cells + 1] = text
    end
    rows[#rows + 1] = row(cells)
  end
  return string.format(
    '#atelier-ws-credit(%s, %s, (%s,))',
    typst_string(labels['credit-title']),
    row(head),
    table.concat(rows, ', ')
  )
end

--- The Typst code that stores the closing in the state `atelier-closing-data`,
--- which the closing section or the closing page shows: the title, the
--- content, the links, the copyright and the licence, each as content or
--- `none`.
--- @param closing table The closing of `core.closing`
--- @return pandoc.Blocks
local function closing_update(closing)
  local raw = function(code) return pandoc.RawInline('typst', code) end
  local optional = function(inlines, value)
    if value == nil then
      inlines:insert(raw('none'))
      return
    end
    inlines:insert(raw('['))
    inlines:extend(value)
    inlines:insert(raw(']'))
  end
  local head = pandoc.Inlines({ raw('#atelier-closing-data.update((title: [') })
  head:extend(closing.title)
  head:insert(raw('], content: '))
  local blocks = pandoc.Blocks({})
  if closing.content == nil then
    head:insert(raw('none'))
    blocks:insert(pandoc.Plain(head))
  else
    head:insert(raw('['))
    blocks:insert(pandoc.Plain(head))
    blocks:extend(closing.content)
  end
  local tail = pandoc.Inlines({ raw((closing.content ~= nil and ']' or '') .. ', links: (') })
  for _, link in ipairs(closing.links) do
    tail:insert(raw('['))
    tail:extend(link)
    tail:insert(raw('], '))
  end
  tail:insert(raw('), copyright: '))
  optional(tail, closing.copyright)
  tail:insert(raw(', licence: '))
  optional(tail, closing.licence)
  tail:insert(raw('))'))
  blocks:insert(pandoc.Plain(tail))
  return blocks
end

--- The Typst code that stores the citation in the state
--- `atelier-citation-data`, which the template shows after the bibliography:
--- the heading, the "cite as" label and the entry.
--- @param entry pandoc.Inlines The entry of `citation.text`
--- @return pandoc.Plain
local function citation_update(entry)
  local language = quarto.doc.language or {}
  local inlines = pandoc.Inlines({ pandoc.RawInline('typst', string.format(
    '#atelier-citation-data.update((title: %s, label: %s, body: [',
    typst_string(language['section-title-citation'] or 'Citation'),
    typst_string(language['appendix-attribution-cite-as'] or 'For attribution, please cite this work as:')
  )) })
  inlines:extend(entry)
  inlines:insert(pandoc.RawInline('typst', ']))'))
  return pandoc.Plain(inlines)
end

--- Finish the handout after its blocks: write the answers collected for the
--- end, an "Answers" heading, then one heading and the content of each
--- answer, then the closing section, the funding and the CRediT table, in the
--- order of the end matter. The bibliography follows, then the citation from
--- the template, and a closing page, if the report has one, comes last.
--- @param doc pandoc.Pandoc The document
--- @param model table The page model
--- @return pandoc.Pandoc|nil
function M.finish(doc, model)
  local page = model.answers
  local credit = core.credit(doc.meta, model)
  local closing = core.closing(doc.meta, model)
  local funding = core.funding(doc.meta)
  local cite = citation.text(doc.meta)
  if page.count == 0 and credit == nil and closing == nil and funding == nil and cite == nil then
    return nil
  end
  if #page.collected > 0 then
    doc.blocks:insert(pandoc.RawBlock('typst', '#atelier-ws-answers-heading()'))
    doc.blocks:insert(pandoc.RawBlock('typst', '#atelier-chapter-end()'))
    for _, entry in ipairs(page.collected) do
      doc.blocks:insert(pandoc.RawBlock(
        'typst',
        '#heading(level: 2, numbering: none, ' .. typst_string(entry.title) .. ') ' .. entry.target
      ))
      doc.blocks:extend(entry.content)
    end
  end
  if closing ~= nil then
    doc.blocks:extend(closing_update(closing))
    doc.blocks:insert(pandoc.RawBlock('typst', '#atelier-closing-section()'))
  end
  if funding ~= nil then
    doc.blocks:insert(pandoc.RawBlock('typst', '#atelier-ws-funding(' .. typst_string(model.labels['funding-title']) .. ')['))
    doc.blocks:extend(core.funding_blocks(funding, model.labels))
    doc.blocks:insert(pandoc.RawBlock('typst', ']'))
  end
  if credit ~= nil then
    doc.blocks:insert(pandoc.RawBlock('typst', credit_call(credit, model.labels)))
  end
  if cite ~= nil then
    doc.blocks:insert(citation_update(cite))
  end
  return doc
end

--- Draw a `.terminal` code block as a terminal: the code window takes the
--- terminal label and colours, and the prompts stay in the text.
--- @param block pandoc.CodeBlock The code block
--- @param model table The page model
--- @return pandoc.Blocks|nil
function M.code_block(block, model)
  if core.terminal(block) == nil then
    return nil
  end
  if (block.attributes['code-window-auto-label'] or '') == '' then
    block.attributes['code-window-auto-label'] = model.labels.terminal
  end
  return wrap('#atelier-terminal', pandoc.Blocks({ block }))
end

return M
