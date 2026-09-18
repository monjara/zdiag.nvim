# zdiag.nvim

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "monjara/zdiag.nvim",
  cmd = "Zdiag",
  keys = {
    {
      "<leader>e",
      "<cmd>Zdiag<cr>",
      desc = "Open diagnostics view",
    },
  },
  opts = {},
}
```

With [mini.deps](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-deps.md):

```lua
MiniDeps.add({ source = "monjara/zdiag.nvim" })

require("zdiag").setup()

vim.keymap.set("n", "<leader>e", "<cmd>Zdiag<cr>", {
  desc = "Open diagnostics view",
})
```

`setup()` is optional when the default configuration is sufficient. You can
also open the view directly with `require("zdiag").open()`.

## Configuration

```lua
require("zdiag").setup({
  -- Source lines displayed before and after each diagnostic.
  context_lines = 2,

  diagnostics = {
    -- Accepts the same severity filter as vim.diagnostic.get().
    severity = nil,
  },

  auto_refresh = {
    -- Rebuild an unmodified view after DiagnosticChanged.
    enabled = true,
    delay = 100,
  },

  jump = {
    -- "close", "split", or "buffer".
    mode = "split",
  },

  line_highlight = {
    [vim.diagnostic.severity.ERROR] = "DiagnosticVirtualTextError",
    [vim.diagnostic.severity.WARN] = "DiagnosticVirtualTextWarn",
    [vim.diagnostic.severity.INFO] = "DiagnosticVirtualTextInfo",
    [vim.diagnostic.severity.HINT] = "DiagnosticVirtualTextHint",
  },
})
```

`jump.mode` controls how `jump_to_source()` opens the source:

- `"close"` closes the zdiag buffer and uses the current window.
- `"split"` keeps zdiag open and creates a split for the source.
- `"buffer"` keeps zdiag loaded and switches the current window to the source.

Close mode refuses to discard unsaved changes in the zdiag buffer.
Pass the same option directly to override the configured mode for one jump:

```lua
require("zdiag").jump_to_source({ mode = "buffer" })
```

zdiag does not define keymaps through its configuration. Configure global
maps through your plugin manager or Neovim config, and use a `FileType zdiag`
autocmd for view-local maps.

Separate source blocks from the same buffer are divided by a display-only
dotted line. The separator uses the `ZdiagSeparator` highlight group, which
links to `NonText` by default.

The diagnostics view starts Tree-sitter highlighting when a parser for the
source language is available. Map code actions explicitly through zdiag so
the same mapping works in both source buffers and the diagnostics view:

```lua
vim.keymap.set({ "n", "x" }, "gra", function()
  require("zdiag").code_action()
end)
```

Code actions can also be requested with `:ZdiagCodeAction` in the diagnostics
view.

Diagnostic lines derive only their background from the colorscheme's standard
`DiagnosticVirtualText*` highlight groups. Their foreground remains untouched
so Tree-sitter syntax colors take priority. The background continues beneath
the diagnostic message to the right edge of the window. Override the source
group name, or disable a severity with `false`, without defining colors in
zdiag:

```lua
require("zdiag").setup({
  line_highlight = {
    [vim.diagnostic.severity.ERROR] = "MyDiagnosticLineError",
    [vim.diagnostic.severity.HINT] = false,
  },
})
```

zdiag does not detect or copy existing keymaps. Other buffer-local operations
can be mapped explicitly with `call`:

```lua
vim.keymap.set("n", "K", function()
  require("zdiag").call(vim.lsp.buf.hover)
end)

vim.keymap.set("n", "gd", function()
  require("zdiag").call(vim.lsp.buf.definition)
end)
```

Outside a zdiag view, `call` runs the callback against the current
buffer normally, so the same mapping can be used globally.

zdiag does not install any keymaps. View-only mappings can be configured with
a `FileType` autocmd:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "zdiag",
  callback = function(event)
    vim.keymap.set("n", "<CR>", function()
      require("zdiag").jump_to_source()
    end, { buffer = event.buf, desc = "Jump to source" })

    vim.keymap.set("n", "q", function()
      require("zdiag").close()
    end, { buffer = event.buf, desc = "Close diagnostics view" })
  end,
})
```

`diagnostic_jump()` continues into the next or previous source buffer instead
of stopping at a file boundary. `diagnostic_open_float()` shows the diagnostic
float for the source buffer represented by the current block.
Diagnostics on the same source line are grouped into one float by default;
pass `{ scope = "cursor" }` to limit it to the cursor position.
The active diagnostics view can be closed with `require("zdiag").close()`;
unsaved edits are protected unless `{ force = true }` is passed.

After edits are written and LSP diagnostics change, the diagnostics view is
rebuilt automatically. Unsaved changes in the view are never overwritten.
