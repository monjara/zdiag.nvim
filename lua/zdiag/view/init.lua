local M = {}

function M.build_view(ctx, buf, groups, order)
  local view = {
    lines = {},
    blocks = {},
    decorations = {}
  }

  for _, bufnr in ipairs(order) do
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)
    end

    if #view.lines > 0 then
      table.insert(view.lines, "")
    end

    local name =
        vim.api.nvim_buf_get_name(bufnr)

    local relative =
        vim.fn.fnamemodify(name, ":.")

    table.insert(view.lines, "▼ " .. relative)
    table.insert(view.lines, "")

    local buffer_diagnostics = groups[bufnr]

    local ranges =
        require("zdiag.diagnostic").build_diagnostics_ranges(ctx, buffer_diagnostics, 2)

    local line_count =
        vim.api.nvim_buf_line_count(bufnr)

    for _, range in ipairs(ranges) do
      local start_line =
          range.start_line

      local end_line =
          math.min(
            line_count - 1,
            range.end_line
          )

      local source_lines =
          vim.api.nvim_buf_get_lines(
            bufnr,
            start_line,
            end_line + 1,
            false
          )

      local view_start = #view.lines

      for index, source_line in ipairs(source_lines) do
        local source_lnum =
            start_line + index - 1

        table.insert(view.lines, source_line)

        local view_row = #view.lines - 1

        table.insert(view.decorations, {
          type = "line",
          row = view_row,
          source_lnum = source_lnum,
        })

        for _, diagnostic in ipairs(range.diagnostics) do
          if diagnostic.lnum == source_lnum then
            table.insert(view.decorations, {
              type = "diagnostic",
              row = view_row,
              col = diagnostic.col,
              diagnostic = diagnostic,
            })
          end
        end
      end

      -- block末尾を示すためのseparator。
      -- end_markはこの行に置くので、
      -- source部分は [start_mark, end_mark) になる。
      local separator_row = #view.lines
      table.insert(view.lines, "")

      table.insert(view.blocks, {
        bufnr = bufnr,

        source_start = start_line,

        -- nvim_buf_set_lines() のendはexclusive
        source_end = end_line + 1,

        view_start = view_start,
        view_end = separator_row,
      })
    end
  end

  if #view.lines == 0 then
    table.insert(view.lines, "No diagnostics")
  end

  vim.api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    view.lines
  )

  --
  -- block boundary
  --

  print("Setting extmarks for blocks in view ctx.ns ", ctx.ns)
  for _, block in ipairs(view.blocks) do
    block.start_mark =
        vim.api.nvim_buf_set_extmark(
          buf,
          ctx.ns,
          block.view_start,
          0,
          {
            right_gravity = false,
          }
        )

    block.end_mark =
        vim.api.nvim_buf_set_extmark(
          buf,
          ctx.ns,
          block.view_end,
          0,
          {
            right_gravity = true,
          }
        )

    block.view_start = nil
    block.view_end = nil
  end

  return view
end

function M.render(ctx, buf, view)
  require("zdiag.view.decoration").apply_decoration(ctx, buf, view)

  vim.api.nvim_create_autocmd(
    "BufWriteCmd",
    {
      buffer = buf,

      callback = function()
        require("zdiag.view.edit").apply_changes(ctx, buf, view.blocks)
      end,
    }
  )
end

return M
