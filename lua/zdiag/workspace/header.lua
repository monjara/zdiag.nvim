---@class zdiag.Header
---@field row integer
---@field text string
---@field new fun(self: zdiag.Header, row: integer, text: string): zdiag.Header
---@field apply fun(self: zdiag.Header, workspace: zdiag.Workspace): nil

local Header = {}
Header.__index = Header

---Create a display-only file header.
---
---@param row integer
---@param text string
---@return zdiag.Header
function Header:new(row, text)
  return setmetatable({
    row = row,
    text = text,
  }, self)
end

---Draw the header as display-only text on its placeholder line.
---
---@param workspace zdiag.Workspace
function Header:apply(workspace)
  local highlight = require('zdiag.core.highlight').header_hl()

  vim.api.nvim_buf_set_extmark(workspace.bufnr, workspace.ctx.ns, self.row, 0, {
    line_hl_group = highlight,
    right_gravity = false,
    virt_text = {
      { self.text, highlight },
    },
    virt_text_pos = 'overlay',
  })
end

return Header
