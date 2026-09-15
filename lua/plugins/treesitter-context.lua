-- 仅在 JSON / JSON5 / JSONC 文件中启用，用于显示键路径与数组层级
return {
	"nvim-treesitter/nvim-treesitter-context",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		enable = true,
		max_lines = 5, -- 最多显示 5 行上下文
		mode = "cursor", -- 跟随光标所在的上下文
		trim_scope = "outer", -- 超出 max_lines 时裁剪外层作用域
		-- 按 filetype 过滤：只在 JSON 相关文件中 attach
		on_attach = function(buf)
			local ft = vim.bo[buf].filetype
			return ft == "json" or ft == "json5" or ft == "jsonc"
		end,
	},
	keys = {
		{
			"[c",
			function()
				require("treesitter-context").go_to_context(vim.v.count1)
			end,
			desc = "跳转到上下文（Treesitter Context）",
		},
	},

	-- 可选：在插件加载时从自定义目录加载 queries
	config = function(_, opts)
		local tsq = require("utils.ts_queries")
		-- 使用环境变量 TTS_QUERIES 或默认 ~/.config/nvim/queries_extra
		local custom = vim.env.TTS_QUERIES or (vim.fn.stdpath("config") .. "/queries_extra")
		tsq.load_dir(custom)
		-- 然后按常规使用 opts
		require("treesitter-context").setup(opts)
	end,
}
