local M = {}

local function find_block_at_cursor(ctx, view_buf, blocks)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  for _, block in ipairs(blocks) do
    local start_row = require("zdiag.extmark").get_mark_row(ctx.ns, view_buf, block.start_mark)
    local end_row = require("zdiag.extmark").get_mark_row(ctx.ns, view_buf, block.end_mark)

    if start_row and end_row then
      if row >= start_row and row < end_row then
        return block, row - start_row
      end
    end
  end

  return nil, nil
end


function M.jump_to_source(ctx, view_buf, blocks)
  local block, offset = find_block_at_cursor(ctx, view_buf, blocks)

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

  local target_win = require('zdiag.window').prepare_window(ctx, view_buf)

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
