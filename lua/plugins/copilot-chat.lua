return {
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		enabled = true,
		build = ":Copilot auth",
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
		opts = {
			model = "gpt-4.1", -- Default model to use, see ':CopilotChatModels' for available models (can be specified manually in prompt via $).
			resources = "selection", -- Default resources to share with LLM (can be specified manually in prompt via #).
			language = "Chinese", -- Default language to use for answers
			--自动进入插入模式
			auto_insert_mode = false,
			insert_at_end = true,
			headers = {
				user = GlobalUtil.icons.kinds.User, -- Header to use for user questions
				assistant = GlobalUtil.icons.kinds.Copilot, -- Header to use for AI answers
				tool = GlobalUtil.icons.kinds.Tool, -- Header to use for tool calls
			},
			separator = "——",
			window = {
				-- layout = 'float',
				-- width = 0.4,
				border = "double",
			},

			prompts = {
				Translate = {
					prompt = "Translate selected code comments into Chinese.",
					mapping = "<leader>at",
				},
				-- MyCustomPrompt = {
				-- 	prompt = "Explain how it works.",
				-- 	system_prompt = "You are very good at explaining stuff",
				-- 	mapping = "<leader>ccmc",
				-- 	description = "My custom prompt description",
				-- },
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
					register = '"', -- Default register to use for yanking
				},
				show_diff = {
					normal = "gd",
					full_diff = false, -- Show full diff instead of unified diff when showing diff window
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
		},
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
					chat.ask("解释这部分代码", {
						selection = select.visual,
						window = {
							layout = "float",
							relative = "cursor",
							width = 1,
							height = 0.4,
							row = 1,
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
			vim.api.nvim_create_autocmd("BufEnter", {
				pattern = "copilot-chat",
				callback = function()
					vim.opt_local.relativenumber = false
					vim.opt_local.number = false
				end,
			})
		end,
	},
}
