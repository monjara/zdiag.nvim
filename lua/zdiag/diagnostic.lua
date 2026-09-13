local M = {}

-- Get all diagnostics in the current buffer and sort them by line number and column number
--
-- @return vim.Diagnostic[]
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
