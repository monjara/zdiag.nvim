---@class zdiag.Workspace
---@field ctx zdiag.Context
---@field bufnr integer
---@field lines string[]
---@field headers zdiag.Header[]
---@field separators zdiag.Separator[]
---@field blocks zdiag.Block[]
---@field decorations zdiag.Decoration[]
---@field line_highlights zdiag.LineHighlight[]
---@field reload_pending boolean?
---@field reload_deferred boolean?
---@field closed boolean?
---@field jump fun(self: zdiag.Workspace, opts?: zdiag.JumpOpts): nil
---@field build fun(self: zdiag.Workspace, buffers: zdiag.BufferDiagnostics[]): zdiag.Workspace
---@field render fun(self: zdiag.Workspace): zdiag.Workspace
---@field reset fun(self: zdiag.Workspace): zdiag.Workspace
---@field mark_unmodified fun(self: zdiag.Workspace): nil
---@field call fun(self: zdiag.Workspace, callback: fun()): boolean, any
---@field code_action fun(self: zdiag.Workspace, opts?: vim.lsp.buf.code_action.Opts): nil
---@field diagnostic_open_float fun(self: zdiag.Workspace, opts?: vim.diagnostic.Opts.Float): integer?
---@field diagnostic_jump fun(self: zdiag.Workspace, opts: vim.diagnostic.JumpOpts): vim.Diagnostic?
---@field new fun(self: zdiag.Workspace, ctx: zdiag.Context): zdiag.Workspace

local Workspace = {}
Workspace.__index = Workspace

---Create a new workspace instance.
---
---@param ctx zdiag.Context
---@return zdiag.Workspace
function Workspace:new(ctx)
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

---Build the workspace from diagnostics grouped by source buffer.
---
---@param buffers zdiag.BufferDiagnostics[]
---@return zdiag.Workspace
function Workspace:build(buffers)
  return require('zdiag.workspace.builder').build(self, buffers)
end

---Render the workspace.
---
---@return zdiag.Workspace
function Workspace:render()
  return require('zdiag.workspace.renderer').render(self)
end

---Reset rendered state before rebuilding the workspace.
---
---@return zdiag.Workspace
function Workspace:reset()
  require('zdiag.workspace.renderer').clear(self)
  require('zdiag.workspace.builder').clear(self)

  return self
end

---Clear the modified flag on the workspace buffer.
function Workspace:mark_unmodified()
  require('zdiag.buffer').mark_modified(self.bufnr)
end

---Jump to the source of the diagnostic under the cursor.
---
---@param opts? zdiag.JumpOpts
function Workspace:jump(opts)
  require('zdiag.workspace.jump').jump_to_source(self, opts)
end

---Call a callback at the source buffer position under the cursor.
---
---@param callback fun(): any
---@return boolean executed
---@return any result
function Workspace:call(callback)
  return require('zdiag.workspace.source').call(self, callback)
end

---Request LSP code actions for the source position under the cursor.
---
---@param opts? vim.lsp.buf.code_action.Opts
function Workspace:code_action(opts)
  require('zdiag.workspace.lsp').code_action(self, opts)
end

---Open diagnostics for the source position under the cursor.
---
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function Workspace:diagnostic_open_float(opts)
  return require('zdiag.workspace.diagnostic').open_float(self, opts)
end

---Move to another diagnostic in the diagnostics workspace.
---
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function Workspace:diagnostic_jump(opts)
  return require('zdiag.workspace.diagnostic').jump(self, opts)
end

return Workspace
