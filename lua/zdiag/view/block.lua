local M = {}

---attach_block_mark attaches extmarks to the start and end of each block in the view.
---
---@param view zdiag.View
function M.attach_block_mark(view)
  for _, block in ipairs(view.blocks) do
    block.start_mark =
        vim.api.nvim_buf_set_extmark(
          view.bufnr,
          view.ctx.ns,
          block.view_start,
          0,
          {
            right_gravity = false,
          }
        )

    block.end_mark =
        vim.api.nvim_buf_set_extmark(
          view.bufnr,
          view.ctx.ns,
          block.view_end,
          0,
          {
            right_gravity = true,
          }
        )

    block.view_start = nil
    block.view_end = nil
  end
end

return M
