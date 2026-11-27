--- Atelier - Workshop Core
--- @module "workshop/core"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief The format-neutral part of the workshop mode.
--- @description Reads the page model (mode, duration, labels), the course
--- model (the sidebar that lists the page and the durations of its pages),
--- and the workshop blocks (objectives, exercise, answer, terminal). Each
--- reader returns plain data, and the writer of each format turns that data
--- into its output. This module writes no output.

local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))
local meta_mod = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))

local M = {}

--- Modes that `extensions.atelier.mode` accepts.
--- @type string
local MODE_DOCUMENTATION = 'documentation'
--- @type string
M.MODE_WORKSHOP = 'workshop'

--- Name that prefixes each warning.
--- @type string
local EXTENSION_NAME = 'atelier'

--- Page file extensions whose front matter holds a duration, in lower case.
--- @type table<string, boolean>
local FRONT_MATTER_EXTENSIONS = { qmd = true, md = true, rmd = true }

--- Page file extensions that Quarto renders through this filter, so such a
--- page can be in workshop mode. A notebook reads its metadata from a raw cell.
--- The extensions are in lower case.
--- @type table<string, boolean>
local RENDERED_EXTENSIONS = { qmd = true, md = true, rmd = true, ipynb = true }

--- Keys of the labels, without the `atelier-` prefix, in output order.
--- The text comes from the `language` files.
--- @type table<integer, string>
local LABELS = {
  'duration-minutes',
  'duration-hours',
  'duration-hours-minutes',
  'reading-bar',
  'reading-progress',
  'reading-position',
  'workshop-bar',
  'workshop-progress',
  'workshop-position',
  'workshop-total',
  'workshop-completed',
  'previous',
  'next',
  'timer-label',
  'timer-pause',
  'toc-read',
  'toc-module-read',
  'objectives-title',
  'exercise-title',
  'prerequisites-title',
  'checkpoint-title',
  'credit-title',
  'credit-role',
  'credit-lead',
  'credit-equal',
  'credit-supporting',
  'credit-contributed',
  'funding-title',
  'funding-recipient',
  'closing-thanks',
  'answer-summary',
  'terminal',
  'workshop-author-single',
  'workshop-author-plural',
  'workshop-published',
  'workshop-modified',
  'author-corresponding',
  'author-equal',
  'author-deceased',
  'author-orcid-profile',
}

-- ============================================================================
-- LABELS AND DURATIONS
-- ============================================================================

--- Resolve every label from the `language` files and overrides.
--- A missing value gives an empty string.
--- @return table<string, string> The label text by key
function M.resolve_labels()
  local language = quarto.doc.language or {}
  local labels = {}
  for _, key in ipairs(LABELS) do
    local value = language['atelier-' .. key]
    labels[key] = type(value) == 'string' and value or ''
  end
  return labels
end

--- Parse a duration into minutes.
--- Accepts `25 min`, `25min`, `1 h`, `1h`, `1 h 30 min`, `1h30min`, and a
--- bare number, which counts as minutes.
--- @param text string The duration text
--- @return integer|nil The minutes, or nil when the text is not a duration
function M.parse_duration(text)
  local value = str.trim(text:lower())
  local minutes = value:match('^(%d+)$') or value:match('^(%d+)%s*min$')
  if minutes then
    return tonumber(minutes)
  end
  local hours = value:match('^(%d+)%s*h$')
  if hours then
    return tonumber(hours) * 60
  end
  local h, m = value:match('^(%d+)%s*h%s*(%d+)%s*min$')
  if h then
    return tonumber(h) * 60 + tonumber(m)
  end
  return nil
end

--- Format minutes with the duration labels.
--- The spaces become no-break spaces, so the duration stays on one line.
--- @param minutes integer The duration in minutes
--- @param labels table<string, string> The resolved labels
--- @return string The text, such as `25 min`, `1 h`, or `1 h 30 min`
function M.format_duration(minutes, labels)
  local hours = minutes // 60
  local rest = minutes % 60
  local template = labels['duration-minutes']
  if hours > 0 and rest > 0 then
    template = labels['duration-hours-minutes']
  elseif hours > 0 then
    template = labels['duration-hours']
  end
  return (template:gsub('{h}', tostring(hours)):gsub('{m}', tostring(rest)):gsub(' ', '\u{00A0}'))
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

--- Read the `extensions.atelier` table of a metadata table.
--- @param meta table The metadata
--- @return table The options, empty when unset
function M.read_options(meta)
  local options = meta_mod.get_extension_config(meta, 'atelier')
  if type(options) ~= 'table' then
    return {}
  end
  return options
end

--- Log the warning for a duration that does not parse.
--- @param subject string What holds the duration, such as an option or an attribute
--- @param text string The duration text
--- @param source string The file the duration comes from
--- @return nil
local function warn_duration(subject, text, source)
  log.log_warning(
    EXTENSION_NAME,
    subject .. " '" .. text .. "' in " .. source ..
    " is not a duration such as '25 min' or '1 h 30 min'. Ignoring it."
  )
end

--- Read the duration option of a metadata table.
--- A duration that does not parse logs a warning naming the source file,
--- unless `quiet` is true.
--- @param meta table The metadata
--- @param source string The file the metadata comes from
--- @param quiet boolean|nil True to log no warning
--- @return integer|nil The minutes, or nil when unset or invalid
function M.read_duration(meta, source, quiet)
  local value = M.read_options(meta).duration
  if value == nil then
    return nil
  end
  local text = pandoc.utils.stringify(value)
  local minutes = M.parse_duration(text)
  if minutes == nil and not quiet then
    warn_duration('extensions.atelier.duration', text, source)
  end
  return minutes
end

-- Quarto rewrites a project metadata string as a path relative to the page when a file or folder of that name exists, so `workshop` reaches pages under `workshop/` as `../../workshop`. Strip the leading `../` and `./` segments to get the value back, for the mode and the sidebar id.
-- The mode default stays in this file and never in `_extension.yml`, where the offset also holds the extension folder.
-- Upstream: https://github.com/quarto-dev/quarto-cli/issues/12963
-- Remove when: the minimum Quarto version includes the fix.
--- @param value string The value as the filter reads it
--- @return string The value without the leading `../` and `./` segments
function M.strip_rewrite(value)
  local text, count = value, 1
  while count > 0 do
    text, count = text:gsub('^%.%.?/', '')
  end
  return text
end

