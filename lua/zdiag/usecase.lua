local Context = require('zdiag.core.context')
local Workspace = require('zdiag.workspace')

---@class zdiag.Usecase
local M = {}

---@type zdiag.Workspace?
local active_workspace

---Open a diagnostics workspace for the current Neovim session.
function M.open()
  if
    active_workspace
    and not active_workspace.closed
    and vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    and vim.api.nvim_buf_is_loaded(active_workspace.bufnr)
  then
    if vim.bo[active_workspace.bufnr].modified then
      vim.notify(
        'zdiag: reopening the workspace without refreshing because it has unsaved changes',
        vim.log.levels.INFO
      )
    else
      active_workspace:reload()
    end

    vim.api.nvim_set_current_buf(active_workspace.bufnr)
    vim.bo[active_workspace.bufnr].filetype = 'zdiag'
    return
  end

  if active_workspace then
    active_workspace:dispose()
    active_workspace = nil
  end

  local workspace = Workspace:new(Context:new()):build()

  require('zdiag.workspace.autocmd').create_autocmd(workspace)
  active_workspace = workspace

  vim.api.nvim_set_current_buf(workspace.bufnr)
  vim.bo[workspace.bufnr].filetype = 'zdiag'
end

---Jump from the active diagnostics workspace to the represented source line.
---
---@param opts? zdiag.JumpOpts
function M.jump_to_source(opts)
  if
    not active_workspace
    or not vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    or vim.api.nvim_get_current_buf() ~= active_workspace.bufnr
  then
    return
  end

  require('zdiag.workspace.jump').jump_to_source(active_workspace, opts)

  if not vim.api.nvim_buf_is_valid(active_workspace.bufnr) then
    active_workspace = nil
  end
end

---Close the active diagnostics workspace buffer.
---
---@param opts? { force?: boolean }
function M.close(opts)
  opts = opts or {}

  if not active_workspace then
    return
  end

  if not vim.api.nvim_buf_is_valid(active_workspace.bufnr) then
    active_workspace:dispose()
    active_workspace = nil
    return
  end

  local force = opts.force or false

  if vim.bo[active_workspace.bufnr].modified and not force then
    vim.notify(
      'zdiag: write or discard workspace changes before closing',
      vim.log.levels.WARN
    )
    return
  end

  active_workspace:dispose { force = force }
  active_workspace = nil
end

---Call a callback in the represented source context when called from the active workspace.
---Visual selections are translated when both ends belong to one source block.
---Outside the workspace, run the callback in the current buffer as usual.
---
---@param callback fun(): any
---@return any
function M.call(callback)
  if
    active_workspace
    and vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    and vim.api.nvim_get_current_buf() == active_workspace.bufnr
  then
    local _, result =
      require('zdiag.workspace.source').call(active_workspace, callback)
    return result
  end

  return callback()
end

return M
