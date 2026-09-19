local M = {}

---Return whether two line collections contain the same text.
---
---@param left string[]
---@param right string[]
---@return boolean
local function same_lines(left, right)
  if #left ~= #right then
    return false
  end

  for index, line in ipairs(left) do
    if line ~= right[index] then
      return false
    end
  end

  return true
end

---Collect edited source blocks from the diagnostics workspace.
---
---@param workspace zdiag.Workspace
---@return { block: zdiag.Block, bufnr: integer, source_start: integer, source_end: integer, lines: string[] }[]
local function collect_edits(workspace)
  local edits = {}

  for _, block in ipairs(workspace.blocks) do
    local start_row, end_row = block:get_workspace_range(workspace)

    if start_row and end_row then
      local edited_lines = vim.api.nvim_buf_get_lines(workspace.bufnr, start_row, end_row, false)

      if not same_lines(edited_lines, block.original_lines) then
        table.insert(edits, {
          block = block,
          bufnr = block.bufnr,
          source_start = block.source_start,
          source_end = block.source_end,
          lines = edited_lines,
        })
      end
    end
  end

  return edits
end

---Update source ranges after an edit changes a block's line count.
---
---Blocks do not overlap, so only blocks after the edited source range move.
---Keeping these ranges current makes another write safe before the scheduled
---diagnostic reload has rebuilt the workspace.
---
---@param workspace zdiag.Workspace
---@param edit { block: zdiag.Block, bufnr: integer, source_start: integer, source_end: integer, lines: string[] }
local function update_source_ranges(workspace, edit)
  local line_delta = #edit.lines - (edit.source_end - edit.source_start)

  edit.block.source_end = edit.source_start + #edit.lines

  if line_delta == 0 then
    return
  end

  for _, block in ipairs(workspace.blocks) do
    if block ~= edit.block and block.bufnr == edit.bufnr and block.source_start >= edit.source_end then
      block.source_start = block.source_start + line_delta
      block.source_end = block.source_end + line_delta
    end
  end
end

---Apply changes from the workspace to the source files.
---
---@param workspace zdiag.Workspace
function M.apply_changes(workspace)
  local edits = collect_edits(workspace)

  -- 同じファイル内では後ろから適用する。
  -- 前方で行が増減しても後方rangeの位置がずれない。
  table.sort(edits, function(a, b)
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end

    return a.source_start > b.source_start
  end)

  local touched_buffers = {}

  for _, edit in ipairs(edits) do
    if not vim.api.nvim_buf_is_valid(edit.bufnr) then
      goto continue
    end

    require('zdiag.buffer').ensure_loaded(edit.bufnr)

    vim.api.nvim_buf_set_lines(edit.bufnr, edit.source_start, edit.source_end, false, edit.lines)

    update_source_ranges(workspace, edit)
    touched_buffers[edit.bufnr] = true

    ::continue::
  end

  for bufnr in pairs(touched_buffers) do
    local name = vim.api.nvim_buf_get_name(bufnr)

    if name ~= '' then
      local ok, err = pcall(function()
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd('silent write')
        end)
      end)

      if not ok then
        vim.notify('zdiag: failed to write ' .. name .. '\n' .. tostring(err), vim.log.levels.ERROR)

        return
      end
    end
  end

  for _, edit in ipairs(edits) do
    edit.block.original_lines = vim.deepcopy(edit.lines)
  end

  workspace:mark_unmodified()
  workspace.reload_deferred = false

  require('zdiag.workspace.autocmd').schedule_reload(workspace)

  vim.notify('zdiag: changes written to source files', vim.log.levels.INFO)
end

return M
