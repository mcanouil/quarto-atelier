--- Atelier - Workshop Options Filter
--- @module "atelier-workshop"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Publish the workshop mode, page duration, and sidebar data.
--- @description Writes one JSON block into the head of each HTML page. It
--- holds the mode from `extensions.atelier.mode`, the project offset, the
--- translated labels, and, in workshop mode, the page duration, the sidebar
--- that lists the page, and the durations of every page in that sidebar.
--- A workshop page also gets the `atelier-workshop` class on `<html>`.

--- Load modules
local str = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))
local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))
local meta_mod = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))

--- Modes that `extensions.atelier.mode` accepts.
--- @type string
local MODE_DOCUMENTATION = 'documentation'
--- @type string
local MODE_WORKSHOP = 'workshop'

--- Name that prefixes each warning.
--- @type string
local EXTENSION_NAME = 'atelier'

--- Page file extensions whose front matter holds a duration.
--- @type table<string, boolean>
local FRONT_MATTER_EXTENSIONS = { qmd = true, md = true, Rmd = true }

--- Labels and their default text, in output order.
--- @type table<integer, { key: string, default: string }>
local LABELS = {
  { key = 'duration-minutes', default = '{m} min' },
  { key = 'duration-hours', default = '{h} h' },
  { key = 'duration-hours-minutes', default = '{h} h {m} min' },
  { key = 'reading-bar', default = 'Reading navigation' },
  { key = 'reading-progress', default = 'Reading progress' },
  { key = 'reading-position', default = 'Page {n} of {m}' },
  { key = 'workshop-bar', default = 'Module navigation' },
  { key = 'workshop-progress', default = 'Workshop progress' },
  { key = 'workshop-position', default = 'Module {n} of {m}' },
  { key = 'workshop-total', default = 'about {time}' },
  { key = 'workshop-completed', default = '(completed)' },
  { key = 'previous', default = 'Previous' },
  { key = 'next', default = 'Next' },
  { key = 'timer-label', default = 'Session time left' },
  { key = 'timer-pause', default = 'Pause the session timer' },
  { key = 'toc-read', default = '(read)' },
  { key = 'toc-module-read', default = '{n}% of this module read' },
  { key = 'objectives-title', default = 'By the end of this module, you can' },
  { key = 'exercise-title', default = 'Exercise' },
  { key = 'solution-summary', default = 'Show the solution' },
  { key = 'terminal', default = 'Terminal' },
}

--- Resolve every label, taking a non-empty `language` override over the default.
--- @return table<string, string> The label text by key
local function resolve_labels()
  local language = quarto.doc.language or {}
  local labels = {}
  for _, label in ipairs(LABELS) do
    local value = language['atelier-' .. label.key]
    if type(value) == 'string' and value ~= '' then
      labels[label.key] = value
    else
      labels[label.key] = label.default
    end
  end
  return labels
end

--- Parse a duration into minutes.
--- Accepts `25 min`, `25min`, `1 h`, `1h`, `1 h 30 min`, `1h30min`, and a
--- bare number, which counts as minutes.
--- @param text string The duration text
--- @return integer|nil The minutes, or nil when the text is not a duration
local function parse_duration(text)
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
local function format_duration(minutes, labels)
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

--- Read the `extensions.atelier` table of a metadata table.
--- @param meta table The metadata
--- @return table The options, empty when unset
local function read_options(meta)
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
local function read_duration(meta, source, quiet)
  local value = read_options(meta).duration
  if value == nil then
    return nil
  end
  local text = pandoc.utils.stringify(value)
  local minutes = parse_duration(text)
  if minutes == nil and not quiet then
    warn_duration('extensions.atelier.duration', text, source)
  end
  return minutes
end

--- Read the mode option, falling back to documentation with a warning.
--- @param meta table The metadata
--- @param source string The input file, for the warning
--- @return string The mode
local function read_mode(meta, source)
  local value = read_options(meta).mode
  if value == nil then
    return MODE_DOCUMENTATION
  end
  local text = pandoc.utils.stringify(value)
  if text == MODE_DOCUMENTATION or text == MODE_WORKSHOP then
    return text
  end
  log.log_warning(
    EXTENSION_NAME,
    'extensions.atelier.mode must be documentation or workshop, but was \'' .. text ..
    '\' in ' .. source .. '. Using documentation.'
  )
  return MODE_DOCUMENTATION
