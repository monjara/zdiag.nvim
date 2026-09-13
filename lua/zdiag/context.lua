local M = {}

function M.build_context()
  local ns = vim.api.nvim_create_namespace("zdiag")

  return {
    ns = ns,
  }
end

return M
