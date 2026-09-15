return {
	"andy-neoaira/nvim-filetype",
	cmd = "FTSelect",
	-- dev = true,
	opts = {
		-- Pinned filetypes always shown first, in the order listed
		filetypes = { "json5", "json", "python", "java" },
		-- When false, only pinned filetypes are shown
		show_all_filetypes = true,
		-- Icon shown next to the current filetype
		selected_icon = " ",
	},
}
