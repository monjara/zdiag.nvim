local M = {}

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

return M
