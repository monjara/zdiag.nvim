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
  if view.closed or view.reload_pending then
    return
  end

  view.reload_pending = true

  vim.defer_fn(function()
    view.reload_pending = false

    if view.closed
        or not vim.api.nvim_buf_is_valid(view.bufnr)
        or vim.bo[view.bufnr].modified
    then
      return
    end

    require("zdiag.usecase").reload(view)
  end, require("zdiag.config").get_auto_refresh_delay())
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
    "BufUnload",
    {
      group = group,
      buffer = view.bufnr,

      callback = function()
        local bufnr = view.bufnr
        view.closed = true

        -- BufUnload runs while Neovim is still processing the original
        -- deletion.  Complete the wipe on the next event-loop turn.
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr)
              and not vim.api.nvim_buf_is_loaded(bufnr)
          then
            vim.api.nvim_buf_delete(
              bufnr,
              { force = false }
            )
          end

          M.remove_autocmd(view)
        end)
      end,
    }
  )

  if require("zdiag.config").is_auto_refresh_enabled() then
    vim.api.nvim_create_autocmd(
      "DiagnosticChanged",
      {
        group = group,

        callback = function()
          M.schedule_reload(view)
        end,
      }
    )
  end

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
