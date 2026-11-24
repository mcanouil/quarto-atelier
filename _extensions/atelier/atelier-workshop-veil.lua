--- Atelier - Workshop Solutions in Veil
--- @module "atelier-workshop-veil"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Put the solutions of a workshop deck in the veil group `solutions`.
--- @description Veil runs at `pre-quarto` and reads the div that a `Proof`
--- node holds, so this filter runs at `pre-quarto` too, just before Veil.
--- In a Reveal.js deck in workshop mode, the div of each workshop solution
--- gets the `veil` class and `group="solutions"`, so the solution stays hidden
--- until the reader shows the group. A solution with its own `.veil` class
--- keeps it, and its own group. A solution with a `sol-` identifier is a
--- cross-reference target and stays shown, as in HTML. The other formats are
--- left as they are.

local core = require(quarto.utils.resolve_path('workshop/core.lua'):gsub('%.lua$', ''))

--- The veil group of the workshop solutions.
--- @type string
local GROUP = 'solutions'

--- True when the page is a Reveal.js deck in workshop mode.
--- @type boolean
local active = false

--- Read the mode of the page. The workshop filter logs the warnings of the
--- mode, so this read is quiet.
--- @param meta table The document metadata
--- @return nil
local function read_mode(meta)
  active = quarto.doc.is_format('revealjs') and
    core.read_mode(meta, quarto.doc.input_file or '', true) == core.MODE_WORKSHOP
end

--- Add the `veil` class and the `solutions` group to the div of a workshop
--- solution.
--- @param proof table The `Proof` node
--- @return table|nil The node, or nil to keep it
local function veil_solution(proof)
  if not active or not core.is_workshop_solution(proof) or proof.div.classes:includes('veil') then
    return nil
  end
  proof.div.classes:insert('veil')
  proof.div.attributes.group = GROUP
  return proof
end

--- Two filter tables, so the mode is known before the first `Proof`.
return {
  { Meta = read_mode },
  { Proof = veil_solution },
}
