---@class zdiag.LineHighlight
---@field row integer
---@field severity vim.diagnostic.Severity
---@field apply fun(self: zdiag.LineHighlight, workspace: zdiag.Workspace): nil

local LineHighlight = {}
LineHighlight.__index = LineHighlight

---Create a whole-line diagnostic highlight.
---
---@param row integer
---@param severity vim.diagnostic.Severity
---@return zdiag.LineHighlight
function LineHighlight:new(row, severity)
  return setmetatable({
    row = row,
    severity = severity,
  }, self)
end

---Apply the theme-provided highlight group to the line.
---
---@param workspace zdiag.Workspace
function LineHighlight:apply(workspace)
  local group = require('zdiag.core.highlight').line_hl(self.severity)

  if not group then
    return
  end

  vim.api.nvim_buf_set_extmark(workspace.bufnr, workspace.ctx.ns, self.row, 0, {
    line_hl_group = group,
    priority = 10,
    right_gravity = false,
  })
end

return LineHighlight
