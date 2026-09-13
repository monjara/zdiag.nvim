local M = {}

function M.get_mark_row(ns, buf, mark_id)
  local position = vim.api.nvim_buf_get_extmark_by_id(
    buf,
    ns,
    mark_id,
    {}
  )

  if #position == 0 then
    return nil
  end

  return position[1]
end

return M
