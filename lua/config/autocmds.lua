--创建分组
local function augroup(name)
	return vim.api.nvim_create_augroup("custom_" .. name, { clear = true })
end

-- 离开插入模式后自动保存a
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
	group = augroup("auto_save"),
	pattern = "*",
	command = "silent! write",
})

local english_input_method = "com.apple.keylayout.ABC"
local previous_input_method
local input_method_generation = 0
local auto_switch_input_method_group = augroup("auto_switch_input_method")

---@param script string
---@param callback? fun(result: vim.SystemCompleted)
local function run_hammerspoon(script, callback)
	local ok = pcall(vim.system, { "hs", "-c", script }, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify_once("无法通过 Hammerspoon 切换输入法", vim.log.levels.WARN)
				return
			end
			if callback then
				callback(result)
			end
		end)
	end)
	if not ok then
		vim.notify_once("未找到 Hammerspoon CLI（hs）", vim.log.levels.WARN)
	end
end

---@param input_method string
local function switch_input_method(input_method)
	local script = string.format("hs.keycodes.currentSourceID(%q)", input_method)
	run_hammerspoon(script)
end

local function in_insert_mode()
	return vim.api.nvim_get_mode().mode:match("^[iR]") ~= nil
end

-- 单次 IPC 同时读取并切换，避免阻塞 Neovim 主线程。
local function remember_and_switch_to_english()
	input_method_generation = input_method_generation + 1
	local generation = input_method_generation
	local script = string.format(
		'local current = hs.keycodes.currentSourceID(); print("NVIM_INPUT_METHOD:" .. (current or "")); if current ~= %q then hs.keycodes.currentSourceID(%q) end',
		english_input_method,
		english_input_method
	)
	run_hammerspoon(script, function(result)
		local current = (result.stdout or ""):match("NVIM_INPUT_METHOD:([^\r\n]+)")
		if current and current ~= english_input_method then
			previous_input_method = current
		end

		-- 若用户在 IPC 返回前已重新进入插入模式，立即恢复刚记录的输入法。
		if generation ~= input_method_generation
			and in_insert_mode()
			and current
			and current ~= english_input_method
		then
			switch_input_method(current)
		end
	end)
end

local function force_english_input_method()
	input_method_generation = input_method_generation + 1
	switch_input_method(english_input_method)
end

local function previous_character_is_non_ascii()
	local _, col = unpack(vim.api.nvim_win_get_cursor(0))
	if col == 0 then
		return false
	end
	local text = vim.api.nvim_get_current_line():sub(1, col)
	local char_count = vim.fn.strchars(text)
	local previous_character = vim.fn.strcharpart(text, char_count - 1, 1)
	return previous_character:byte() > 127
end

-- 离开插入模式时记住非英文输入法，并强制切换到 ABC。
vim.api.nvim_create_autocmd("InsertLeave", {
	group = auto_switch_input_method_group,
	callback = remember_and_switch_to_english,
})

-- 启动、重新聚焦或进入命令行时，非插入模式始终使用英文输入法。
vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "CmdlineEnter" }, {
	group = auto_switch_input_method_group,
	callback = function()
		if not in_insert_mode() then
			force_english_input_method()
		end
	end,
})

-- 中文等非 ASCII 文本后进入插入模式时，恢复上次使用的非英文输入法。
vim.api.nvim_create_autocmd("InsertEnter", {
	group = auto_switch_input_method_group,
	callback = function()
		input_method_generation = input_method_generation + 1
		if previous_input_method and previous_character_is_non_ascii() then
			switch_input_method(previous_input_method)
		end
	end,
})

-- 换行不自动注释
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("no_auto_comment"),
	pattern = "*",
	callback = function()
		vim.opt_local.formatoptions:append("c")
		vim.opt_local.formatoptions:remove({ "r", "o" })
	end,
})

--判断是否需要重新加载
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	group = augroup("checktime"),
	callback = function()
		if vim.o.buftype ~= "nofile" then
			vim.cmd("checktime")
		end
	end,
})
--
-- y复制是高亮
vim.api.nvim_create_autocmd("TextYankPost", {
	group = augroup("highlight_yank"),
	callback = function()
		vim.highlight.on_yank()
	end,
})

--分屏重置标签大小
vim.api.nvim_create_autocmd({ "VimResized" }, {
	group = augroup("resize_splits"),
	callback = function()
		local current_tab = vim.fn.tabpagenr()
		vim.cmd("tabdo wincmd =")
		vim.cmd("tabnext " .. current_tab)
	end,
})

--光标自动回复上次关闭的位置
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup("last_loc"),
	callback = function(event)
		local exclude = { "gitcommit" }
		local buf = event.buf
		if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].last_loc_flag then
			return
		end
		vim.b[buf].last_loc_flag = true
		local mark = vim.api.nvim_buf_get_mark(buf, '"')
		local lcount = vim.api.nvim_buf_line_count(buf)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- q直接退出部分缓冲区
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("close_with_q"),
	pattern = {
		"PlenaryTestPopup",
		"checkhealth",
		"dbout",
		"gitsigns-blame",
		"grug-far",
		"help",
		"lspinfo",
		"neotest-output",
		"neotest-output-panel",
		"neotest-summary",
		"notify",
		"qf",
		"snacks_win",
		"spectre_panel",
		"startuptime",
		"tsplayground",
	},
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(event.buf) then return end
			vim.keymap.set("n", "q", function()
				vim.cmd("close")
				pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
			end, {
				buffer = event.buf,
				silent = true,
				desc = "Quit buffer",
			})
		end)
	end,
})

-- make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("man_unlisted"),
	pattern = { "man" },
	callback = function(event)
		vim.bo[event.buf].buflisted = false
	end,
})

-- wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("wrap_spell"),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.breakindent = true
    vim.opt_local.showbreak = "↳ "
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("textwidth_text"),
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.textwidth = 80
    vim.opt_local.formatoptions:append("t")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("textwidth_git"),
  pattern = { "gitcommit" },
  callback = function()
    vim.opt_local.textwidth = 72
    vim.opt_local.formatoptions:append("t")
  end,
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd({ "FileType" }, {
	group = augroup("json_conceal"),
	pattern = { "json", "jsonc", "json5" },
	callback = function()
		vim.opt_local.conceallevel = 0
	end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = augroup("auto_create_dir"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- 切换项目（如 Snacks.picker.projects）时同步根目录缓存和目录树
vim.api.nvim_create_autocmd("DirChanged", {
  group = augroup("sync_root_on_dir_change"),
  callback = function()
    -- 清除缓冲区级根目录缓存，确保下次 M.get() 重新检测
    GlobalUtil.root.cache = {}
    -- 直接更新 root_path，不再调用 chdir（避免循环触发 DirChanged）
    local new_cwd = vim.uv.cwd()
    GlobalUtil.root.root_path = GlobalUtil.root.realpath(new_cwd)
    -- snacks explorer watch=true 会自动监听文件系统变化，此处无需手动刷新
  end,
})

-- 自动清除目录 buffer（Snacks.picker.projects 等切换项目后残留的目录 buffer）
-- replace_netrw=true 已由 snacks explorer 接管目录打开，此处只需清理残留 buffer
vim.api.nvim_create_autocmd("BufEnter", {
  group = augroup("kill_dir_buf"),
  callback = function(ev)
    local path = vim.api.nvim_buf_get_name(ev.buf)
    if path == "" or vim.fn.isdirectory(path) ~= 1 then
      return
    end
    vim.schedule(function()
      pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
    end)
  end,
})
