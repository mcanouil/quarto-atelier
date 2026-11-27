--- Atelier - Workshop HTML Writer
--- @module "workshop/html"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Write the workshop data and blocks of an HTML page.
--- @description Writes one JSON block into the head of each HTML page. It
--- holds the mode, the project offset, the translated labels, and, in
--- workshop mode, the page duration, the sidebar that lists
--- the page, and the durations of every page in that sidebar. A workshop
--- page also gets the
--- `atelier-workshop` class on `<html>` and the motif of its preset, and a
--- workshop page that no listed
--- sidebar holds also gets `atelier-workshop-unlisted`.
--- The blocks of `workshop/core.lua` become the head line and body of each
--- block, objective checkboxes, a `<details>` answer, and a terminal code
--- block for the code-blocks script.

local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))
local palette = require(quarto.utils.resolve_path('palette.lua'):gsub('%.lua$', ''))
local motifs = require(quarto.utils.resolve_path('motifs.lua'):gsub('%.lua$', ''))
local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))

local M = {}

--- The objectives written so far on the page, by base id, so a repeated
--- objective text gets its own id. `M.publish` resets it for each page.
--- @type table<string, integer>
local objectives = {}

--- Encode the data as JSON.
--- @param data table The data
--- @return string The JSON text, safe inside a script element
local function encode(data)
  return (quarto.json.encode(data):gsub('</', '<\\/'))
end

--- Add the workshop data block to the head, the authors that
--- `html/title-metadata.html` writes in the title block, and the
--- title-block labels of a workshop page.
--- @param meta table The document metadata
--- @param model table The page model of `core.page`
--- @return table|nil The changed metadata, or nil when the page changes none
function M.publish(meta, model)
  objectives = {}
  local data = {
    mode = model.mode,
    offset = quarto.project.offset or '',
    labels = model.labels,
  }
  local authors = core.authors(meta, model.labels)
  if #authors > 0 then
    -- A file, not a data URI: the pages of a course share it in the cache.
    meta['atelier-authors'] = core.authors_meta(authors, model.labels, function(path)
      quarto.doc.add_resource(path)
      return path
    end)
  end
  local changed = #authors > 0 and meta or nil
  if model.mode == core.MODE_WORKSHOP then
    changed = meta
    data.duration = model.duration
    local course = core.course(model)
    if course.listed then
      data.listed = true
      data.sidebar = course.sidebar
      data.durations = course.durations
    end
    -- An unlisted page gets no workshop bar, so its CSS must not reserve the bar row.
    local classes = '"atelier-workshop"'
    if not course.listed then
      classes = classes .. ', "atelier-workshop-unlisted"'
    end
    quarto.doc.include_text(
      'in-header',
      '<script>document.documentElement.classList.add(' .. classes .. ');</script>'
    )
    -- The motif of the preset, which `html/workshop.scss` draws in the title
    -- block. A brand can set a preset for each scheme, so the dark page takes
    -- the motif of its own preset.
    local light, dark = motifs.name(palette.preset('light')), motifs.name(palette.preset('dark'))
    local style = ':root { --atelier-motif: ' .. motifs.mask(light) .. '; }'
    if dark ~= light then
      style = style .. ' body.quarto-dark { --atelier-motif: ' .. motifs.mask(dark) .. '; }'
    end
    quarto.doc.include_text('in-header', '<style>' .. style .. '</style>')
    core.apply_title_labels(meta, model.labels)
  end
  quarto.doc.include_text(
    'in-header',
    '<script type="application/json" id="atelier-workshop">' .. encode(data) .. '</script>'
  )
  return changed
end

--- Build the head line of a block.
--- @param icon string|nil The Bootstrap Icons name, such as `bullseye`, or nil for no icon
--- @param title string The title text
--- @param time string|nil The formatted duration, or nil to leave the pill out
--- @return pandoc.Plain The head paragraph
function M.block_head(icon, title, time)
  local head = pandoc.Inlines({
    pandoc.RawInline(
      'html',
      '<p class="atelier-block-head">' .. (icon and ('<i class="bi bi-' .. icon .. '" aria-hidden="true"></i>') or '')
    ),
    pandoc.Str(title),
  })
  if time ~= nil then
    head:insert(pandoc.RawInline('html', '<span class="atelier-block-time">'))
    head:insert(pandoc.Str(time))
    head:insert(pandoc.RawInline('html', '</span>'))
  end
  head:insert(pandoc.RawInline('html', '</p>'))
  return pandoc.Plain(head)
end

--- Make the id of an objective from its text.
--- The browser stores the ticked objectives by these ids, so a tick stays on
--- its objective when the author adds, removes, or moves other objectives.
--- The second and later objectives with the same text on the page get `-2`,
--- `-3`, and so on.
--- @param inlines pandoc.Inlines The text of the objective
--- @return string The id, such as `o-1a2b3c4d`
local function objective_id(inlines)
  local base = 'o-' .. pandoc.utils.sha1(pandoc.utils.stringify(inlines)):sub(1, 8)
  local count = (objectives[base] or 0) + 1
  objectives[base] = count
  if count == 1 then
    return base
  end
  return base .. '-' .. count
