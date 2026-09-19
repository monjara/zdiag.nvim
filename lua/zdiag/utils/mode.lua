local M = {}

---Return whether a mode is one of the Visual modes.
---
---@param mode string
---@return boolean
function M.is_visual(mode)
  return mode == 'v' or mode == 'V' or mode == '\22'
end

return M
