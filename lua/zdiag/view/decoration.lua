---@class zdiag.Decoration
---@field row integer
---@field col integer
---@field diagnostic vim.Diagnostic
---@field mark_id integer?
---@field apply fun(self: zdiag.Decoration, view: zdiag.View): nil
---@field get_position fun(self: zdiag.Decoration, view: zdiag.View): integer?, integer?

local Decoration = {}
Decoration.__index = Decoration

---Create a diagnostic decoration.
---
---@param row integer
---@param col integer
---@param diagnostic vim.Diagnostic
---@return zdiag.Decoration
function Decoration:new_diagnostic(row, col, diagnostic)
  return setmetatable({
    row = row,
    col = col,
    diagnostic = diagnostic,
  }, self)
end

---Apply the decoration to the view.
---
---@param view zdiag.View
function Decoration:apply(view)
  local diagnostic =
      self.diagnostic

  local line =
      vim.api.nvim_buf_get_lines(
        view.bufnr,
        self.row,
        self.row + 1,
        false
      )[1] or ""

  local col =
      math.min(self.col, #line)

  local end_col =
      math.min(
        math.max(
          col,
          diagnostic.end_col
          or col + 1
        ),
        #line
      )

  local opts = {
    virt_text = {
      {
        "  "
        .. diagnostic.message,
        require("zdiag.highlight").severity_hl(
          diagnostic.severity
        ),
      },
    },

    virt_text_pos = "eol",
  }

  if end_col > col then
    opts.end_col = end_col
    opts.hl_group =
        require("zdiag.highlight").severity_hl(
          diagnostic.severity
        )
  end

  self.mark_id =
      vim.api.nvim_buf_set_extmark(
        view.bufnr,
        view.ctx.ns,
        self.row,
        col,
        opts
      )
end

---Return the decoration's current position in the editable view.
---
---@param view zdiag.View
---@return integer? row
---@return integer? col
function Decoration:get_position(view)
  if not self.mark_id then
    return nil, nil
  end

  local position =
      vim.api.nvim_buf_get_extmark_by_id(
        view.bufnr,
        view.ctx.ns,
        self.mark_id,
        {}
      )

  if #position == 0 then
    return nil, nil
  end

  return position[1], position[2]
end

return Decoration
