local M = {}

---Get all diagnostics and sort them by buffer, line, and column.
---
---@param _ctx zdiag.Context
---@return vim.Diagnostic[]
function M.get_diagnostics(_ctx)
  local diagnostics = vim.diagnostic.get(nil)

  table.sort(diagnostics, function(a, b)
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end

    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end

    return a.col < b.col
  end)

  return diagnostics
end

---Group diagnostics by source buffer.
---
---@param _ctx zdiag.Context
---@param diagnostics vim.Diagnostic[]
---@return table<integer, vim.Diagnostic[]> groups
---@return integer[] order
function M.group_diagnostics(_ctx, diagnostics)
  local groups = {}
  local order = {}

  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr

    if not groups[bufnr] then
      groups[bufnr] = {}
      table.insert(order, bufnr)
    end

    table.insert(groups[bufnr], diagnostic)
  end

  return groups, order
end

---Build merged source-line ranges around diagnostics.
---
---@param _ctx zdiag.Context
---@param diagnostics vim.Diagnostic[]
---@param range integer
---@return { start_line: integer, end_line: integer, diagnostics: vim.Diagnostic[] }[]
function M.build_diagnostics_ranges(_ctx, diagnostics, range)
  local ranges = {}

  for _, diagnostic in ipairs(diagnostics) do
    local start_line = math.max(0, diagnostic.lnum - range)
    local end_line = diagnostic.lnum + range

    local last = ranges[#ranges]

    if last and start_line <= last.end_line + 1 then
      last.end_line = math.max(last.end_line, end_line)
      table.insert(last.diagnostics, diagnostic)
    else
      table.insert(ranges, {
        start_line = start_line,
        end_line = end_line,
        diagnostics = { diagnostic },
      })
    end
  end

  return ranges
end

return M
