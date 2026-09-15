-- 工具安装与 LSP 启动分离，普通启动不刷新远端注册表。
return {
	{
		"mason-org/mason.nvim",
		cmd = { "Mason", "ToolsInstall" },
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		build = ":MasonUpdate",
		opts_extend = { "ensure_installed" },
		opts = {
			ensure_installed = {
				"stylua",
				"shfmt",
				"js-debug-adapter",
				"debugpy",
				"neocmakelsp",
				"dockerfile-language-server",
				"docker-compose-language-service",
				"nushell",
				"vue-language-server",
				"prettier",
				--"typescript-language-server",
				"jdtls",
				"google-java-format",
				"lua-language-server",
				"json-lsp",
				"vtsls",
				"basedpyright",
				"ruff",
				"taplo",
				"markdown-oxide",
			},
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(_, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			mr:on("package:install:success", function()
				vim.defer_fn(function()
					-- trigger FileType event to possibly load this newly installed LSP server
					require("lazy.core.handler.event").trigger({
						event = "FileType",
						buf = vim.api.nvim_get_current_buf(),
					})
				end, 100)
			end)

			vim.api.nvim_create_user_command("ToolsInstall", function()
				mr.refresh(function()
					for _, tool in ipairs(opts.ensure_installed) do
						local ok, p = pcall(mr.get_package, tool)
						if not ok then
							GlobalUtil.warn("Mason 包不可用: " .. tool)
						elseif not p:is_installed() and not p:is_installing() then
							p:install()
						end
					end
				end)
			end, { desc = "安装配置中声明的 LSP、格式化与调试工具" })
		end,
	},
}
