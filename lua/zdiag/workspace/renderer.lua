local M = {}

---Render a workspace's in-memory representation into its Neovim buffer.
---
---@param workspace zdiag.Workspace
---@return zdiag.Workspace
function M.render(workspace)
  vim.api.nvim_buf_set_lines(workspace.bufnr, 0, -1, false, workspace.lines)

  local highlighted_buffers = {}

  -- Neovim keeps one active Tree-sitter highlighter per buffer. Use the first
  -- source language with an available parser; starting another language would
  -- replace it. Blocks with the same language are all parsed by this highlighter.
  for _, block in ipairs(workspace.blocks) do
    if not highlighted_buffers[block.bufnr] then
      highlighted_buffers[block.bufnr] = true

      if
        require('zdiag.core.highlight').start_treesitter(
          workspace.bufnr,
          block.bufnr
        )
      then
        break
      end
    end
  end

  for _, block in ipairs(workspace.blocks) do
    block:attach_mark(workspace)
  end

  for _, header in ipairs(workspace.headers) do
    header:apply(workspace)
  end

  for _, separator in ipairs(workspace.separators) do
    separator:apply(workspace)
  end

  for _, line_highlight in ipairs(workspace.line_highlights) do
    line_highlight:apply(workspace)
  end

  for _, decoration in ipairs(workspace.decorations) do
    decoration:apply(workspace)
  end

  workspace:mark_unmodified()

  return workspace
end

---Clear state attached to a rendered workspace buffer.
---
---@param workspace zdiag.Workspace
function M.clear(workspace)
  if vim.treesitter and type(vim.treesitter.stop) == 'function' then
    pcall(vim.treesitter.stop, workspace.bufnr)
  end

  vim.api.nvim_buf_clear_namespace(workspace.bufnr, workspace.ctx.ns, 0, -1)
end

return M
