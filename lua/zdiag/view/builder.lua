local M = {}

---Append one source line and its diagnostic metadata to the view model.
---
---@param view zdiag.View
---@param source_line string
---@param diagnostics vim.Diagnostic[]
local function append_source_line(view, source_line, diagnostics)
  local Decoration = require('zdiag.view.decoration')
  local LineHighlight = require('zdiag.view.line_highlight')

  table.insert(view.lines, source_line)

  local view_row = #view.lines - 1
  local highest_severity

  for _, diagnostic in ipairs(diagnostics) do
    highest_severity = math.min(highest_severity or vim.diagnostic.severity.HINT, diagnostic.severity)

    table.insert(view.decorations, Decoration:new_diagnostic(view_row, diagnostic.col, diagnostic, #source_line))
  end

  if highest_severity then
    table.insert(view.line_highlights, LineHighlight:new(view_row, highest_severity))
  end
end

---Append one contiguous source range to the view model.
---
---@param view zdiag.View
---@param bufnr integer
---@param range zdiag.DiagnosticRange
---@param line_count integer
---@param diagnostics_by_line table<integer, vim.Diagnostic[]>
---@return integer separator_row
local function append_range(view, bufnr, range, line_count, diagnostics_by_line)
  local Block = require('zdiag.view.block')
  local start_line = range.start_line
  local end_line = math.min(line_count - 1, range.end_line)
  local source_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  local view_start = #view.lines

  for index, source_line in ipairs(source_lines) do
    local source_lnum = start_line + index - 1
    append_source_line(view, source_line, diagnostics_by_line[source_lnum] or {})
  end

  -- block末尾を示すためのseparator。
  -- end_markはこの行に置くので、
  -- source部分は [start_mark, end_mark) になる。
  local separator_row = #view.lines
  table.insert(view.lines, '')

  table.insert(
    view.blocks,
    Block:new {
      bufnr = bufnr,

      source_start = start_line,

      -- nvim_buf_set_lines() のendはexclusive
      source_end = end_line + 1,

      original_lines = source_lines,

      view_start = view_start,
      view_end = separator_row,
    }
  )

  return separator_row
end

---Append one source buffer and all of its diagnostic ranges to the view model.
---
---@param view zdiag.View
---@param buffer zdiag.BufferDiagnostics
local function append_buffer(view, buffer)
  local Diagnostic = require('zdiag.diagnostic')
  local Header = require('zdiag.view.header')
  local Separator = require('zdiag.view.separator')
  local bufnr = buffer.bufnr

  require('zdiag.buffer').ensure_loaded(bufnr)

  if #view.lines > 0 then
    table.insert(view.lines, '')
  end

  table.insert(view.headers, Header:new(#view.lines, '▼ ' .. require('zdiag.fs').get_relative_path(bufnr)))

  -- The header is drawn over this empty placeholder, so its text is not
  -- part of the editable buffer contents.
  table.insert(view.lines, '')

  -- Keep one editable-text line between the header and its source blocks.
  table.insert(view.lines, '')

  local diagnostics_by_line = Diagnostic.group_by_line(buffer.diagnostics)
  local ranges = Diagnostic.build_ranges(buffer.diagnostics, require('zdiag.config').get_context_lines())
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local previous_separator_row

  for _, range in ipairs(ranges) do
    if range.start_line >= line_count then
      break
    end

    if previous_separator_row then
      table.insert(view.separators, Separator:new(previous_separator_row))
    end

    previous_separator_row = append_range(view, bufnr, range, line_count, diagnostics_by_line)
  end
end

---Clear the in-memory representation of a view.
---
---@param view zdiag.View
function M.clear(view)
  view.lines = {}
  view.headers = {}
  view.separators = {}
  view.blocks = {}
  view.decorations = {}
  view.line_highlights = {}
end

---Build the in-memory representation of a view from diagnostics grouped by
---source buffer.
---
---@param view zdiag.View
---@param buffers zdiag.BufferDiagnostics[]
---@return zdiag.View
function M.build(view, buffers)
  for _, buffer in ipairs(buffers) do
    append_buffer(view, buffer)
  end

  if #view.lines == 0 then
    table.insert(view.lines, 'No diagnostics')
  end

  return view
end

return M
