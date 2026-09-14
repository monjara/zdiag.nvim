local M = {}

---@class zdiag.Config
---@field line_highlight? table<vim.diagnostic.Severity, string|false>

---@type zdiag.Config
local defaults = {
  line_highlight = {
    [vim.diagnostic.severity.ERROR] =
        "DiagnosticVirtualTextError",
    [vim.diagnostic.severity.WARN] =
        "DiagnosticVirtualTextWarn",
    [vim.diagnostic.severity.INFO] =
        "DiagnosticVirtualTextInfo",
    [vim.diagnostic.severity.HINT] =
        "DiagnosticVirtualTextHint",
  },
}

---@type zdiag.Config
local options = vim.deepcopy(defaults)

---Configure zdiag.
---
---@param opts? zdiag.Config
function M.setup(opts)
  opts = opts or {}

  options = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(defaults),
    opts
  )

  options.line_highlight = vim.tbl_extend(
    "force",
    vim.deepcopy(defaults.line_highlight),
    opts.line_highlight or {}
  )
end

---Return the configured line highlight group for a severity.
---
---@param severity vim.diagnostic.Severity
---@return string?
function M.get_line_highlight(severity)
  local groups = options.line_highlight or {}
  local group = groups[severity]

  return type(group) == "string" and group or nil
end

return M