end

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

--- Read the id of a sidebar.
--- Quarto also rewrites the id as a path relative to the page, so the leading
--- `../` parts are removed.
--- @param sidebar table The sidebar map
--- @return string The id
local function read_sidebar_id(sidebar)
  local id = pandoc.utils.stringify(sidebar.id or '')
  return (id:gsub('^[%./]+', ''))
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
          return read_sidebar_id(sidebar), paths
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
--- @param path string The file path
--- @return table|nil The metadata, or nil when the file has no front matter
--- @return boolean True when the file exists
local function read_front_matter(path)
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
      meta = pandoc.read('---\n' .. yaml .. '\n---\n', 'markdown').meta
    else
      meta = pandoc.Meta({})
    end
  end
  files[path] = { exists = true, read = true, meta = meta }
  return meta, true
end

--- Find the first page of a list that exists.
--- @param paths string[] The page paths relative to the project
--- @param directory string The project folder
--- @return string|nil The first path whose file exists
local function first_existing(paths, directory)
  for _, path in ipairs(paths) do
    if file_exists(directory .. '/' .. path) then
      return path
    end
  end
  return nil
end

--- Read the duration of each page of a sidebar.
--- Each page of the sidebar reads all the durations, so each problem must log
--- one warning only. The render of a page warns for its own duration. The
--- render of the first page that exists warns for the files that do not exist.
--- @param paths string[] The page paths relative to the project
--- @param page string The page path relative to the project
--- @return table<string, integer> The minutes by output path
local function read_durations(paths, page)
  local durations = {}
  local directory = quarto.project.directory or '.'
  local first = first_existing(paths, directory)
  for _, path in ipairs(paths) do
    local extension = path:match('%.(%w+)$')
    if extension and FRONT_MATTER_EXTENSIONS[extension] then
      local meta, exists = read_front_matter(directory .. '/' .. path)
      if not exists then
        if page == first then
          log.log_warning(
            EXTENSION_NAME,
            'extensions.atelier.sidebars lists ' .. path .. ', but that file does not exist. ' ..
            'Correct the path or remove the entry from the sidebar.'
          )
        end
      elseif meta ~= nil then
        local minutes = read_duration(meta, path, true)
        if minutes ~= nil then
          durations[path:gsub('%.%w+$', '.html')] = minutes
        end
      end
    end
  end
  return durations
end

--- Encode the data as JSON.
--- @param data table The data
--- @return string The JSON text, safe inside a script element
local function encode(data)
  return (quarto.json.encode(data):gsub('</', '<\\/'))
end

--- The mode, page duration, and labels that the `Div` handler reads.
--- `publish_workshop` fills it in the first filter pass.
--- `objectives` counts the checkboxes written so far, so the numbers run on across the page.
--- @type { mode: string|nil, duration: integer|nil, labels: table<string, string>|nil, objectives: integer }
local state = { objectives = 0 }

--- Add the workshop data block to the head.
--- @param meta table The document metadata
--- @return nil
local function publish_workshop(meta)
  if not quarto.doc.is_format('html') then
    return nil
  end
  local source = quarto.doc.input_file or ''
  local options = read_options(meta)
  local mode = read_mode(meta, source)
  local duration = read_duration(meta, source)
  state = { mode = mode, duration = duration, labels = resolve_labels(), objectives = 0 }
  local data = {
    mode = mode,
    offset = quarto.project.offset or '',
    labels = state.labels,
  }
  if mode == MODE_WORKSHOP then
    data.duration = duration
    local page = project_relative_input()
    local sidebar, paths = find_sidebar(options, page)
    if sidebar == nil then
      log.log_warning(
        EXTENSION_NAME,
        source .. ' is in workshop mode, but no sidebar in extensions.atelier.sidebars lists it. ' ..
        'Add a YAML anchor to its website.sidebar entry and list the alias in extensions.atelier.sidebars. ' ..
        'The extension does not resolve contents: auto or glob patterns, so list the page by its path.'
      )
    else
      data.sidebar = sidebar
      local durations = read_durations(paths, page)
      if next(durations) ~= nil then
        data.durations = durations
      end
    end
    quarto.doc.include_text(
      'in-header',
      '<script>document.documentElement.classList.add("atelier-workshop");</script>'
    )
  end
  quarto.doc.include_text(
    'in-header',
    '<script type="application/json" id="atelier-workshop">' .. encode(data) .. '</script>'
  )
  return nil
