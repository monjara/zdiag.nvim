---@class zdiag.LineHighlight
---@field row integer
---@field severity vim.diagnostic.Severity
---@field mark_id integer?
---@field apply fun(self: zdiag.LineHighlight, view: zdiag.View): nil

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
---@param view zdiag.View
function LineHighlight:apply(view)
  local group =
      require("zdiag.highlight")
          .line_hl(self.severity)

  if not group then
    return
  end

  self.mark_id =
      vim.api.nvim_buf_set_extmark(
        view.bufnr,
        view.ctx.ns,
        self.row,
        0,
        {
          line_hl_group = group,
          priority = 10,
          right_gravity = false,
        }
      )
end

return LineHighlight
