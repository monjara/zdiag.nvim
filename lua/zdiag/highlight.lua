local M = {}

local line_highlight_groups = {
  [vim.diagnostic.severity.ERROR] =
      "ZdiagDiagnosticLineError",
  [vim.diagnostic.severity.WARN] =
      "ZdiagDiagnosticLineWarn",
  [vim.diagnostic.severity.INFO] =
      "ZdiagDiagnosticLineInfo",
  [vim.diagnostic.severity.HINT] =
      "ZdiagDiagnosticLineHint",
}

---Start Tree-sitter highlighting using the source buffer's language.
---
---@param bufnr integer
---@param source_bufnr integer
---@return boolean started
function M.start_treesitter(bufnr, source_bufnr)
  if not vim.treesitter
      or type(vim.treesitter.start) ~= "function"
      or not vim.api.nvim_buf_is_valid(source_bufnr)
  then
    return false
  end

  local filetype = vim.bo[source_bufnr].filetype

  if filetype == "" then
    return false
  end

  local language = filetype

  if vim.treesitter.language
      and type(vim.treesitter.language.get_lang) == "function"
  then
    language =
        vim.treesitter.language.get_lang(filetype)
        or filetype
  end

  return pcall(
    vim.treesitter.start,
    bufnr,
    language
  )
end

---Return the highlight group for a diagnostic severity.
---
---@param severity vim.diagnostic.Severity
---@return string
function M.severity_hl(severity)
  if severity == vim.diagnostic.severity.ERROR then
    return "DiagnosticError"
  elseif severity == vim.diagnostic.severity.WARN then
    return "DiagnosticWarn"
  elseif severity == vim.diagnostic.severity.INFO then
    return "DiagnosticInfo"
  else
    return "DiagnosticHint"
  end
end

---Copy only the theme-provided background into a zdiag line group.
---
---@param severity vim.diagnostic.Severity
---@return string?
function M.line_hl(severity)
  local source_group =
      require("zdiag.config")
          .get_line_highlight(severity)
  local target_group =
      line_highlight_groups[severity]

  if not source_group or not target_group then
    return nil
  end

  local ok, source =
      pcall(
        vim.api.nvim_get_hl,
        0,
        {
          name = source_group,
          link = false,
        }
      )

  source = ok and source or {}

  local background = {}

  if source.bg then
    background.bg = source.bg
  end

  if source.ctermbg then
    background.ctermbg = source.ctermbg
  end

  if source.blend then
    background.blend = source.blend
  end

  vim.api.nvim_set_hl(
    0,
    target_group,
    background
  )

  return target_group
end

---Refresh derived line groups after a colorscheme change.
function M.refresh_line_highlights()
  for severity in pairs(line_highlight_groups) do
    M.line_hl(severity)
  end
end

return M
