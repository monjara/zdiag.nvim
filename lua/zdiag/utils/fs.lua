local M = {}

---Return a buffer's path relative to Neovim's current working directory.
---
---@param bufnr integer
---@return string
function M.get_relative_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return vim.fn.fnamemodify(name, ':.')
end

return M
