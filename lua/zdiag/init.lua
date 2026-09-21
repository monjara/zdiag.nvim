if vim.fn.has('nvim-0.11') == 0 then
  local message = 'zdiag.nvim requires Neovim >= 0.11'

  vim.notify_once(message, vim.log.levels.ERROR, {
    title = 'zdiag.nvim',
  })

  error(message, 0)
end

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
