return {
	"MeanderingProgrammer/render-markdown.nvim",
	lazy = false,
	init = function()
		if vim.fn.exists(":Markview") == 0 then
			vim.api.nvim_create_user_command("Markview", function()
				require("utils.image").toggle_markdown()
			end, { desc = "兼容旧的 Markview 切换命令" })
		end
	end,
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"mini.icons",
	},
	opts = {
		enabled = true,
		render_modes = { "n", "c" },
		file_types = { "markdown" },
		anti_conceal = {
			enabled = false,
		},
		win_options = {
			conceallevel = {
				default = vim.o.conceallevel,
				rendered = 2,
			},
			-- Normal/Command 模式下保持光标行 conceal，避免 Checkbox 的列表符号和
			-- 右方括号因原始语法显露而残留。Insert 模式不 conceal，仍可编辑原文。
			-- Mermaid 已由下方 code.disable 排除，不会受此设置影响。
			concealcursor = {
				default = vim.o.concealcursor,
				rendered = "nc",
			},
		},
		heading = {
			sign = false,
		},
		checkbox = {
			enabled = true,
			render_modes = false,
			bullet = false,
			left_pad = 0,
			right_pad = 1,
			unchecked = {
				icon = "󰄱 ",
				highlight = "RenderMarkdownUnchecked",
				scope_highlight = nil,
			},
			checked = {
				icon = "󰱒 ",
				highlight = "RenderMarkdownChecked",
				scope_highlight = nil,
			},
			custom = {
				todo = { raw = "[/]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo", scope_highlight = nil },
			},
			scope_priority = nil,
		},
		code = {
			sign = false,
			-- 完全跳过 mermaid 代码块渲染，交由 snacks.nvim 处理图表
			-- 这样 render-markdown 不在该区域放置 extmarks，图片可正常显示
			disable = { "mermaid" },
		},
	},
}
