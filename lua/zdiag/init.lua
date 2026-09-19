local M = {}

---Configure zdiag.
---
---@param opts? zdiag.Config
function M.setup(opts)
  require('zdiag.config').setup(opts)
end

---Open the diagnostics workspace.
function M.open()
  require('zdiag.usecase').open()
end

---Jump from the diagnostics workspace to the represented source line.
---
---@param opts? zdiag.JumpOpts
---@return boolean jumped
function M.jump_to_source(opts)
  return require('zdiag.usecase').jump_to_source(opts)
end

---Close the active diagnostics workspace buffer.
---
---@param opts? { force?: boolean }
---@return boolean closed
function M.close(opts)
  return require('zdiag.usecase').close(opts)
end

---Call a callback in the source context represented by the cursor or Visual selection.
---Outside a zdiag workspace, run it against the current buffer.
---
---@param callback fun(): any
---@return any
function M.call(callback)
  return require('zdiag.usecase').call(callback)
end

return M
