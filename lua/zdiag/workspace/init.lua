---@class zdiag.Workspace
---@field ctx zdiag.Context
---@field bufnr integer
---@field lines string[]
---@field headers zdiag.Header[]
---@field separators zdiag.Separator[]
---@field blocks zdiag.Block[]
---@field decorations zdiag.Decoration[]
---@field line_highlights zdiag.LineHighlight[]
---@field attached_buffers table<integer, boolean>
---@field reload_pending boolean?
---@field reload_deferred boolean?
---@field closed boolean?
---@field build fun(self: zdiag.Workspace): zdiag.Workspace
---@field reset fun(self: zdiag.Workspace): zdiag.Workspace
---@field mark_unmodified fun(self: zdiag.Workspace): nil
---@field dispose fun(self: zdiag.Workspace, opts?: { force?: boolean }): nil
---@field new fun(self: zdiag.Workspace, ctx: zdiag.Context): zdiag.Workspace
---@field reload fun(self: zdiag.Workspace): nil

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
    attached_buffers = {},
  }, self)
end

---Build and render the workspace from the current diagnostics.
---
---@return zdiag.Workspace
function Workspace:build()
  local buffers = require('zdiag.core.diagnostic').get_by_buffer()

  require('zdiag.workspace.presentation.builder').build(self, buffers)
  require('zdiag.workspace.presentation.renderer').render(self)
  require('zdiag.workspace.autocmd').attach_source_buffers(self)

  return self
end

---Reset rendered state before rebuilding the workspace.
---
---@return zdiag.Workspace
function Workspace:reset()
  require('zdiag.workspace.presentation.renderer').clear(self)
  require('zdiag.workspace.presentation.builder').clear(self)

  return self
end

---Clear the modified flag on the workspace buffer.
function Workspace:mark_unmodified()
  vim.bo[self.bufnr].modified = false
end

---Dispose of the workspace buffer and its autocmds.
---
---@param opts? { force?: boolean }
function Workspace:dispose(opts)
  if self.closed then
    return
  end

  opts = opts or {}
  self.closed = true

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    local ok, err = pcall(vim.api.nvim_buf_delete, self.bufnr, {
      force = opts.force or false,
    })

    if not ok then
      self.closed = false
      error(err, 0)
    end
  end

  require('zdiag.workspace.autocmd').remove_autocmd(self)
end

---Reload a workspace from the latest diagnostics.
---
function Workspace:reload()
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end

  local winid = vim.fn.bufwinid(self.bufnr)
  local source_position

  if winid ~= -1 then
    local cursor = vim.api.nvim_win_get_cursor(winid)

    source_position = require('zdiag.workspace.position').get_position(
      self,
      cursor[1] - 1,
      cursor[2]
    )
  end

  self:reset()
  self:build()

  if
    winid == -1
    or not vim.api.nvim_win_is_valid(winid)
    or not source_position
  then
    return
  end

  for _, block in ipairs(self.blocks) do
    if
      block.bufnr == source_position.bufnr
      and source_position.row >= block.source_start
      and source_position.row < block.source_end
    then
      local start_row = block:get_workspace_range(self)

      if start_row then
        vim.api.nvim_win_set_cursor(winid, {
          start_row + source_position.row - block.source_start + 1,
          source_position.col,
        })
      end

      break
    end
  end
end

return Workspace
