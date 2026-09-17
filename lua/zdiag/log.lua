local M = {}

local enabled = true

---Print a debug message when debug logging is enabled.
---
---@param ... any
function M.debug(...)
  if enabled then
    print('[zdiag debug]', ...)
  end
end

return M
