local M = {}

function M.open()
  local ctx = require("zdiag.context").build_context()

  local diagnostics = require("zdiag.diagnostic").get_diagnostics(ctx)
  local groups, order = require("zdiag.diagnostic").group_diagnostics(ctx, diagnostics)

  local buf = require("zdiag.buffer").build_buffer(ctx)

  print("ctx: ", ctx)
  print("ctx.ns: ", ctx)

  local view = require("zdiag.view").build_view(ctx, buf, groups, order)

  require("zdiag.view").render(ctx, buf, view)


  -- jump
  local function jump()
    require('zdiag.jump').jump_to_source(ctx, buf, view.blocks)
  end

  vim.keymap.set(
    "n",
    "<C-Space>",
    jump,
    {
      buffer = buf,
      desc = "zdiag: jump to source",
    }
  )

  -- terminalによってCtrl-SpaceがCtrl-@として届く場合用
  vim.keymap.set(
    "n",
    "<C-@>",
    jump,
    {
      buffer = buf,
      desc = "zdiag: jump to source",
    }
  )

  vim.api.nvim_set_current_buf(buf)

  -- acwrite bufferなのでここでmodifiedを落としておく
  require("zdiag.buffer").mark_modified(ctx, buf)
end

return M