--- Read the mode option, falling back to documentation with a warning.
--- @param meta table The metadata
--- @param source string The input file, for the warning
--- @param quiet boolean|nil True to log no warning
--- @return string The mode
function M.read_mode(meta, source, quiet)
  local value = M.read_options(meta).mode
  if value == nil then
    return MODE_DOCUMENTATION
  end
  local text = M.strip_rewrite(pandoc.utils.stringify(value))
  if text == MODE_DOCUMENTATION or text == M.MODE_WORKSHOP then
    return text
  end
  if not quiet then
    log.log_warning(
      EXTENSION_NAME,
      'extensions.atelier.mode must be documentation or workshop, but was \'' .. text ..
      '\' in ' .. source .. '. Using documentation.'
    )
  end
  return MODE_DOCUMENTATION
end

-- ============================================================================
-- PAGE MODEL
-- ============================================================================

--- Read the page model: what every writer needs to know about the page.
--- @param meta table The document metadata
--- @return { mode: string, duration: integer|nil, labels: table<string, string>, options: table, source: string } The model
function M.page(meta)
  local source = quarto.doc.input_file or ''
  local mode = M.read_mode(meta, source)
  return {
    options = M.read_options(meta),
    mode = mode,
    -- The page duration is workshop metadata, so a page in another mode has none.
    duration = mode == M.MODE_WORKSHOP and M.read_duration(meta, source) or nil,
    labels = M.resolve_labels(),
    source = source,
  }
end

--- Count the authors of a page, as Quarto does for the author label.
--- @param meta table The document metadata
--- @return integer The number of authors
local function count_authors(meta)
  local authors = meta['by-author'] or meta.author
  if authors == nil then
    return 0
  end
  if pandoc.utils.type(authors) == 'List' then
    return #authors
  end
  return 1
end

--- Set the title-block labels of a workshop page.
--- Quarto fills `meta.labels` from the `language` keys before this filter runs.
--- A label that the page sets with `author-title`, `published-title`, or
--- `modified-title` stays as it is.
--- @param meta table The document metadata
--- @param labels table<string, string> The resolved Atelier labels
--- @return nil
function M.apply_title_labels(meta, labels)
  local values = meta.labels or {}
  if meta['author-title'] == nil then
    local key = count_authors(meta) == 1 and 'workshop-author-single' or 'workshop-author-plural'
    values.authors = pandoc.Inlines(labels[key])
  end
  if meta['published-title'] == nil then
    values.published = pandoc.Inlines(labels['workshop-published'])
  end
  if meta['modified-title'] == nil then
    values.modified = pandoc.Inlines(labels['workshop-modified'])
  end
  meta.labels = values
end

-- ============================================================================
-- AUTHORS
-- ============================================================================

--- The media types of the photo files that an author can have, by extension.
--- @type table<string, string>
local PHOTO_TYPES = {
  svg = 'image/svg+xml',
  png = 'image/png',
  jpg = 'image/jpeg',
  jpeg = 'image/jpeg',
  gif = 'image/gif',
  webp = 'image/webp',
}

--- The plain text of a metadata value, or an empty string.
--- @param value any
--- @return string
local function text_of(value)
  if value == nil then
    return ''
  end
  return pandoc.utils.stringify(value)
end

--- Answer the name of an author as Quarto normalises it.
--- @param author table An entry of `by-author`
--- @return string
function M.author_name(author)
  if author.name == nil then
    return ''
  end
  return text_of(author.name.literal or author.name)
end

--- Resolve a path against the folder of the document, such as the photo of
--- an author or the file of the closing. An absolute path stays as it is.
--- @param path string The path, relative to the document
--- @return string
local function document_file(path)
  if path:sub(1, 1) ~= '/' and quarto.doc.input_file then
    return pandoc.path.join({ pandoc.path.directory(quarto.doc.input_file), path })
  end
  return path
end

--- Resolve the `photo` key of an author to a path relative to the folder of
--- the document. A value that starts with `/` is relative to the project
--- root, as other Quarto site paths are, so a project-level author list works
--- on nested pages; any other value is relative to the document.
--- @param value string The value of the `photo` key
--- @return string The path, relative to the folder of the document
local function photo_path(value)
  if value:sub(1, 1) ~= '/' or quarto.doc.input_file == nil then
    return value
  end
  local root = quarto.project.directory or pandoc.path.directory(quarto.doc.input_file)
  local file = pandoc.path.join({ root, value:sub(2) })
  -- `unsafe` lets the answer start with `../`, for a page below the root.
  return pandoc.path.make_relative(file, pandoc.path.directory(quarto.doc.input_file), true)
end

--- Check the photo file of an author. A file that does not exist, or that is
--- not an image type that a browser shows, logs a warning.
--- @param path string The path, relative to the document
--- @param value string The value of the `photo` key, for the warning
--- @param name string The name of the author, for the warning
--- @return boolean True when the photo can be shown
local function photo_ok(path, value, name)
  local subject = "The photo '" .. value .. "' of the author " .. name .. ' in ' ..
    (quarto.doc.input_file or '')
  if PHOTO_TYPES[(path:match('%.([^./\\]+)$') or ''):lower()] == nil then
    log.log_warning(
      EXTENSION_NAME,
      subject .. ' is not an svg, png, jpg, gif or webp file, so the author has no photo. ' ..
      'Set the author key photo to an image file.'
    )
    return false
  end
  local file = io.open(document_file(path), 'rb')
  if file == nil then
    log.log_warning(
      EXTENSION_NAME,
      subject .. ' does not exist, so the author has no photo. ' ..
      'Correct the author key photo: a path relative to the document, or to the project root when it starts with /.'
    )
    return false
  end
  file:close()
  return true
end

--- Read the photo of an author as a data URI, so the page carries it.
--- @param path string The path of a photo that `M.authors` checked
--- @return string The data URI
function M.photo_uri(path)
  local file = assert(io.open(document_file(path), 'rb'))
  local content = file:read('a')
  file:close()
  local media = PHOTO_TYPES[path:match('%.([^./\\]+)$'):lower()]
  return 'data:' .. media .. ';base64,' .. quarto.base64.encode(content)
end

--- The author attributes that show as text, in order, with their label keys.
--- @type { key: string, label: string }[]
local AUTHOR_ATTRIBUTES = {
  { key = 'corresponding', label = 'author-corresponding' },
  { key = 'equal-contributor', label = 'author-equal' },
  { key = 'deceased', label = 'author-deceased' },
}

--- Tell whether a metadata value is true.
--- @param value any
--- @return boolean
local function is_true(value)
  return value == true or text_of(value) == 'true'
end

