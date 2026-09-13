local M = {}

---writes the lines of a view to the buffer
---
---@param view zdiag.View
function M.write_lines(view)
  vim.api.nvim_buf_set_lines(
    view.bufnr,
    0,
    -1,
    false,
    view.lines
  )
end

return M
