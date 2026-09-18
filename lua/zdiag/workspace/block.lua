---@class zdiag.Block
---@field bufnr integer
---@field source_start integer
---@field source_end integer
---@field original_lines string[]
---@field workspace_start integer?
---@field workspace_end integer?
---@field start_mark integer?
---@field end_mark integer?
---@field new fun(self: zdiag.Block, opts: table): zdiag.Block
---@field attach_mark fun(self: zdiag.Block, workspace: zdiag.Workspace): nil
---@field get_workspace_range fun(self: zdiag.Block, workspace: zdiag.Workspace): integer?, integer?

local Block = {}
Block.__index = Block

---Create a new source block.
---
---@param opts { bufnr: integer, source_start: integer, source_end: integer, original_lines: string[], workspace_start: integer, workspace_end: integer }
---@return zdiag.Block
function Block:new(opts)
  return setmetatable({
    bufnr = opts.bufnr,
    source_start = opts.source_start,
    source_end = opts.source_end,
    original_lines = opts.original_lines,
    workspace_start = opts.workspace_start,
    workspace_end = opts.workspace_end,
  }, self)
end

---Attach extmarks to the start and end of the block in the workspace.
---
---@param workspace zdiag.Workspace
function Block:attach_mark(workspace)
  self.start_mark = vim.api.nvim_buf_set_extmark(workspace.bufnr, workspace.ctx.ns, self.workspace_start, 0, {
    right_gravity = false,
  })

  self.end_mark = vim.api.nvim_buf_set_extmark(workspace.bufnr, workspace.ctx.ns, self.workspace_end, 0, {
    right_gravity = true,
  })

  self.workspace_start = nil
  self.workspace_end = nil
end

---Get the current row for an extmark in the workspace buffer.
---
---@param workspace zdiag.Workspace
---@param mark_id integer?
---@return integer?
local function get_mark_row(workspace, mark_id)
  if not mark_id then
    return nil
  end

  local position = vim.api.nvim_buf_get_extmark_by_id(workspace.bufnr, workspace.ctx.ns, mark_id, {})

  if #position == 0 then
    return nil
  end

  return position[1]
end

---Get the current row range in the workspace.
---
---@param workspace zdiag.Workspace
---@return integer?
---@return integer?
function Block:get_workspace_range(workspace)
  return get_mark_row(workspace, self.start_mark), get_mark_row(workspace, self.end_mark)
end

return Block
