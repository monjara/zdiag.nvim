local M = {}

local highlight_autocmd_created = false

---Return the autocmd group name for a diagnostics workspace.
---
---@param workspace zdiag.Workspace
---@return string
local function group_name(workspace)
  return 'zdiag_workspace_' .. workspace.bufnr
end

---Create the plugin-wide colorscheme autocmd once.
local function ensure_highlight_autocmd()
  if highlight_autocmd_created then
    return
  end

  local group = vim.api.nvim_create_augroup('zdiag_highlight', { clear = true })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,

    callback = function()
      require('zdiag.core.highlight').refresh_line_highlights()
    end,
  })

  highlight_autocmd_created = true
end

---Resume a reload that was deferred while the workspace had unsaved edits.
---
---@param workspace zdiag.Workspace
local function resume_deferred_reload(workspace)
  if
    workspace.reload_deferred
    and not workspace.closed
    and vim.api.nvim_buf_is_valid(workspace.bufnr)
    and not vim.bo[workspace.bufnr].modified
  then
    workspace.reload_deferred = false
    M.schedule_reload(workspace)
  end
end

---Schedule a diagnostics workspace rebuild after diagnostics settle.
---
---@param workspace zdiag.Workspace
function M.schedule_reload(workspace)
  if workspace.closed or workspace.reload_pending then
    return
  end

  workspace.reload_pending = true

  vim.defer_fn(function()
    workspace.reload_pending = false

    if workspace.closed or not vim.api.nvim_buf_is_valid(workspace.bufnr) then
      return
    end

    if vim.bo[workspace.bufnr].modified then
      workspace.reload_deferred = true
      return
    end

    workspace.reload_deferred = false
    workspace:reload()
  end, require('zdiag.core.config').get_auto_refresh_delay())
end

---Create autocmds for the given workspace.
---
---@param workspace zdiag.Workspace
function M.create_autocmd(workspace)
  ensure_highlight_autocmd()

  local group =
    vim.api.nvim_create_augroup(group_name(workspace), { clear = true })

  vim.api.nvim_create_autocmd('BufWriteCmd', {
    group = group,
    buffer = workspace.bufnr,

    callback = function()
      local ok =
        require('zdiag.workspace.interaction.edit').apply_changes(workspace)

      if ok then
        workspace.reload_deferred = false
        M.schedule_reload(workspace)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufUnload', {
    group = group,
    buffer = workspace.bufnr,

    callback = function()
      if workspace.closed then
        return
      end

      local bufnr = workspace.bufnr
      workspace.closed = true

      -- BufUnload runs while Neovim is still processing the original
      -- deletion.  Complete the wipe on the next event-loop turn.
      vim.schedule(function()
        if
          vim.api.nvim_buf_is_valid(bufnr)
          and not vim.api.nvim_buf_is_loaded(bufnr)
        then
          vim.api.nvim_buf_delete(bufnr, { force = false })
        end

        M.remove_autocmd(workspace)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    buffer = workspace.bufnr,

    callback = function()
      resume_deferred_reload(workspace)
    end,
  })

  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,

    callback = function()
      if require('zdiag.core.config').is_auto_refresh_enabled() then
        M.schedule_reload(workspace)
      end
    end,
  })
end

---Remove autocmds owned by a diagnostics workspace.
---
---@param workspace zdiag.Workspace
function M.remove_autocmd(workspace)
  pcall(vim.api.nvim_del_augroup_by_name, group_name(workspace))
end

return M
