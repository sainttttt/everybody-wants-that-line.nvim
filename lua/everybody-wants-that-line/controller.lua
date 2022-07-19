local C = require("everybody-wants-that-line.colors")
local S = require("everybody-wants-that-line.settings")
local CB = require("everybody-wants-that-line.components.buffer")
local CD = require("everybody-wants-that-line.components.diagnostics")
local CE = require("everybody-wants-that-line.components.elements")
local CG = require("everybody-wants-that-line.components.git")
local CP = require("everybody-wants-that-line.components.filepath")
local CQ = require("everybody-wants-that-line.components.qflist")
local UC = require("everybody-wants-that-line.utils.color-util")
local UU = require("everybody-wants-that-line.utils.util")

local M = {}

---Returns `text` with spacers on each side
---@param text string
---@return string
function M.spaced_text(text)
	return CE.el.spacer .. text .. CE.el.spacer
end

---Returns buffer
---@return string
function M.get_buffer()
	local buffer = ""
	if S.opt.buffer.show == true then
		---@type buffer_cache_bufnr
		local bufnr_item = CB.get_buff_nr(S.opt.buffer)
		local prefix = #bufnr_item.prefix > 0 and UC.highlight_text(bufnr_item.prefix, C.group_names.fg_30) or ""
		local nr = UC.highlight_text(bufnr_item.nr, C.group_names.fg_bold)
		buffer = CE.el.space .. CB.cache.bufmod_flag .. CE.el.space .. prefix .. nr .. CE.separator(S.opt.separator)
	end
	return buffer
end

---comment
---@param diagnostic_object diagnostic_object
---@param count_group_name string
---@param arrow_group_name string
---@param lnum_group_name string
---@return string
local function highlight_diagnostic(diagnostic_object, count_group_name, arrow_group_name, lnum_group_name)
	return table.concat({
		UC.highlight_text(tostring(diagnostic_object.count), count_group_name),
		UC.highlight_text("↓", arrow_group_name),
		UC.highlight_text(tostring(diagnostic_object.first_lnum), lnum_group_name)
	})
end

---Returns diagnostics
---@return string
function M.get_diagnostics()
	local diagnostics = CD.get_diagnostics()
	local err, warn, hint, info = "0", "0", "0", "0"
	if diagnostics.error.count > 0 then
		err = highlight_diagnostic(diagnostics.error, C.group_names.fg_error_bold, C.group_names.fg_error_50, C.group_names.fg_error)
	end
	if diagnostics.warn.count > 0 then
		warn = highlight_diagnostic(diagnostics.warn, C.group_names.fg_warn_bold, C.group_names.fg_warn_50, C.group_names.fg_warn)
	end
	if diagnostics.hint.count > 0 then
		hint = highlight_diagnostic(diagnostics.hint, C.group_names.fg_hint_bold, C.group_names.fg_hint_50, C.group_names.fg_hint)
	end
	if diagnostics.info.count > 0 then
		info = highlight_diagnostic(diagnostics.info, C.group_names.fg_info_bold, C.group_names.fg_info_50, C.group_names.fg_info)
	end
	local comma_space = CE.comma() .. CE.el.space
	return err .. comma_space .. warn .. comma_space .. hint .. comma_space .. info .. CE.separator(S.opt.separator)
end

---Returns branch and git status
---@return string
function M.get_branch_status()
	local branch = ""
	local insertions = ""
	local deletions = ""
	if #CG.cache.branch ~= 0 then
		branch = UC.highlight_text(CG.cache.branch, C.group_names.fg_60_bold) .. CE.el.space
	end
	if CG.cache.diff_info.insertions ~= 0 then
		insertions = UC.highlight_text(tostring(CG.cache.diff_info.insertions), C.group_names.fg_diff_add_bold)
		insertions = insertions .. UC.highlight_text("+", C.group_names.fg_diff_add_50) .. CE.el.space
	end
	if CG.cache.diff_info.deletions ~= 0 then
		deletions = UC.highlight_text(tostring(CG.cache.diff_info.deletions), C.group_names.fg_diff_delete_bold)
		deletions = deletions .. UC.highlight_text("-", C.group_names.fg_diff_delete_50) .. CE.el.space
	end
	return CE.el.spacer .. branch .. insertions .. deletions
end

---Returns path to the file
---@return string
function M.get_filepath()
	local path_parts = CP.filepath()
	local path = "[No name]"
	if #path_parts.relative.path ~= 0 and #path_parts.full.path ~= 0 then
		local filename = UC.highlight_text(path_parts.relative.filename, C.group_names.fg_bold)
		if S.opt.filepath.path == "tail" then
			path = filename
		elseif S.opt.filepath.path == "relative" then
			local relative = S.opt.filepath.shorten and path_parts.relative.shorten or path_parts.relative.path
			path = UC.highlight_text(relative, C.group_names.fg_60) .. filename
		elseif S.opt.filepath.path == "full" then
			local full = S.opt.filepath.shorten and path_parts.full.shorten or path_parts.full.path
			path = UC.highlight_text(full, C.group_names.fg_60) .. filename
		end
	end
	return CE.el.truncate .. path .. CE.el.spacer
end

