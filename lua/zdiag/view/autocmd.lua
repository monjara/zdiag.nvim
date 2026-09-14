local M = {}

---Return the autocmd group name for a diagnostics view.
---
---@param view zdiag.View
---@return string
local function group_name(view)
  return "zdiag_view_" .. view.bufnr
end

---Schedule a diagnostics view rebuild after diagnostics settle.
---
---@param view zdiag.View
function M.schedule_reload(view)
  if view.reload_pending then
    return
  end

  view.reload_pending = true

  vim.defer_fn(function()
    view.reload_pending = false

    if not vim.api.nvim_buf_is_valid(view.bufnr)
        or vim.bo[view.bufnr].modified
    then
      return
    end

    require("zdiag.usecase").reload(view)
  end, 100)
end

---Create autocmds for the given view.
---
---@param view zdiag.View
function M.create_autocmd(view)
  local group =
      vim.api.nvim_create_augroup(
        group_name(view),
        { clear = true }
      )

  vim.api.nvim_create_autocmd(
    "BufWriteCmd",
    {
      group = group,
      buffer = view.bufnr,

      callback = function()
        require("zdiag.view.edit").apply_changes(view)
      end,
    }
  )

  vim.api.nvim_create_autocmd(
    "DiagnosticChanged",
    {
      group = group,

      callback = function()
        M.schedule_reload(view)
      end,
    }
  )

  vim.api.nvim_create_autocmd(
    "ColorScheme",
    {
      group = group,

      callback = function()
        require("zdiag.highlight")
            .refresh_line_highlights()
      end,
    }
  )
end

---Remove autocmds owned by a diagnostics view.
---
---@param view zdiag.View
function M.remove_autocmd(view)
  pcall(
    vim.api.nvim_del_augroup_by_name,
    group_name(view)
  )
end

return M
