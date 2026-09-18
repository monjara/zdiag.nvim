local M = {}

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
---@return { bufnr: integer, row: integer, col: integer, block: zdiag.Block }?
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

---Run a callback with the source buffer and position under the cursor active.
---
---@param workspace zdiag.Workspace
---@param callback fun(): any
---@return boolean executed
---@return any result
function M.call(workspace, callback)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local position = M.get_position(workspace, cursor[1] - 1, cursor[2])

  if not position then
    vim.notify('zdiag: cursor is not on a source line', vim.log.levels.INFO)
    return false, nil
  end

  local result

  vim.api.nvim_buf_call(position.bufnr, function()
    local winid = vim.api.nvim_get_current_win()
    local previous_cursor = vim.api.nvim_win_get_cursor(winid)

    vim.api.nvim_win_set_cursor(winid, { position.row + 1, position.col })

    local ok, callback_result = xpcall(callback, debug.traceback)

    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == position.bufnr then
      vim.api.nvim_win_set_cursor(winid, previous_cursor)
    end

    if not ok then
      error(callback_result, 0)
    end

    result = callback_result
  end)

  return true, result
end

return M
