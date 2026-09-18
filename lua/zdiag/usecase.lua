local M = {}

---@type zdiag.Workspace?
local active_workspace

---Build the current diagnostic data into a workspace.
---
---@param workspace zdiag.Workspace
---@return zdiag.Workspace
local function build_workspace(workspace)
  local buffers = require('zdiag.diagnostic').get_by_buffer()

  workspace:build(buffers):render()

  return workspace
end

---Reload a workspace from the latest diagnostics.
---
---@param workspace zdiag.Workspace
function M.reload(workspace)
  if not vim.api.nvim_buf_is_valid(workspace.bufnr) then
    return
  end

  local winid = vim.fn.bufwinid(workspace.bufnr)
  local source_position

  if winid ~= -1 then
    local cursor = vim.api.nvim_win_get_cursor(winid)

    source_position = require('zdiag.workspace.source').get_position(workspace, cursor[1] - 1, cursor[2])
  end

  workspace:reset()
  build_workspace(workspace)

  if winid == -1 or not vim.api.nvim_win_is_valid(winid) or not source_position then
    return
  end

  for _, block in ipairs(workspace.blocks) do
    if
      block.bufnr == source_position.bufnr
      and source_position.row >= block.source_start
      and source_position.row < block.source_end
    then
      local start_row = block:get_workspace_range(workspace)

      if start_row then
        vim.api.nvim_win_set_cursor(winid, {
          start_row + source_position.row - block.source_start + 1,
          source_position.col,
        })
      end

      break
    end
  end
end

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
      M.reload(active_workspace)
    end

    vim.api.nvim_set_current_buf(active_workspace.bufnr)
    vim.bo[active_workspace.bufnr].filetype = 'zdiag'
    return
  end

  if active_workspace then
    require('zdiag.workspace.autocmd').remove_autocmd(active_workspace)
    active_workspace = nil
  end

  local Context = require('zdiag.context')
  local ctx = Context:new()

  local Workspace = require('zdiag.workspace')
  local workspace = build_workspace(Workspace:new(ctx))
  active_workspace = workspace

  vim.api.nvim_buf_create_user_command(workspace.bufnr, 'ZdiagCodeAction', function()
    workspace:code_action()
  end, {
    desc = 'Request LSP code actions for the source under the cursor',
  })

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
    vim.notify('zdiag: write or discard workspace changes before closing', vim.log.levels.WARN)
    return false
  end

  vim.api.nvim_buf_delete(workspace.bufnr, { force = force })

  require('zdiag.workspace.autocmd').remove_autocmd(workspace)

  if active_workspace == workspace then
    active_workspace = nil
  end

  return true
end

---Call a callback at the represented position when called from the active workspace.
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

---Request an LSP code action in the active source context.
---
---@param opts? vim.lsp.buf.code_action.Opts
function M.code_action(opts)
  if
    active_workspace
    and vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    and vim.api.nvim_get_current_buf() == active_workspace.bufnr
  then
    return active_workspace:code_action(opts)
  end

  return vim.lsp.buf.code_action(opts)
end

---Open diagnostics for the source position represented by the cursor.
---
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function M.diagnostic_open_float(opts)
  if
    active_workspace
    and vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    and vim.api.nvim_get_current_buf() == active_workspace.bufnr
  then
    return active_workspace:diagnostic_open_float(opts)
  end

  return vim.diagnostic.open_float(opts)
end

---Move to another diagnostic in the active diagnostics workspace.
---Outside the workspace, delegate to vim.diagnostic.jump().
---
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function M.diagnostic_jump(opts)
  if
    active_workspace
    and vim.api.nvim_buf_is_valid(active_workspace.bufnr)
    and vim.api.nvim_get_current_buf() == active_workspace.bufnr
  then
    return active_workspace:diagnostic_jump(opts)
  end

  return vim.diagnostic.jump(opts)
end

return M