end

--- Turn each item of a bullet list into a checkbox label.
--- Each checkbox has the id of its objective text. The empty span after each
--- checkbox holds the tick that the style draws.
--- @param list pandoc.BulletList The list
--- @return pandoc.Blocks The labels, followed by any further blocks of the items
local function objective_labels(list)
  local blocks = pandoc.Blocks({})
  for _, item in ipairs(list.content) do
    local inlines, rest = core.objective_text(item)
    local label = pandoc.Inlines({
      pandoc.RawInline(
        'html',
        '<label><input type="checkbox" data-atelier-objective="' .. objective_id(inlines) .. '">' ..
        '<span class="atelier-check" aria-hidden="true"></span> '
      ),
    })
    label:extend(inlines)
    label:insert(pandoc.RawInline('html', '</label>'))
    blocks:insert(pandoc.Plain(label))
    for position = rest, #item do
      blocks:insert(item[position])
    end
  end
  return blocks
end

--- Build the attributes of a workshop block from the attributes of its div.
--- The author's identifier, other classes, and other attributes stay, and the
--- block class replaces the div class.
--- @param div pandoc.Div The div
--- @param class string The div class, such as `objectives`
--- @return pandoc.Attr The attributes
function M.block_attr(div, class)
  local classes, attributes = core.other_attr(div, class)
  table.insert(classes, 1, 'atelier-' .. class)
  return pandoc.Attr(div.identifier, classes, attributes)
end

--- Wrap blocks in the body container of a workshop block.
--- @param blocks pandoc.Blocks The content
--- @return pandoc.Div The body
function M.block_body(blocks)
  return pandoc.Div(blocks, pandoc.Attr('', { 'atelier-block-body' }))
end

--- Build the objectives block.
--- @param div pandoc.Div The `.objectives` div
--- @param model table The page model
--- @return pandoc.Div The block
local function objectives_block(div, model)
  local block = core.objectives(div, model)
  local body = pandoc.Blocks({})
  for position, content in ipairs(block.blocks) do
    if position == block.list then
      body:extend(objective_labels(content))
    else
      body:insert(content)
    end
  end
  return pandoc.Div(
    { M.block_head('bullseye', block.title, block.time), M.block_body(body) },
    M.block_attr(div, 'objectives')
  )
end

--- Build a block of `core.BLOCKS`: the prerequisites, a checkpoint, or an
--- exercise.
--- @param div pandoc.Div The div
--- @param kind string The class, a key of `core.BLOCKS`
--- @param model table The page model
--- @return pandoc.Div The block
local function head_block(div, kind, model)
  local block = core.block(div, kind, model)
  return pandoc.Div(
    { M.block_head(core.BLOCKS[kind], block.title, block.time), M.block_body(block.blocks) },
    M.block_attr(div, kind)
  )
end

--- Turn an answer into the closed disclosure. When the div has other classes
--- or attributes, a div that carries them wraps the disclosure, so that a
--- filter that runs later still finds them, for example Veil with
--- `.veil group="..."`.
--- @param answer { title: string|nil, identifier: string, div: pandoc.Div, blocks: pandoc.Blocks } The answer of `core.answer`
--- @param labels table<string, string> The resolved labels
--- @return pandoc.Blocks The disclosure
local function answer_block(answer, labels)
  local identifier = answer.identifier
  local id = identifier ~= '' and (' id="' .. str.escape_attribute(identifier) .. '"') or ''
  local disclosure = pandoc.Blocks({
    pandoc.RawBlock('html', '<details class="atelier-answer"' .. id .. '>'),
    pandoc.Plain({
      pandoc.RawInline('html', '<summary>'),
      pandoc.Str(answer.title or labels['answer-summary']),
      pandoc.RawInline('html', '</summary>'),
    }),
    M.block_body(answer.blocks),
    pandoc.RawBlock('html', '</details>'),
  })
  local classes, attributes = core.other_attr(answer.div, 'answer')
  if #classes == 0 and #attributes == 0 then
    return disclosure
  end
  return pandoc.Blocks({ pandoc.Div(disclosure, pandoc.Attr('', classes, attributes)) })
end

--- Turn the workshop divs into blocks.
--- @param div pandoc.Div The div
--- @param model table The page model
--- @return pandoc.Div|pandoc.Blocks|nil The block, or nil to keep the div
function M.div(div, model)
  local answer = core.answer(div, model)
  if answer ~= nil then
    return answer_block(answer, model.labels)
  end
  if div.classes:includes('objectives') then
    return objectives_block(div, model)
  end
  local kind = core.block_kind(div)
  if kind ~= nil then
    return head_block(div, kind, model)
  end
  return nil
end

--- Build the CRediT section: a heading and the table, in an `.appendix`
--- section that Quarto moves into its appendix.
--- @param credit table The table of `core.credit`
--- @param labels table<string, string> The resolved labels
--- @return pandoc.Div
function M.credit_section(credit, labels)
  return pandoc.Div({
    pandoc.Header(2, pandoc.Inlines(labels['credit-title']), pandoc.Attr('atelier-credit-title', { 'unnumbered' })),
    core.credit_table(credit, labels),
  }, pandoc.Attr('', { 'atelier-credit', 'appendix' }))
