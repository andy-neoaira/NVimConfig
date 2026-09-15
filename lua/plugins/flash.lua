return {
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		-- @type Flash.Config
		opts = {
			highlight = {
				-- show a backdrop with hl FlashBackdrop
				backdrop = true,
			},
			modes = {
				char = {
					keys = {},
				},
				-- 开启搜索增强
				search = {
					enabled = true,
				},
			},
		},
		keys = function()
			return {
				{
					"f",
					mode = { "n", "x", "o" },
					function()
						require("flash").jump()
					end,
					desc = "Flash",
				},
				{
					"F",
					mode = { "n", "x", "o" },
					function()
						require("flash").treesitter()
					end,
					desc = "Flash Treesitter",
				},
			}
		end,
	},
}
