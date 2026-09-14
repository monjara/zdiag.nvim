local M = {}

---Open a diagnostics view for the current Neovim session.
function M.open()
  local Context = require("zdiag.context")
  local ctx = Context:new()

  local diagnostics = require("zdiag.diagnostic").get_diagnostics(ctx)
  local groups, order = require("zdiag.diagnostic").group_diagnostics(ctx, diagnostics)
  local range_groups = {}

  for bufnr, buffer_diagnostics in pairs(groups) do
    range_groups[bufnr] =
        require("zdiag.diagnostic").build_diagnostics_ranges(
          ctx,
          buffer_diagnostics,
          2
        )
  end

  local View = require("zdiag.view")
  local view = View:new(ctx):build(range_groups, order):render()

  vim.keymap.set(
    "n",
    "<C-Space>",
    function() view:jump() end,
    {
      buffer = view.bufnr,
      desc = "zdiag: jump to source",
    }
  )

  -- terminalによってCtrl-SpaceがCtrl-@として届く場合用
  vim.keymap.set(
    "n",
    "<C-@>",
    function() view:jump() end,
    {
      buffer = view.bufnr,
      desc = "zdiag: jump to source",
    }
  )

  vim.api.nvim_set_current_buf(view.bufnr)
end

return M
