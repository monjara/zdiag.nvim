local M = {}

---Prepare a target window for jumping to source.
---
---@param mode zdiag.JumpMode
---@return integer
local function prepare_window(mode)
  if mode == "split" then
    vim.cmd("split")
  end

  return vim.api.nvim_get_current_win()
end

---Delete the diagnostics view after a successful close-mode jump.
---
---@param view zdiag.View
local function close_view(view)
  vim.api.nvim_buf_delete(view.bufnr, { force = false })
  view.closed = true
  require("zdiag.view.autocmd").remove_autocmd(view)
end

---Jump to the source line corresponding to the current cursor position in the view.
---
---@param view zdiag.View
---@param opts? zdiag.JumpOpts
function M.jump_to_source(view, opts)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local block, offset =
      require("zdiag.view.source").find_block(
        view,
        cursor[1] - 1
      )

  if not block then
    vim.notify(
      "zdiag: cursor is not on a source line",
      vim.log.levels.INFO
    )
    return
  end

  local mode = require("zdiag.config").get_jump_mode(opts)

  if mode == "close" and vim.bo[view.bufnr].modified then
    vim.notify(
      "zdiag: write or discard view changes before a close-mode jump",
      vim.log.levels.WARN
    )
    return
  end

  local col = cursor[2]

  local source_lnum = block.source_start + offset

  local source_line_count =
      vim.api.nvim_buf_line_count(block.bufnr)

  source_lnum = math.min(
    source_lnum,
    math.max(0, source_line_count - 1)
  )

  local target_win = prepare_window(mode)

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

  if mode == "close" then
    close_view(view)
  end
end

return M
