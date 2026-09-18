---@class zdiag.Separator
---@field row integer
---@field mark_id integer?
---@field new fun(self: zdiag.Separator, row: integer): zdiag.Separator
---@field apply fun(self: zdiag.Separator, workspace: zdiag.Workspace): nil

local Separator = {}
Separator.__index = Separator

---Create a display-only separator between source blocks.
---
---@param row integer
---@return zdiag.Separator
function Separator:new(row)
  return setmetatable({
    row = row,
  }, self)
end

---Draw the separator on its empty placeholder line.
---
---@param workspace zdiag.Workspace
function Separator:apply(workspace)
  local highlight = require('zdiag.highlight').separator_hl()

  self.mark_id = vim.api.nvim_buf_set_extmark(workspace.bufnr, workspace.ctx.ns, self.row, 0, {
    right_gravity = false,
    virt_text = {
      {
        string.rep('┈', math.max(vim.o.columns, 1)),
        highlight,
      },
    },
    virt_text_pos = 'overlay',
  })
end

return Separator
