---@class zdiag.Decoration
---@field type "line"|"diagnostic"
---@field row integer
---@field source_lnum integer?
---@field col integer?
---@field diagnostic vim.Diagnostic?
---@field apply fun(self: zdiag.Decoration, view: zdiag.View): nil

local Decoration = {}
Decoration.__index = Decoration

---Create a line-number decoration.
---
---@param row integer
---@param source_lnum integer
---@return zdiag.Decoration
function Decoration:new_line(row, source_lnum)
  return setmetatable({
    type = "line",
    row = row,
    source_lnum = source_lnum,
  }, self)
end

---Create a diagnostic decoration.
---
---@param row integer
---@param col integer
---@param diagnostic vim.Diagnostic
---@return zdiag.Decoration
function Decoration:new_diagnostic(row, col, diagnostic)
  return setmetatable({
    type = "diagnostic",
    row = row,
    col = col,
    diagnostic = diagnostic,
  }, self)
end

---Apply the decoration to the view.
---
---@param view zdiag.View
function Decoration:apply(view)
  if self.type == "line" then
    local prefix =
        string.format(
          "%4d │ ",
          self.source_lnum + 1
        )

    vim.api.nvim_buf_set_extmark(
      view.bufnr,
      view.ctx.ns,
      self.row,
      0,
      {
        virt_text = {
          {
            prefix,
            "LineNr",
          },
        },

        -- buffer本文には行番号を入れない
        virt_text_pos = "inline",
      }
    )
  elseif self.type == "diagnostic" then
    local diagnostic =
        self.diagnostic

    vim.api.nvim_buf_set_extmark(
      view.bufnr,
      view.ctx.ns,
      self.row,
      self.col,
      {
        end_col = math.max(
          self.col + 1,
          diagnostic.end_col
          or self.col + 1
        ),

        hl_group =
            require("zdiag.highlight").severity_hl(
              diagnostic.severity
            ),

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
    )
  end
end

return Decoration
