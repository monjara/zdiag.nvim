# zdiag.nvim

An editable, multi-buffer diagnostics workspace for Neovim.

## Features

- View diagnostics from all buffers with their surrounding source lines.
- Edit source lines in one workspace and write the changes back to the original
  files.
- Keep file headers and diagnostic messages outside the editable text.
- Use Tree-sitter highlighting when a parser for the source language is
  available.
- Run source-aware LSP and diagnostic operations directly from the workspace.
- Refresh automatically without overwriting unsaved workspace changes.

## Requirements

- Neovim >= 0.11
- A configured diagnostic provider, such as an LSP client or linter
- Tree-sitter parsers are optional

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
```

`setup()` is optional when the default configuration is sufficient.

## Usage

Run `:Zdiag` to open the workspace. Edit its source lines and use `:write` to
apply the changes to the original files.

zdiag does not define keymaps. Workspace-local mappings can be added with a
`FileType` autocmd:

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

Use `call()` to run an operation against the source location represented by the
current workspace line. The same mapping also works in ordinary source buffers:

```lua
vim.keymap.set({ "n", "x" }, "gra", function()
  require("zdiag").call(vim.lsp.buf.code_action)
end)

vim.keymap.set("n", "gl", function()
  require("zdiag").call(vim.diagnostic.open_float)
end)
```

Visual selections must stay within one source block. Diagnostic navigation
through `call()` continues across source-buffer boundaries, and diagnostics on
the same source line are grouped into one float.

## Configuration

```lua
require("zdiag").setup({
  context_lines = 2,
  diagnostics = {
    severity = nil,
  },
  auto_refresh = {
    enabled = true,
    delay = 100,
  },
  jump = {
    -- "close", "split", or "buffer"
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

Set a `line_highlight` severity to `false` to disable its whole-line
background.

See [`:help zdiag`](doc/zdiag.txt) for all options, mappings, and Lua APIs.