end

--- Build the head line of a block.
--- @param icon string The Bootstrap Icons name, such as `bullseye`
--- @param title string The title text
--- @param time string|nil The formatted duration, or nil to leave the pill out
--- @return pandoc.Plain The head paragraph
local function block_head(icon, title, time)
  local head = pandoc.Inlines({
    pandoc.RawInline('html', '<p class="atelier-block-head"><i class="bi bi-' .. icon .. '" aria-hidden="true"></i>'),
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

--- Read the duration attribute of a block.
--- @param div pandoc.Div The block
--- @param class string The block class, for the warning
--- @return string|nil The formatted duration, or nil when absent or invalid
local function attribute_duration(div, class)
  local text = div.attributes.duration
  if text == nil then
    return nil
  end
  local minutes = parse_duration(text)
  if minutes == nil then
    warn_duration('The duration attribute of the .' .. class .. ' block', text, quarto.doc.input_file or '')
    return nil
  end
  return format_duration(minutes, state.labels)
end

--- Turn each item of a bullet list into a checkbox label.
--- The checkboxes are numbered from 1 across the whole page. The empty span
--- after each checkbox holds the tick that the style draws.
--- @param list pandoc.BulletList The list
--- @return pandoc.Blocks The labels, followed by any further blocks of the items
local function objective_labels(list)
  local blocks = pandoc.Blocks({})
  for _, item in ipairs(list.content) do
    state.objectives = state.objectives + 1
    local index = state.objectives
    local first = item[1]
    local inlines = pandoc.Inlines({})
    local rest = 1
    if first ~= nil and (first.t == 'Plain' or first.t == 'Para') then
      inlines = first.content
      rest = 2
    end
    local label = pandoc.Inlines({
      pandoc.RawInline(
        'html',
        '<label><input type="checkbox" data-atelier-objective="' .. index .. '">' ..
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
--- The author's identifier, other classes, and other attributes stay. The
--- block class replaces the div class, and `title` and `duration` go, as the
--- head shows them.
--- @param div pandoc.Div The div
--- @param class string The div class, such as `objectives`
--- @return pandoc.Attr The attributes
local function block_attr(div, class)
  local classes = { 'atelier-' .. class }
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
  return pandoc.Attr(div.identifier, classes, attributes)
end

--- Wrap blocks in the body container of a workshop block.
--- @param blocks pandoc.Blocks The content
--- @return pandoc.Div The body
local function block_body(blocks)
  return pandoc.Div(blocks, pandoc.Attr('', { 'atelier-block-body' }))
end

--- Build the objectives block.
--- @param div pandoc.Div The `.objectives` div
--- @return pandoc.Div The block
local function objectives_block(div)
  local time = attribute_duration(div, 'objectives')
  if div.attributes.duration == nil and state.duration ~= nil then
    time = format_duration(state.duration, state.labels)
  end
  local body = pandoc.Blocks({})
  local done = false
  for _, block in ipairs(div.content) do
    if not done and block.t == 'BulletList' then
      body:extend(objective_labels(block))
      done = true
    else
      body:insert(block)
    end
  end
  if not done then
    log.log_warning(
      EXTENSION_NAME,
      'The .objectives block in ' .. (quarto.doc.input_file or '') .. ' has no bullet list, so it shows no checkboxes. ' ..
      'Write each objective as an item of a bullet list.'
    )
  end
  return pandoc.Div(
    { block_head('bullseye', div.attributes.title or state.labels['objectives-title'], time), block_body(body) },
    block_attr(div, 'objectives')
  )
end

--- Build the exercise block.
--- @param div pandoc.Div The `.exercise` div
--- @return pandoc.Div The block
local function exercise_block(div)
  local time = attribute_duration(div, 'exercise')
  return pandoc.Div(
    {
      block_head('pencil-square', div.attributes.title or state.labels['exercise-title'], time),
      block_body(div.content),
    },
    block_attr(div, 'exercise')
  )
end

--- Build the closed solution disclosure.
--- @param div pandoc.Div The solution content
--- @param title string The summary text
--- @param identifier string The identifier, or an empty string
--- @return pandoc.Blocks The disclosure
local function solution_block(div, title, identifier)
  local id = identifier ~= '' and (' id="' .. identifier .. '"') or ''
  return pandoc.Blocks({
    pandoc.RawBlock('html', '<details class="atelier-solution"' .. id .. '>'),
    pandoc.Plain({
      pandoc.RawInline('html', '<summary>'),
      pandoc.Str(title),
      pandoc.RawInline('html', '</summary>'),
    }),
    block_body(div.content),
    pandoc.RawBlock('html', '</details>'),
  })
end

--- Turn the workshop divs into blocks, in workshop mode only.
--- @param div pandoc.Div The div
--- @return pandoc.Div|pandoc.Blocks|nil The block, or nil to keep the div
local function style_block(div)
  if state.mode ~= MODE_WORKSHOP then
    return nil
  end
  if div.classes:includes('objectives') then
    return objectives_block(div)
  elseif div.classes:includes('exercise') then
    return exercise_block(div)
  end
  return nil
end

--- Turn a `.solution` div into the disclosure, in workshop mode only.
--- Quarto turns a `.solution` div into a `Proof` node before this filter runs
--- and removes the class, so the handler takes the node and its `div`.
--- The summary is the `title` attribute, else the name that Quarto took from
--- the `name` attribute or a leading heading, else the label.
--- A solution with a `sol-` identifier is a cross-reference target and stays.
--- @param proof table The `Proof` node
--- @return pandoc.Blocks|nil The disclosure, or nil to keep the node
local function style_proof(proof)
  if state.mode ~= MODE_WORKSHOP or (proof.identifier or ''):find('^sol%-') then
    return nil
  end
  if pandoc.utils.stringify(proof.type or ''):lower() ~= 'solution' then
    return nil
  end
  local title = proof.div.attributes.title
  if title == nil then
    local name = pandoc.utils.stringify(proof.name or '')
    title = name ~= '' and name or state.labels['solution-summary']
  end
  return solution_block(proof.div, title, proof.identifier or '')
end

--- Draw a `.terminal` code block as a terminal, in both modes.
--- Each line that starts with `$` and a space loses those two characters, and
--- its number joins `atelier-prompt`, a line spec. The code-blocks script marks
--- those lines, and the style draws the `$` prompt before them. The prompt is
--- not in the text, so screen readers and the copy button skip it.
--- Code Window draws the header from `filename`, which this filter sets to the
--- `terminal` label when the block has none. The class `cw-auto` makes the Code
--- Window script build the window. This filter runs before Code Window.
--- @param block pandoc.CodeBlock The code block
--- @return pandoc.CodeBlock|nil The block, or nil to keep it
local function style_terminal(block)
  if not quarto.doc.is_format('html') or not block.classes:includes('terminal') then
    return nil
  end
  local lines = {}
  local prompts = {}
  local number = 0
  for line in (block.text .. '\n'):gmatch('(.-)\n') do
    number = number + 1
    if line:sub(1, 2) == '$ ' then
      line = line:sub(3)
      prompts[#prompts + 1] = tostring(number)
    end
    lines[#lines + 1] = line
  end
  block.text = table.concat(lines, '\n')
  block.classes:insert('atelier-terminal')
  if #prompts > 0 then
    block.attributes['atelier-prompt'] = table.concat(prompts, ',')
  end
  if block.attributes.filename == nil then
    block.attributes.filename = state.labels.terminal
    block.classes:insert('cw-auto')
  end
  return block
end

--- Two filter tables: pandoc finishes the `Meta` pass before the `Div` pass
--- starts, so `state` is complete when `style_block` reads it. One table gives
--- no such order between element types.
return {
  { Meta = publish_workshop },
  { Div = style_block, Proof = style_proof, CodeBlock = style_terminal },
}
