local M = {}

---@class zdiag.DiagnosticsConfig
---@field severity? vim.diagnostic.SeverityFilter

---@class zdiag.AutoRefreshConfig
---@field enabled? boolean
---@field delay? integer

---@alias zdiag.JumpMode "close"|"split"|"buffer"

---@class zdiag.JumpOpts
---@field mode? zdiag.JumpMode

---@class zdiag.Config
---@field context_lines? integer
---@field diagnostics? zdiag.DiagnosticsConfig
---@field auto_refresh? zdiag.AutoRefreshConfig
---@field jump? zdiag.JumpOpts
---@field line_highlight? table<vim.diagnostic.Severity, string|false>

---@type zdiag.Config
local defaults = {
  context_lines = 2,
  diagnostics = {},
  auto_refresh = {
    enabled = true,
    delay = 100,
  },
  jump = {
    mode = 'split',
  },
  line_highlight = {
    [vim.diagnostic.severity.ERROR] = 'DiagnosticVirtualTextError',
    [vim.diagnostic.severity.WARN] = 'DiagnosticVirtualTextWarn',
    [vim.diagnostic.severity.INFO] = 'DiagnosticVirtualTextInfo',
    [vim.diagnostic.severity.HINT] = 'DiagnosticVirtualTextHint',
  },
}

---@type zdiag.Config
local options = vim.deepcopy(defaults)

---Return whether a value names a supported jump mode.
---
---@param mode any
---@return boolean
local function is_jump_mode(mode)
  return mode == 'close' or mode == 'split' or mode == 'buffer'
end

---Validate user-provided configuration before merging it with defaults.
---
---@param opts zdiag.Config
local function validate(opts)
  if type(opts) ~= 'table' then
    error('zdiag: setup options must be a table')
  end

  if
    opts.context_lines ~= nil
    and (
      type(opts.context_lines) ~= 'number'
      or opts.context_lines < 0
      or opts.context_lines % 1 ~= 0
    )
  then
    error('zdiag: context_lines must be a non-negative integer')
  end

  if opts.diagnostics ~= nil and type(opts.diagnostics) ~= 'table' then
    error('zdiag: diagnostics must be a table')
  end

  if opts.auto_refresh ~= nil and type(opts.auto_refresh) ~= 'table' then
    error('zdiag: auto_refresh must be a table')
  end

  if opts.line_highlight ~= nil and type(opts.line_highlight) ~= 'table' then
    error('zdiag: line_highlight must be a table')
  end

  if opts.jump ~= nil and type(opts.jump) ~= 'table' then
    error('zdiag: jump must be a table')
  end

  local auto_refresh = opts.auto_refresh or {}

  if
    auto_refresh.enabled ~= nil and type(auto_refresh.enabled) ~= 'boolean'
  then
    error('zdiag: auto_refresh.enabled must be a boolean')
  end

  if
    auto_refresh.delay ~= nil
    and (
      type(auto_refresh.delay) ~= 'number'
      or auto_refresh.delay < 0
      or auto_refresh.delay % 1 ~= 0
    )
  then
    error('zdiag: auto_refresh.delay must be a non-negative integer')
  end

  local jump = opts.jump or {}

  if jump.mode ~= nil and not is_jump_mode(jump.mode) then
    error('zdiag: jump.mode must be "close", "split", or "buffer"')
  end
end

---Configure zdiag.
---
---@param opts? zdiag.Config
function M.setup(opts)
  if opts == nil then
    opts = {}
  end
  validate(opts)

  options = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)

  options.line_highlight = vim.tbl_extend(
    'force',
    vim.deepcopy(defaults.line_highlight),
    opts.line_highlight or {}
  )

  local highlight = package.loaded['zdiag.core.highlight']

  if highlight then
    highlight.invalidate_line_highlights()
  end
end

---Return the number of source lines shown around each diagnostic.
---
---@return integer
function M.get_context_lines()
  return options.context_lines
end

---Return the configured diagnostic severity filter.
---
---@return vim.diagnostic.SeverityFilter?
function M.get_diagnostic_severity()
  return options.diagnostics.severity
end

---Return whether DiagnosticChanged events rebuild the workspace.
---
---@return boolean
function M.is_auto_refresh_enabled()
  return options.auto_refresh.enabled
end

---Return the delay before rebuilding the workspace.
---
---@return integer
function M.get_auto_refresh_delay()
  return options.auto_refresh.delay
end

---Resolve how a source buffer is opened when jumping from the workspace.
---
---@param opts? zdiag.JumpOpts
---@return zdiag.JumpMode
function M.get_jump_mode(opts)
  if opts == nil then
    return options.jump.mode
  end

  if type(opts) ~= 'table' then
    error('zdiag: jump options must be a table')
  end

  if opts.mode ~= nil and not is_jump_mode(opts.mode) then
    error('zdiag: jump mode must be "close", "split", or "buffer"')
  end

  return opts.mode or options.jump.mode
end

---Return the configured line highlight group for a severity.
---
---@param severity vim.diagnostic.Severity
---@return string?
function M.get_line_highlight(severity)
  local groups = options.line_highlight or {}
  local group = groups[severity]

  return type(group) == 'string' and group or nil
end

return M
