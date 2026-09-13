local M = {}

---@param view zdiag.View
---@param mark_id integer
function M.get_mark_row(view, mark_id)
  local position = vim.api.nvim_buf_get_extmark_by_id(
    view.bufnr,
    view.ctx.ns,
    mark_id,
    {}
  )

  if #position == 0 then
    return nil
  end

  return position[1]
end

return M
