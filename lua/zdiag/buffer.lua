local M = {}

function M.build_buffer(ctx)
  local bufnr = vim.api.nvim_create_buf(false, true)
  require("zdiag.log").debug("Buffer created with bufnr: " .. bufnr)

  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true

  vim.api.nvim_buf_set_name(bufnr, "zdiag://diagnostics")

  return bufnr
end

function M.mark_modified(ctx, bufnr)
  vim.bo[bufnr].modified = false
end

return M
