---@class zdiag.Context
---@field ns number

local Context = {}
Context.__index = Context

function Context:new()
  local ns = vim.api.nvim_create_namespace("zdiag")

  return setmetatable({
    ns = ns
  }, Context)
end

return Context
