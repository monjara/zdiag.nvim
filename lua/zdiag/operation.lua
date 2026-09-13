local M = {}

function M.open()
  local Context = require("zdiag.context")
  local ctx = Context:new()

  local diagnostics = require("zdiag.diagnostic").get_diagnostics(ctx)
  local groups, order = require("zdiag.diagnostic").group_diagnostics(ctx, diagnostics)

  local View = require("zdiag.view")
  local view = View:new(ctx):build(groups, order):render()

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

  -- acwrite bufferなのでここでmodifiedを落としておく
  require("zdiag.buffer").mark_modified(view.bufnr)
end

return M