---Returns quickfix list
---@return string
function M.get_quickfix()
	local idx = UC.highlight_text(tostring(CQ.get_qflist_idx()), C.group_names.fg_bold)
	local entries_count = CQ.get_entries_count()
	local files_count = CQ.get_files_w_entries_count()
	local title
	local quickfix = ""
	if CQ.get_qflist_winid() == vim.api.nvim_get_current_win() then
		local text_in = UC.highlight_text("in", C.group_names.fg_60)
		local text_file = UC.highlight_text(files_count > 1 and "files" or "file", C.group_names.fg_60)
		title = UC.highlight_text("Quickfix List", C.group_names.fg_60_bold)
		local text_of = UC.highlight_text("of", C.group_names.fg_60)
		quickfix = M.spaced_text(table.concat({
			title .. CE.el.space,
			idx .. CE.el.space .. text_of .. CE.el.space .. entries_count .. CE.el.space,
			files_count ~= 0 and text_in .. CE.el.space .. files_count .. CE.el.space .. text_file or "",
		}))
	else
		if UU.laststatus() == 3 and not CQ.is_qflist_empty() then
			title = UC.highlight_text("QF:", C.group_names.fg_60)
			local text_slash = UC.highlight_text("/", C.group_names.fg_60)
			quickfix = table.concat({
				title .. CE.el.space,
				idx .. text_slash .. entries_count,
				CE.separator(S.opt.separator),
			})
		end
	end
	return quickfix
end

---Returns help filename
---@return string
function M.get_help()
	local help = UC.highlight_text("Help", C.group_names.fg_60_bold)
	local buff_name = vim.api.nvim_buf_get_name(0)
	return M.spaced_text(help .. CE.el.space .. buff_name:match("[%s%w_]-%.%w-$"))
end

---Returns spaced branch, git status and text
---@param text any
---@return string
function M.get_branch_status_text(text)
	return M.get_branch_status() .. text .. CE.el.spacer
end

---Returns file size
---@return string
function M.get_filesize()
	local size = S.opt.filesize.metric == "decimal" and UU.si_fsize() or UU.bi_fsize()
	return table.concat({
		CE.separator(S.opt.separator),
		size[1] .. UC.highlight_text(size[2], C.group_names.fg_50),
	})
end

---Returns ruller
---@param ln boolean
---@param col boolean
---@param loc boolean
---@return string
function M.get_ruller(ln, col, loc)
	return table.concat({
		CE.separator(S.opt.separator),
		ln and CE.ln() .. CE.comma() .. CE.el.space or "",
		col and CE.col() .. CE.comma() .. CE.el.space or "",
		loc and CE.loc() or "",
	})
end

---Auto commands
---@type string
local autocmd_group = vim.api.nvim_create_augroup(UU.prefix .. "Group", {
	clear = true,
})

---Sets auto commands
---@param cb function
local function setup_autocmd(cb)
	-- colors
	vim.api.nvim_create_autocmd({
		"ColorScheme",
	}, {
		pattern = "*",
		callback = function()
			C._init()
			cb()
		end,
		group = autocmd_group,
	})

	-- buffer number
	-- buffer modified flag
	-- diagnostics
	vim.api.nvim_create_autocmd({
		"BufAdd",
		"BufModifiedSet",
		"DiagnosticChanged",
	}, {
		pattern = "*",
		callback = function()
			CB.set_bufmod_flag(S.opt.buffer)
			cb()
		end,
		group = autocmd_group,
	})

	-- buffer number
	-- branch name
	vim.api.nvim_create_autocmd({
		"BufEnter",
	}, {
		pattern = "*",
		callback = function()
			CG.set_git_branch()
			cb()
		end,
		group = autocmd_group,
	})

	-- diff info
	vim.api.nvim_create_autocmd({
		"BufWritePost",
		"BufReadPost",
	}, {
		pattern = "*",
		callback = function()
			CG.set_diff_info()
			cb()
		end,
		group = autocmd_group,
	})

	-- branch name
	-- diff info
	vim.api.nvim_create_autocmd({
		"VimEnter",
		"FocusGained",
	}, {
		pattern = "*",
		callback = function()
			CG.set_git_branch()
			CG.set_diff_info()
			cb()
		end,
		group = autocmd_group,
	})

	-- neogit commit complete
	vim.api.nvim_create_autocmd('User', {
		pattern = 'NeogitCommitComplete',
		callback = function()
			CG.set_diff_info()
			cb()
		end,
		group = autocmd_group,
	})

	-- neogit push complete
	vim.api.nvim_create_autocmd('User', {
		pattern = 'NeogitPushComplete',
		callback = function()
			CG.set_diff_info()
			cb()
		end,
		group = autocmd_group,
	})

	-- quickfix list
	vim.api.nvim_create_autocmd({
		"QuickFixCmdPost",
	}, {
		pattern = "*",
		callback = function()
			CQ.set_qflist()
			cb()
		end,
		group = autocmd_group,
	})
end

---Setup callback
---@param opts opts
---@param cb function
function M._init(opts, cb)
	S.setup(opts)
	C._init()
	CB.clear_cache()
	CB.set_bufmod_flag(S.opt.buffer)
	setup_autocmd(cb)
	cb()
end

return M
