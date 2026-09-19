local M = {}

---Append one source line and its diagnostic metadata to the workspace model.
---
---@param workspace zdiag.Workspace
---@param source_line string
---@param diagnostics vim.Diagnostic[]
local function append_source_line(workspace, source_line, diagnostics)
  local Decoration = require('zdiag.workspace.decoration')
  local LineHighlight = require('zdiag.workspace.line_highlight')

  table.insert(workspace.lines, source_line)

  local workspace_row = #workspace.lines - 1
  local highest_severity

  for _, diagnostic in ipairs(diagnostics) do
    highest_severity = math.min(
      highest_severity or vim.diagnostic.severity.HINT,
      diagnostic.severity
    )

    table.insert(
      workspace.decorations,
      Decoration:new_diagnostic(
        workspace_row,
        diagnostic.col,
        diagnostic,
        #source_line
      )
    )
  end

  if highest_severity then
    table.insert(
      workspace.line_highlights,
      LineHighlight:new(workspace_row, highest_severity)
    )
  end
end

---Append one contiguous source range to the workspace model.
---
---@param workspace zdiag.Workspace
---@param bufnr integer
---@param range zdiag.DiagnosticRange
---@param line_count integer
---@param diagnostics_by_line table<integer, vim.Diagnostic[]>
---@return integer separator_row
local function append_range(
  workspace,
  bufnr,
  range,
  line_count,
  diagnostics_by_line
)
  local Block = require('zdiag.workspace.block')
  local start_line = range.start_line
  local end_line = math.min(line_count - 1, range.end_line)
  local source_lines =
    vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  local workspace_start = #workspace.lines

  for index, source_line in ipairs(source_lines) do
    local source_lnum = start_line + index - 1
    append_source_line(
      workspace,
      source_line,
      diagnostics_by_line[source_lnum] or {}
    )
  end

  -- block末尾を示すためのseparator。
  -- end_markはこの行に置くので、
  -- source部分は [start_mark, end_mark) になる。
  local separator_row = #workspace.lines
  table.insert(workspace.lines, '')

  table.insert(
    workspace.blocks,
    Block:new {
      bufnr = bufnr,

      source_start = start_line,

      -- nvim_buf_set_lines() のendはexclusive
      source_end = end_line + 1,

      original_lines = source_lines,

      workspace_start = workspace_start,
      workspace_end = separator_row,
    }
  )

  return separator_row
end

---Append one source buffer and all of its diagnostic ranges to the workspace model.
---
---@param workspace zdiag.Workspace
---@param buffer zdiag.BufferDiagnostics
local function append_buffer(workspace, buffer)
  local Diagnostic = require('zdiag.core.diagnostic')
  local Header = require('zdiag.workspace.header')
  local Separator = require('zdiag.workspace.separator')
  local bufnr = buffer.bufnr

  require('zdiag.utils.buffer').ensure_loaded(bufnr)

  if #workspace.lines > 0 then
    table.insert(workspace.lines, '')
  end

  table.insert(
    workspace.headers,
    Header:new(
      #workspace.lines,
      '▼ ' .. require('zdiag.utils.fs').get_relative_path(bufnr)
    )
  )

  -- The header is drawn over this empty placeholder, so its text is not
  -- part of the editable buffer contents.
  table.insert(workspace.lines, '')

  -- Keep one editable-text line between the header and its source blocks.
  table.insert(workspace.lines, '')

  local diagnostics_by_line = Diagnostic.group_by_line(buffer.diagnostics)
  local ranges = Diagnostic.build_ranges(
    buffer.diagnostics,
    require('zdiag.core.config').get_context_lines()
  )
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local previous_separator_row

  for _, range in ipairs(ranges) do
    if range.start_line >= line_count then
      break
    end

    if previous_separator_row then
      table.insert(workspace.separators, Separator:new(previous_separator_row))
    end

    previous_separator_row =
      append_range(workspace, bufnr, range, line_count, diagnostics_by_line)
  end
end

---Clear the in-memory representation of a workspace.
---
---@param workspace zdiag.Workspace
function M.clear(workspace)
  workspace.lines = {}
  workspace.headers = {}
  workspace.separators = {}
  workspace.blocks = {}
  workspace.decorations = {}
  workspace.line_highlights = {}
end

---Build the in-memory representation of a workspace from diagnostics grouped by
---source buffer.
---
---@param workspace zdiag.Workspace
---@param buffers zdiag.BufferDiagnostics[]
---@return zdiag.Workspace
function M.build(workspace, buffers)
  for _, buffer in ipairs(buffers) do
    append_buffer(workspace, buffer)
  end

  if #workspace.lines == 0 then
    table.insert(workspace.lines, 'No diagnostics')
  end

  return workspace
end

return M
