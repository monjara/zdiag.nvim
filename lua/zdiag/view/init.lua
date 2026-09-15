---@class zdiag.View
---@field ctx zdiag.Context
---@field bufnr integer
---@field lines string[]
---@field headers zdiag.Header[]
---@field separators zdiag.Separator[]
---@field blocks zdiag.Block[]
---@field decorations zdiag.Decoration[]
---@field line_highlights zdiag.LineHighlight[]
---@field reload_pending boolean?
---@field closed boolean?
---@field jump fun(self: zdiag.View, opts?: zdiag.JumpOpts): nil
---@field build fun(self: zdiag.View, buffers: zdiag.BufferDiagnostics[]): zdiag.View
---@field render fun(self: zdiag.View): zdiag.View
---@field reset fun(self: zdiag.View): zdiag.View
---@field mark_unmodified fun(self: zdiag.View): nil
---@field with_source fun(self: zdiag.View, callback: fun()): boolean, any
---@field code_action fun(self: zdiag.View, opts?: vim.lsp.buf.code_action.Opts): nil
---@field diagnostic_open_float fun(self: zdiag.View, opts?: vim.diagnostic.Opts.Float): integer?
---@field diagnostic_jump fun(self: zdiag.View, opts: vim.diagnostic.JumpOpts): vim.Diagnostic?
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
    headers = {},
    separators = {},
    blocks = {},
    decorations = {},
    line_highlights = {},
  }, self)
end

---Build the view from diagnostics grouped by source buffer.
---
---@param buffers zdiag.BufferDiagnostics[]
---@return zdiag.View
function View:build(buffers)
  local Block = require("zdiag.view.block")
  local Decoration = require("zdiag.view.decoration")
  local Diagnostic = require("zdiag.diagnostic")
  local Header = require("zdiag.view.header")
  local LineHighlight =
      require("zdiag.view.line_highlight")
  local Separator = require("zdiag.view.separator")

  for _, buffer in ipairs(buffers) do
    local bufnr = buffer.bufnr
    require("zdiag.buffer").ensure_loaded(bufnr)

    local diagnostics_by_line = {}

    for _, diagnostic in ipairs(buffer.diagnostics) do
      local diagnostics = diagnostics_by_line[diagnostic.lnum]

      if not diagnostics then
        diagnostics = {}
        diagnostics_by_line[diagnostic.lnum] = diagnostics
      end

      table.insert(diagnostics, diagnostic)
    end

    if #self.lines > 0 then
      table.insert(self.lines, "")
    end

    local name =
        vim.api.nvim_buf_get_name(bufnr)

    local relative =
        vim.fn.fnamemodify(name, ":.")

    table.insert(
      self.headers,
      Header:new(#self.lines, "▼ " .. relative)
    )

    -- The header is drawn over this empty placeholder, so its text is not
    -- part of the editable buffer contents.
    table.insert(self.lines, "")

    -- Keep one editable-text line between the header and its source blocks.
    table.insert(self.lines, "")

    local ranges = Diagnostic.build_ranges(
      buffer.diagnostics,
      require("zdiag.config").get_context_lines()
    )

    local line_count =
        vim.api.nvim_buf_line_count(bufnr)
    local previous_separator_row

    for _, range in ipairs(ranges) do
      local start_line =
          range.start_line

      if start_line >= line_count then
        break
      end

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

      if previous_separator_row then
        table.insert(
          self.separators,
          Separator:new(previous_separator_row)
        )
      end

      local view_start = #self.lines

      for index, source_line in ipairs(source_lines) do
        local source_lnum =
            start_line + index - 1

        table.insert(self.lines, source_line)

        local view_row = #self.lines - 1
        local highest_severity
        local line_diagnostics =
            diagnostics_by_line[source_lnum] or {}

        for _, diagnostic in ipairs(line_diagnostics) do
          highest_severity =
              math.min(
                highest_severity
                or vim.diagnostic.severity.HINT,
                diagnostic.severity
              )

          table.insert(
            self.decorations,
            Decoration:new_diagnostic(
              view_row,
              diagnostic.col,
              diagnostic,
              #source_line
            )
          )
        end

        if highest_severity then
          table.insert(
            self.line_highlights,
            LineHighlight:new(
              view_row,
              highest_severity
            )
          )
        end
      end

      -- block末尾を示すためのseparator。
      -- end_markはこの行に置くので、
      -- source部分は [start_mark, end_mark) になる。
      local separator_row = #self.lines
      table.insert(self.lines, "")
      previous_separator_row = separator_row

      table.insert(
        self.blocks,
        Block:new({
          bufnr = bufnr,

          source_start = start_line,

          -- nvim_buf_set_lines() のendはexclusive
          source_end = end_line + 1,

          original_lines = source_lines,

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

  local highlighted_buffers = {}

  for _, block in ipairs(self.blocks) do
    if not highlighted_buffers[block.bufnr] then
      highlighted_buffers[block.bufnr] = true

      if require("zdiag.highlight").start_treesitter(
            self.bufnr,
            block.bufnr
          )
      then
        break
      end
    end
  end

  for _, block in ipairs(self.blocks) do
    block:attach_mark(self)
  end

  for _, header in ipairs(self.headers) do
    header:apply(self)
  end

  for _, separator in ipairs(self.separators) do
    separator:apply(self)
  end

  for _, line_highlight in ipairs(self.line_highlights) do
    line_highlight:apply(self)
  end

  for _, decoration in ipairs(self.decorations) do
    decoration:apply(self)
  end

  require("zdiag.view.autocmd").create_autocmd(self)
  self:mark_unmodified()

  return self
end

---Reset rendered state before rebuilding the view.
---
---@return zdiag.View
function View:reset()
  if vim.treesitter
      and type(vim.treesitter.stop) == "function"
  then
    pcall(vim.treesitter.stop, self.bufnr)
  end

  vim.api.nvim_buf_clear_namespace(
    self.bufnr,
    self.ctx.ns,
    0,
    -1
  )

  self.lines = {}
  self.headers = {}
  self.separators = {}
  self.blocks = {}
  self.decorations = {}
  self.line_highlights = {}

  return self
end

---Clear the modified flag on the view buffer.
function View:mark_unmodified()
  require("zdiag.buffer").mark_modified(self.bufnr)
end

---Jump to the source of the diagnostic under the cursor.
---
---@param opts? zdiag.JumpOpts
function View:jump(opts)
  require('zdiag.view.jump').jump_to_source(self, opts)
end

---Run a callback in the source buffer context under the cursor.
---
---@param callback fun(): any
---@return boolean executed
---@return any result
function View:with_source(callback)
  return require("zdiag.view.source").call(
    self,
    callback
  )
end

---Request LSP code actions for the source position under the cursor.
---
---@param opts? vim.lsp.buf.code_action.Opts
function View:code_action(opts)
  require("zdiag.view.lsp").code_action(self, opts)
end

---Open diagnostics for the source position under the cursor.
---
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function View:diagnostic_open_float(opts)
  return require("zdiag.view.diagnostic")
      .open_float(self, opts)
end

---Move to another diagnostic in the diagnostics view.
---
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function View:diagnostic_jump(opts)
  return require("zdiag.view.diagnostic").jump(
    self,
    opts
  )
end

return View
