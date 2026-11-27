--- Atelier - Icons
--- @module "icons"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief The icons of the workshop block heads, for every format.
--- @description One source for the head icons of the workshop blocks. HTML
--- draws them with the Bootstrap Icons font, the deck draws them as CSS masks
--- from `M.mask`, and Typst draws the SVG that it builds from `M.typst`.
--- The paths are Bootstrap Icons 1.11.3, in their 16 by 16 view box.
--- Bootstrap Icons: Copyright (c) 2019-2024 The Bootstrap Authors, MIT
--- licence, https://github.com/twbs/icons.

local M = {}

--- The paths of each icon: the `d` data of each path, and whether the path
--- fills with the `evenodd` rule.
--- @type table<string, { d: string, evenodd: boolean|nil }[]>
M.PATHS = {
  bullseye = {
    { d = 'M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16' },
    { d = 'M8 13A5 5 0 1 1 8 3a5 5 0 0 1 0 10m0 1A6 6 0 1 0 8 2a6 6 0 0 0 0 12' },
    { d = 'M8 11a3 3 0 1 1 0-6 3 3 0 0 1 0 6m0 1a4 4 0 1 0 0-8 4 4 0 0 0 0 8' },
    { d = 'M9.5 8a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0' },
  },
  ['pencil-square'] = {
    { d = 'M15.502 1.94a.5.5 0 0 1 0 .706L14.459 3.69l-2-2L13.502.646a.5.5 0 0 1 .707 0l1.293 1.293zm-1.75 2.456-2-2L4.939 9.21a.5.5 0 0 0-.121.196l-.805 2.414a.25.25 0 0 0 .316.316l2.414-.805a.5.5 0 0 0 .196-.12l6.813-6.814z' },
    { d = 'M1 13.5A1.5 1.5 0 0 0 2.5 15h11a1.5 1.5 0 0 0 1.5-1.5v-6a.5.5 0 0 0-1 0v6a.5.5 0 0 1-.5.5h-11a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .5-.5H9a.5.5 0 0 0 0-1H2.5A1.5 1.5 0 0 0 1 2.5z', evenodd = true },
  },
  ['list-check'] = {
    { d = 'M5 11.5a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5m0-4a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5m0-4a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5M3.854 2.146a.5.5 0 0 1 0 .708l-1.5 1.5a.5.5 0 0 1-.708 0l-.5-.5a.5.5 0 1 1 .708-.708L2 3.293l1.146-1.147a.5.5 0 0 1 .708 0m0 4a.5.5 0 0 1 0 .708l-1.5 1.5a.5.5 0 0 1-.708 0l-.5-.5a.5.5 0 1 1 .708-.708L2 7.293l1.146-1.147a.5.5 0 0 1 .708 0m0 4a.5.5 0 0 1 0 .708l-1.5 1.5a.5.5 0 0 1-.708 0l-.5-.5a.5.5 0 0 1 .708-.708l.146.147 1.146-1.147a.5.5 0 0 1 .708 0', evenodd = true },
  },
  flag = {
    { d = 'M14.778.085A.5.5 0 0 1 15 .5V8a.5.5 0 0 1-.314.464L14.5 8l.186.464-.003.001-.006.003-.023.009a12 12 0 0 1-.397.15c-.264.095-.631.223-1.047.35-.816.252-1.879.523-2.71.523-.847 0-1.548-.28-2.158-.525l-.028-.01C7.68 8.71 7.14 8.5 6.5 8.5c-.7 0-1.638.23-2.437.477A20 20 0 0 0 3 9.342V15.5a.5.5 0 0 1-1 0V.5a.5.5 0 0 1 1 0v.282c.226-.079.496-.17.79-.26C4.606.272 5.67 0 6.5 0c.84 0 1.524.277 2.121.519l.043.018C9.286.788 9.828 1 10.5 1c.7 0 1.638-.23 2.437-.477a20 20 0 0 0 1.349-.476l.019-.007.004-.002h.001M14 1.221c-.22.078-.48.167-.766.255-.81.252-1.872.523-2.734.523-.886 0-1.592-.286-2.203-.534l-.008-.003C7.662 1.21 7.139 1 6.5 1c-.669 0-1.606.229-2.415.478A21 21 0 0 0 3 1.845v6.433c.22-.078.48-.167.766-.255C4.576 7.77 5.638 7.5 6.5 7.5c.847 0 1.548.28 2.158.525l.028.01C9.32 8.29 9.86 8.5 10.5 8.5c.668 0 1.606-.229 2.415-.478A21 21 0 0 0 14 7.655V1.222z' },
  },
}

--- Answer the SVG document of an icon, in one colour.
--- @param name string An icon name of `M.PATHS`
--- @param fill string The colour, such as `#1a1a1a`
--- @return string
function M.svg(name, fill)
  local parts = { '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="' .. fill .. '">' }
  for _, path in ipairs(M.PATHS[name]) do
    parts[#parts + 1] = '<path' .. (path.evenodd and ' fill-rule="evenodd"' or '') .. ' d="' .. path.d .. '"/>'
  end
  parts[#parts + 1] = '</svg>'
  return table.concat(parts)
end

--- Answer the CSS value that draws an icon as a mask.
--- @param name string An icon name of `M.PATHS`
--- @return string Such as `url("data:image/svg+xml,...")`
function M.mask(name)
  local encoded = M.svg(name, '#000'):gsub('[^%w%-%._~/:=,]', function(char)
    return string.format('%%%02X', string.byte(char))
  end)
  return 'url("data:image/svg+xml,' .. encoded .. '")'
end

--- Answer the paths of every icon as a Typst dictionary, which
--- `typst/workshop.typ` turns into SVG documents: each icon is an array of
--- `(d: "...", evenodd: true)` dictionaries.
--- @return string
function M.typst()
  local names = {}
  for name in pairs(M.PATHS) do
    names[#names + 1] = name
  end
  table.sort(names)
  local entries = {}
  for _, name in ipairs(names) do
    local paths = {}
    for _, path in ipairs(M.PATHS[name]) do
      paths[#paths + 1] = '(d: "' .. path.d .. '", evenodd: ' .. tostring(path.evenodd == true) .. ')'
    end
    entries[#entries + 1] = '"' .. name .. '": (' .. table.concat(paths, ', ') .. ',)'
  end
  return '(' .. table.concat(entries, ', ') .. ')'
end

return M
