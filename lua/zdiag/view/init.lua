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
---@field call fun(self: zdiag.View, callback: fun()): boolean, any
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
  local bufnr = require('zdiag.buffer').build_buffer()

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
  return require('zdiag.view.builder').build(self, buffers)
end

---Render the view.
---
---@return zdiag.View
function View:render()
  return require('zdiag.view.renderer').render(self)
end

---Reset rendered state before rebuilding the view.
---
---@return zdiag.View
function View:reset()
  require('zdiag.view.renderer').clear(self)
  require('zdiag.view.builder').clear(self)

  return self
end

---Clear the modified flag on the view buffer.
function View:mark_unmodified()
  require('zdiag.buffer').mark_modified(self.bufnr)
end

---Jump to the source of the diagnostic under the cursor.
---
---@param opts? zdiag.JumpOpts
function View:jump(opts)
  require('zdiag.view.jump').jump_to_source(self, opts)
end

---Call a callback at the source buffer position under the cursor.
---
---@param callback fun(): any
---@return boolean executed
---@return any result
function View:call(callback)
  return require('zdiag.view.source').call(self, callback)
end

---Request LSP code actions for the source position under the cursor.
---
---@param opts? vim.lsp.buf.code_action.Opts
function View:code_action(opts)
  require('zdiag.view.lsp').code_action(self, opts)
end

---Open diagnostics for the source position under the cursor.
---
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function View:diagnostic_open_float(opts)
  return require('zdiag.view.diagnostic').open_float(self, opts)
end

---Move to another diagnostic in the diagnostics view.
---
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function View:diagnostic_jump(opts)
  return require('zdiag.view.diagnostic').jump(self, opts)
end

return View
