local M = {}

function M.get_relative_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return vim.fn.fnamemodify(name, ':.')
end

return M
