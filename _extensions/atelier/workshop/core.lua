--- Atelier - Workshop Core
--- @module "workshop/core"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief The format-neutral part of the workshop mode.
--- @description Reads the page model (mode, duration, labels), the course
--- model (the sidebar that lists the page and the durations of its pages),
--- and the workshop blocks (objectives, exercise, solution, terminal). Each
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
  'solution-summary',
  'terminal',
  'workshop-author-single',
  'workshop-author-plural',
  'workshop-published',
  'workshop-modified',
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
  return {
    options = M.read_options(meta),
    mode = M.read_mode(meta, source),
    duration = M.read_duration(meta, source),
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

--- Answer the class of the first block of `M.BLOCKS` that a div has, in the
--- order prerequisites, checkpoint, exercise.
--- @param div pandoc.Div The div
--- @return string|nil The class, or nil when the div is no such block
function M.block_kind(div)
  for _, kind in ipairs({ 'prerequisites', 'checkpoint', 'exercise' }) do
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

--- Tell whether a `Proof` node is a solution: Quarto's `Proof` of type
--- `Solution`, from a `.solution` div or a `sol-` identifier.
--- @param proof table The `Proof` node
--- @return boolean
function M.is_solution(proof)
  return pandoc.utils.stringify(proof.type or ''):lower() == 'solution'
end

--- Tell whether a `Proof` node is a workshop solution, which the workshop
--- hides. Quarto turns a `.solution` div into a `Proof` node of type
--- `Solution` before the `pre-quarto` filters run, and removes the class.
--- A solution with a `sol-` identifier is a cross-reference target and stays
--- shown.
--- @param proof table The `Proof` node
--- @return boolean True when the node is a workshop solution
function M.is_workshop_solution(proof)
  if (proof.identifier or ''):find('^sol%-') then
    return false
  end
  return M.is_solution(proof)
end

--- Read a solution from the `Proof` node that Quarto makes of a `.solution`
--- div, in workshop mode only. Quarto removes the class, so the node keeps
--- the div in `div`.
--- The title is the `title` attribute, else the name that Quarto took from
--- the `name` attribute or a leading heading, else the label.
--- @param proof table The `Proof` node
--- @param model table The page model
--- @return { title: string, identifier: string, div: pandoc.Div }|nil The solution, or nil when the node is not a workshop solution
function M.solution(proof, model)
  if model.mode ~= M.MODE_WORKSHOP or not M.is_workshop_solution(proof) then
    return nil
  end
  local title = proof.div.attributes.title
  if title == nil then
    local name = pandoc.utils.stringify(proof.name or '')
    title = name ~= '' and name or model.labels['solution-summary']
  end
  return { title = title, identifier = proof.identifier or '', div = proof.div }
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
