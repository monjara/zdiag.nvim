local M = {}

---Find the source block containing a row, or the closest block when the row is
---a display-only header, spacer, or separator.  Prefer the following block
---when both sides are equally close.
---
---@param workspace zdiag.Workspace
---@param row integer
---@return zdiag.Block?
---@return integer? offset
---@return boolean? exact
local function find_block(workspace, row)
  local previous_block
  local previous_distance
  local next_block
  local next_distance

  for _, block in ipairs(workspace.blocks) do
    local start_row, end_row = block:get_workspace_range(workspace)

    if start_row and end_row and row >= start_row and row < end_row then
      return block, row - start_row, true
    end

    if start_row and row < start_row then
      local distance = start_row - row

      if not next_distance or distance < next_distance then
        next_block = block
        next_distance = distance
      end
    elseif end_row and row >= end_row then
      local distance = row - end_row + 1

      if not previous_distance or distance < previous_distance then
        previous_block = block
        previous_distance = distance
      end
    end
  end

  if
    next_block and (not previous_distance or next_distance <= previous_distance)
  then
    return next_block, 0, false
  end

  if previous_block then
    return previous_block,
      math.max(previous_block.source_end - previous_block.source_start - 1, 0),
      false
  end

  return nil, nil, nil
end

---Return the source position represented by a row and column in the workspace.
---
---@param workspace zdiag.Workspace
---@param row integer
---@param col integer
---@return zdiag.SourcePosition?
function M.get_position(workspace, row, col)
  local block, offset, exact = find_block(workspace, row)

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
    col = exact and math.min(col, #source_line) or 0,
    block = block,
  }
end

return M
