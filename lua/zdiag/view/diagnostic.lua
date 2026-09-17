local M = {}

---Convert a diagnostic severity name or number to its numeric value.
---
---@param severity string|integer|nil
---@return integer?
local function severity_number(severity)
  if type(severity) == 'number' then
    return severity
  end

  if type(severity) == 'string' then
    return vim.diagnostic.severity[severity:upper()]
  end

  return nil
end

---Return whether a diagnostic matches a severity filter.
---
---@param diagnostic vim.Diagnostic
---@param severity? vim.diagnostic.SeverityFilter
---@return boolean
local function matches_severity(diagnostic, severity)
  if not severity then
    return true
  end

  if type(severity) ~= 'table' then
    return diagnostic.severity == severity_number(severity)
  end

  if severity.min or severity.max then
    local min = severity_number(severity.min) or vim.diagnostic.severity.HINT
    local max = severity_number(severity.max) or vim.diagnostic.severity.ERROR

    return diagnostic.severity <= min and diagnostic.severity >= max
  end

  for _, value in ipairs(severity) do
    if diagnostic.severity == severity_number(value) then
      return true
    end
  end

  return false
end

---Return whether a diagnostic matches a namespace filter.
---
---@param diagnostic vim.Diagnostic
---@param namespace? integer|integer[]
---@return boolean
local function matches_namespace(diagnostic, namespace)
  if not namespace then
    return true
  end

  if type(namespace) == 'number' then
    return diagnostic.namespace == namespace
  end

  return vim.tbl_contains(namespace, diagnostic.namespace)
end

---Return whether a diagnostic matches jump filters.
---
---@param diagnostic vim.Diagnostic
---@param opts vim.diagnostic.JumpOpts
---@return boolean
local function matches_filters(diagnostic, opts)
  if not matches_severity(diagnostic, opts.severity) or not matches_namespace(diagnostic, opts.namespace) then
    return false
  end

  local end_lnum = diagnostic.end_lnum or diagnostic.lnum

  if opts.lnum and (opts.lnum < diagnostic.lnum or opts.lnum > end_lnum) then
    return false
  end

  if opts.enabled ~= nil then
    local enabled = vim.diagnostic.is_enabled {
      bufnr = diagnostic.bufnr,
      ns_id = diagnostic.namespace,
    }

    if enabled ~= opts.enabled then
      return false
    end
  end

  return true
end

---Collect diagnostics in their current order in the editable view.
---
---@param view zdiag.View
---@param opts vim.diagnostic.JumpOpts
---@return { row: integer, col: integer, diagnostic: vim.Diagnostic }[]
local function collect(view, opts)
  local entries = {}
  local positions = {}

  local extmarks = vim.api.nvim_buf_get_extmarks(view.bufnr, view.ctx.ns, 0, -1, { type = 'virt_text' })

  for _, extmark in ipairs(extmarks) do
    positions[extmark[1]] = extmark
  end

  for _, decoration in ipairs(view.decorations) do
    local position = decoration.mark_id and positions[decoration.mark_id]
    local diagnostic = decoration.diagnostic

    if position and matches_filters(diagnostic, opts) then
      table.insert(entries, {
        row = position[2],
        col = position[3],
        diagnostic = diagnostic,
      })
    end
  end

  if opts._highest and #entries > 0 then
    local highest = vim.diagnostic.severity.HINT

    for _, entry in ipairs(entries) do
      highest = math.min(highest, entry.diagnostic.severity)
    end

    entries = vim.tbl_filter(function(entry)
      return entry.diagnostic.severity == highest
    end, entries)
  end

  table.sort(entries, function(a, b)
    if a.row ~= b.row then
      return a.row < b.row
    end

    return a.col < b.col
  end)

  return entries
end

---Return whether one view position is after another.
---
---@param entry { row: integer, col: integer }
---@param row integer
---@param col integer
---@return boolean
local function is_after(entry, row, col)
  return entry.row > row or entry.row == row and entry.col > col
end

---Return whether one view position is before another.
---
---@param entry { row: integer, col: integer }
---@param row integer
---@param col integer
---@return boolean
local function is_before(entry, row, col)
  return entry.row < row or entry.row == row and entry.col < col
end

