-- 在仓库根目录执行：nvim --headless -u NONE -i NONE -l tests/core.lua
-- 只操作临时文件，不加载用户插件、不写入个人会话和历史记录。
vim.opt.rtp:prepend(vim.fn.getcwd())
local passed = 0
local function check(value, message)
	assert(value, message)
	passed = passed + 1
end
local warnings = {}
_G.GlobalUtil = {
	norm = vim.fs.normalize,
	warn = function(message)
		warnings[#warnings + 1] = message
	end,
	info = function() end,
	has = function()
		return false
	end,
}
local temp = vim.fn.tempname()
vim.fn.mkdir(temp .. "/app", "p")
vim.fn.mkdir(temp .. "/apple", "p")
local original_cwd = vim.fn.getcwd()
local function run()
	local format = require("utils.format")
	local function formatter(name, priority)
		return {
			name = name,
			priority = priority,
			primary = true,
			sources = function()
				return { name }
			end,
			format = function() end,
		}
	end
	format.register(formatter("LSP", 1))
	format.register(formatter("external", 100))
	format.register(formatter("external", 200))
	check(#format.formatters == 2, "同名格式化器不能重复注册")
	check(format.resolve()[1].active and not format.resolve()[2].active, "主格式化器按优先级选择")
	vim.g.autoformat = true
	vim.b.autoformat = false
	format.enable(true, true)
	check(vim.b.autoformat == true, "缓冲区 false 应能重新启用")
	vim.b.autoformat = false
	format.enable(false)
	check(vim.b.autoformat == false, "切换全局应保留缓冲区覆盖")
	format.toggle()
	check(vim.g.autoformat == true and not format.enabled(), "全局切换不应读取缓冲区覆盖状态")

	local root = require("utils.root")
	check(root.realpath("/") == "/", "规范化不能把文件系统根目录变为空字符串")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, temp .. "/apple/new.lua")
	GlobalUtil.lsp = {
		get_clients = function()
			return { { config = {}, root_dir = temp .. "/app" } }
		end,
	}
	check(#root.detectors.lsp(buf) == 0, "LSP 根路径不能按任意字符串前缀匹配")
	GlobalUtil.lsp.get_clients = function()
		return { { config = {}, workspace_folders = { { uri = vim.uri_from_fname(temp .. "/apple") } } } }
	end
	check(root.detectors.lsp(buf)[1] == temp .. "/apple", "识别动态 workspace_folders")
	local calls = 0
	local roots = root.detect({
		spec = {
			function()
				return temp
			end,
			function()
				calls = calls + 1
				return temp
			end,
		},
	})
	check(#roots == 1 and calls == 0, "默认找到第一项即停止检测")
	root.cache[buf] = "cached-root"
	check(root.get({ buf = 0 }) == "cached-root", "buf=0 与当前缓冲区使用同一缓存")
	check(root.reload_root_path(temp .. "/apple") and next(root.cache) == nil, "切换目录成功后清空缓存")
	local before = root.root_path
	check(
		not root.reload_root_path(temp .. "/missing") and root.root_path == before,
		"无效目录不能更新根状态"
	)
	check(root.bufpath(999999) == nil, "无效缓冲区应安全返回")

	local buffer = require("utils.buffer")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "saved" })
	vim.bo[buf].readonly = true
	check(
		not buffer.autosave(buf) and vim.fn.filereadable(temp .. "/apple/new.lua") == 0,
		"不自动保存只读文件"
	)
	vim.bo[buf].readonly = false
	check(buffer.autosave(buf), "自动保存可写文件")
	check(vim.fn.readfile(temp .. "/apple/new.lua")[1] == "saved", "内容写入目标文件")
	check(not buffer.autosave(buf), "未修改时不重复保存")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved" })
	vim.b[buf].autosave = false
	check(not buffer.autosave(buf) and vim.bo[buf].modified, "支持缓冲区级禁用自动保存")
	vim.b[buf].autosave = nil
	local scratch = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(scratch)
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "draft" })
	check(not buffer.autosave(scratch), "未命名草稿不触发写入")
	check(buffer.autosave(buf) and vim.bo[scratch].modified, "后台保存不能写入当前窗口草稿")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "debounced" })
	buffer.schedule_autosave(buf)
	buffer.schedule_autosave(buf)
	check(
		vim.wait(500, function()
			return not vim.bo[buf].modified
		end),
		"延迟自动保存必须最终写入目标缓冲区"
	)
	check(vim.fn.readfile(temp .. "/apple/new.lua")[1] == "debounced", "延迟写盘内容正确")
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "keep me" })
	-- fallback 不应使用 bdelete!；modified 内容和缓冲区必须保留。
	vim.o.confirm = false
	require("utils.ui").close()
	check(vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified, "关闭回退路径保护未保存内容")
	check(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "keep me", "关闭失败后内容完整")
end

local ok, err = xpcall(run, debug.traceback)
vim.api.nvim_set_current_dir(original_cwd)
-- temp 由 tempname 创建且本脚本独占，仅清理自己的测试产物。
vim.fn.delete(temp, "rf")
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
end
print(("通过 %d 项核心回归断言"):format(passed))
vim.cmd("qa!")
