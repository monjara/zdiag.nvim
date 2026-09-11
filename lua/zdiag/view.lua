local M = {}

local ns = vim.api.nvim_create_namespace("zdiag")

local function severity_hl(severity)
	if severity == vim.diagnostic.severity.ERROR then
		return "DiagnosticError"
	elseif severity == vim.diagnostic.severity.WARN then
		return "DiagnosticWarn"
	elseif severity == vim.diagnostic.severity.INFO then
		return "DiagnosticInfo"
	else
		return "DiagnosticHint"
	end
end

local function build_ranges(diagnostics, context)
	local ranges = {}

	for _, diagnostic in ipairs(diagnostics) do
		local start_line = math.max(0, diagnostic.lnum - context)
		local end_line = diagnostic.lnum + context

		local last = ranges[#ranges]

		if last and start_line <= last.end_line + 1 then
			last.end_line = math.max(last.end_line, end_line)
			table.insert(last.diagnostics, diagnostic)
		else
			table.insert(ranges, {
				start_line = start_line,
				end_line = end_line,
				diagnostics = { diagnostic },
			})
		end
	end

	return ranges
end

local function group_diagnostics(diagnostics)
	local groups = {}
	local order = {}

	for _, diagnostic in ipairs(diagnostics) do
		local bufnr = diagnostic.bufnr

		if not groups[bufnr] then
			groups[bufnr] = {}
			table.insert(order, bufnr)
		end

		table.insert(groups[bufnr], diagnostic)
	end

	return groups, order
end

local function get_mark_row(buf, mark_id)
	local position = vim.api.nvim_buf_get_extmark_by_id(
		buf,
		ns,
		mark_id,
		{}
	)

	if #position == 0 then
		return nil
	end

	return position[1]
end

local function find_block_at_cursor(view_buf, blocks)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1

	for _, block in ipairs(blocks) do
		local start_row = get_mark_row(view_buf, block.start_mark)
		local end_row = get_mark_row(view_buf, block.end_mark)

		if start_row and end_row then
			if row >= start_row and row < end_row then
				return block, row - start_row
			end
		end
	end

	return nil, nil
end

local function find_target_window(view_buf)
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

local function jump_to_source(view_buf, blocks)
	local block, offset = find_block_at_cursor(view_buf, blocks)

	if not block then
		vim.notify(
			"zdiag: cursor is not on a source line",
			vim.log.levels.INFO
		)
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local col = cursor[2]

	local source_lnum = block.source_start + offset

	local source_line_count =
		vim.api.nvim_buf_line_count(block.bufnr)

	source_lnum = math.min(
		source_lnum,
		math.max(0, source_line_count - 1)
	)

	local target_win = find_target_window(view_buf)

	if target_win then
		vim.api.nvim_set_current_win(target_win)
	else
		vim.cmd("split")
		target_win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_win_set_buf(target_win, block.bufnr)

	local source_line =
		vim.api.nvim_buf_get_lines(
			block.bufnr,
			source_lnum,
			source_lnum + 1,
			false
		)[1] or ""

	col = math.min(col, #source_line)

	vim.api.nvim_win_set_cursor(
		target_win,
		{ source_lnum + 1, col }
	)
end

local function collect_edits(view_buf, blocks)
	local edits = {}

	for _, block in ipairs(blocks) do
		local start_row = get_mark_row(
			view_buf,
			block.start_mark
		)

		local end_row = get_mark_row(
			view_buf,
			block.end_mark
		)

		if start_row and end_row then
			local edited_lines =
				vim.api.nvim_buf_get_lines(
					view_buf,
					start_row,
					end_row,
					false
				)

			table.insert(edits, {
				bufnr = block.bufnr,
				source_start = block.source_start,
				source_end = block.source_end,
				lines = edited_lines,
			})
		end
	end

	return edits
end

local function apply_changes(view_buf, blocks)
	local edits = collect_edits(view_buf, blocks)

	-- 同じファイル内では後ろから適用する。
	-- 前方で行が増減しても後方rangeの位置がずれない。
	table.sort(edits, function(a, b)
		if a.bufnr ~= b.bufnr then
			return a.bufnr < b.bufnr
		end

		return a.source_start > b.source_start
	end)

	local touched_buffers = {}

	for _, edit in ipairs(edits) do
		if not vim.api.nvim_buf_is_valid(edit.bufnr) then
			goto continue
		end

		if not vim.api.nvim_buf_is_loaded(edit.bufnr) then
			vim.fn.bufload(edit.bufnr)
		end

		vim.api.nvim_buf_set_lines(
			edit.bufnr,
			edit.source_start,
			edit.source_end,
			false,
			edit.lines
		)

		touched_buffers[edit.bufnr] = true

		::continue::
	end

	for bufnr in pairs(touched_buffers) do
		local name = vim.api.nvim_buf_get_name(bufnr)

		if name ~= "" then
			local ok, err = pcall(function()
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd("silent write")
				end)
			end)

			if not ok then
				vim.notify(
					"zdiag: failed to write "
						.. name
						.. "\n"
						.. tostring(err),
					vim.log.levels.ERROR
				)

				return
			end
		end
	end

	vim.bo[view_buf].modified = false

	vim.notify(
		"zdiag: changes written to source files",
		vim.log.levels.INFO
	)
end

function M.open()
	local diagnostics = vim.diagnostic.get(nil)

	table.sort(diagnostics, function(a, b)
		if a.bufnr ~= b.bufnr then
			return a.bufnr < b.bufnr
		end

		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end

		return a.col < b.col
	end)

	local groups, order =
		group_diagnostics(diagnostics)

	local buf = vim.api.nvim_create_buf(false, true)

	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true

	vim.api.nvim_buf_set_name(buf, "zdiag://diagnostics")

	local lines = {}
	local blocks = {}
	local decorations = {}

	for _, bufnr in ipairs(order) do
		if not vim.api.nvim_buf_is_loaded(bufnr) then
			vim.fn.bufload(bufnr)
		end

		local buffer_diagnostics = groups[bufnr]

		table.sort(buffer_diagnostics, function(a, b)
			if a.lnum ~= b.lnum then
				return a.lnum < b.lnum
			end

			return a.col < b.col
		end)

		if #lines > 0 then
			table.insert(lines, "")
		end

		local name =
			vim.api.nvim_buf_get_name(bufnr)

		local relative =
			vim.fn.fnamemodify(name, ":.")

		table.insert(lines, "▼ " .. relative)
		table.insert(lines, "")

		local ranges =
			build_ranges(buffer_diagnostics, 2)

		local line_count =
			vim.api.nvim_buf_line_count(bufnr)

		for _, range in ipairs(ranges) do
			local start_line =
				range.start_line

			local end_line =
				math.min(
					line_count - 1,
					range.end_line
				)

			local source_lines =
				vim.api.nvim_buf_get_lines(
					bufnr,
					start_line,
					end_line + 1,
					false
				)

			local view_start = #lines

			for index, source_line in ipairs(source_lines) do
				local source_lnum =
					start_line + index - 1

				table.insert(lines, source_line)

				local view_row = #lines - 1

				table.insert(decorations, {
					type = "line",
					row = view_row,
					source_lnum = source_lnum,
				})

				for _, diagnostic in ipairs(range.diagnostics) do
					if diagnostic.lnum == source_lnum then
						table.insert(decorations, {
							type = "diagnostic",
							row = view_row,
							col = diagnostic.col,
							diagnostic = diagnostic,
						})
					end
				end
			end

			-- block末尾を示すためのseparator。
			-- end_markはこの行に置くので、
			-- source部分は [start_mark, end_mark) になる。
			local separator_row = #lines
			table.insert(lines, "")

			table.insert(blocks, {
				bufnr = bufnr,

				source_start = start_line,

				-- nvim_buf_set_lines() のendはexclusive
				source_end = end_line + 1,

				view_start = view_start,
				view_end = separator_row,
			})
		end
	end

	if #lines == 0 then
		table.insert(lines, "No diagnostics")
	end

	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		lines
	)

	--
	-- block boundary
	--

	for _, block in ipairs(blocks) do
		block.start_mark =
			vim.api.nvim_buf_set_extmark(
				buf,
				ns,
				block.view_start,
				0,
				{
					right_gravity = false,
				}
			)

		block.end_mark =
			vim.api.nvim_buf_set_extmark(
				buf,
				ns,
				block.view_end,
				0,
				{
					right_gravity = true,
				}
			)

		block.view_start = nil
		block.view_end = nil
	end

	--
	-- decorations
	--

	for _, decoration in ipairs(decorations) do
		if decoration.type == "line" then
			local prefix =
				string.format(
					"%4d │ ",
					decoration.source_lnum + 1
				)

			vim.api.nvim_buf_set_extmark(
				buf,
				ns,
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
				buf,
				ns,
				decoration.row,
				decoration.col,
				{
					end_col = math.max(
						decoration.col + 1,
						diagnostic.end_col
							or decoration.col + 1
					),

					hl_group =
						severity_hl(
							diagnostic.severity
						),

					virt_text = {
						{
							"  "
								.. diagnostic.message,
							severity_hl(
								diagnostic.severity
							),
						},
					},

					virt_text_pos = "eol",
				}
			)
		end
	end

	--
	-- :write
	--

	vim.api.nvim_create_autocmd(
		"BufWriteCmd",
		{
			buffer = buf,

			callback = function()
				apply_changes(buf, blocks)
			end,
		}
	)

	--
	-- jump
	--

	local function jump()
		jump_to_source(buf, blocks)
	end

	vim.keymap.set(
		"n",
		"<C-Space>",
		jump,
		{
			buffer = buf,
			desc = "zdiag: jump to source",
		}
	)

	-- terminalによってCtrl-SpaceがCtrl-@として届く場合用
	vim.keymap.set(
		"n",
		"<C-@>",
		jump,
		{
			buffer = buf,
			desc = "zdiag: jump to source",
		}
	)

	vim.api.nvim_set_current_buf(buf)

	-- acwrite bufferなのでここでmodifiedを落としておく
	vim.bo[buf].modified = false
end

return M