--- @class Author
--- @field index integer The position of the author in `by-author`
--- @field name string
--- @field url string|nil
--- @field photo string|nil The checked path, relative to the folder of the document
--- @field photo_alt string The alt text of the photo, empty when it is decorative
--- @field degrees string[]
--- @field orcid string|nil
--- @field email string|nil
--- @field affiliations { name: string, url: string|nil }[]
--- @field attributes string[] The visible labels of the author attributes
--- @field note string|nil

--- Read one value of an author as text, or nil when it is empty.
--- @param value any
--- @return string|nil
local function optional_text(value)
  local text = text_of(value)
  return text ~= '' and text or nil
end

--- Read the authors of a page: each named author of Quarto's `by-author`,
--- in order, with the native keys `photo` and `photo-alt`. A photo with no
--- `photo-alt` is decorative, because the name is next to it.
--- @param meta table The document metadata
--- @param labels table<string, string> The resolved Atelier labels
--- @return Author[] The authors
function M.authors(meta, labels)
  local authors = {}
  for index, author in ipairs(meta['by-author'] or {}) do
    local name = M.author_name(author)
    if name ~= '' then
      local extra = author.metadata or {}
      local entry = {
        index = index,
        name = name,
        url = optional_text(author.url),
        photo_alt = '',
        degrees = {},
        orcid = optional_text(author.orcid),
        email = optional_text(author.email),
        affiliations = {},
        attributes = {},
        note = author.note and optional_text(author.note.text or author.note) or nil,
      }
      local value = text_of(extra.photo)
      if value ~= '' then
        local path = photo_path(value)
        if photo_ok(path, value, name) then
          entry.photo = path
          entry.photo_alt = text_of(extra['photo-alt'])
        end
      end
      for _, degree in ipairs(author.degrees or {}) do
        entry.degrees[#entry.degrees + 1] = text_of(degree)
      end
      for _, affiliation in ipairs(author.affiliations or {}) do
        local affiliation_name = text_of(affiliation.name)
        if affiliation_name ~= '' then
          entry.affiliations[#entry.affiliations + 1] = {
            name = affiliation_name,
            url = optional_text(affiliation.url),
          }
        end
      end
      for _, attribute in ipairs(AUTHOR_ATTRIBUTES) do
        if is_true((author.attributes or {})[attribute.key]) then
          entry.attributes[#entry.attributes + 1] = labels[attribute.label]
        end
      end
      authors[#authors + 1] = entry
    end
  end
  return authors
end

--- Text for a template that puts it in an attribute. Pandoc escapes `&` and
--- `<` in inlines but not `"`, so each `"` becomes a raw entity and the value
--- cannot end the attribute.
--- @param text string
--- @return pandoc.MetaInlines
local function escaped(text)
  local inlines = pandoc.List({})
  local first = true
  for piece in (text .. '"'):gmatch('(.-)"') do
    if not first then
      inlines:insert(pandoc.RawInline('html', '&quot;'))
    end
    first = false
    if piece ~= '' then
      inlines:insert(pandoc.Str(piece))
    end
  end
  return pandoc.MetaInlines(inlines)
end

--- Write the authors as metadata for a template partial: one map for each
--- author, with no key for an absent field, so `$if(...)$` works.
--- @param authors Author[] The authors of `M.authors`
--- @param labels table<string, string> The resolved Atelier labels
--- @param photo_src fun(path: string): string Answers the `src` of a checked photo
--- @return pandoc.List The metadata list
function M.authors_meta(authors, labels, photo_src)
  local list = pandoc.List({})
  for _, author in ipairs(authors) do
    local item = {
      index = pandoc.MetaString(tostring(author.index)),
      name = pandoc.MetaString(author.name),
      url = author.url and escaped(author.url) or nil,
      degrees = #author.degrees > 0 and pandoc.MetaString(table.concat(author.degrees, ', ')) or nil,
      email = author.email and escaped(author.email) or nil,
      note = author.note and pandoc.MetaString(author.note) or nil,
    }
    if author.photo then
      item.photo = escaped(photo_src(author.photo))
      item['photo-alt'] = escaped(author.photo_alt)
    end
    if author.orcid then
      item.orcid = escaped(author.orcid)
      item['orcid-label'] = escaped((labels['author-orcid-profile']:gsub('{name}', function()
        return author.name
      end)))
    end
    if #author.affiliations > 0 then
      local affiliations = pandoc.List({})
      for _, affiliation in ipairs(author.affiliations) do
        affiliations:insert({
          name = pandoc.MetaString(affiliation.name),
          url = affiliation.url and escaped(affiliation.url) or nil,
        })
      end
      item.affiliations = affiliations
    end
    if #author.attributes > 0 then
      item.attributes = pandoc.List(author.attributes):map(pandoc.MetaString)
    end
    list:insert(item)
  end
  return list
end

-- ============================================================================
-- CREDIT
-- ============================================================================

--- The degrees of contribution that have a label of their own.
--- @type table<string, boolean>
local DEGREES = { lead = true, equal = true, supporting = true }

--- Read the contribution roles of the authors, from the `role` field of
--- Quarto's `author` list, which Quarto maps to the CRediT terms. The rows
--- are the roles in order of first use, and each cell holds the label of the
--- degree of contribution of one author: lead, equal, supporting, else
--- contributed, or an empty string when the author has not that role.
--- @param meta table The document metadata
--- @param model table The page model
--- @return { authors: string[], rows: { role: string, cells: string[] }[] }|nil The table, or nil when no author has a role
function M.credit(meta, model)
  local authors, people = {}, {}
  for _, author in ipairs(meta['by-author'] or {}) do
    local name = M.author_name(author)
    if name ~= '' then
      authors[#authors + 1] = name
      people[#people + 1] = author
    end
  end
  local rows, by_role = {}, {}
  for column, author in ipairs(people) do
    for _, role in ipairs(author.roles or {}) do
      local term = text_of(role['vocab-term'] or role.role)
      if term ~= '' then
        local row = by_role[term]
        if row == nil then
          row = { role = term:sub(1, 1):upper() .. term:sub(2), cells = {} }
          for other = 1, #people do
            row.cells[other] = ''
          end
          by_role[term] = row
          rows[#rows + 1] = row
        end
        local degree = text_of(role['degree-of-contribution']):lower()
        row.cells[column] = model.labels['credit-' .. (DEGREES[degree] and degree or 'contributed')]
      end
    end
  end
  if #rows == 0 then
    return nil
  end
  return { authors = authors, rows = rows }
end

--- Build the CRediT table as a pandoc table: a header row with the role
--- label and the author names, then one row for each role, whose first cell
--- is a row header.
--- @param credit table The table of `M.credit`
--- @param labels table<string, string> The resolved labels
--- @return pandoc.Table
function M.credit_table(credit, labels)
  local function cell(text, scope)
    local attr = scope and pandoc.Attr('', {}, { scope = scope }) or pandoc.Attr()
    return pandoc.Cell(pandoc.Blocks({ pandoc.Plain(pandoc.Inlines(text)) }), pandoc.AlignDefault, 1, 1, attr)
  end
  local head = { cell(labels['credit-role'], 'col') }
  local specs = { { pandoc.AlignLeft, pandoc.ColWidthDefault } }
  for _, name in ipairs(credit.authors) do
    head[#head + 1] = cell(name, 'col')
    specs[#specs + 1] = { pandoc.AlignCenter, pandoc.ColWidthDefault }
  end
  local body = {}
  for _, row in ipairs(credit.rows) do
    local cells = { cell(row.role, 'row') }
    for _, text in ipairs(row.cells) do
      cells[#cells + 1] = cell(text)
    end
    body[#body + 1] = pandoc.Row(cells)
  end
  return pandoc.Table(
    { long = {}, short = {} },
    specs,
    pandoc.TableHead({ pandoc.Row(head) }),
    { { attr = pandoc.Attr(), body = body, head = {}, row_head_columns = 1 } },
    pandoc.TableFoot()
  )
end

-- ============================================================================
-- CLOSING
-- ============================================================================

--- Turn a metadata value into inlines.
--- @param value any A string, inlines or blocks
--- @return pandoc.Inlines
local function to_inlines(value)
  local kind = pandoc.utils.type(value)
  if kind == 'Inlines' then
    return value
  elseif kind == 'Blocks' then
    return pandoc.utils.blocks_to_inlines(value)
  end
  return pandoc.Inlines(text_of(value))
end

--- Stop the build with an error about a key of `extensions.atelier.closing`.
--- Quarto replaces the global `error` with a function that only logs, so the
--- build stops with `os.exit`.
--- @param message string The message
local function closing_error(message)
  log.log_error(EXTENSION_NAME, 'extensions.atelier.closing: ' .. message)
  os.exit(1)
end

--- Read an on and off switch of the closing: `true` when it is not set.
--- @param options table The closing options
--- @param key string The key
--- @param source string The Quarto key that gives the text
--- @return boolean
local function closing_switch(options, key, source)
  local value = options[key]
  if value == nil then
    return true
  end
  if type(value) ~= 'boolean' then
    closing_error('`' .. key .. '` accepts only true or false. The text comes from the Quarto `' .. source .. '`.')
  end
  return value
end

--- Answer a metadata value as inlines, or nil when it is empty.
--- @param value any The value
--- @return pandoc.Inlines|nil
local function inlines_or_nil(value)
  return text_of(value) ~= '' and to_inlines(value) or nil
end

--- Answer the copyright of the document: the `copyright` string, its
--- `statement`, or "© year holder".
--- @param value any The Quarto `copyright`
--- @return pandoc.Inlines|nil
local function copyright_text(value)
  if pandoc.utils.type(value) ~= 'table' then
    return inlines_or_nil(value)
  end
  if value.statement ~= nil then
    return inlines_or_nil(value.statement)
  end
  if value.holder == nil then
    return nil
  end
  local inlines = pandoc.Inlines({ pandoc.Str('©'), pandoc.Space() })
  if text_of(value.year) ~= '' then
    inlines:extend(to_inlines(value.year))
    inlines:insert(pandoc.Space())
  end
  inlines:extend(to_inlines(value.holder))
  return inlines
end

--- Answer the licence of the document: the `license` string, its `text`, or
--- its `type`, as `typst/typst-show.typ` reads it for the PDF frame.
--- @param value any The Quarto `license`
--- @return pandoc.Inlines|nil
local function licence_text(value)
  if pandoc.utils.type(value) == 'table' then
    value = value.text or value.type
  end
  return inlines_or_nil(value)
end

--- Answer the content of the closing: the Markdown of `text`, or of the file
--- at `file`, relative to the folder of the document.
--- @param options table The closing options
--- @return pandoc.Blocks|nil
local function closing_content(options)
  if options.text ~= nil and options.file ~= nil then
    closing_error('`text` and `file` are both set. Set one of them.')
  end
  if options.text ~= nil then
    -- Pandoc reads a metadata string as Markdown already.
    local kind = pandoc.utils.type(options.text)
    if kind == 'Blocks' then
      return options.text
    elseif kind == 'Inlines' then
      return pandoc.Blocks({ pandoc.Para(options.text) })
    end
    return pandoc.read(text_of(options.text), 'markdown').blocks
  end
  if options.file == nil then
    return nil
  end
  local path = document_file(text_of(options.file))
  local handle = io.open(path, 'r')
  if handle == nil then
    closing_error('the file of `file` does not exist: ' .. path .. '.')
  end
  local markdown = handle:read('a')
  handle:close()
  return pandoc.read(markdown, 'markdown').blocks
end

--- Read the closing of a workshop page from `extensions.atelier.closing`:
--- `true`, or a map with `title`, `text` or `file`, `links`, `copyright` and
--- `licence`. The title is the closing label by default. The copyright and
--- the licence are the Quarto `copyright` and `license`, and each of
--- `copyright: false` and `licence: false` hides its line. A part that the
--- format shows elsewhere, `true` in `shown`, is left out whatever its switch.
--- @param meta table The document metadata
--- @param model table The page model
--- @param shown { copyright: boolean, licence: boolean }|nil The parts that the format shows elsewhere
--- @return { title: pandoc.Inlines, content: pandoc.Blocks|nil, links: pandoc.Inlines[], copyright: pandoc.Inlines|nil, licence: pandoc.Inlines|nil }|nil The closing, or nil when unset
function M.closing(meta, model, shown)
  local value = model.options.closing
  if value == nil or value == false then
    return nil
  end
  local options = type(value) == 'table' and value or {}
  local closing = {
    title = options.title and to_inlines(options.title) or pandoc.Inlines(model.labels['closing-thanks']),
    content = closing_content(options),
    links = {},
  }
  for _, link in ipairs(options.links or {}) do
    closing.links[#closing.links + 1] = to_inlines(link)
  end
  shown = shown or {}
  if closing_switch(options, 'copyright', 'copyright') and not shown.copyright then
    closing.copyright = copyright_text(meta.copyright)
  end
  if closing_switch(options, 'licence', 'license') and not shown.licence then
    closing.licence = licence_text(meta.license)
  end
  return closing
end

local project_in_book = nil

--- Answer whether the page is a chapter of a Quarto book. A filter does not
--- get `book` in the document metadata, so it also comes from the project
--- metadata.
--- @param meta table The document metadata
--- @return boolean
function M.in_book(meta)
  if meta.book ~= nil then
    return true
  end
  if project_in_book == nil then
    local project = meta_mod.get_project_metadata()
    project_in_book = project ~= nil and project.book ~= nil
  end
  return project_in_book
end

--- Answer which of the copyright and the licence Quarto shows in its HTML
--- appendix, as Copyright and Reuse. Quarto shows no appendix in a book or
--- with `appendix-style` `none` or `false`. It shows the copyright only as a
--- string or a `statement`, and the licence only as a string, a list or a
--- `text`.
--- @param meta table The document metadata
--- @return { copyright: boolean, licence: boolean }
function M.appendix_rights(meta)
  local none = { copyright = false, licence = false }
  local style = meta['appendix-style']
  if style == false or text_of(style) == 'none' or text_of(style) == 'false' or M.in_book(meta) then
    return none
  end
  local function shown(value, key)
    if pandoc.utils.type(value) == 'table' then
      value = value[key]
    end
    return text_of(value) ~= ''
  end
  return {
    copyright = shown(meta.copyright, 'statement'),
    licence = shown(meta.license, 'text'),
  }
end

--- Build the parts of the closing after its heading: the content, the links
--- as a list, the copyright and the licence, each in a div of its own class.
--- @param closing table The closing of `M.closing`
--- @return pandoc.Blocks
function M.closing_parts(closing)
  local blocks = pandoc.Blocks({})
  if closing.content ~= nil then
    blocks:insert(pandoc.Div(closing.content, pandoc.Attr('', { 'atelier-closing-content' })))
  end
  if #closing.links > 0 then
    local items = {}
    for _, link in ipairs(closing.links) do
      items[#items + 1] = { pandoc.Plain(link) }
    end
    blocks:insert(pandoc.Div({ pandoc.BulletList(items) }, pandoc.Attr('', { 'atelier-closing-links' })))
  end
  for _, part in ipairs({ 'copyright', 'licence' }) do
    if closing[part] ~= nil then
      blocks:insert(pandoc.Div({ pandoc.Para(closing[part]) }, pandoc.Attr('', { 'atelier-closing-' .. part })))
    end
  end
  return blocks
end

-- ============================================================================
-- FUNDING
-- ============================================================================

--- @class Award
--- @field source pandoc.Inlines|nil The sources, joined with ', '
--- @field id string|nil The award id
--- @field recipients pandoc.Inlines|nil The names or institutions, joined with ', '

--- @class Funding
--- @field statements pandoc.Inlines[] One for each funding group with a statement
--- @field awards Award[]

--- Answer the text of one source or recipient as Quarto normalises it:
--- `{ text }`, `{ name }` or `{ institution }`.
--- @param entry table The entry
--- @return string
local function funder_text(entry)
  if entry.name ~= nil then
    return M.author_name(entry)
  elseif entry.institution ~= nil then
    return text_of(entry.institution.name or entry.institution)
  end
  return text_of(entry.text)
end

--- Join the texts of a list of sources or recipients with ', ', or answer
--- nil when none has a text.
--- @param entries table|nil The entries
--- @return pandoc.Inlines|nil
local function funder_list(entries)
  local names = {}
  for _, entry in ipairs(entries or {}) do
    local name = funder_text(entry)
    if name ~= '' then
      names[#names + 1] = name
    end
  end
  if #names == 0 then
    return nil
  end
  return pandoc.Inlines(table.concat(names, ', '))
end

--- Read the funding of the document from the Quarto `funding` key, which
--- Quarto normalises into a list of groups, each with a `statement` and
--- `awards`. The `open-access` key is not shown.
--- @param meta table The document metadata
--- @return Funding|nil The funding, or nil when there is no statement and no award
function M.funding(meta)
  local funding = { statements = {}, awards = {} }
  for _, group in ipairs(meta.funding or {}) do
    if text_of(group.statement) ~= '' then
      funding.statements[#funding.statements + 1] = to_inlines(group.statement)
    end
    for _, raw in ipairs(group.awards or {}) do
      local id = text_of(raw.id)
      local award = {
        source = funder_list(raw.source),
        id = id ~= '' and id or nil,
        recipients = funder_list(raw.recipient),
      }
      if award.source ~= nil or award.id ~= nil or award.recipients ~= nil then
        funding.awards[#funding.awards + 1] = award
      end
    end
  end
  if #funding.statements == 0 and #funding.awards == 0 then
    return nil
  end
  return funding
end

--- Build the funding blocks: one paragraph for each statement, then a list
--- with one item for each award: the source, the id in parentheses, and the
--- recipients after the `funding-recipient` label. Each writer adds its own
--- heading.
--- @param funding Funding The funding of `M.funding`
--- @param labels table<string, string> The resolved labels
--- @return pandoc.Blocks
function M.funding_blocks(funding, labels)
  local blocks = pandoc.Blocks({})
  for _, statement in ipairs(funding.statements) do
    blocks:insert(pandoc.Para(statement))
  end
  local items = {}
  for _, award in ipairs(funding.awards) do
    local parts = {}
    if award.source ~= nil then
      parts[#parts + 1] = pandoc.utils.stringify(award.source)
    end
    if award.id ~= nil then
      parts[#parts + 1] = '(' .. award.id .. ')'
    end
    local text = table.concat(parts, ' ')
    if award.recipients ~= nil then
      local recipient = labels['funding-recipient']:gsub('{names}', function()
        return pandoc.utils.stringify(award.recipients)
      end)
      text = text == '' and recipient or text .. ', ' .. recipient
    end
    items[#items + 1] = { pandoc.Plain(pandoc.Inlines(text)) }
  end
  if #items > 0 then
    blocks:insert(pandoc.BulletList(items))
  end
  return blocks
end

-- ============================================================================
-- COURSE MODEL
-- ============================================================================

--- Normalise a path: forward slashes, no `.` parts, and `..` parts folded.
--- A leading `/` marks a path from the project root and is dropped.
--- @param path string The path
--- @return string The normalised path
local function normalise_path(path)
  local parts = {}
  for part in path:gsub('\\', '/'):gmatch('[^/]+') do
    if part == '..' and #parts > 0 and parts[#parts] ~= '..' then
      table.remove(parts)
    elseif part ~= '.' then
      parts[#parts + 1] = part
    end
  end
  return table.concat(parts, '/')
end

--- The input file, relative to the project folder, with forward slashes.
--- @return string The relative path, or the input file when it is outside the project
local function project_relative_input()
  local input = normalise_path(quarto.doc.input_file or '')
  local directory = quarto.project.directory
  if directory == nil then
    return input
  end
  directory = normalise_path(directory):gsub('/$', '') .. '/'
  if input:sub(1, #directory) == directory then
    return input:sub(#directory + 1)
  end
  return input
end

--- What the render knows about each file, by path.
--- Each entry holds `exists`, `read` (true once the front matter is read), and `meta`.
--- @type table<string, { exists: boolean, read: boolean, meta: table|nil }>
local files = {}

--- Tell if a file exists.
--- @param path string The file path
--- @return boolean True when the file opens
local function file_exists(path)
  local entry = files[path]
  if entry == nil then
    local file = io.open(path, 'r')
    entry = { exists = file ~= nil, read = false }
    if file ~= nil then
      file:close()
    end
    files[path] = entry
  end
  return entry.exists
end

--- Resolve a sidebar path to a project path.
--- Quarto rewrites the paths of existing files relative to the page, so the
--- path is joined to the folder of the page. A path that does not exist that
--- way is already relative to the project, as Quarto leaves missing files
--- alone. A leading `/` marks a path from the project root.
--- @param path string The path as the metadata holds it
--- @param base string The folder of the page, relative to the project
--- @return string The project path
local function resolve_path(path, base)
  if path:sub(1, 1) == '/' then
    return normalise_path(path)
  end
  local joined = normalise_path(base .. '/' .. path)
  if not file_exists((quarto.project.directory or '.') .. '/' .. joined) then
    return normalise_path(path)
  end
  return joined
end

--- Tell if a sidebar path is a URL with a scheme, such as `https://example.org`.
--- @param path string The path
--- @return boolean True when the path is a URL
local function is_url(path)
  return path:match('^%a[%w+.-]*:') ~= nil
end

--- Add a sidebar path to a list, unless it is a URL or holds a `*`.
--- @param path string The path as the metadata holds it
--- @param base string The folder of the page, relative to the project
--- @param paths string[] The list that receives the path
--- @return nil
local function add_path(path, base, paths)
  if not path:find('*', 1, true) and not is_url(path) then
    paths[#paths + 1] = resolve_path(path, base)
  end
end

--- Collect the file paths of a sidebar `contents` tree, in order.
--- An item is a path string, a map with `href` or its alias `file`, or a map
--- with `section` and `contents`. An item with `auto`, a `*`, or a URL is
--- skipped.
--- @param contents table The contents list
--- @param base string The folder of the page, relative to the project
--- @param paths string[] The list that receives the paths
--- @return string[] The paths
local function collect_paths(contents, base, paths)
  for _, item in ipairs(contents) do
    local kind = pandoc.utils.type(item)
    if kind == 'Inlines' or kind == 'string' or kind == 'Blocks' then
      add_path(pandoc.utils.stringify(item), base, paths)
    elseif type(item) == 'table' and item.auto == nil then
      local href = item.href or item.file
      if href ~= nil then
        add_path(pandoc.utils.stringify(href), base, paths)
      end
      if type(item.contents) == 'table' then
        collect_paths(item.contents, base, paths)
      end
    end
  end
  return paths
end

--- Find the first sidebar in `extensions.atelier.sidebars` that lists the page.
--- @param options table The `extensions.atelier` options
--- @param page string The page path relative to the project
--- @return string|nil The sidebar id
--- @return string[]|nil The file paths of that sidebar
local function find_sidebar(options, page)
  if type(options.sidebars) ~= 'table' then
    return nil, nil
  end
  local base = page:match('^(.*)/[^/]*$') or ''
  for _, sidebar in ipairs(options.sidebars) do
    if type(sidebar) == 'table' and type(sidebar.contents) == 'table' then
      local paths = collect_paths(sidebar.contents, base, {})
      for _, path in ipairs(paths) do
        if path == page then
          return M.strip_rewrite(pandoc.utils.stringify(sidebar.id or '')), paths
        end
      end
    end
  end
  return nil, nil
end

--- Read the YAML text of the front matter of an open file.
--- The read stops at the closing `---`.
--- @param file file* The open file
--- @return string|nil The YAML text, or nil when the file has no front matter
local function read_yaml(file)
  local first = file:read('l')
  if first == nil or first:gsub('\r$', '') ~= '---' then
    return nil
  end
  local lines = {}
  for raw in file:lines() do
    local line = raw:gsub('\r$', '')
    if line:match('^%-%-%-[ \t]*$') then
      return table.concat(lines, '\n')
    end
    lines[#lines + 1] = line
  end
  return nil
end

--- Read the front matter of a page file as metadata, once per render.
--- The YAML is parsed only when it mentions `duration`.
--- A front matter that pandoc cannot read logs one warning and gives no metadata.
--- @param path string The file path
--- @param report boolean True to log the warning when the front matter cannot be read
--- @return table|nil The metadata, or nil when the file has no front matter or it cannot be read
--- @return boolean True when the file exists
local function read_front_matter(path, report)
  local entry = files[path]
  if entry ~= nil and (entry.read or not entry.exists) then
    return entry.meta, entry.exists
  end
  local file = io.open(path, 'r')
  if file == nil then
    files[path] = { exists = false, read = true }
    return nil, false
  end
  local yaml = read_yaml(file)
  file:close()
  local meta = nil
  if yaml ~= nil then
    if yaml:find('duration', 1, true) then
      local ok, document = pcall(pandoc.read, '---\n' .. yaml .. '\n---\n', 'markdown')
      if ok then
        meta = document.meta
      elseif report then
        log.log_warning(
          EXTENSION_NAME,
          path .. ': its front matter could not be read; its duration is ignored. ' ..
          'Correct the YAML of that file.'
        )
      end
    else
      meta = pandoc.Meta({})
    end
  end
  files[path] = { exists = true, read = true, meta = meta }
  return meta, true
end

--- Tell whether the extension of a page is in a set of extensions.
--- The letter case of the extension has no effect, so `.Rmd` and `.rmd` match.
--- @param path string The page path
--- @param extensions table<string, boolean> The set, such as `FRONT_MATTER_EXTENSIONS`
--- @return boolean True when the extension of the page is in the set
local function has_extension(path, extensions)
  local extension = path:match('%.(%w+)$')
  return extension ~= nil and extensions[extension:lower()] == true
end

--- Find the page of a sidebar that logs the warnings for the whole sidebar.
--- Each page renders on its own, so one page must log each problem. It is the
--- first page that exists and that Quarto renders through this filter, because
--- only such a page can be in workshop mode and read the sidebar.
--- @param paths string[] The page paths relative to the project
--- @param directory string The project folder
--- @return string|nil The path of that page, or nil when there is none
local function reporting_page(paths, directory)
  for _, path in ipairs(paths) do
    if has_extension(path, RENDERED_EXTENSIONS) and file_exists(directory .. '/' .. path) then
      return path
    end
  end
  return nil
end

--- Read the duration of each page of a sidebar.
--- Each page of the sidebar reads all the durations, so each problem must log
--- one warning only. The render of a page warns for its own duration. The
--- render of the page that `reporting_page` gives warns for the files that do
--- not exist.
--- @param paths string[] The page paths relative to the project
--- @param page string The page path relative to the project
--- @return table<string, integer> The minutes by output path
local function read_durations(paths, page)
  local durations = {}
  local directory = quarto.project.directory or '.'
  local first = reporting_page(paths, directory)
  for _, path in ipairs(paths) do
    if has_extension(path, FRONT_MATTER_EXTENSIONS) then
      local meta, exists = read_front_matter(directory .. '/' .. path, page == first)
      if not exists then
        if page == first then
          log.log_warning(
            EXTENSION_NAME,
            'extensions.atelier.sidebars lists ' .. path .. ', but that file does not exist. ' ..
            'Correct the path or remove the entry from the sidebar.'
          )
        end
      elseif meta ~= nil then
        local minutes = M.read_duration(meta, path, true)
        if minutes ~= nil then
          durations[path:gsub('%.%w+$', '.html')] = minutes
        end
      end
    end
  end
  return durations
end

--- Log the warning for a listed sidebar that has no id.
--- Each page of the sidebar finds the same problem, so only the page that
--- `reporting_page` gives warns.
--- @param source string The input file, for the warning
--- @param paths string[] The page paths of the sidebar
--- @param page string The page path relative to the project
--- @return nil
local function warn_sidebar_without_id(source, paths, page)
  if page ~= reporting_page(paths, quarto.project.directory or '.') then
    return nil
  end
  log.log_warning(
    EXTENSION_NAME,
    source .. ' is listed in a sidebar of extensions.atelier.sidebars that has no id, ' ..
    'so its progress is not stored. Give its website.sidebar entry an id, ' ..
    'for example `id: course`, so progress can be stored.'
  )
end

--- Read the course model of a workshop page: the sidebar of
--- `extensions.atelier.sidebars` that lists the page, and the durations of
--- the pages of that sidebar. Logs the warnings of the sidebar list.
--- A page that no listed sidebar holds, such as `404.qmd`, gets no sidebar
--- data and shows no course.
--- @param model table The page model of `M.page`
--- @return { listed: boolean, sidebar: string|nil, durations: table<string, integer>|nil } The course
function M.course(model)
  local options, source = model.options, model.source
  local page = project_relative_input()
  if type(options.sidebars) ~= 'table' or next(options.sidebars) == nil then
    log.log_warning(
      EXTENSION_NAME,
      source .. ' is in workshop mode, but extensions.atelier.sidebars lists no sidebar, so no page shows the course. ' ..
      'Add a YAML anchor to the website.sidebar entry of the workshop and list the alias in extensions.atelier.sidebars.'
    )
  end
  local course = { listed = false }
  local sidebar, paths = find_sidebar(options, page)
  if sidebar ~= nil then
    course.listed = true
    if sidebar == '' then
      warn_sidebar_without_id(source, paths, page)
    else
      course.sidebar = sidebar
    end
    local durations = read_durations(paths, page)
    if next(durations) ~= nil then
      course.durations = durations
    end
  end
  return course
end

-- ============================================================================
-- BLOCKS
-- ============================================================================

--- Read the duration attribute of a block.
--- @param div pandoc.Div The block
--- @param class string The block class, for the warning
--- @param labels table<string, string> The resolved labels
--- @return string|nil The formatted duration, or nil when absent or invalid
local function attribute_duration(div, class, labels)
  local text = div.attributes.duration
  if text == nil then
    return nil
  end
  local minutes = M.parse_duration(text)
  if minutes == nil then
    warn_duration('The duration attribute of the .' .. class .. ' block', text, quarto.doc.input_file or '')
    return nil
  end
  return M.format_duration(minutes, labels)
end

--- Collect the author's classes and attributes of a workshop div: every class
--- but the div class, and every attribute but `title` and `duration`, as the
--- head shows them.
--- @param div pandoc.Div The div
--- @param class string The div class, such as `objectives`
--- @return table classes The other classes
--- @return table attributes The other attributes
function M.other_attr(div, class)
  local classes = {}
  for _, name in ipairs(div.classes) do
    if name ~= class then
      classes[#classes + 1] = name
    end
  end
  local attributes = {}
  for _, pair in ipairs(div.attributes) do
    if pair[1] ~= 'title' and pair[1] ~= 'duration' then
      attributes[#attributes + 1] = pair
    end
  end
  return classes, attributes
end

--- Read the objectives block. The objectives are the items of the first
--- bullet list of the block.
--- A block with no bullet list logs a warning.
--- @param div pandoc.Div The `.objectives` div
--- @param model table The page model
--- @return { title: string, time: string|nil, blocks: pandoc.Blocks, list: integer|nil } The block: `list` is the position of the objectives list in `blocks`. A position, not the node: pandoc nodes compare by content, so two equal lists would both match.
function M.objectives(div, model)
  local time = attribute_duration(div, 'objectives', model.labels)
  if div.attributes.duration == nil and model.duration ~= nil then
    time = M.format_duration(model.duration, model.labels)
  end
  local list = nil
  for position, block in ipairs(div.content) do
    if block.t == 'BulletList' then
      list = position
      break
    end
  end
  if list == nil then
    log.log_warning(
      EXTENSION_NAME,
      'The .objectives block in ' .. (quarto.doc.input_file or '') .. ' has no bullet list, so it lists no objectives. ' ..
      'Write each objective as an item of a bullet list.'
    )
  end
  return {
    title = div.attributes.title or model.labels['objectives-title'],
    time = time,
    blocks = div.content,
    list = list,
  }
end

--- Split an objective item into its text and its further blocks.
--- @param item pandoc.Blocks The list item
--- @return pandoc.Inlines text The text of the first paragraph, empty when the item starts with another block
--- @return integer rest The position of the first further block in the item
function M.objective_text(item)
  local first = item[1]
  if first ~= nil and (first.t == 'Plain' or first.t == 'Para') then
    return first.content, 2
  end
  return pandoc.Inlines({}), 1
end

--- The blocks with a head line and a body, other than the objectives, by
--- class, with the Bootstrap Icons name of the icon of each one.
--- @type table<string, string>
M.BLOCKS = {
  prerequisites = 'list-check',
  checkpoint = 'flag',
  exercise = 'pencil-square',
}

--- The classes of `M.BLOCKS`, in the order that `M.block_kind` tries them.
--- @type string[]
local BLOCK_ORDER = { 'prerequisites', 'checkpoint', 'exercise' }

--- Answer the class of the first block of `M.BLOCKS` that a div has, in the
--- order prerequisites, checkpoint, exercise.
--- @param div pandoc.Div The div
--- @return string|nil The class, or nil when the div is no such block
function M.block_kind(div)
  for _, kind in ipairs(BLOCK_ORDER) do
    if div.classes:includes(kind) then
      return kind
    end
  end
  return nil
end

--- Read a block of `M.BLOCKS`: the `title` attribute, else the label of the
--- kind, and the `duration` attribute.
--- @param div pandoc.Div The div
--- @param kind string The class, a key of `M.BLOCKS`
--- @param model table The page model
--- @return { title: string, time: string|nil, blocks: pandoc.Blocks } The block
function M.block(div, kind, model)
  return {
    title = div.attributes.title or model.labels[kind .. '-title'],
    time = attribute_duration(div, kind, model.labels),
    blocks = div.content,
  }
end

--- Read an answer block: a div with the class `answer`, in every mode.
--- The title is the `title` attribute, else the `name` attribute, else the
--- text of a leading heading, which then leaves the body, else nil, and each
--- writer gives its own label. The `name` attribute leaves the div.
--- @param div pandoc.Div The div
--- @param model table The page model
--- @return { title: string|nil, identifier: string, div: pandoc.Div, blocks: pandoc.Blocks }|nil The answer, or nil when the div is not an answer
function M.answer(div, model)
  if not div.classes:includes('answer') then
    return nil
  end
  local blocks = div.content
  local title = div.attributes.title or div.attributes.name
  div.attributes.name = nil
  if title == nil and #blocks > 0 and blocks[1].t == 'Header' then
    title = pandoc.utils.stringify(blocks[1])
    blocks = pandoc.Blocks({ table.unpack(blocks, 2) })
  end
  return {
    title = not str.is_empty(title) and title or nil,
    identifier = div.identifier or '',
    div = div,
    blocks = blocks,
  }
end

--- Leave an answer with a `sol-` identifier to Quarto. Quarto turns every
--- div with a `sol-` identifier into its own solution before Atelier sees
--- it, so the div stays a Quarto solution: this drops the `answer` class, so
--- the block pass leaves the div alone, and warns once so the author learns
--- why. It must run in a pass before the block pass, while the slot of the
--- node is still a div. The pass visits each node once, so each warns once.
--- @param proof table The `Proof` node
--- @return table|nil The node without the `answer` class, or nil to keep it
function M.release_answer_id(proof)
  local identifier = proof.identifier or ''
  local div = proof.div
  if pandoc.utils.type(div) ~= 'Block' or div.t ~= 'Div' or not div.classes:includes('answer') or not identifier:find('^sol%-') then
    return nil
  end
  div.classes = div.classes:filter(function(class)
    return class ~= 'answer'
  end)
  proof.div = div
  log.log_warning(
    EXTENSION_NAME,
    "The answer block with the id '" .. identifier .. "' in " .. (quarto.doc.input_file or '') ..
    ' is a Quarto solution, because Quarto reads every div with a sol- id as one. ' ..
    'Remove the id to make it an answer, or use .solution for a Quarto cross-reference.'
  )
  return proof
end

--- Pandoc can highlight a language when it names the language on the `code`
--- element of a block. A class that only turns on line numbers gives a
--- `sourceCode` class with no language after it.
--- @type table<string, boolean>
local highlights = {}

--- Check that a code block has a class that names a language Pandoc can
--- highlight.
--- @param block pandoc.CodeBlock The code block
--- @return boolean
local function has_highlighted_class(block)
  for _, class in ipairs(block.classes) do
    if highlights[class] == nil then
      local html = pandoc.write(pandoc.Pandoc({ pandoc.CodeBlock('x', { class = class }) }), 'html')
      highlights[class] = html:find('<code%s+class="sourceCode%s+[^"]') ~= nil
    end
    if highlights[class] then
      return true
    end
  end
  return false
end

--- Read a `.terminal` code block.
--- Each line that starts with `$` and a space loses those two characters, and
--- its number joins `prompts`. A line that is only `$`, with or without
--- spaces after it, becomes one space and is a prompt line too.
--- A command that ends with `\` goes on to the next line. The numbers of these
--- next lines join `continuations`. An indented `$` line is output, as in
--- usage text.
--- A block with no class that Pandoc can highlight cannot show the prompt, so
--- the reader logs a warning and gives nil.
--- @param block pandoc.CodeBlock The code block
--- @return { text: string, prompts: string[], continuations: string[] }|nil The terminal, or nil when the block is not a terminal
function M.terminal(block)
  if not block.classes:includes('terminal') then
    return nil
  end
  if not has_highlighted_class(block) then
    log.log_warning(
      EXTENSION_NAME,
      'The .terminal block in ' .. (quarto.doc.input_file or '') .. ' has no language class, so it is not highlighted and shows no prompt. ' ..
      'Add a language class such as `bash`, for example `{.bash .terminal}`.'
    )
    return nil
  end
  local lines = {}
  local prompts = {}
  local continuations = {}
  local continued = false
  local number = 0
  for line in (block.text .. '\n'):gmatch('(.-)\n') do
    number = number + 1
    local command = true
    if continued then
      continuations[#continuations + 1] = tostring(number)
    elseif line:match('^%$%s*$') then
      -- A space, not an empty line: the highlighter drops an empty last line.
      line = ' '
      prompts[#prompts + 1] = tostring(number)
    elseif line:sub(1, 2) == '$ ' then
      line = line:sub(3)
      prompts[#prompts + 1] = tostring(number)
    else
      command = false
    end
    continued = command and line:sub(-1) == '\\'
    lines[#lines + 1] = line
  end
  return { text = table.concat(lines, '\n'), prompts = prompts, continuations = continuations }
end

return M
