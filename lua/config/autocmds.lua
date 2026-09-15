--创建分组
local function augroup(name)
	return vim.api.nvim_create_augroup("custom_" .. name, { clear = true })
end

-- 只保存有名称且可写的普通文件；update 避免未修改时重复写盘。
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
	group = augroup("auto_save"),
	pattern = "*",
	callback = function(event)
		if event.event == "TextChanged" then
			GlobalUtil.buffer.schedule_autosave(event.buf)
		else
			GlobalUtil.buffer.autosave(event.buf)
		end
	end,
})

-- macOS 输入法集成按平台和可用性启用，具体 IPC 状态由独立模块管理。
require("utils.input_method").setup()

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
		vim.hl.on_yank()
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
			if not vim.api.nvim_buf_is_valid(event.buf) then
				return
			end
			vim.keymap.set("n", "q", function()
				vim.cmd("close")
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

-- 文件改名、LSP 附加/退出后重新检测根目录，删除缓冲区时释放缓存。
vim.api.nvim_create_autocmd({ "BufFilePost", "LspAttach", "LspDetach", "BufWipeout" }, {
	group = augroup("invalidate_root"),
	callback = function(event)
		GlobalUtil.root.cache[event.buf] = nil
	end,
})

-- 目录缓冲区生命周期交由 Snacks explorer 管理，避免延迟删除误伤新内容。