---Find the next entry from a position.
---
---@param entries { row: integer, col: integer, diagnostic: vim.Diagnostic }[]
---@param row integer
---@param col integer
---@param forward boolean
---@param wrap boolean
---@return { row: integer, col: integer, diagnostic: vim.Diagnostic }?
local function next_entry(entries, row, col, forward, wrap)
  if forward then
    for _, entry in ipairs(entries) do
      if is_after(entry, row, col) then
        return entry
      end
    end

    return wrap and entries[1] or nil
  end

  for index = #entries, 1, -1 do
    local entry = entries[index]

    if is_before(entry, row, col) then
      return entry
    end
  end

  return wrap and entries[#entries] or nil
end

---Return whether two diagnostics identify the same item.
---
---@param left vim.Diagnostic
---@param right vim.Diagnostic
---@return boolean
local function same_diagnostic(left, right)
  return left == right
    or left.bufnr == right.bufnr
      and left.namespace == right.namespace
      and left.lnum == right.lnum
      and left.col == right.col
      and left.message == right.message
end

---Open a diagnostic float at an explicit source position.
---
---@param view zdiag.View
---@param opts? vim.diagnostic.Opts.Float
---@param position? { bufnr: integer, row: integer, col: integer }
---@return integer? float_bufnr
local function open_float(view, opts, position)
  if not position then
    local cursor = vim.api.nvim_win_get_cursor(0)
    position = require('zdiag.view.source').get_position(view, cursor[1] - 1, cursor[2])
  end

  if not position then
    vim.notify('zdiag: cursor is not on a source line', vim.log.levels.INFO)
    return nil
  end

  local float_opts = vim.deepcopy(opts or {})
  float_opts.bufnr = position.bufnr
  float_opts.pos = { position.row, position.col }
  float_opts.scope = float_opts.scope or 'line'

  return vim.diagnostic.open_float(float_opts)
end

---Open diagnostics for the source position represented by the view cursor.
---
---@param view zdiag.View
---@param opts? vim.diagnostic.Opts.Float
---@return integer? float_bufnr
function M.open_float(view, opts)
  return open_float(view, opts)
end

---Run the callback associated with a completed jump.
---
---@param view zdiag.View
---@param winid integer
---@param diagnostic vim.Diagnostic
---@param opts vim.diagnostic.JumpOpts
local function run_on_jump(view, winid, diagnostic, opts)
  local callback = opts.on_jump

  if opts.float then
    local float_opts = type(opts.float) == 'table' and vim.deepcopy(opts.float) or {}
    local on_jump = callback

    callback = function(jumped, bufnr)
      if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == view.bufnr then
        vim.api.nvim_win_call(winid, function()
          if float_opts.focus == nil then
            float_opts.focus = false
          end

          open_float(view, float_opts, {
            bufnr = jumped.bufnr,
            row = jumped.lnum,
            col = jumped.col,
          })
        end)
      end

      if on_jump then
        on_jump(jumped, bufnr)
      end
    end
  end

  if callback then
    vim.schedule(function()
      callback(diagnostic, diagnostic.bufnr)
    end)
  end
end

---Move to a diagnostic in the diagnostics view.
---
---@param view zdiag.View
---@param opts vim.diagnostic.JumpOpts
---@return vim.Diagnostic?
function M.jump(view, opts)
  vim.validate('opts', opts, 'table')

  assert(
    opts.diagnostic or opts.count,
    'One of "diagnostic" or "count" must be specified in the options to zdiag.diagnostic_jump()'
  )

  local config = vim.diagnostic.config() or {}
  opts = vim.tbl_deep_extend('keep', vim.deepcopy(opts), config.jump or {})

  if opts.wrap == nil then
    opts.wrap = true
  end

  local winid = opts.winid or opts.win_id or 0

  if winid == 0 then
    winid = vim.api.nvim_get_current_win()
  end

  if not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_win_get_buf(winid) ~= view.bufnr then
    error('zdiag: diagnostic jump window is not showing the diagnostics view')
  end

  local entries = collect(view, opts.diagnostic and {} or opts)
  local target

  if opts.diagnostic then
    for _, entry in ipairs(entries) do
      if same_diagnostic(entry.diagnostic, opts.diagnostic) then
        target = entry
        break
      end
    end
  else
    local count = opts.count

    if count == 0 then
      return nil
    end

    local position = opts.pos or opts.cursor_position or vim.api.nvim_win_get_cursor(winid)
    local row = position[1] - 1
    local col = position[2]

    for _ = 1, math.abs(count) do
      local entry = next_entry(entries, row, col, count > 0, opts.wrap)

      if not entry then
        break
      end

      target = entry
      row = entry.row
      col = entry.col
    end
  end

  if not target then
    vim.api.nvim_echo({
      {
        'No more valid diagnostics to move to',
        'WarningMsg',
      },
    }, true, {})
    return nil
  end

  vim.api.nvim_win_call(winid, function()
    vim.cmd("normal! m'")
  end)

  vim.api.nvim_win_set_cursor(winid, { target.row + 1, target.col })

  vim.api.nvim_win_call(winid, function()
    vim.cmd('normal! zv')
  end)

  run_on_jump(view, winid, target.diagnostic, opts)

  return target.diagnostic
end

return M
