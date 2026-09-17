local M = {}

---@type zdiag.View?
local active_view

---Build the current diagnostic data into a view.
---
---@param view zdiag.View
---@return zdiag.View
local function build_view(view)
  local buffers = require('zdiag.diagnostic').get_by_buffer()

  view:build(buffers):render()

  return view
end

---Reload a view from the latest diagnostics.
---
---@param view zdiag.View
function M.reload(view)
  if not vim.api.nvim_buf_is_valid(view.bufnr) then
    return
  end

  local winid = vim.fn.bufwinid(view.bufnr)
  local source_position

  if winid ~= -1 then
    local cursor = vim.api.nvim_win_get_cursor(winid)

    source_position = require('zdiag.view.source').get_position(view, cursor[1] - 1, cursor[2])
  end

  view:reset()
  build_view(view)

  if winid == -1 or not vim.api.nvim_win_is_valid(winid) or not source_position then
    return
  end

  for _, block in ipairs(view.blocks) do
    if
      block.bufnr == source_position.bufnr
      and source_position.row >= block.source_start
      and source_position.row < block.source_end
    then
      local start_row = block:get_view_range(view)

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

---Open a diagnostics view for the current Neovim session.
function M.open()
  if
    active_view
    and not active_view.closed
    and vim.api.nvim_buf_is_valid(active_view.bufnr)
    and vim.api.nvim_buf_is_loaded(active_view.bufnr)
  then
    if vim.bo[active_view.bufnr].modified then
      vim.notify('zdiag: reopening the view without refreshing because it has unsaved changes', vim.log.levels.INFO)
    else
      M.reload(active_view)
    end

    vim.api.nvim_set_current_buf(active_view.bufnr)
    vim.bo[active_view.bufnr].filetype = 'zdiag'
    return
  end

  if active_view then
    require('zdiag.view.autocmd').remove_autocmd(active_view)
    active_view = nil
  end

  local Context = require('zdiag.context')
  local ctx = Context:new()

  local View = require('zdiag.view')
  local view = build_view(View:new(ctx))
  active_view = view

  vim.api.nvim_buf_create_user_command(view.bufnr, 'ZdiagCodeAction', function()
    view:code_action()
  end, {
    desc = 'Request LSP code actions for the source under the cursor',
  })

  vim.api.nvim_set_current_buf(view.bufnr)
  vim.bo[view.bufnr].filetype = 'zdiag'
end

---Jump from the active diagnostics view to the represented source line.
---
---@param opts? zdiag.JumpOpts
---@return boolean jumped
function M.jump_to_source(opts)
  if
    not active_view
    or not vim.api.nvim_buf_is_valid(active_view.bufnr)
    or vim.api.nvim_get_current_buf() ~= active_view.bufnr
  then
    return false
  end

  local view = active_view
  view:jump(opts)

  if not vim.api.nvim_buf_is_valid(view.bufnr) then
    active_view = nil
  end

  return true
end

---Close the active diagnostics view buffer.
---
---@param opts? { force?: boolean }
---@return boolean closed
function M.close(opts)
  opts = opts or {}

  if not active_view then
    return false
  end

  local view = active_view

  if not vim.api.nvim_buf_is_valid(view.bufnr) then
    active_view = nil
    require('zdiag.view.autocmd').remove_autocmd(view)
    return false
  end

  vim.api.nvim_buf_delete(view.bufnr, { force = opts.force or false })

  require('zdiag.view.autocmd').remove_autocmd(view)

  if active_view == view then
    active_view = nil
  end

  return true
end

---Call a callback at the represented position when called from the active view.
---Outside the view, run the callback in the current buffer as usual.
---
---@param callback fun(): any
---@return any
function M.call(callback)
  if
    active_view
    and vim.api.nvim_buf_is_valid(active_view.bufnr)
    and vim.api.nvim_get_current_buf() == active_view.bufnr
  then
    local _, result = active_view:call(callback)
    return result
  end

  return callback()
end

---Request an LSP code action in the active source context.
---
---@param opts? vim.lsp.buf.code_action.Opts
function M.code_action(opts)
  if
    active_view
    and vim.api.nvim_buf_is_valid(active_view.bufnr)
    and vim.api.nvim_get_current_buf() == active_view.bufnr
  then
    return active_view:code_action(opts)
  end

  return vim.lsp.buf.code_action(opts)
end

---Open diagnostics for the source position represented by the cursor.
---
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function M.diagnostic_open_float(opts)
  if
    active_view
    and vim.api.nvim_buf_is_valid(active_view.bufnr)
    and vim.api.nvim_get_current_buf() == active_view.bufnr
  then
    return active_view:diagnostic_open_float(opts)
  end

  return vim.diagnostic.open_float(opts)
end

---Move to another diagnostic in the active diagnostics view.
---Outside the view, delegate to vim.diagnostic.jump().
---
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function M.diagnostic_jump(opts)
  if
    active_view
    and vim.api.nvim_buf_is_valid(active_view.bufnr)
    and vim.api.nvim_get_current_buf() == active_view.bufnr
  then
    return active_view:diagnostic_jump(opts)
  end

  return vim.diagnostic.jump(opts)
end

return M
