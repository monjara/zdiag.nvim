local M = {}

---Find a window that is not showing the diagnostics view.
---
---@param view zdiag.View
---@return integer?
local function find_target_window(view)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local win_buf = vim.api.nvim_win_get_buf(win)

      if win_buf ~= view.bufnr then
        return win
      end
    end
  end

  return nil
end

---Prepare a target window for jumping to source.
---
---@param view zdiag.View
---@return integer
local function prepare_window(view)
  local target_win = find_target_window(view)

  if target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("split")
    target_win = vim.api.nvim_get_current_win()
  end

  return target_win
end


---Find the source block at the current cursor position.
---
---@param view zdiag.View
---@return zdiag.Block?
---@return integer?
local function find_block_at_cursor(view)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  for _, block in ipairs(view.blocks) do
    local start_row, end_row = block:get_view_range(view)

    if start_row and end_row then
      if row >= start_row and row < end_row then
        return block, row - start_row
      end
    end
  end

  return nil, nil
end


---Jump to the source line corresponding to the current cursor position in the view.
---
---@param view zdiag.View
function M.jump_to_source(view)
  local block, offset = find_block_at_cursor(view)

  if not block then
    vim.notify(
      "zdiag: cursor is not on a source line",
      vim.log.levels.INFO
    )
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = cursor[2]

  local source_lnum = block.source_start + offset

  local source_line_count =
      vim.api.nvim_buf_line_count(block.bufnr)

  source_lnum = math.min(
    source_lnum,
    math.max(0, source_line_count - 1)
  )

  local target_win = prepare_window(view)

  vim.api.nvim_win_set_buf(target_win, block.bufnr)

  local source_line =
      vim.api.nvim_buf_get_lines(
        block.bufnr,
        source_lnum,
        source_lnum + 1,
        false
      )[1] or ""

  col = math.min(col, #source_line)

  vim.api.nvim_win_set_cursor(
    target_win,
    { source_lnum + 1, col }
  )
end

return M
