local M = {}

---@param opts? zdiag.Config
function M.setup(opts)
  require("zdiag.config").setup(opts)
end

-- TODO delete
function M.open()
  require("zdiag.operation").open()
end

return M
