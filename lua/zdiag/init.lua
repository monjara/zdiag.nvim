local M = {}

---Configure zdiag.
---
---@param opts? zdiag.Config
function M.setup(opts)
  require("zdiag.config").setup(opts)
end

---Open the diagnostics view.
function M.open()
  require("zdiag.usecase").open()
end

return M
