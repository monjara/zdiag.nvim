---@class zdiag.Header
---@field row integer
---@field text string
---@field mark_id integer?
---@field new fun(self: zdiag.Header, row: integer, text: string): zdiag.Header
---@field apply fun(self: zdiag.Header, view: zdiag.View): nil

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
---@param view zdiag.View
function Header:apply(view)
  local highlight = require('zdiag.highlight').header_hl()

  self.mark_id = vim.api.nvim_buf_set_extmark(view.bufnr, view.ctx.ns, self.row, 0, {
    line_hl_group = highlight,
    right_gravity = false,
    virt_text = {
      { self.text, highlight },
    },
    virt_text_pos = 'overlay',
  })
end

return Header
