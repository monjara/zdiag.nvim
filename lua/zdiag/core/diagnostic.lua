local M = {}

---@class zdiag.BufferDiagnostics
---@field bufnr integer
---@field diagnostics vim.Diagnostic[]

---@class zdiag.DiagnosticRange
---@field start_line integer
---@field end_line integer
---@field diagnostics vim.Diagnostic[]

---Sort diagnostics by buffer and source position.
---
---@param diagnostics vim.Diagnostic[]
local function sort_by_position(diagnostics)
  table.sort(diagnostics, function(a, b)
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end

    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end

    return a.col < b.col
  end)
end

---Group sorted diagnostics by their source buffer.
---
---@param diagnostics vim.Diagnostic[]
---@return zdiag.BufferDiagnostics[]
local function group_by_buffer(diagnostics)
  local buffers = {}

  for _, diagnostic in ipairs(diagnostics) do
    local buffer = buffers[#buffers]

    if not buffer or buffer.bufnr ~= diagnostic.bufnr then
      buffer = {
        bufnr = diagnostic.bufnr,
        diagnostics = {},
      }
      table.insert(buffers, buffer)
    end

    table.insert(buffer.diagnostics, diagnostic)
  end

  return buffers
end

---Get all diagnostics, ordered and grouped by source buffer.
---
---@return zdiag.BufferDiagnostics[]
function M.get_by_buffer()
  local severity = require('zdiag.core.config').get_diagnostic_severity()
  local diagnostics = vim.diagnostic.get(nil, {
    severity = severity,
  })
  sort_by_position(diagnostics)
  return group_by_buffer(diagnostics)
end

---Build merged source-line ranges around diagnostics from one buffer.
---
---@param diagnostics vim.Diagnostic[]
---@param context_lines integer
---@return zdiag.DiagnosticRange[]
function M.build_ranges(diagnostics, context_lines)
  local ranges = {}

  for _, diagnostic in ipairs(diagnostics) do
    local start_line = math.max(0, diagnostic.lnum - context_lines)
    local end_line = diagnostic.lnum + context_lines
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

---Group diagnostics by their zero-based source line number.
---
---@param diagnostics vim.Diagnostic[]
---@return table<integer, vim.Diagnostic[]>
function M.group_by_line(diagnostics)
  local result = {}

  for _, diagnostic in ipairs(diagnostics) do
    local line = diagnostic.lnum

    result[line] = result[line] or {}
    table.insert(result[line], diagnostic)
  end

  return result
end

return M