end

--- Build the funding section: a heading, the statements and the awards, in
--- an `.appendix` section that Quarto moves into its appendix.
--- @param funding table The funding of `core.funding`
--- @param labels table<string, string> The resolved labels
--- @return pandoc.Div
function M.funding_section(funding, labels)
  local blocks = pandoc.Blocks({
    pandoc.Header(2, pandoc.Inlines(labels['funding-title']), pandoc.Attr('atelier-funding-title', { 'unnumbered' })),
  })
  blocks:extend(core.funding_blocks(funding, labels))
  return pandoc.Div(blocks, pandoc.Attr('', { 'atelier-funding', 'appendix' }))
end

--- Write a list of links as a `ul` with `role="list"`. The style hides the
--- bullets, and some browsers then drop the list semantics, so the role keeps
--- them. Each item stays pandoc inlines, so Quarto still resolves the links.
--- @param list pandoc.BulletList The list
--- @return pandoc.Blocks
local function link_list(list)
  local blocks = pandoc.Blocks({ pandoc.RawBlock('html', '<ul role="list">') })
  for _, item in ipairs(list.content) do
    local inlines = pandoc.Inlines({ pandoc.RawInline('html', '<li>') })
    inlines:extend(pandoc.utils.blocks_to_inlines(item))
    inlines:insert(pandoc.RawInline('html', '</li>'))
    blocks:insert(pandoc.Plain(inlines))
  end
  blocks:insert(pandoc.RawBlock('html', '</ul>'))
  return blocks
end

--- Build the closing section: the heading and the parts, with the links as
--- a list that keeps its semantics.
--- @param closing table The closing of `core.closing`
--- @return pandoc.Div
local function closing_section(closing)
  local blocks = pandoc.Blocks({
    pandoc.Header(2, closing.title, pandoc.Attr('atelier-closing-title', { 'unnumbered' })),
  })
  for _, part in ipairs(core.closing_parts(closing)) do
    if part.classes:includes('atelier-closing-links') then
      part.content = link_list(part.content[1])
    end
    blocks:insert(part)
  end
  return pandoc.Div(blocks, pandoc.Attr('', { 'atelier-closing' }))
end

--- Finish a page after its blocks: the closing at the end of the body, then
--- the funding and the CRediT table as `.appendix` sections, which Quarto
--- moves into its appendix before the references.
--- The closing drops its copyright and its licence line when Quarto's
--- appendix shows it, as Copyright or Reuse.
--- The pages of a website share their authors, so a website page shows the
--- CRediT table only when it sets `extensions.atelier.closing`.
--- @param doc pandoc.Pandoc The document
--- @param model table The page model
--- @return pandoc.Pandoc|nil
function M.finish(doc, model)
  local closing = core.closing(doc.meta, model, core.appendix_rights(doc.meta))
  local funding = core.funding(doc.meta)
  local credit = (closing ~= nil or not logo.in_website()) and core.credit(doc.meta, model) or nil
  if closing == nil and funding == nil and credit == nil then
    return nil
  end
  if closing ~= nil then
    doc.blocks:insert(closing_section(closing))
  end
  if funding ~= nil then
    doc.blocks:insert(M.funding_section(funding, model.labels))
  end
  if credit ~= nil then
    doc.blocks:insert(M.credit_section(credit, model.labels))
  end
  return doc
end

--- Draw a `.terminal` code block as a terminal, in both modes.
--- The prompt lines join `atelier-prompt` and the continuation lines join
--- `atelier-continuation`, both line specs. The code-blocks script marks those
--- lines, and the style draws the `$` prompt before a prompt line, and gives a
--- continuation line the command colour with no prompt. The prompt is not in
--- the text, so screen readers and the copy button skip it.
--- The block gets the `terminal` label in `code-window-auto-label`.
--- Code Window uses this label only for a block with no `filename`.
--- A block with `filename=""` keeps a title bar with no name.
--- This filter runs before Code Window. A `filename`, `code-window-auto-label`,
--- `code-window-enabled`, or `code-window-no-auto-filename` on the block still
--- wins.
--- @param block pandoc.CodeBlock The code block
--- @param model table The page model
--- @return pandoc.CodeBlock|nil The block, or nil to keep it
function M.code_block(block, model)
  local terminal = core.terminal(block)
  if terminal == nil then
    return nil
  end
  block.text = terminal.text
  block.classes:insert('atelier-terminal')
  if #terminal.prompts > 0 then
    block.attributes['atelier-prompt'] = table.concat(terminal.prompts, ',')
  end
  if #terminal.continuations > 0 then
    block.attributes['atelier-continuation'] = table.concat(terminal.continuations, ',')
  end
  if (block.attributes['code-window-auto-label'] or '') == '' then
    block.attributes['code-window-auto-label'] = model.labels.terminal
  end
  return block
end

return M
