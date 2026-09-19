local M = {}

---@class zdiag.SourcePosition
---@field bufnr integer
---@field row integer
---@field col integer
---@field block zdiag.Block

---@class zdiag.SourceSelection
---@field mode string
---@field anchor zdiag.SourcePosition
---@field cursor zdiag.SourcePosition
---@field workspace_anchor { row: integer, col: integer }
---@field workspace_cursor { row: integer, col: integer }

---Find the source block containing a row in the diagnostics workspace.
---
---@param workspace zdiag.Workspace
---@param row integer
---@return zdiag.Block?
---@return integer? offset
local function find_block(workspace, row)
  for _, block in ipairs(workspace.blocks) do
    local start_row, end_row = block:get_workspace_range(workspace)

    if start_row and end_row and row >= start_row and row < end_row then
      return block, row - start_row
    end
  end

  return nil, nil
end

---Return the source position represented by a row and column in the workspace.
---
---@param workspace zdiag.Workspace
---@param row integer
---@param col integer
---@return zdiag.SourcePosition?
function M.get_position(workspace, row, col)
  local block, offset = find_block(workspace, row)

  if not block or not offset then
    return nil
  end

  if not vim.api.nvim_buf_is_valid(block.bufnr) then
    return nil
  end

  require('zdiag.buffer').ensure_loaded(block.bufnr)

  local source_row = block.source_start + offset
  local source_line = vim.api.nvim_buf_get_lines(block.bufnr, source_row, source_row + 1, false)[1] or ''

  return {
    bufnr = block.bufnr,
    row = source_row,
    col = math.min(col, #source_line),
    block = block,
  }
end

---Return whether a mode is one of the Visual modes.
---
---@param mode string
---@return boolean
local function is_visual(mode)
  return mode == 'v' or mode == 'V' or mode == '\22'
end

---Translate the active Visual selection to positions in one source block.
---
---@param workspace zdiag.Workspace
---@param mode string
---@return zdiag.SourceSelection?
local function get_selection(workspace, mode)
  if not is_visual(mode) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local anchor = vim.fn.getpos('v')
  local anchor_position = M.get_position(workspace, anchor[2] - 1, anchor[3] - 1)
  local cursor_position = M.get_position(workspace, cursor[1] - 1, cursor[2])

  if not anchor_position or not cursor_position or anchor_position.block ~= cursor_position.block then
    vim.notify('zdiag: selection must stay within one source block', vim.log.levels.INFO)
    return nil
  end

  return {
    mode = mode,
    anchor = anchor_position,
    cursor = cursor_position,
    workspace_anchor = { row = anchor[2] - 1, col = anchor[3] - 1 },
    workspace_cursor = { row = cursor[1] - 1, col = cursor[2] },
  }
end

---Enter a Visual mode with the given anchor and cursor positions.
---
---@param winid integer
---@param mode string
---@param anchor { row: integer, col: integer }
---@param cursor { row: integer, col: integer }
local function set_selection(winid, mode, anchor, cursor)
  vim.api.nvim_win_set_cursor(winid, { anchor.row + 1, anchor.col })
  vim.cmd('normal! ' .. mode)
  vim.api.nvim_win_set_cursor(winid, { cursor.row + 1, cursor.col })
end

---Leave Visual mode when it is still active.
local function stop_visual()
  if is_visual(vim.api.nvim_get_mode().mode) then
    local escape = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    vim.cmd('normal! ' .. escape)
  end
end

---Run a source callback with workspace-aware adapters for APIs whose work
---outlives the temporary source window created by nvim_buf_call().
---
---@param workspace zdiag.Workspace
---@param workspace_winid integer
---@param callback fun(): any
---@return boolean ok
---@return any result
local function call_with_workspace_apis(workspace, workspace_winid, callback)
  local original_jump = vim.diagnostic.jump
  local original_open_float = vim.diagnostic.open_float

  vim.diagnostic.jump = function(opts)
    local jump_opts = opts and vim.deepcopy(opts) or opts

    if
      type(jump_opts) == 'table'
      and (jump_opts.winid == 0 or jump_opts.winid == nil and (jump_opts.win_id == nil or jump_opts.win_id == 0))
    then
      jump_opts.winid = workspace_winid
      jump_opts.win_id = nil
    end

    return require('zdiag.workspace.diagnostic').jump(workspace, jump_opts)
  end

  vim.diagnostic.open_float = function(opts, ...)
    if opts == nil or type(opts) == 'number' then
      opts = ...
    end

    return vim.api.nvim_win_call(workspace_winid, function()
      return require('zdiag.workspace.diagnostic').open_float(workspace, opts, original_open_float)
    end)
  end

  -- A function passed directly was resolved before the adapter above was
  -- installed. Use the adapter for that common mapping form as well.
  local adapted_callback = callback == original_open_float and vim.diagnostic.open_float or callback
  local ok, result = xpcall(adapted_callback, debug.traceback)
  vim.diagnostic.jump = original_jump
  vim.diagnostic.open_float = original_open_float

  return ok, result
end

---Run a callback with the represented source cursor or Visual selection active.
---
---@param workspace zdiag.Workspace
---@param callback fun(): any
---@return boolean executed
---@return any result
function M.call(workspace, callback)
  local mode = vim.api.nvim_get_mode().mode
  local selection = get_selection(workspace, mode)

  if is_visual(mode) and not selection then
    return false, nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local position = M.get_position(workspace, cursor[1] - 1, cursor[2])

  if not position then
    vim.notify('zdiag: cursor is not on a source line', vim.log.levels.INFO)
    return false, nil
  end

  local result
  local callback_ok = true
  local callback_error
  local workspace_winid = vim.api.nvim_get_current_win()

  local call_ok, call_error = xpcall(function()
    vim.api.nvim_buf_call(position.bufnr, function()
      local winid = vim.api.nvim_get_current_win()
      local previous_cursor = vim.api.nvim_win_get_cursor(winid)

      local ok, callback_result = xpcall(function()
        if selection then
          set_selection(winid, selection.mode, selection.anchor, selection.cursor)
        else
          vim.api.nvim_win_set_cursor(winid, { position.row + 1, position.col })
        end

        local ok, callback_result = call_with_workspace_apis(workspace, workspace_winid, callback)

        if not ok then
          error(callback_result, 0)
        end

        return callback_result
      end, debug.traceback)

      if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == position.bufnr then
        stop_visual()
        vim.api.nvim_win_set_cursor(winid, previous_cursor)
      end

      if not ok then
        callback_ok = false
        callback_error = callback_result
        return
      end

      result = callback_result
    end)
  end, debug.traceback)

  if
    selection
    and vim.api.nvim_win_is_valid(workspace_winid)
    and vim.api.nvim_get_current_win() == workspace_winid
    and vim.api.nvim_win_get_buf(workspace_winid) == workspace.bufnr
  then
    stop_visual()
    set_selection(workspace_winid, selection.mode, selection.workspace_anchor, selection.workspace_cursor)
  end

  if not call_ok then
    error(call_error, 0)
  end

  if not callback_ok then
    error(callback_error, 0)
  end

  return true, result
end

return M
