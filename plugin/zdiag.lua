if vim.g.loaded_zdiag then
	return
end
vim.g.loaded_zdiag = true

vim.api.nvim_create_user_command("Zdiag", function()
	require("zdiag").open()
end, {
	desc = "Open the zdiag diagnostics view",
})
