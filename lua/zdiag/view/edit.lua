local M = {}

local function get_mark_row(ctx, buf, mark_id)
  local position = vim.api.nvim_buf_get_extmark_by_id(
    buf,
    ctx.ns,
    mark_id,
    {}
  )

  if #position == 0 then
    return nil
  end

  return position[1]
end


local function collect_edits(view)
  local edits = {}

  for _, block in ipairs(view.blocks) do
    local start_row = get_mark_row(
      view.ctx,
      view.view_buf,
      block.start_mark
    )

    local end_row = get_mark_row(
      view.ctx,
      view.view_buf,
      block.end_mark
    )

    if start_row and end_row then
      local edited_lines =
          vim.api.nvim_buf_get_lines(
            view.view_buf,
            start_row,
            end_row,
            false
          )

      table.insert(edits, {
        bufnr = block.bufnr,
        source_start = block.source_start,
        source_end = block.source_end,
        lines = edited_lines,
      })
    end
  end

  return edits
end

---apply changes from the view to the source files
---
---@param view zdiag.View
function M.apply_changes(view)
  local edits = collect_edits(view)

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

    if not vim.api.nvim_buf_is_loaded(edit.bufnr) then
      vim.fn.bufload(edit.bufnr)
    end

    vim.api.nvim_buf_set_lines(
      edit.bufnr,
      edit.source_start,
      edit.source_end,
      false,
      edit.lines
    )

    touched_buffers[edit.bufnr] = true

    ::continue::
  end

  for bufnr in pairs(touched_buffers) do
    local name = vim.api.nvim_buf_get_name(bufnr)

    if name ~= "" then
      local ok, err = pcall(function()
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd("silent write")
        end)
      end)

      if not ok then
        vim.notify(
          "zdiag: failed to write "
          .. name
          .. "\n"
          .. tostring(err),
          vim.log.levels.ERROR
        )

        return
      end
    end
  end

  require("zdiag.buffer").mark_modified(view.bufnr)

  vim.notify(
    "zdiag: changes written to source files",
    vim.log.levels.INFO
  )
end

return M
