local M = {}

---Prepare a target window for jumping to source.
---
---@param mode zdiag.JumpMode
---@return integer
local function prepare_window(mode)
  if mode == 'split' then
    vim.cmd('split')
  end

  return vim.api.nvim_get_current_win()
end

---Delete the diagnostics workspace after a successful close-mode jump.
---
---@param workspace zdiag.Workspace
local function close_workspace(workspace)
  vim.api.nvim_buf_delete(workspace.bufnr, { force = false })
  workspace.closed = true
  require('zdiag.workspace.autocmd').remove_autocmd(workspace)
end

---Jump to the source line corresponding to the current cursor position in the workspace.
---
---@param workspace zdiag.Workspace
---@param opts? zdiag.JumpOpts
function M.jump_to_source(workspace, opts)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local position = require('zdiag.workspace.position').get_position(
    workspace,
    cursor[1] - 1,
    cursor[2]
  )

  if not position then
    vim.notify('zdiag: cursor is not on a source line', vim.log.levels.INFO)
    return
  end

  local mode = require('zdiag.core.config').get_jump_mode(opts)

  if mode == 'close' and vim.bo[workspace.bufnr].modified then
    vim.notify(
      'zdiag: write or discard workspace changes before a close-mode jump',
      vim.log.levels.WARN
    )
    return
  end

  local target_win = prepare_window(mode)

  vim.api.nvim_win_set_buf(target_win, position.bufnr)

  vim.api.nvim_win_set_cursor(target_win, { position.row + 1, position.col })

  if mode == 'close' then
    close_workspace(workspace)
  end
end

return M
