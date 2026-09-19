---@class zdiag.Decoration
---@field row integer
---@field col integer
---@field line_length integer
---@field diagnostic vim.Diagnostic
---@field mark_id integer?
---@field apply fun(self: zdiag.Decoration, workspace: zdiag.Workspace): nil

local Decoration = {}
Decoration.__index = Decoration

---Create a diagnostic decoration.
---
---@param row integer
---@param col integer
---@param diagnostic vim.Diagnostic
---@param line_length integer
---@return zdiag.Decoration
function Decoration:new_diagnostic(row, col, diagnostic, line_length)
  return setmetatable({
    row = row,
    col = col,
    diagnostic = diagnostic,
    line_length = line_length,
  }, self)
end

---Apply the decoration to the workspace.
---
---@param workspace zdiag.Workspace
function Decoration:apply(workspace)
  local diagnostic = self.diagnostic

  local col = math.min(self.col, self.line_length)

  local end_col =
    math.min(math.max(col + 1, diagnostic.end_col or col + 1), self.line_length)

  local opts = {
    -- Preserve the whole-line diagnostic background underneath virtual text
    -- while applying the severity group as its foreground.
    hl_mode = 'combine',

    virt_text = {
      {
        '  ' .. diagnostic.message,
        require('zdiag.core.highlight').severity_hl(diagnostic.severity),
      },
    },

    virt_text_pos = 'eol',
  }

  if end_col > col then
    opts.end_col = end_col
    opts.hl_group =
      require('zdiag.core.highlight').severity_hl(diagnostic.severity)
  end

  self.mark_id = vim.api.nvim_buf_set_extmark(
    workspace.bufnr,
    workspace.ctx.ns,
    self.row,
    col,
    opts
  )
end

return Decoration
