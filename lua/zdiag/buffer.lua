local M = {}

local BUFFER_NAME = 'zdiag://diagnostics'

---Load a source buffer, tolerating stale deferred diagnostic decorations.
---
---Neovim defers diagnostic rendering for unloaded buffers until BufRead. A
---stale diagnostic outside the current file can make that callback fail even
---though bufload() has successfully loaded the buffer. Ignore only that known
---rendering failure; propagate every other BufRead error.
---
---@param bufnr integer
function M.ensure_loaded(bufnr)
  if vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local ok, err = pcall(vim.fn.bufload, bufnr)

  if ok then
    return
  end

  local message = tostring(err)
  local stale_diagnostic_error = vim.api.nvim_buf_is_loaded(bufnr)
    and message:find('vim/diagnostic.lua', 1, true)
    and message:find('Index out of bounds', 1, true)

  if not stale_diagnostic_error then
    error(err, 0)
  end
end

---Create the editable diagnostics view buffer.
---
---@return integer bufnr
function M.build_buffer()
  local existing = vim.fn.bufnr(BUFFER_NAME)

  -- A caller may have used nvim_buf_delete({ unload = true }).  Such a
  -- buffer still owns its name, so finish deleting it instead of reusing it.
  if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) and not vim.api.nvim_buf_is_loaded(existing) then
    vim.api.nvim_buf_delete(existing, { force = false })
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  require('zdiag.log').debug('Buffer created with bufnr: ' .. bufnr)

  vim.bo[bufnr].buftype = 'acwrite'
  -- Keep the buffer alive while a buffer-closing mapping switches to its
  -- replacement.  With "wipe", nvim_set_current_buf() invalidates this
  -- buffer before the mapping can call nvim_buf_delete() on it.
  vim.bo[bufnr].bufhidden = 'hide'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true

  vim.api.nvim_buf_set_name(bufnr, BUFFER_NAME)

  return bufnr
end

---Clear the modified flag on a diagnostics view buffer.
---
---@param bufnr integer
function M.mark_modified(bufnr)
  vim.bo[bufnr].modified = false
end

return M
