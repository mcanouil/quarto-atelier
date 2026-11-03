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
local meta_mod = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))

--- Modes that `extensions.atelier.mode` accepts.
--- @type string
local MODE_DOCUMENTATION = 'documentation'
--- @type string
local MODE_WORKSHOP = 'workshop'

--- Page file extensions whose front matter holds a duration.
--- @type table<string, boolean>
local FRONT_MATTER_EXTENSIONS = { qmd = true, md = true, Rmd = true }

--- Labels and their default text, in output order.
--- @type table<integer, { key: string, default: string }>
local LABELS = {
  { key = 'duration-minutes', default = '{m} min' },
  { key = 'duration-hours', default = '{h} h' },
  { key = 'duration-hours-minutes', default = '{h} h {m} min' },
  { key = 'reading-bar', default = 'Page navigation' },
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
  local value = text:lower():gsub('^%s+', ''):gsub('%s+$', '')
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
  return (template:gsub('{h}', tostring(hours)):gsub('{m}', tostring(rest)))
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

--- Read the duration option of a metadata table.
--- A duration that does not parse logs a warning naming the source file.
--- @param meta table The metadata
--- @param source string The file the metadata comes from
--- @return integer|nil The minutes, or nil when unset or invalid
local function read_duration(meta, source)
  local value = read_options(meta).duration
  if value == nil then
    return nil
  end
  local text = pandoc.utils.stringify(value)
  local minutes = parse_duration(text)
  if minutes == nil then
    quarto.log.warning(
      "extensions.atelier.duration '" .. text .. "' in " .. source ..
      " is not a duration such as '25 min' or '1 h 30 min'. Ignoring it."
    )
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
  quarto.log.warning(
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

--- Resolve a sidebar path to a project path.
--- Quarto rewrites the paths of the project metadata relative to the page, so
--- the path is joined to the folder of the page. A leading `/` marks a path
--- from the project root.
--- @param path string The path as the metadata holds it
--- @param base string The folder of the page, relative to the project
--- @return string The project path
local function resolve_path(path, base)
  if path:sub(1, 1) == '/' then
    return normalise_path(path)
  end
  return normalise_path(base .. '/' .. path)
end

--- Collect the file paths of a sidebar `contents` tree, in order.
--- An item is a path string, a map with `href`, or a map with `section` and
--- `contents`. An item with `auto` or a `*` is skipped.
--- @param contents table The contents list
--- @param base string The folder of the page, relative to the project
--- @param paths string[] The list that receives the paths
--- @return string[] The paths
local function collect_paths(contents, base, paths)
  for _, item in ipairs(contents) do
    local kind = pandoc.utils.type(item)
    if kind == 'Inlines' or kind == 'string' or kind == 'Blocks' then
      local path = pandoc.utils.stringify(item)
      if not path:find('*', 1, true) then
        paths[#paths + 1] = resolve_path(path, base)
      end
    elseif type(item) == 'table' and item.auto == nil then
      if item.href ~= nil then
        local path = pandoc.utils.stringify(item.href)
        if not path:find('*', 1, true) then
          paths[#paths + 1] = resolve_path(path, base)
        end
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

--- Read the front matter of a page file as metadata.
--- @param path string The file path
--- @return table|nil The metadata, or nil when the file has no front matter
local function read_front_matter(path)
  local file = io.open(path, 'r')
  if file == nil then
    return nil
  end
  local text = file:read('a')
  file:close()
  local yaml = text:match('^%-%-%-\r?\n(.-)\r?\n%-%-%-[ \t]*\r?\n') or
    text:match('^%-%-%-\r?\n(.-)\r?\n%-%-%-[ \t]*$')
  if yaml == nil then
    return nil
  end
  return pandoc.read('---\n' .. yaml .. '\n---\n', 'markdown').meta
end

--- Read the duration of each page of a sidebar.
--- @param paths string[] The page paths relative to the project
--- @return table<string, integer> The minutes by output path
local function read_durations(paths)
  local durations = {}
  local directory = quarto.project.directory or '.'
  for _, path in ipairs(paths) do
    local extension = path:match('%.(%w+)$')
    if extension and FRONT_MATTER_EXTENSIONS[extension] then
      local full = directory .. '/' .. path
      local meta = read_front_matter(full)
      if meta == nil and io.open(full, 'r') == nil then
        quarto.log.warning(
          'extensions.atelier.sidebars lists ' .. path .. ', but ' .. full .. ' does not exist.'
        )
      elseif meta ~= nil then
        local minutes = read_duration(meta, path)
        if minutes ~= nil then
          durations[path:gsub('%.%w+$', '.html')] = minutes
        end
      end
    end
  end
  return durations
end

--- Encode the data as JSON, keeping an empty `durations` as an object.
--- @param data table The data without `durations`
--- @param durations table<string, integer>|nil The durations, or nil to leave them out
--- @return string The JSON text, safe inside a script element
local function encode(data, durations)
  local placeholder = '__atelier_durations__'
  if durations ~= nil then
    data.durations = placeholder
  end
  local json = quarto.json.encode(data)
  if durations ~= nil then
    local encoded = next(durations) == nil and '{}' or quarto.json.encode(durations)
    json = json:gsub('"' .. placeholder .. '"', function() return encoded end)
  end
  return (json:gsub('</', '<\\/'))
end

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
  local data = {
    mode = mode,
    offset = quarto.project.offset or '',
    labels = resolve_labels(),
  }
  local durations = nil
  if mode == MODE_WORKSHOP then
    data.duration = duration
    local sidebar, paths = find_sidebar(options, project_relative_input())
    if sidebar == nil then
      quarto.log.warning(
        source .. ' is in workshop mode, but no sidebar in extensions.atelier.sidebars lists it. ' ..
        'Add a YAML anchor to its website.sidebar entry and list the alias in extensions.atelier.sidebars.'
      )
    else
      data.sidebar = sidebar
      durations = read_durations(paths)
    end
    quarto.doc.include_text(
      'in-header',
      '<script>document.documentElement.classList.add("atelier-workshop");</script>'
    )
  end
  quarto.doc.include_text(
    'in-header',
    '<script type="application/json" id="atelier-workshop">' .. encode(data, durations) .. '</script>'
  )
  return nil
end

return {
  { Meta = publish_workshop },
}
