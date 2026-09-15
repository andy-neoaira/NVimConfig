-- nvim --headless -u NONE -i NONE -l tests/async.lua
-- 使用受控的异步响应验证时序，不执行 Hammerspoon 或图片转换程序。
vim.opt.rtp:prepend(vim.fn.getcwd())
local passed = 0
local function check(value, message)
	assert(value, message)
	passed = passed + 1
end
_G.GlobalUtil = { warn = function() end }
local function run()
	local calls = {}
	local system, uis, executable = vim.system, vim.api.nvim_list_uis, vim.fn.executable
	vim.api.nvim_list_uis = function()
		return { {} }
	end
	vim.fn.executable = function()
		return 1
	end
	vim.system = function(cmd, _, callback)
		calls[#calls + 1] = { cmd = cmd, callback = callback }
	end
	if vim.fn.has("macunix") == 1 then
		require("utils.input_method").setup()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "中文x" })
		vim.api.nvim_win_set_cursor(0, { 1, 6 })
		vim.api.nvim_exec_autocmds("InsertLeave", {})
		vim.api.nvim_exec_autocmds("InsertEnter", {})
		check(#calls == 1, "输入法 IPC 必须串行执行")
		calls[1].callback({ code = 0, stdout = "NVIM_INPUT_METHOD:com.test.Chinese\n" })
		vim.wait(100, function()
			return #calls == 2
		end)
		check(
			#calls == 2 and calls[2].cmd[3]:find("com.test.Chinese", 1, true),
			"首次快速返回插入模式应恢复刚读出的输入法"
		)
		calls[2].callback({ code = 0, stdout = "NVIM_INPUT_METHOD:com.apple.keylayout.ABC\n" })
		vim.wait(20, function()
			return false
		end)
		vim.api.nvim_del_augroup_by_name("custom_input_method")
	end
	vim.system, vim.api.nvim_list_uis, vim.fn.executable = system, uis, executable

	local linted = {}
	package.loaded.lint = {
		linters = { fish = {} },
		_resolve_linter_by_ft = function()
			return { "fish" }
		end,
		try_lint = function()
			linted[vim.api.nvim_get_current_buf()] = true
		end,
	}
	local spec = dofile("lua/plugins/nvim-lint.lua")
	spec.config(nil, spec.opts)
	local first = vim.api.nvim_get_current_buf()
	local second = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_exec_autocmds("InsertLeave", { buffer = first })
	vim.api.nvim_exec_autocmds("InsertLeave", { buffer = second })
	vim.wait(300, function()
		return linted[first] and linted[second]
	end)
	check(linted[first] and linted[second], "多个缓冲区的诊断事件不能相互覆盖")
	vim.api.nvim_del_augroup_by_name("custom_nvim_lint")

	local created, closed, updates = 0, 0, 0
	local deferred
	local inline = {}
	inline.__index = inline
	inline.new = function(buf)
		created = created + 1
		return setmetatable(
			{ buf = buf, imgs = { {
				close = function()
					closed = closed + 1
				end,
			} }, idx = {} },
			inline
		)
	end
	inline.update = function()
		updates = updates + 1
	end
	inline.conceal = function() end
	package.loaded["snacks.image.inline"] = inline
	package.loaded["snacks.image.doc"] = {
		find_visible = function(_, callback)
			deferred = callback
		end,
		hover = function() end,
		hover_close = function() end,
	}
	package.loaded["snacks.image.placement"] = { update = function() end }
	local image = require("utils.image")
	image.setup()
	image.setup()
	local instance = inline.new(first)
	check(inline.new(first) == instance and created == 1, "预览切换不能创建重复图片实例")
	local result
	package.loaded["snacks.image.doc"].find_visible(first, function(value)
		result = value
	end)
	image.set_enabled(false)
	check(closed == 1 and next(instance.imgs) == nil, "关闭图片时释放 placement 和索引")
	deferred({ "stale-image" })
	check(#result == 0, "过期异步结果不能使关闭的图片重新出现")
	image.set_enabled(true)
	check(updates == 1 and created == 1, "重新开启时刷新原实例")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
end
io.stdout:write(("通过 %d 项异步回归断言\n"):format(passed))
io.stdout:flush()
vim.cmd("qa!")
