---@class zdiag.View
---@field ctx zdiag.Context
---@field bufnr integer
---@field lines string[]
---@field blocks zdiag.Block[]
---@field decorations zdiag.Decoration[]
---@field jump fun(self: zdiag.View): nil
---@field build fun(self: zdiag.View, range_groups: table<integer, any[]>, order: integer[]): zdiag.View
---@field render fun(self: zdiag.View): zdiag.View
---@field mark_unmodified fun(self: zdiag.View): nil
---@field new fun(self: zdiag.View, ctx: zdiag.Context): zdiag.View

local View = {}
View.__index = View

---Create a new view instance.
---
---@param ctx zdiag.Context
---@return zdiag.View
function View:new(ctx)
  local bufnr = require("zdiag.buffer").build_buffer()

  return setmetatable({
    ctx = ctx,
    bufnr = bufnr,
    lines = {},
    blocks = {},
    decorations = {}
  }, self)
end

---Build the view from the given diagnostic ranges and order.
---
---@param range_groups table<integer, { start_line: integer, end_line: integer, diagnostics: vim.Diagnostic[] }[]>
---@param order integer[]
---@return zdiag.View
function View:build(range_groups, order)
  local Block = require("zdiag.view.block")
  local Decoration = require("zdiag.view.decoration")

  for _, bufnr in ipairs(order) do
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)
    end

    if #self.lines > 0 then
      table.insert(self.lines, "")
    end

    local name =
        vim.api.nvim_buf_get_name(bufnr)

    local relative =
        vim.fn.fnamemodify(name, ":.")

    table.insert(self.lines, "▼ " .. relative)
    table.insert(self.lines, "")

    local ranges =
        range_groups[bufnr] or {}

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

      local view_start = #self.lines

      for index, source_line in ipairs(source_lines) do
        local source_lnum =
            start_line + index - 1

        table.insert(self.lines, source_line)

        local view_row = #self.lines - 1

        table.insert(
          self.decorations,
          Decoration:new_line(view_row, source_lnum)
        )

        for _, diagnostic in ipairs(range.diagnostics) do
          if diagnostic.lnum == source_lnum then
            table.insert(
              self.decorations,
              Decoration:new_diagnostic(
                view_row,
                diagnostic.col,
                diagnostic
              )
            )
          end
        end
      end

      -- block末尾を示すためのseparator。
      -- end_markはこの行に置くので、
      -- source部分は [start_mark, end_mark) になる。
      local separator_row = #self.lines
      table.insert(self.lines, "")

      table.insert(
        self.blocks,
        Block:new({
          bufnr = bufnr,

          source_start = start_line,

          -- nvim_buf_set_lines() のendはexclusive
          source_end = end_line + 1,

          view_start = view_start,
          view_end = separator_row,
        })
      )
    end
  end

  if #self.lines == 0 then
    table.insert(self.lines, "No diagnostics")
  end

  return self
end

---Render the view.
---
---@return zdiag.View
function View:render()
  require("zdiag.view.line").write_lines(self)

  for _, block in ipairs(self.blocks) do
    block:attach_mark(self)
  end

  for _, decoration in ipairs(self.decorations) do
    decoration:apply(self)
  end

  require("zdiag.view.autocmd").create_autocmd(self)
  self:mark_unmodified()

  return self
end

---Clear the modified flag on the view buffer.
function View:mark_unmodified()
  require("zdiag.buffer").mark_modified(self.bufnr)
end

---Jump to the source of the diagnostic under the cursor.
function View:jump()
  require('zdiag.view.jump').jump_to_source(self)
end

return View
