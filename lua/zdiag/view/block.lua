---@class zdiag.Block
---@field bufnr integer
---@field source_start integer
---@field source_end integer
---@field original_lines string[]
---@field view_start integer?
---@field view_end integer?
---@field start_mark integer?
---@field end_mark integer?
---@field new fun(self: zdiag.Block, opts: table): zdiag.Block
---@field attach_mark fun(self: zdiag.Block, view: zdiag.View): nil
---@field get_view_range fun(self: zdiag.Block, view: zdiag.View): integer?, integer?

local Block = {}
Block.__index = Block

---Create a new source block.
---
---@param opts { bufnr: integer, source_start: integer, source_end: integer, original_lines: string[], view_start: integer, view_end: integer }
---@return zdiag.Block
function Block:new(opts)
  return setmetatable({
    bufnr = opts.bufnr,
    source_start = opts.source_start,
    source_end = opts.source_end,
    original_lines = opts.original_lines,
    view_start = opts.view_start,
    view_end = opts.view_end,
  }, self)
end

---Attach extmarks to the start and end of the block in the view.
---
---@param view zdiag.View
function Block:attach_mark(view)
  self.start_mark = vim.api.nvim_buf_set_extmark(view.bufnr, view.ctx.ns, self.view_start, 0, {
    right_gravity = false,
  })

  self.end_mark = vim.api.nvim_buf_set_extmark(view.bufnr, view.ctx.ns, self.view_end, 0, {
    right_gravity = true,
  })

  self.view_start = nil
  self.view_end = nil
end

---Get the current row for an extmark in the view buffer.
---
---@param view zdiag.View
---@param mark_id integer?
---@return integer?
local function get_mark_row(view, mark_id)
  if not mark_id then
    return nil
  end

  local position = vim.api.nvim_buf_get_extmark_by_id(view.bufnr, view.ctx.ns, mark_id, {})

  if #position == 0 then
    return nil
  end

  return position[1]
end

---Get the current row range in the view.
---
---@param view zdiag.View
---@return integer?
---@return integer?
function Block:get_view_range(view)
  return get_mark_row(view, self.start_mark), get_mark_row(view, self.end_mark)
end

return Block
