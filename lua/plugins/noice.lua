return {
	"folke/noice.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	event = "VeryLazy",
	opts = {
		lsp = {
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
				["cmp.entry.get_documentation"] = true,
			},
		},
		routes = {
			{
				filter = {
					event = "msg_show",
					any = {
						{ find = "%d+L, %d+B" },
						{ find = "; after #%d+" },
						{ find = "; before #%d+" },
					},
				},
				view = "mini",
			},
			-- LSP hover 无信息时的提示，静默处理（可能经由 notify / lsp / msg_show 三条路径）
			{
				filter = {
					any = {
						{ event = "notify", find = "No information available" },
						{ event = "lsp", find = "No information available" },
						{ event = "msg_show", find = "No information available" },
					},
				},
				opts = { skip = true },
			},
			-- copilot.lua 在切换工作区时会主动 stop 旧客户端（SIGTERM → exit 143），
			-- 这是预期行为，不展示警告。
			{
				filter = {
					event = "notify",
					find = "Client copilot quit with exit code 143",
				},
				opts = { skip = true },
			},
		},
		presets = {
			bottom_search = true,
			command_palette = true,
			long_message_to_split = true,
		},
	},
    -- stylua: ignore
    keys = {
        { "<leader>sn",  "",                                                                            desc = "+noice" },
        { "<leader>snl", function() require("noice").cmd("last") end,                                   desc = "Noice Last Message" },
        { "<leader>snh", function() require("noice").cmd("history") end,                                desc = "Noice History" },
        { "<leader>sna", function() require("noice").cmd("all") end,                                    desc = "Noice All" },
        { "<leader>snd", function() require("noice").cmd("dismiss") end,                                desc = "Dismiss All" },
        { "<leader>snt", function() require("noice").cmd("pick") end,                                   desc = "Noice Picker" },
    },
	config = function(_, opts)
		-- HACK: noice shows messages from before it was enabled,
		-- but this is not ideal when Lazy is installing plugins,
		-- so clear the messages in this case.
		if vim.o.filetype == "lazy" then
			vim.cmd([[messages clear]])
		end
		require("noice").setup(opts)
	end,
}
