return {
	"mikesmithgh/kitty-scrollback.nvim",
	enabled = true,
	lazy = true,
	cmd = {
		"KittyScrollbackGenerateKittens",
		"KittyScrollbackCheckHealth",
		"KittyScrollbackGenerateCommandLineEditing",
	},
	event = { "User KittyScrollbackLaunch" },
	-- version = '^6.0.0',
	opts = {
		default = {
			keymaps_enabled = true,
			restore_options = true,
			status_window = { enabled = true, autoclose = true, show_timer = true },
			paste_window = { yank_register = '"', yank_register_enabled = true },
			kitty_get_text = { ansi = true, extent = "all", clear_selection = true },
		},
		last_cmd = { kitty_get_text = { extent = "last_cmd_output" } },
		noansi = { kitty_get_text = { ansi = false, extent = "all" } },
	},
	config = function(_, opts)
		require("kitty-scrollback").setup(opts)
	end,
}
