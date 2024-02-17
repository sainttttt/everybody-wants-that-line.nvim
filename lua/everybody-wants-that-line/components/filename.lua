local C  = require("everybody-wants-that-line.colors")
local CE = require("everybody-wants-that-line.components.elements")
local CF = require("everybody-wants-that-line.components.filepath")
local UU = require("everybody-wants-that-line.utils.util")

local M = {}

---@class filename_win_cache
---@field win_id number
---@field float_win_id number
---@field float_buf_id number
---@field buf_id number
---@field filename string

---@type { [number]: filename_win_cache }
local cache = {}

local show_float = true

local ns_id = vim.api.nvim_create_namespace(UU.prefix)

---Returns floating window config
---@param win_id number
---@param filename string
---@return table
local function get_config(win_id, filename)
	local width = #filename
	width = width > 0 and width or 1
	local win_width = vim.api.nvim_win_get_width(win_id)
	local win_height = vim.api.nvim_win_get_height(win_id)
  local row_loc = 0
  local col_loc = win_width - 1
  local zindex = 50
  if vim.g.zen_opened then
    if vim.api.nvim_win_get_config(win_id).relative == '' then
      row_loc = win_height / 2
      col_loc = win_width / 2
      zindex = 1
    else
      zindex = 50
    end
  else
    zindex = 50
  end
	local config = {
		relative = "win",
		win = win_id,
		anchor = "NE",
		width = width + 2,
		height = 2,
		row = row_loc,
		col = col_loc,
		focusable = false,
		style = "minimal",
		noautocmd = true,
    zindex = zindex,
	}
	return config
end


