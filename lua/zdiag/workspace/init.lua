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
---@field new fun(self: zdiag.Workspace, ctx: zdiag.Context): zdiag.Workspace

local Workspace = {}
Workspace.__index = Workspace

---Create a new workspace instance.
---
---@param ctx zdiag.Context
---@return zdiag.Workspace
function Workspace:new(ctx)
  local bufnr = require('zdiag.utils.buffer').build_buffer()

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
  require('zdiag.utils.buffer').mark_modified(self.bufnr)
end

---Jump to the source of the diagnostic under the cursor.
---
---@param opts? zdiag.JumpOpts
function Workspace:jump(opts)
  require('zdiag.workspace.jump').jump_to_source(self, opts)
end

---Call a callback in the source context represented by the cursor or Visual selection.
---
---@param callback fun(): any
---@return boolean executed
---@return any result
function Workspace:call(callback)
  return require('zdiag.workspace.source').call(self, callback)
end

return Workspace
