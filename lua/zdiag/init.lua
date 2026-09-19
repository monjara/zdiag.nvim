---@class zdiag: zdiag.Usecase
local M = {}

---@param opts? zdiag.Config
function M.setup(opts)
  require('zdiag.core.config').setup(opts)
end

return setmetatable(M, {
  __index = function(_, k)
    return require('zdiag.usecase')[k]
  end,
})
