local M = {}

---Translate the active visual selection to a source-buffer range.
---
---@param view zdiag.View
---@return { start: [integer, integer], end: [integer, integer] }?
local function visual_range(view)
  local mode = vim.api.nvim_get_mode().mode

  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local anchor = vim.fn.getpos('v')
  local start_row = anchor[2] - 1
  local start_col = anchor[3] - 1
  local end_row = cursor[1] - 1
  local end_col = cursor[2]

  if end_row < start_row or end_row == start_row and end_col < start_col then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == 'V' then
    start_col = 0

    local line = vim.api.nvim_buf_get_lines(view.bufnr, end_row, end_row + 1, false)[1] or ''

    end_col = #line
  else
    -- Visual character and block selections include the cursor byte, while
    -- LSP ranges use an exclusive end position.
    end_col = end_col + 1
  end

  local source = require('zdiag.view.source')
  local start_position = source.get_position(view, start_row, start_col)

  local end_position = source.get_position(view, end_row, end_col)

  if not start_position or not end_position or start_position.block ~= end_position.block then
    vim.notify('zdiag: selection must stay within one source block', vim.log.levels.INFO)
    return nil
  end

  return {
    start = {
      start_position.row + 1,
      start_position.col,
    },
    ['end'] = {
      end_position.row + 1,
      end_position.col,
    },
  }
end

---Request LSP code actions for the source represented by the view cursor.
---
---@param view zdiag.View
---@param opts? vim.lsp.buf.code_action.Opts
function M.code_action(view, opts)
  opts = vim.deepcopy(opts or {})

  local mode = vim.api.nvim_get_mode().mode

  if not opts.range and (mode == 'v' or mode == 'V' or mode == '\22') then
    opts.range = visual_range(view)

    if not opts.range then
      return
    end
  end

  view:call(function()
    vim.lsp.buf.code_action(opts)
  end)
end

return M