local function update_float(float_win_id)

  print('updating float')
	local bufnr = UU.get_bufnr()
	local is_modifiable = vim.api.nvim_buf_get_option(bufnr, "mod") --[[@as boolean]]
  print(float_win_id)

  if is_modifiable then
    local cat = vim.api.nvim_create_namespace("cat")
    -- local cat = 0
    -- vim.api.nvim_set_hl_ns(cat)
    -- vim.api.nvim_set_hl(cat, "StatusLineNC", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(cat, "StatusLine", { ctermbg = 3, ctermfg = 4})
    vim.api.nvim_set_hl(cat, "Pmenu", { ctermbg = 1})
    -- vim.api.nvim_set_hl(cat, "PmenuSel", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(cat, "NonText", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(cat, "TabLine", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(0, "Visual", { ctermbg = 8, ctermfg = 3})
    vim.api.nvim_win_set_hl_ns(float_win_id, cat)
  else
    local cat = vim.api.nvim_create_namespace("cat")
    -- local cat = 0
    -- vim.api.nvim_set_hl_ns(cat)
    vim.api.nvim_win_set_hl_ns(float_win_id, cat)
    -- vim.api.nvim_set_hl(cat, "StatusLineNC", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(cat, "StatusLine", { ctermbg = 3, ctermfg = 4})
    vim.api.nvim_set_hl(cat, "Pmenu", { ctermbg = 8})
    -- vim.api.nvim_set_hl(cat, "PmenuSel", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(cat, "NonText", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(cat, "TabLine", { ctermbg = 3, ctermfg = 4})
    -- vim.api.nvim_set_hl(0, "Visual", { ctermbg = 8, ctermfg = 3})
    print(cat)
    print("wooof")
  end

end
---Creates new floating window
---@param win_id number
---@param filename string
local function create_float(win_id, filename)
	local config = get_config(win_id, filename)

  if not show_float then
    return
  end


	local buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf_id, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf_id, "filetype", UU.prefix)
	vim.api.nvim_buf_set_option(buf_id, "buftype", "nofile")
	local content = CE.with_offset(filename)
	vim.api.nvim_buf_set_lines(buf_id, 0, 1, false, { string.rep(" ", #content), content })
	local float_win_id = vim.api.nvim_open_win(buf_id, false, config)

	cache[win_id] = {
		win_id = win_id,
		float_win_id = float_win_id,
		float_buf_id = buf_id,
		buf_id = vim.api.nvim_get_current_buf(),
		filename = filename,
	}
end

---Updates content of a floating window
---@param win_id number
---@param new_filename string
local function update_filename(win_id, new_filename)
	if new_filename ~= cache[win_id].filename then
		cache[win_id].filename = new_filename
		local content = CE.with_offset(new_filename)
		vim.api.nvim_buf_set_lines(cache[win_id].float_buf_id, 0, 1, false, { string.rep(" ", #content), content })
	end
end

---Align floats
---@param win_id number
local function move_float(win_id)
	local config = get_config(win_id, cache[win_id].filename)
	config.noautocmd = nil

	vim.api.nvim_win_set_config(cache[win_id].float_win_id, config)
end

---Remove unused floats
---@param win_ids number[]
local function clean_floats(win_ids)
	---@type filename_win_cache[]
	local ids_to_clean = {}
	for win_id, _ in pairs(cache) do
		if not vim.tbl_contains(win_ids, win_id) then
			table.insert(ids_to_clean, cache[win_id])
		end
	end
	for _, win_cache in ipairs(ids_to_clean) do
		if UU.is_win_valid(win_cache.float_win_id) then
			vim.api.nvim_win_close(win_cache.float_win_id, false)
			cache[win_cache.win_id] = nil
		end
	end
end

---highlight active window
---@param curwin_id number
---@param win_id number
local function highlight_float(curwin_id, win_id)

	local bufnr = cache[win_id].buf_id
	local is_modifiable = vim.api.nvim_buf_get_option(bufnr, "mod") --[[@as boolean]]

  local hlgroup = C.group_names[curwin_id == win_id and "fg_bold" or "fg_60_bold"]
  if is_modifiable then
    hlgroup = "FloatFilenameChange"
  else
    hlgroup = "FloatFilename"
  end

	vim.api.nvim_buf_clear_namespace(cache[win_id].float_buf_id, ns_id, 0, -1)
	vim.api.nvim_buf_add_highlight(cache[win_id].float_buf_id, ns_id, hlgroup, 0, 0, #cache[win_id].filename + 2)
	vim.api.nvim_buf_add_highlight(cache[win_id].float_buf_id, ns_id, hlgroup, 1, 0, #cache[win_id].filename + 2)
end



---Sets file name floating windows
---@param args event_args
function M.set_filename(args)
	vim.schedule(function()
		---@type number[]
		local win_ids = vim.api.nvim_list_wins()
		if args.event == "WinClosed" then
			clean_floats(win_ids)
		end
		-- get new list after cleaning
		win_ids = vim.api.nvim_list_wins()
		---@type number
		local curwin_id = vim.api.nvim_get_current_win()
		if cache[curwin_id] == nil then
			local filepath = CF.get_filepath(vim.api.nvim_get_current_buf())
			if #filepath.full.filename > 0 then
				local wintype = UU.get_wintype(curwin_id)
				if wintype == "normal" or wintype == "help" then
					create_float(curwin_id, filepath.full.filename)
				end
			end
    else

    -- update_float(cache[curwin_id].float_win_id)

		end
		for _, win_id in ipairs(win_ids) do
			if cache[win_id] ~= nil and UU.is_win_valid(win_id) then
				cache[win_id].buf_id = vim.api.nvim_win_get_buf(win_id)
				local filepath = CF.get_filepath(cache[win_id].buf_id)
				-- <C-w o> closes all floats, so we have to recreate them
				if not UU.is_win_valid(cache[win_id].float_win_id) then
					create_float(win_id, filepath.full.filename)
				end
				update_filename(win_id, filepath.full.filename)
				move_float(win_id)
				highlight_float(curwin_id, win_id)
			end
		end
	end)
end

function M.toggle_float()
  show_float = not show_float

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = nil
    if pcall( function() config = vim.api.nvim_win_get_config(win) end) then
      if config.relative ~= "" then
        vim.api.nvim_win_close(win, false)
      else
        cache[win] = nil
        -- cache[win]["float_buf_id"] = nil
      end
    else
      print("tete")
    end

  end
  M.set_filename({event = "none"})
end

return M
