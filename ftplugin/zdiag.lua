local zdiag = require("zdiag")

local function with_source(callback)
  return function()
    return zdiag.with_source(callback)
  end
end

local function map(lhs, callback, desc)
  vim.keymap.set("n", lhs, callback, {
    buffer = true,
    desc = desc,
  })
end

map(
  "gD",
  with_source(vim.lsp.buf.declaration),
  "LSP declaration"
)

map(
  "gd",
  with_source(vim.lsp.buf.definition),
  "LSP definition"
)

map(
  "K",
  with_source(vim.lsp.buf.hover),
  "LSP hover"
)

map(
  "gi",
  with_source(vim.lsp.buf.implementation),
  "LSP implementation"
)

map("gl", function()
  zdiag.with_source(function()
    vim.lsp.inlay_hint.enable(
      not vim.lsp.inlay_hint.is_enabled()
    )
  end)
end, "Toggle LSP inlay hints")

map(
  "K",
  with_source(vim.lsp.buf.signature_help),
  "LSP signature help"
)

map(
  "<space>wa",
  with_source(vim.lsp.buf.add_workspace_folder),
  "LSP add workspace folder"
)

map(
  "<space>wr",
  with_source(vim.lsp.buf.remove_workspace_folder),
  "LSP remove workspace folder"
)

map("<space>wl", function()
  zdiag.with_source(function()
    print(
      vim.inspect(
        vim.lsp.buf.list_workspace_folders()
      )
    )
  end)
end, "LSP list workspace folders")

map(
  "gt",
  with_source(vim.lsp.buf.type_definition),
  "LSP type definition"
)

map(
  "<space>rn",
  with_source(vim.lsp.buf.rename),
  "LSP rename"
)

map(
  "gr",
  with_source(vim.lsp.buf.references),
  "LSP references"
)

map("<space>ca", function()
  zdiag.code_action()
end, "LSP code action")

map(
  "<space>ef",
  function()
    zdiag.diagnostic_open_float()
  end,
  "Open floating diagnostic message"
)

map("g[", function()
  zdiag.diagnostic_jump({
    count = -1,
    float = true,
  })
end, "Go to next diagnostic message")

map("g]", function()
  zdiag.diagnostic_jump({
    count = 1,
    float = true,
  })
end, "Go to previous diagnostic message")

map(
  "<space>el",
  with_source(vim.diagnostic.setloclist),
  "Open diagnostics list"
)
