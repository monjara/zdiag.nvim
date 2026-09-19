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
    require('zdiag.workspace.autocmd').remove_autocmd(active_workspace)
    active_workspace = nil
  end

  local Context = require('zdiag.core.context')
  local ctx = Context:new()

  local Workspace = require('zdiag.workspace')
  local workspace = Workspace:new(ctx):build_workspace()
  active_workspace = workspace

  vim.api.nvim_set_current_buf(workspace.bufnr)
  vim.bo[workspace.bufnr].filetype = 'zdiag'
end

---Jump from the active diagnostics workspace to the represented source line.
---
---@param opts? zdiag.JumpOpts
---@return boolean jumped
function M.jump_to_source(opts)
  if
    not active_workspace
    or not vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    or vim.api.nvim_get_current_buf() ~= active_workspace.bufnr
  then
    return false
  end

  local workspace = active_workspace
  workspace:jump(opts)

  if not vim.api.nvim_buf_is_valid(workspace.bufnr) then
    active_workspace = nil
  end

  return true
end

---Close the active diagnostics workspace buffer.
---
---@param opts? { force?: boolean }
---@return boolean closed
function M.close(opts)
  opts = opts or {}

  if not active_workspace then
    return false
  end

  local workspace = active_workspace

  if not vim.api.nvim_buf_is_valid(workspace.bufnr) then
    active_workspace = nil
    require('zdiag.workspace.autocmd').remove_autocmd(workspace)
    return false
  end

  local force = opts.force or false

  if vim.bo[workspace.bufnr].modified and not force then
    vim.notify(
      'zdiag: write or discard workspace changes before closing',
      vim.log.levels.WARN
    )
    return false
  end

  vim.api.nvim_buf_delete(workspace.bufnr, { force = force })

  require('zdiag.workspace.autocmd').remove_autocmd(workspace)

  if active_workspace == workspace then
    active_workspace = nil
  end

  return true
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
    local _, result = active_workspace:call(callback)
    return result
  end

  return callback()
end

return M
