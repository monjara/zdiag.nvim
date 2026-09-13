local M = {}

function M.build_context()
  local ns = vim.api.nvim_create_namespace("zdiag")

  print("Namespace created with id: " .. ns)

  return {
    ns = ns,
  }
end

return M
