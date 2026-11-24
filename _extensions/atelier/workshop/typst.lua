--- Atelier - Workshop Typst Writer
--- @module "workshop/typst"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Write the workshop parts of a Typst handout.
--- @description In workshop mode, the title block gets the workshop labels
--- and the session duration, and the blocks of `workshop/core.lua` become the
--- `atelier-ws-block` calls of `typst/workshop.typ`. Typst has no disclosure,
--- so `extensions.atelier.solutions` places each solution: `end` (the
--- default) collects the solutions at the end behind a "Solution: page n"
--- link, `inline` keeps each solution in place, and `hide` leaves them out.
--- The solutions are numbered in order, and a citation of a solution, such as
--- `@sol-a`, becomes a link with the label "Solution 1". A `.terminal` code
--- block becomes a terminal in its code window, with its `$` prompts.

local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))
local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))

local M = {}

--- Name that prefixes each warning.
--- @type string
local EXTENSION_NAME = 'atelier'

--- Values of `extensions.atelier.solutions`, the default first.
--- @type string[]
local PLACEMENTS = { 'end', 'inline', 'hide' }

--- The label of a numbered solution, such as "Solution 1". The text comes
--- from the `language` files.
--- @param number integer The number of the solution
--- @return string
local function solution_name(number)
  local value = (quarto.doc.language or {})['atelier-solution-title']
  return (type(value) == 'string' and value or '') .. ' ' .. tostring(number)
end

--- A Typst string literal.
--- @param text string
--- @return string
local function typst_string(text)
  return '"' .. str.escape_typst_string(text) .. '"'
end

--- Read `extensions.atelier.solutions`. An unknown value logs a warning and
--- gives the default.
--- @param options table The `extensions.atelier` options
--- @return string
local function read_placement(options)
  local value = options.solutions
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
    'extensions.atelier.solutions must be end, inline, or hide, but was "' .. text .. '" in ' ..
    (quarto.doc.input_file or '') .. ', so the solutions go to the end.'
  )
  return PLACEMENTS[1]
end

--- Set the workshop labels and the duration of a workshop handout, and add
--- the solution state to the page model: where the solutions go, the
--- solutions to write at the end, and the number of each solution identifier.
--- @param meta table The document metadata
--- @param model table The page model of `core.page`
--- @return table|nil The changed metadata of a workshop page, or nil
function M.publish(meta, model)
  model.solutions = { placement = read_placement(model.options), collected = {}, numbers = {}, count = 0 }
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
--- @param label string|nil A Typst label to attach, such as `<sol-a>`
--- @return pandoc.Blocks
local function wrap(call, blocks, label)
  local result = pandoc.Blocks({ pandoc.RawBlock('typst', call .. '[') })
  result:extend(blocks)
  result:insert(pandoc.RawBlock('typst', ']' .. (label and (' ' .. label) or '')))
  return result
end

--- The call of a workshop block, without its content.
--- @param kind string `objectives`, `exercise` or `solution`
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

--- Turn the objectives and exercise divs into blocks, in workshop mode only.
--- @param div pandoc.Div The div
--- @param model table The page model
--- @return pandoc.Blocks|nil
function M.div(div, model)
  if model.mode ~= core.MODE_WORKSHOP then
    return nil
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
  elseif div.classes:includes('exercise') then
    local block = core.exercise(div, model)
    return wrap(block_call('exercise', block.title, block.time), block.blocks)
  end
  return nil
end

--- The label of a solution: "Solution 1", and its own title after a colon.
--- @param proof table The `Proof` node
--- @param number integer The number of the solution
--- @return string
local function solution_label(proof, number)
  local name = solution_name(number)
  local own = proof.div.attributes.title or pandoc.utils.stringify(proof.name or '')
  if own == '' then
    return name
  end
  return name .. ': ' .. own
end

--- Place a solution after `extensions.atelier.solutions`. Unlike HTML, a
--- solution with a `sol-` identifier follows the placement too: Typst has no
--- disclosure to keep it in.
--- @param proof table The `Proof` node
--- @param model table The page model
--- @return pandoc.Blocks|nil
function M.proof(proof, model)
  if model.mode ~= core.MODE_WORKSHOP or not core.is_solution(proof) then
    return nil
  end
  local page = model.solutions
  page.count = page.count + 1
  local number = page.count
  local identifier = proof.identifier or ''
  if identifier ~= '' then
    page.numbers[identifier] = number
  end
  local title = solution_label(proof, number)
  local target = '<' .. (identifier ~= '' and identifier or ('atelier-solution-' .. number)) .. '>'
  if page.placement == 'hide' then
    return pandoc.Blocks({})
  elseif page.placement == 'inline' then
    return wrap(block_call('solution', title, nil), proof.div.content, target)
  end
  page.collected[#page.collected + 1] = { title = title, target = target, content = proof.div.content }
  return pandoc.Blocks({ pandoc.RawBlock('typst', '#atelier-ws-solution-link(' .. target .. ')') })
end

--- Replace a citation of solutions, such as `@sol-a` or `[@sol-a; @sol-b]`,
--- with a link to each solution, labelled "Solution 1". With `hide`, the
--- label has no link. A citation that mixes solutions with other references
--- is left to Quarto, with a warning.
--- @param cite pandoc.Cite The citation
--- @param page table The solution state of the page model
--- @return pandoc.Inlines|nil
local function solution_cite(cite, page)
  local known = 0
  for _, citation in ipairs(cite.citations) do
    if page.numbers[citation.id] ~= nil then
      known = known + 1
    end
  end
  if known == 0 then
    return nil
  end
  if known < #cite.citations then
    log.log_warning(
      EXTENSION_NAME,
      'A citation in ' .. (quarto.doc.input_file or '') .. ' mixes workshop solutions with other references, ' ..
      'so Quarto cannot resolve the solutions. Cite the solutions in a citation of their own.'
    )
    return nil
  end
  local inlines = pandoc.Inlines({})
  for index, citation in ipairs(cite.citations) do
    if index > 1 then
      inlines:insert(pandoc.Str(','))
      inlines:insert(pandoc.Space())
    end
    inlines:extend(citation.prefix)
    if #citation.prefix > 0 then
      inlines:insert(pandoc.Space())
    end
    local name = solution_name(page.numbers[citation.id])
    if page.placement == 'hide' then
      inlines:insert(pandoc.Str(name))
    else
      inlines:insert(pandoc.RawInline('typst', '#link(<' .. citation.id .. '>)[' .. str.escape_typst(name) .. ']'))
    end
    inlines:extend(citation.suffix)
  end
  return inlines
end

--- Finish the handout after its blocks: write the solutions collected for
--- the end, a "Solutions" heading, then one heading and the content of each
--- solution. Then resolve the citations of solutions, the moved ones too.
--- @param doc pandoc.Pandoc The document
--- @param model table The page model
--- @return pandoc.Pandoc|nil
function M.finish(doc, model)
  local page = model.solutions
  if page.count == 0 then
    return nil
  end
  if #page.collected > 0 then
    doc.blocks:insert(pandoc.RawBlock('typst', '#atelier-ws-solutions-heading()'))
    doc.blocks:insert(pandoc.RawBlock('typst', '#atelier-chapter-end()'))
    for _, entry in ipairs(page.collected) do
      doc.blocks:insert(pandoc.RawBlock(
        'typst',
        '#heading(level: 2, numbering: none, ' .. typst_string(entry.title) .. ') ' .. entry.target
      ))
      doc.blocks:extend(entry.content)
    end
  end
  return doc:walk({ Cite = function(cite) return solution_cite(cite, page) end })
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
