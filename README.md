# zdiag.nvim

## Documentation

- [Source code guide](doc/source-code-guide.md)
- [Neovim plugin beginner's guide](doc/neovim-plugin-beginners-guide.md)
- [Neovim API reference used by zdiag.nvim](doc/neovim-api-reference.md)

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
      desc = "Open diagnostics workspace",
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
  desc = "Open diagnostics workspace",
})
```

`setup()` is optional when the default configuration is sufficient. You can
also open the workspace directly with `require("zdiag").open()`.

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
    -- Rebuild an unmodified workspace after DiagnosticChanged.
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
autocmd for workspace-local maps.

Separate source blocks from the same buffer are divided by a display-only
dotted line. The separator uses the `ZdiagSeparator` highlight group, which
links to `NonText` by default.

The diagnostics workspace starts Tree-sitter highlighting when a parser for the
source language is available. `call()` translates both Normal-mode cursor
positions and Visual selections to the underlying source context, so the same
mapping works in source buffers and the diagnostics workspace:

```lua
vim.keymap.set({ "n", "x" }, "gra", function()
  require("zdiag").call(vim.lsp.buf.code_action)
end)
```

Visual selections must stay within one source block. To pass options, wrap the
call; `require("zdiag").code_action(opts)` remains available for compatibility
and for mapping blockwise Visual selections.

```lua
require("zdiag").call(function()
  vim.lsp.buf.code_action(opts)
end)
```

Code actions can also be requested with `:ZdiagCodeAction` in the diagnostics
workspace.

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

zdiag does not detect or copy existing keymaps. Buffer-local operations can be
mapped explicitly with `call`:

```lua
vim.keymap.set("n", "K", function()
  require("zdiag").call(vim.lsp.buf.hover)
end)

vim.keymap.set("n", "gd", function()
  require("zdiag").call(vim.lsp.buf.definition)
end)

vim.keymap.set("n", "gl", function()
  require("zdiag").call(vim.diagnostic.open_float)
end)
```

Outside a zdiag workspace, `call` runs the callback against the current
buffer normally, so the same mapping can be used globally.

zdiag does not install any keymaps. workspace-only mappings can be configured with
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
    end, { buffer = event.buf, desc = "Close diagnostics workspace" })
  end,
})
```

`vim.diagnostic.jump()` called inside `call()` continues into the next or
previous source buffer instead of stopping at a file boundary.
`call(vim.diagnostic.open_float)` shows the diagnostic float for the source
buffer represented by the current block.
Diagnostics on the same source line are grouped into one float by default.
Options can be passed with a closure; `diagnostic_open_float(opts)` remains
available as a convenience wrapper.

```lua
require("zdiag").call(function()
  vim.diagnostic.jump({ count = -1, float = true })
end)

require("zdiag").call(function()
  vim.diagnostic.open_float({ scope = "cursor" })
end)
```
The active diagnostics workspace can be closed with `require("zdiag").close()`;
unsaved edits are protected unless `{ force = true }` is passed.

After edits are written and LSP diagnostics change, the diagnostics workspace is
rebuilt automatically. Unsaved changes in the workspace are never overwritten.
