local M = {}

---apply decorations to the view
---
---@param view zdiag.View
function M.apply_decoration(view)
  for _, decoration in ipairs(view.decorations) do
    if decoration.type == "line" then
      local prefix =
          string.format(
            "%4d │ ",
            decoration.source_lnum + 1
          )

      vim.api.nvim_buf_set_extmark(
        view.bufnr,
        view.ctx.ns,
        decoration.row,
        0,
        {
          virt_text = {
            {
              prefix,
              "LineNr",
            },
          },

          -- buffer本文には行番号を入れない
          virt_text_pos = "inline",
        }
      )
    elseif decoration.type == "diagnostic" then
      local diagnostic =
          decoration.diagnostic

      vim.api.nvim_buf_set_extmark(
        view.bufnr,
        view.ctx.ns,
        decoration.row,
        decoration.col,
        {
          end_col = math.max(
            decoration.col + 1,
            diagnostic.end_col
            or decoration.col + 1
          ),

          hl_group =
              require("zdiag.highlight").severity_hl(
                diagnostic.severity
              ),

          virt_text = {
            {
              "  "
              .. diagnostic.message,
              require("zdiag.highlight").severity_hl(
                diagnostic.severity
              ),
            },
          },

          virt_text_pos = "eol",
        }
      )
    end
  end
end

return M
