local M = {}

---Configure zdiag.
---
---@param opts? zdiag.Config
function M.setup(opts)
  require('zdiag.config').setup(opts)
end

---Open the diagnostics view.
function M.open()
  require('zdiag.usecase').open()
end

---Jump from the diagnostics view to the represented source line.
---
---@param opts? zdiag.JumpOpts
---@return boolean jumped
function M.jump_to_source(opts)
  return require('zdiag.usecase').jump_to_source(opts)
end

---Close the active diagnostics view buffer.
---
---@param opts? { force?: boolean }
---@return boolean closed
function M.close(opts)
  return require('zdiag.usecase').close(opts)
end

---Call a callback at the buffer position represented by the current line.
---Outside a zdiag view, run it against the current buffer.
---
---@param callback fun(): any
---@return any
function M.call(callback)
  return require('zdiag.usecase').call(callback)
end

---Request LSP code actions for the source position represented by the current line.
---
---@param opts? vim.lsp.buf.code_action.Opts
function M.code_action(opts)
  return require('zdiag.usecase').code_action(opts)
end

---Open diagnostics for the source position represented by the cursor.
---
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function M.diagnostic_open_float(opts)
  return require('zdiag.usecase').diagnostic_open_float(opts)
end

---Move to another diagnostic, continuing across source buffers in a zdiag view.
---
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function M.diagnostic_jump(opts)
  return require('zdiag.usecase').diagnostic_jump(opts)
end

return M
