local function moonshot_api_key()
	local key = vim.env.NVIM_AI_API_KEY
	if type(key) ~= "string" or key == "" then
		error("未设置环境变量 NVIM_AI_API_KEY")
	end
	return key:gsub("^%s*[Bb]earer%s+", ""):gsub("%s+$", "")
end

local function volcano_api_key()
	local key = vim.env.NVIM_VOLCE_AI_API_KEY
	if type(key) ~= "string" or key == "" then
		error("未设置环境变量 NVIM_VOLCE_AI_API_KEY")
	end
	return key:gsub("^%s*[Bb]earer%s+", ""):gsub("%s+$", "")
end

return {
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		enabled = true,
		-- 认证由用户显式执行 :Copilot auth，安装/更新插件不打开授权流程。
		event = "BufReadPost",
		opts = {
			suggestion = {
				enabled = false,
				auto_trigger = true,
				hide_during_completion = true,
				keymap = {
					accept = false,
				},
			},
			panel = { enabled = false },
			filetypes = {
				markdown = false,
				help = true,
			},
		},
	},
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		branch = "main",
		cmd = "CopilotChat",
		build = "make tiktoken",
		dependencies = {
			{ "nvim-lua/plenary.nvim", branch = "master" },
		},
		opts = function()
			local provider_helpers = require("CopilotChat.config.providers")

			return {
				model = "glm-5.3",
				providers = {
					-- Copilot 仅用于代码补全；CopilotChat 通过第三方 OpenAI 兼容 API 请求模型。
					copilot = { disabled = true },
					moonshot = {
						get_url = function()
							return "https://api.moonshot.cn/v1/chat/completions"
						end,
						get_headers = function()
							return {
								Authorization = "Bearer " .. moonshot_api_key(),
								["Content-Type"] = "application/json",
							}
						end,
						get_models = function()
							return {
								{
									id = "kimi-k2.7-code",
									name = "Kimi K2.7 Code",
									streaming = true,
									tools = true,
								},
							}
						end,
						prepare_input = function(inputs, opts)
							local request, headers = provider_helpers.copilot.prepare_input(inputs, opts)
							-- kimi-k2.7-code 仅接受以下固定采样参数。
							request.temperature = 1
							request.top_p = 0.95
							return request, headers
						end,
						prepare_output = function(output, opts)
							local response = provider_helpers.copilot.prepare_output(output, opts)
							-- Kimi 的思考过程不写入 CopilotChat，只显示最终答案。
							response.reasoning = nil
							return response
						end,
					},
					-- 火山方舟 Coding Plan：必须使用 /api/coding/v3 端点与套餐模型名，按订阅额度抵扣。
					volcano = {
						get_url = function()
							return "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions"
						end,
						get_headers = function()
							return {
								Authorization = "Bearer " .. volcano_api_key(),
								["Content-Type"] = "application/json",
							}
						end,
						get_models = function()
							return {
								{
									id = "glm-5.3-flash",
									name = "GLM-5.3-Flash (Coding Plan)",
									streaming = true,
									tools = true,
								},
								{
									id = "glm-5.3",
									name = "GLM-5.3 (Coding Plan)",
									streaming = true,
									tools = true,
								},
							}
						end,
						prepare_input = function(inputs, opts)
							return provider_helpers.copilot.prepare_input(inputs, opts)
						end,
						prepare_output = function(output, opts)
							local response = provider_helpers.copilot.prepare_output(output, opts)
							-- GLM 的思考过程不写入 CopilotChat，只显示最终答案。
							response.reasoning = nil
							return response
						end,
					},
				},
				resources = "selection",
				language = "Chinese",
				auto_insert_mode = false,
				insert_at_end = true,
				headers = {
					user = GlobalUtil.icons.kinds.User,
					assistant = GlobalUtil.icons.kinds.Copilot,
					tool = GlobalUtil.icons.kinds.Tool,
				},
				separator = "——",
				window = {
					border = "double",
				},
				prompts = {
					Translate = {
						prompt = "Translate selected code comments into Chinese.",
						mapping = "<leader>at",
					},
				},
				mappings = {
					close = {
						normal = "q",
						insert = "<c-a>",
					},
					complete = {
						detail = "Use @<Tab> or /<Tab> for options.",
						insert = "<Tab>",
					},
					reset = {
						normal = "<C-x>",
						insert = "<C-x>",
					},
					submit_prompt = {
						normal = "<CR>",
						insert = "<C-s>",
					},
					toggle_sticky = {
						normal = "grr",
					},
					clear_stickies = {
						normal = "grx",
					},
					accept_diff = {
						normal = "<C-y>",
						insert = "<C-y>",
					},
					jump_to_diff = {
						normal = "gj",
					},
					quickfix_answers = {
						normal = "gqa",
					},
					quickfix_diffs = {
						normal = "gqd",
					},
					yank_diff = {
						normal = "gy",
						register = '"',
					},
					show_diff = {
						normal = "gd",
						full_diff = false,
					},
					show_info = {
						normal = "gi",
					},
					show_context = {
						normal = "gc",
					},
					show_help = {
						normal = "gh",
					},
				},
			}
		end,
		keys = {
			{ "<c-s>", "<CR>", ft = "copilot-chat", desc = "Submit Prompt", remap = true },
			{
				"<C-a>",
				function()
					local select = require("CopilotChat.select")
					local mode = vim.api.nvim_get_mode().mode
					return require("CopilotChat").toggle(
						(mode == "v" or mode == "V") and { selection = select.visual } or nil
					)
				end,
				desc = "Toggle (CopilotChat)",
				remap = true,
				mode = { "n", "v", "i" },
			},
			{ "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
			{
				"<leader>aa",
				function()
					local select = require("CopilotChat.select")
					local mode = vim.api.nvim_get_mode().mode
					return require("CopilotChat").toggle(
						(mode == "v" or mode == "V") and { selection = select.visual } or nil
					)
				end,
				desc = "Toggle (CopilotChat)",
				mode = { "n", "v" },
			},
			{
				"<leader>ai",
				function()
					local chat = require("CopilotChat")
					local select = require("CopilotChat.select")
					local win = vim.api.nvim_get_current_win()
					local win_height = vim.api.nvim_win_get_height(win)
					local cursor = vim.api.nvim_win_get_cursor(win)
					local textoff = vim.fn.getwininfo(win)[1].textoff
					-- inline 浮窗按当前窗口实际尺寸定位，避开侧边栏与行号列；
					-- 光标贴近底部时改为在光标上方展开，保证输入栏可见。
					local height = math.max(10, math.floor(win_height * 0.4))
					local row = cursor[1]
					if row + height > win_height then
						row = math.max(1, cursor[1] - height - 1)
					end
					chat.ask("解释这部分代码", {
						selection = select.visual,
						window = {
							layout = "float",
							relative = "win",
							width = vim.api.nvim_win_get_width(win) - textoff,
							height = height,
							row = row,
							col = textoff,
						},
					})
				end,
				mode = { "v", "n" },
				desc = "CopilotChat - Inline chat",
			},
			{
				"<leader>ax",
				function()
					require("CopilotChat").reset()
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
				end,
				desc = "Clear (CopilotChat)",
				mode = { "n", "v" },
			},
			{
				"<leader>aq",
				function()
					local input = vim.fn.input("Quick Chat: ")
					if input ~= "" then
						local select = require("CopilotChat.select")
						local mode = vim.api.nvim_get_mode().mode
						require("CopilotChat").ask(
							input,
							(mode == "v" or mode == "V") and { selection = select.visual } or nil
						)
					end
				end,
				desc = "Quick Chat (CopilotChat)",
				mode = { "n", "v" },
			},
			{
				"<leader>ap",
				function()
					local chat = require("CopilotChat")
					local select = require("CopilotChat.select")
					local mode = vim.api.nvim_get_mode().mode
					chat.select_prompt((mode == "v" or mode == "V") and { selection = select.visual } or nil)
				end,
				desc = "Prompt Actions (CopilotChat)",
				mode = { "n", "v" },
			},
			{
				"<leader>am",
				function()
					return require("CopilotChat").select_model()
				end,
				desc = "Select Models (CopilotChat)",
				mode = { "n", "v" },
			},
		},
		config = function(_, opts)
			local chat = require("CopilotChat")
			chat.setup(opts)

			-- 原生补全被确认后，CopilotChat 的 TextChangedI 会再次触发同一个精确匹配项。
			-- 取消这次防抖任务，让 <Tab>/<CR> 的“确认”表现为插入候选并关闭菜单。
			local function stop_completion_retrigger()
				vim.schedule(function()
					local ok, utils = pcall(require, "CopilotChat.utils")
					if not ok then
						return
					end

					local timer = utils.timers and utils.timers.copilot_chat_complete
					if timer then
						pcall(timer.stop, timer)
						pcall(timer.close, timer)
						utils.timers.copilot_chat_complete = nil
					end
				end)
			end

			vim.api.nvim_create_autocmd("BufEnter", {
				pattern = "copilot-chat",
				callback = function(event)
					vim.opt_local.relativenumber = false
					vim.opt_local.number = false
					vim.opt_local.completeopt:remove("noselect")
					vim.opt_local.completeopt:append({ "menuone", "noinsert" })

					-- MiniPairs 的全局 <CR> 映射不会确认原生补全，因此在聊天缓冲区单独覆盖。
					vim.keymap.set("i", "<CR>", function()
						if vim.fn.pumvisible() == 1 then
							vim.api.nvim_feedkeys(vim.keycode("<C-y>"), "n", false)
							return
						end
						vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
					end, { buffer = event.buf, desc = "CopilotChat confirm completion" })

					if not vim.b[event.buf].copilot_chat_completion_done then
						vim.b[event.buf].copilot_chat_completion_done = true
						vim.api.nvim_create_autocmd("CompleteDone", {
							buffer = event.buf,
							callback = stop_completion_retrigger,
						})
					end
				end,
			})
		end,
	},
}
