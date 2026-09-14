local M = {}

---Create the editable diagnostics view buffer.
---
---@return integer bufnr
function M.build_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  require("zdiag.log").debug("Buffer created with bufnr: " .. bufnr)

  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true

  vim.api.nvim_buf_set_name(bufnr, "zdiag://diagnostics")

  return bufnr
end

---Clear the modified flag on a diagnostics view buffer.
---
---@param bufnr integer
function M.mark_modified(bufnr)
  vim.bo[bufnr].modified = false
end

return M
