-- 使用已安装的插件做离线配置集成检查；不触发认证、下载或测试运行。
-- nvim --headless -u NONE -i NONE -l tests/integration.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.loadplugins = true
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
local errors = {}
local lazy_util = require("lazy.core.util")
local original_error = lazy_util.error
lazy_util.error = function(message, opts)
	errors[#errors + 1] = type(message) == "table" and table.concat(message, "\n") or tostring(message)
	return original_error(message, opts)
end
local lazy = require("lazy")
local setup = lazy.setup
lazy.setup = function(opts)
	-- AI 服务不属于离线测试范围，防止复用本机认证发出远端请求。
	opts.spec[#opts.spec + 1] = { "zbirenbaum/copilot.lua", enabled = false }
	return setup(opts)
end
local ok, err = xpcall(function()
	require("config")
	-- -l 不经历正常的 VimEnter 生命周期，显式补发一次延迟初始化事件。
	if not vim.g.did_very_lazy then
		vim.g.did_very_lazy = true
		vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
	end
	lazy.load({
		plugins = {
			"nvim-lspconfig",
			"conform.nvim",
			"nvim-lint",
			"neotest",
			"nvim-dap",
			"nvim-dap-python",
			"nvim-treesitter-context",
			"refactoring.nvim",
			"render-markdown.nvim",
			"persistence.nvim",
			"trouble.nvim",
			"nvim-filetype",
			"bufferline.nvim",
			"lualine.nvim",
			"which-key.nvim",
			"flash.nvim",
			"mini.pairs",
			"mini.surround",
			"CopilotChat.nvim",
			"miniobsidian.nvim",
			"grug-far.nvim",
			"gitsigns.nvim",
			"todo-comments.nvim",
			"noice.nvim",
			"venv-selector.nvim",
			"kitty-scrollback.nvim",
		},
	})
	vim.wait(500, function()
		return false
	end, 20)
	local plugins = require("lazy.core.config").plugins
	assert(not plugins["none-ls.nvim"], "重复格式化引擎仍然启用")
	assert(vim.lsp.config.vue_ls and vim.lsp.config.vue_ls.filetypes[1] == "vue", "Vue 服务器未正确配置")
	assert(vim.fn.exists(":ToolsInstall") == 2, "工具安装命令未注册")
	assert(vim.fn.exists(":TSInstallConfigured") == 2, "解析器安装命令未注册")
	assert(vim.fn.maparg("f", "n") ~= "", "Flash 快捷键不存在")
	assert(vim.fn.maparg("<D-/>", "n", false, true).noremap == 0, "注释快捷键未保留 remap")
	-- 真实调用本机 StyLua，验证 Conform 保存链路及格式化开关。
	if vim.fn.executable("stylua") == 1 then
		vim.g.autosave = false
		local file = vim.fn.tempname() .. ".lua"
		vim.cmd.enew()
		vim.api.nvim_buf_set_name(0, file)
		vim.bo.filetype = "lua"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x={1,2}" })
		vim.cmd.write()
		assert(vim.fn.readfile(file)[1] == "local x = { 1, 2 }", "保存未执行 StyLua 格式化")
		vim.b.autoformat = false
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x={3,4}" })
		vim.cmd.write()
		assert(vim.fn.readfile(file)[1] == "local x={3,4}", "禁用后保存仍修改了格式")
		vim.fn.delete(file)
	end
	local render = require("render-markdown")
	local was_enabled = render.get()
	require("utils.image").toggle_markdown()
	assert(render.get() ~= was_enabled, "Markdown 开关未切换")
	require("utils.image").toggle_markdown()
	assert(render.get() == was_enabled, "Markdown 开关未恢复")
	GlobalUtil.format.resolve()
	assert(#GlobalUtil.format.formatters == 2, "格式化入口应只注册 Conform 与 LSP")
	-- 使用真实匹配器验证截图中的排序，同时保护其他语言与 LSP 编辑内容。
	do
		local config = require("blink.cmp.config")
		local fuzzy = require("blink.cmp.fuzzy")
		assert(config.cmdline.completion.menu.auto_show == true, "命令行补全菜单应自动显示")
		assert(
			vim.fn.maparg("<Up>", "c", false, true).desc == "blink.cmp: Select Prev",
			"命令行上方向键未绑定上一项"
		)
		assert(
			vim.fn.maparg("<Down>", "c", false, true).desc == "blink.cmp: Select Next",
			"命令行下方向键未绑定下一项"
		)
		local kinds = vim.lsp.protocol.CompletionItemKind
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].filetype = "python"
		local ctx = { bufnr = buf }
		local transform = config.sources.providers.lsp.transform_items
		local edits = { { newText = "from models import ChatDeepSeek\n" } }
		local original = {
			{ label = "chat", kind = kinds.Module },
			{ label = "chat_models", kind = kinds.Module },
			{ label = "ChatDeepSeek", kind = kinds.Class, additionalTextEdits = edits },
		}
		local ranked = transform(ctx, original)
		assert(original[3].score_offset == nil, "排序不能修改原始缓存候选")
		assert(ranked[3].additionalTextEdits == edits, "排序必须保留自动导入编辑")
		assert(transform(ctx, original)[3].score_offset == ranked[3].score_offset, "重复处理不能累计加分")
		for _, query in ipairs({ "chat", "Chat", "CHAT", "chatdeepseek" }) do
			local result = fuzzy.fuzzy(query, #query, {
				lsp = ranked,
				copilot = {
					{
						label = "chat = ChatDeepSeek(",
						source_id = "copilot",
						score_offset = config.sources.providers.copilot.score_offset,
					},
				},
			}, "prefix")
			assert(result[1].source_id == "copilot", query .. " 应优先显示 AI 候选")
			assert(result[2].label == "ChatDeepSeek", query .. " 的 LSP 候选应优先显示类")
			local lsp_only = fuzzy.fuzzy(query, #query, { lsp = ranked }, "prefix")
			assert(lsp_only[1].label == "ChatDeepSeek", "没有 AI 候选时类应排第一")
		end
		ranked[#ranked + 1] = transform(ctx, { { label = "chat", kind = kinds.Variable } })[1]
		assert(
			fuzzy.fuzzy("chat", 4, { lsp = ranked }, "prefix")[1].kind == kinds.Variable,
			"完全匹配变量仍应优先"
		)
		vim.bo[buf].filetype = "lua"
		assert(transform(ctx, original) == original, "不能改变其他语言的 LSP 排序加分")
		vim.api.nvim_buf_delete(buf, { force = true })
	end
	for _, lang in ipairs({ "json", "json5" }) do
		for _, file in ipairs(vim.fn.globpath("queries/" .. lang, "*.scm", false, true)) do
			vim.treesitter.query.parse(lang, table.concat(vim.fn.readfile(file), "\n"))
		end
	end
	assert(#errors == 0, table.concat(errors, "\n"))
end, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
end
io.stdout:write("插件配置集成检查通过（AI 请求与实际语言服务会话未覆盖）\n")
io.stdout:flush()
vim.cmd("qa!")
