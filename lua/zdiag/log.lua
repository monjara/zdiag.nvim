local M = {}

local enabled = true

function M.setup()
end

function M.debug(...)
  if enabled then
    print("[zdiag debug]", ...)
  end
end

return M
