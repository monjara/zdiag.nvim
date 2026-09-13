local M = {}

---Create autocmds for the given view.
---
---@param view zdiag.View
function M.create_autocmd(view)
  vim.api.nvim_create_autocmd(
    "BufWriteCmd",
    {
      buffer = view.bufnr,

      callback = function()
        require("zdiag.view.edit").apply_changes(view)
      end,
    }
  )
end

return M
