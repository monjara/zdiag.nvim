# zdiag.nvim

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
so Tree-sitter syntax colors take priority. Override the source group name, or
disable a severity with `false`, without defining colors in zdiag:

```lua
require("zdiag").setup({
  line_highlight = {
    [vim.diagnostic.severity.ERROR] = "MyDiagnosticLineError",
    [vim.diagnostic.severity.HINT] = false,
  },
})
```

zdiag does not detect or copy existing keymaps. Other source-buffer operations
can be mapped explicitly with `with_source`:

```lua
vim.keymap.set("n", "K", function()
  require("zdiag").with_source(vim.lsp.buf.hover)
end)

vim.keymap.set("n", "gd", function()
  require("zdiag").with_source(vim.lsp.buf.definition)
end)
```

Outside a zdiag view, `with_source` runs the callback against the current
buffer normally, so the same mapping can be used globally.

The `zdiag` filetype currently installs buffer-local mappings for testing the
standard LSP operations. Diagnostic navigation uses `g[` and `g]`; it
continues into the next or previous source buffer instead of stopping at a
file boundary. The same behavior is available through
`require("zdiag").diagnostic_jump({ count = 1 })`.
Use `<space>ef` or `require("zdiag").diagnostic_open_float()` to show the
diagnostic float for the source buffer represented by the current block.
Diagnostics on the same source line are grouped into one float by default;
pass `{ scope = "cursor" }` to limit it to the cursor position.
The active diagnostics view can be closed with `require("zdiag").close()`;
unsaved edits are protected unless `{ force = true }` is passed.

After edits are written and LSP diagnostics change, the diagnostics view is
rebuilt automatically. Unsaved changes in the view are never overwritten.
