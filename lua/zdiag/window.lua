local M = {}

local function find_target_window(_ctx, view_buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local win_buf = vim.api.nvim_win_get_buf(win)

      if win_buf ~= view_buf then
        return win
      end
    end
  end

  return nil
end

function M.prepare_window(ctx, view_buf)
  local target_win = find_target_window(ctx, view_buf)

  if target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("split")
    target_win = vim.api.nvim_get_current_win()
  end

  return target_win
end

return M
