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
---@return zdiag.SourcePosition?
function M.get_position(workspace, row, col)
  local block, offset = find_block(workspace, row)

  if not block or not offset then
    return nil
  end

  if not vim.api.nvim_buf_is_valid(block.bufnr) then
    return nil
  end

  require('zdiag.utils.buffer').ensure_loaded(block.bufnr)

  local source_row = block.source_start + offset
  local source_line = vim.api.nvim_buf_get_lines(
    block.bufnr,
    source_row,
    source_row + 1,
    false
  )[1] or ''

  return {
    bufnr = block.bufnr,
    row = source_row,
    col = math.min(col, #source_line),
    block = block,
  }
end

return M
