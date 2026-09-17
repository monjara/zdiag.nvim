local M = {}

---Write the view's lines to its buffer.
---
---@param view zdiag.View
local function write_lines(view)
  vim.api.nvim_buf_set_lines(view.bufnr, 0, -1, false, view.lines)
end

---Render a view's in-memory representation into its Neovim buffer.
---
---@param view zdiag.View
---@return zdiag.View
function M.render(view)
  write_lines(view)

  local highlighted_buffers = {}

  for _, block in ipairs(view.blocks) do
    if not highlighted_buffers[block.bufnr] then
      highlighted_buffers[block.bufnr] = true

      if require('zdiag.highlight').start_treesitter(view.bufnr, block.bufnr) then
        break
      end
    end
  end

  for _, block in ipairs(view.blocks) do
    block:attach_mark(view)
  end

  for _, header in ipairs(view.headers) do
    header:apply(view)
  end

  for _, separator in ipairs(view.separators) do
    separator:apply(view)
  end

  for _, line_highlight in ipairs(view.line_highlights) do
    line_highlight:apply(view)
  end

  for _, decoration in ipairs(view.decorations) do
    decoration:apply(view)
  end

  require('zdiag.view.autocmd').create_autocmd(view)
  view:mark_unmodified()

  return view
end

---Clear state attached to a rendered view buffer.
---
---@param view zdiag.View
function M.clear(view)
  if vim.treesitter and type(vim.treesitter.stop) == 'function' then
    pcall(vim.treesitter.stop, view.bufnr)
  end

  vim.api.nvim_buf_clear_namespace(view.bufnr, view.ctx.ns, 0, -1)
end

return M
